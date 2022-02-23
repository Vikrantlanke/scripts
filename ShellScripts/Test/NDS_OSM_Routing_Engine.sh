#!/usr/bin/env bash

# Global Variables
GRAPHHOPPER_VERSION=2.3
# Routing Engine Data directory
DATA_MOUNT_POINT="/map"
# Software Installation directory
SERVER_DIRECTORY="/server"

# Status check for commands
status_check() {
  touch /var/log/NDS_OSM_Routing_Engine.log /var/log/NDS_OSM_Routing_Engine_err.log
  if [ "$1" == "0" ]; then
    echo "$2 successfully!" >> /var/log/NDS_OSM_Routing_Engine.log
  else
    echo "$2 failed!" >> /var/log/NDS_OSM_Routing_Engine_err.log
    exit 1
  fi
}

#Replace Line in the File
replace_line(){
  sed -i "s@$1.*@$2@g" "$3"
}

#Install Base Packages
install_app_packages() {
  #Install openjdk
  sudo apt update
  sudo apt install openjdk-11-jre-headless -y
  status_check $? "Java Packages installation"

  #install blobfuse
  ubuntu_release=$(lsb_release -r | awk -F' ' '{print $2}')
  if [ ! -f packages-microsoft-prod.deb ]; then
    wget https://packages.microsoft.com/config/ubuntu/"$ubuntu_release"/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
  fi
  sudo apt-get update
  sudo apt-get install blobfuse -y
  status_check $? "Blobfuse Packages installation"

  #atomic1 library
  sudo apt install libatomic1 -y
  status_check $? "Atomic Lib Packages installation"
}

#Create Required Directory
create_directory(){
  [ ! -d "$SERVER_DIRECTORY" ] && sudo mkdir $SERVER_DIRECTORY
  sudo chown -R mapmetrics_sa:mapmetrics_sa $SERVER_DIRECTORY
  sudo chmod -R 777 $SERVER_DIRECTORY
  [ ! -d $DATA_MOUNT_POINT ] && sudo mkdir $DATA_MOUNT_POINT
  sudo chown -R mapmetrics_sa:mapmetrics_sa $DATA_MOUNT_POINT
  sudo chmod -R 777 $DATA_MOUNT_POINT
}

#Mount the Dataset volume
mount_data(){
  touch $SERVER_DIRECTORY/fuse_connection.cfg
  {
  echo "accountName $1"
  echo "authType SPN"
  echo "servicePrincipalClientId $2"
  echo "servicePrincipalTenantId $3"
  echo "containerName $4"
  } >> $SERVER_DIRECTORY/fuse_connection.cfg
  chmod 600 $SERVER_DIRECTORY/fuse_connection.cfg
  sudo blobfuse $DATA_MOUNT_POINT --tmp-path=/mnt/resource/blobfusetmp  --config-file=$SERVER_DIRECTORY/fuse_connection.cfg \
       -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120
  status_check $? "Storage Mounting"
}

