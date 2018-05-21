#!/usr/bin/python

import boto3
import json

if __name__ == '__main__':
    print("backup sg")
    ec2 = boto3.client('ec2')
    SGs=[]

    for id in SGs:
        response=ec2.describe_security_groups(GroupIds=[id])
        with open(id+'.txt','w') as outfile:
            json.dump(response["SecurityGroups"],outfile)

        print(json.dumps(response["SecurityGroups"]))
