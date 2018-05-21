#!/usr/bin/python

import boto3


if __name__ == '__main__':
    print("Delete Security Groups:-")
    unused_SG=[]

    ec2 = boto3.client('ec2')
    for id in unused_SG:
        response=ec2.delete_security_group(GroupId=id)
        if response["ResponseMetadata"]["HTTPStatusCode"] != 200:
            print(id)
        else:
            print("deleted successfully")
