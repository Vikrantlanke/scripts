#!/usr/bin/env bash

log_path="/var/log/vikrant-testing.log"

touch $log_path
echo `date` > $log_path
echo 'Script Executed' >> $log_path
echo $1 >> $log_path
echo $2 >> $log_path
echo $3 >> $log_path
echo $4 >> $log_path
echo '=======================' >> $log_path