download_nds_software(){
  # Download Software from Azure Blob Storage
  temp_mount_point="/mnt/nds_software"
  sudo touch $SERVER_DIRECTORY/nds_software.cfg
  {
    echo "accountName $1"
    echo "authType SPN"
    echo "servicePrincipalClientId  $2"
    echo "servicePrincipalTenantId $3"
    echo "containerName $4"
  } >> $SERVER_DIRECTORY/nds_software.cfg
  chmod 600 $SERVER_DIRECTORY/nds_software.cfg
  sudo mkdir -p $temp_mount_point
  sudo blobfuse $temp_mount_point --tmp-path=/mnt/resource/nds_software  --config-file=$SERVER_DIRECTORY/nds_software.cfg \
       -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120
  status_check $? "NDS Storage Mounting"
  sudo cp -af $temp_mount_point/* $SERVER_DIRECTORY/
  status_check $? "NDS Data Copy"
  sudo cp -af $temp_mount_point/ConvEngConfig.sqlite /home/mapmetrics_sa/ConvEngConfig.sqlite
  status_check $? "SQLite File Copy"

  #clean temporary files
  /bin/umount $temp_mount_point
  status_check $? "NDS Storage Unmounting"
  rm -rf $SERVER_DIRECTORY/nds_software.cfg  $temp_mount_point
  status_check $? "Remove Temporary Data"
}

start_nds_routing_engine(){
  # Generate the log data for NDS
  touch /var/log/phonetics-converter-http-server.log /var/log/NKWorkerEngine.log  /var/log/routeservice.log
  sudo chown mapmetrics_sa:mapmetrics_sa /var/log/phonetics-converter-http-server.log /var/log/NKWorkerEngine.log  /var/log/routeservice.log
  cd /home/mapmetrics_sa && /usr/bin/java -jar /server/phonetics-converter-http-server-1.0.4264.jar &> /var/log/phonetics-converter-http-server.log & disown
  status_check $? "phonetics converter start"
  /server/NKWorkerEngine serverPort=9090 map=$DATA_MOUNT_POINT phoneticsBaseUrl=http://127.0.0.1:8080 preLoadCache=1 &> /var/log/NKWorkerEngine.log & disown
  status_check $? "NKWorkerEngine start"
  /server/routeservice -listen-addr :6599 -check-interval 15s -max-error-count 120 -endpoint 127.0.0.1:9090 &> /var/log/routeservice.log & disown
  status_check $? "routing service start"
}

download_osm_software() {
  # Log Directory
  log_directory="/var/log/graphhopper"
  sudo mkdir -p "$log_directory"
  #download graph hopper artefact
  wget -O $SERVER_DIRECTORY/graphhopper-web.jar https://roadrunner2storage.blob.core.windows.net/devops/graphhopper-web-${GRAPHHOPPER_VERSION}.jar
  status_check $? "Graphhopper download"
  #download graph hopper config
  wget -O $SERVER_DIRECTORY/config.yml https://roadrunner2storage.blob.core.windows.net/devops/config-example-${GRAPHHOPPER_VERSION}.yml

  #change graph hopper config
  replace_line "graph.location" "graph.location: /opt/graph-cache" $SERVER_DIRECTORY/config.yml
  replace_line "graph.flag_encoders:" "graph.flag_encoders: car|block_private=false" $SERVER_DIRECTORY/config.yml
  replace_line "port: 8989" "port: 8080" $SERVER_DIRECTORY/config.yml
  replace_line "bind_host: localhost" "bind_host: 0.0.0.0" $SERVER_DIRECTORY/config.yml
  replace_line "port: 8990" "port: 8090" $SERVER_DIRECTORY/config.yml
  replace_line "current_log_filename:" "current_log_filename: $log_directory/graphhopper.log" $SERVER_DIRECTORY/config.yml
  replace_line "archived_log_filename_pattern:" "archived_log_filename_pattern: $log_directory/graphhopper-%d.log.gz" $SERVER_DIRECTORY/config.yml
}


start_osm_routing_engine(){
  #Copy graph-cache on local machine
  sudo cp -af $DATA_MOUNT_POINT/graph-cache/ /opt/
  #extract OSM pbf file path
  osm_pbf_file_path=$(find $DATA_MOUNT_POINT| grep -i pbf)
  sudo /usr/bin/java -Xmx42G -Ddw.graphhopper.datareader.file="$osm_pbf_file_path" -jar /server/graphhopper-web.jar server /server/config.yml &
  status_check $? "routing service start"
}

helpFunction()
{
   echo ""
   echo "Usage: $0 -t routingEngineType -a storageAccountName -k storageAccountKey -c containerName"
   echo -e "\t-t Enter a routing Engine Type: OSM or TTNDS"
   echo -e "\t-C Enter Service Principle Client ID"
   echo -e "\t-T Enter Service Principle Tenant ID"
   echo -e "\t-S Enter Service Principle Client Secret"
   echo -e "\t-a (Data)Enter a Azure Storage Account Name."
   echo -e "\t-c (Data)Enter Azure Storage Container Name."
   echo -e "\t-r (Routing Engine)Enter a Azure Storage Account Name."
   echo -e "\t-u (Routing Engine)Enter Azure Storage Container Name."
   exit 1 # Exit script after printing help
}

# Executing the Script
while getopts "t:C:T:S:a:c:r:u:" opt
do
   case "$opt" in
      t ) routingEngineType="$OPTARG" ;;
      C ) spClientID="$OPTARG" ;;
      T ) spTenantID="$OPTARG" ;;
      S ) spClientSecret="$OPTARG" ;;
      a ) accountName="$OPTARG" ;;
      c ) containerName="$OPTARG" ;;
      r ) rtengaccountName="$OPTARG" ;;
      u ) rtengcontainerName="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$routingEngineType" ] || [ -z "$spClientID" ] || [ -z "$spTenantID" ] || [ -z "$spClientSecret" ] || [ -z "$accountName" ] || [ -z "$containerName" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# Provide Azure SP Client Secret in file
sudo /bin/su -c "echo AZURE_STORAGE_SPN_CLIENT_SECRET=$spClientSecret >> /etc/environment"

# Actions based on Routing Engine
if [[ "$routingEngineType" == "OSM" ]];then
  install_app_packages
  create_directory
  mount_data "$accountName" "$spClientID" "$spTenantID" "$containerName"
  download_osm_software
  start_osm_routing_engine
elif [[ "$routingEngineType" == "TTNDS" ]];then
  install_app_packages
  create_directory
  mount_data "$accountName" "$spClientID" "$spTenantID" "$containerName"
  download_nds_software "$rtengaccountName" "$spClientID" "$spTenantID" "$rtengcontainerName"
  start_nds_routing_engine
else
  echo "Invalid Routing Engine"
  exit 1
fi
