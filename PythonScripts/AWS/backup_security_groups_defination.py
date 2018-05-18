#!/usr/bin/python

import boto3
import json

if __name__ == '__main__':
    print("backup sg")
    ec2 = boto3.client('ec2')
    SGs= [u'sg-0572c07e', u'sg-07b2f57d', u'sg-086db273', u'sg-0939c374', u'sg-09ef2372', u'sg-10aa6f6d', u'sg-11fb9576', u'sg-14a16469', u'sg-1692c06d', u'sg-16d7cb6e', u'sg-1be07b60', u'sg-238f535b', u'sg-23edeb59', u'sg-271a7d5f', u'sg-29cd1c52', u'sg-31b2f64b', u'sg-324b2e4a', u'sg-32ccbb55', u'sg-33790249', u'sg-34eb704f', u'sg-36d49d4e', u'sg-3a396241', u'sg-3d1fd05a', u'sg-3eca8a58', u'sg-40cea73b', u'sg-43a6543e', u'sg-47444a23', u'sg-4b0db831', u'sg-4c131236', u'sg-4c459337', u'sg-4d444a29', u'sg-4d9f1836', u'sg-506bd92b', u'sg-50cb8b36', u'sg-513cf336', u'sg-51444a35', u'sg-541ddb29', u'sg-543a672f', u'sg-54ad7c2f', u'sg-57c9052c', u'sg-5b0cca26', u'sg-611eab1b', u'sg-61d2651a', u'sg-62482d1a', u'sg-64a18b1f', u'sg-69b00b0f', u'sg-6b6b6511', u'sg-75521d13', u'sg-7736870c', u'sg-7865d501', u'sg-79646a03', u'sg-82a363f8', u'sg-86aa1bfd', u'sg-967a11ee', u'sg-973395f0', u'sg-97b04bec', u'sg-9bfa4de0', u'sg-9f8bf4e5', u'sg-a2222dda', u'sg-a236aad9', u'sg-a253b6df', u'sg-a64f2ade', u'sg-a8106fd2', u'sg-a97813d1', u'sg-aac00fcd', u'sg-acfc57d7', u'sg-b444a5d2', u'sg-b83177c2', u'sg-bb1b66c0', u'sg-c07912b8', u'sg-c6f46fbd', u'sg-c86435b3', u'sg-c92e45b2', u'sg-ccce4eb7', u'sg-d191d0b7', u'sg-d210bea9', u'sg-d457c8af', u'sg-d7929db3', u'sg-ddec20a6', u'sg-e4d1b49d', u'sg-e5c0a59e', u'sg-e99c7293', u'sg-eb1b7c93', u'sg-f09ba796', u'sg-f3bef595', u'sg-f6e08f8d', u'sg-fcdc8487', u'sg-fd552e87', u'sg-feaaee84']

    for id in SGs:
        response=ec2.describe_security_groups(GroupIds=[id])
        with open(id+'.txt','w') as outfile:
            json.dump(response["SecurityGroups"],outfile)

        print(json.dumps(response["SecurityGroups"]))