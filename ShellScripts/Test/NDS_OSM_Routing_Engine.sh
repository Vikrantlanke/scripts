#!/usr/bin/env bash

# Global Variables
GRAPHHOPPER_VERSION=2.3
DATA_MOUNT_POINT="/map"

# Status check for commands
status_check() {
  if [ $1 == 0 ]; then
    echo "$2 successfully!"
  else
    echo "$2 failed!"
    exit 1
  fi
}

#Install Base Packages
install_app_packages() {
  #Install openjdk
  sudo apt install openjdk-11-jre-headless -y
  status_check $? "Java Packages installation"

  #install blobfuse
  ubuntu_release=`lsb_release -r | awk -F' ' '{print $2}'`
  if [ ! -f packages-microsoft-prod.deb ]; then
    wget https://packages.microsoft.com/config/ubuntu/$ubuntu_release/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
  fi
  sudo apt-get update
  sudo apt-get install blobfuse -y
  status_check $? "Blobfuse Packages installation"

  #atomic1 library
  sudo apt install libatomic1 -y
  status_check $? "Atomic Lib Packages installation"
}

#Mount the Dataset volume
mount_data(){
  [ ! -d "/server/" ] && mkdir /server/
  touch /server/fuse_connection.cfg
  echo "accountName $1" >> /server/fuse_connection.cfg
  echo "authType SPN" >>  /server/fuse_connection.cfg
  echo "servicePrincipalClientId $2" >> /server/fuse_connection.cfg
  echo "servicePrincipalTenantId $3" >> /server/fuse_connection.cfg
  echo "containerName $4" >> /server/fuse_connection.cfg
  chmod 600 /server/fuse_connection.cfg
  [ ! -d $DATA_MOUNT_POINT ] && sudo mkdir $DATA_MOUNT_POINT
  sudo blobfuse $DATA_MOUNT_POINT --tmp-path=/mnt/resource/blobfusetmp  --config-file=/server/fuse_connection.cfg \
       -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120
  status_check $? "Storage Mounting"
}

download_nds_software(){
  # Download Software from Azure Blob Storage
  temp_mount_point="/mnt/nds_software"
  [ ! -d "/server/" ] && sudo mkdir /server/
  sudo touch /server/nds_software.cfg
  echo "accountName $1" >> /server/nds_software.cfg
  echo "authType SPN" >> /server/nds_software.cfg
  echo "servicePrincipalClientId  $2" >> /server/nds_software.cfg
  echo "servicePrincipalTenantId $3" >> /server/nds_software.cfg
  echo "containerName $4" >> /server/nds_software.cfg
  chmod 600 /server/nds_software.cfg
  sudo mkdir -p $temp_mount_point
  sudo blobfuse $temp_mount_point --tmp-path=/mnt/resource/nds_software  --config-file=/server/nds_software.cfg \
       -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120
  status_check $? "NDS Storage Mounting"
  sudo cp -af $temp_mount_point/* /server/
  sudo cp -af $temp_mount_point/ConvEngConfig.sqlite /home/mapmetrics_sa/ConvEngConfig.sqlite
  sudo chown -R mapmetrics_sa:mapmetrics_sa /server/*
  sudo chmod 777 /server/*
  rm -rf /server/nds_software.cfg
  /bin/umount $temp_mount_point
}

start_nds_routing_engine(){
  /usr/bin/java -jar /server/phonetics-converter-http-server-1.0.4264.jar &
  status_check $? "phonetics converter start"
  /server/NKWorkerEngine serverPort=9090 map=$DATA_MOUNT_POINT phoneticsBaseUrl=http://127.0.0.1:8080 preLoadCache=1 &
  status_check $? "NKWorkerEngine start"
  /server/routeservice -listen-addr :6599 -check-interval 15s -max-error-count 120 -endpoint 127.0.0.1:9090 &
  status_check $? "routing service start"
}

download_osm_software() {
  [ ! -d "/server/" ] && mkdir /server/
  sudo chown -R mapmetrics_sa:mapmetrics_sa /server
  sudo chmod 777 /server
  #download graph hopper artifact
  wget -O /server/graphhopper-web.jar https://graphhopper.com/public/releases/graphhopper-web-${GRAPHHOPPER_VERSION}.jar
  status_check $? "Graphhopper download"
  #download graph hopper configuration
  wget -O /server/config.yml https://github.com/tomtom-internal/innovations-map-metrics/blob/master/route-engine/osm/config-${GRAPHHOPPER_VERSION}.yml
}


start_osm_routing_engine(){
  #extract OSM pbf file path
  # shellcheck disable=SC2006
  osm_pbf_file_path=`find $DATA_MOUNT_POINT| grep pbf`

  /usr/bin/java -Xmx32G -Ddw.graphhopper.datareader.file="$osm_pbf_file_path" -jar /server/graphhopper-web.jar server /server/config.yml
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
if [ -z "$routingEngineType" ] || [ -z "$spClientID" ] || [ -z "$spTenantID" ] || [ -z "$spClientSecret" ] || [ -z "$accountName" ] || [ -z "$containerName" ] || [ -z "$rtengaccountName" ] || [ -z "$rtengcontainerName" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# Provide Azure SP Secret in file
sudo /bin/su -c "echo AZURE_STORAGE_SPN_CLIENT_SECRET=$spClientSecret >> /etc/environment"

# Actions based on Routing Engine
if [[ "$routingEngineType" == "OSM" ]];then
  install_app_packages
  mount_data "$accountName" "$spClientID" "$spTenantID" "$containerName"
  download_osm_software
  start_osm_routing_engine
elif [[ "$routingEngineType" == "TTNDS" ]];then
  install_app_packages
  mount_data "$accountName" "$spClientID" "$spTenantID" "$containerName"
  download_nds_software "$rtengaccountName" "$spClientID" "$spTenantID" "$rtengcontainerName"
  start_nds_routing_engine
else
  echo "Invalid Routing Engine"
  exit 1
fi