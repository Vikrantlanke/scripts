#!/usr/bin/env bash

sudo apt update -y
sudo apt install openjdk-11-jre-headless -y
sudo apt install zip -y
sudo apt install unzip -y

SERVER_DIRECTORY="/service"

create_directory(){
  [ ! -d "$SERVER_DIRECTORY" ] && sudo mkdir $SERVER_DIRECTORY
  sudo chown -R mapmetrics_sa:mapmetrics_sa $SERVER_DIRECTORY
  sudo chmod -R 777 $SERVER_DIRECTORY
}


create_directory

wget -O $SERVER_DIRECTORY/innovation-trafficsign-service.jar  https://trafficsign2021.blob.core.windows.net/jars/innovation-trafficsign-service-1.0-SNAPSHOT.jar

nohup java -Xmx8g -jar $SERVER_DIRECTORY/innovation-trafficsign-service.jar > service.log &