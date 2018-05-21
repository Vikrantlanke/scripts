#Python Scripts

Details per script: 

1) used_unused_security_groups.py
It will check used security groups by EC2,ELB,RDS. For other services feel free to extend the script.   
Pre requisites: python, python module - boto, boto3, json. 

2) backup_security_groups_defination.py
It will backup SG definations into multiple files. Files are generated with name of security group. 
Pre requisites: python, python module - boto3

3) delete_unused_security_groups.py
Delete Unused Security Groups. It will not delete security groups which depends on any other resource or used by any resporce. 
Pre requisites: python, python module - boto3
