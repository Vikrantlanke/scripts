#!/bin/bash

users_list=`aws iam list-users | grep "UserName" | awk -F'"' '{print $4}'`

for user in  $users_list
do
    echo  "*******************************************************************************"
    echo "User Name : $user"
	access_key_info=`aws iam list-access-keys --user-name $user --output text`
	AccessKeyId=`echo $access_key_info | awk -F" " '{print $2}' `
	if [ "$AccessKeyId" != "" ]; then
	    echo "Access Key ID: $AccessKeyId"
		echo "access key last used:"
		aws iam get-access-key-last-used --access-key-id $AccessKeyId
	fi

	groups=`aws iam list-groups-for-user --user-name $user --output text | awk -F" " '{print $5}'`
	if [ "$groups" != "" ]; then
	    echo "User $user - groups attached policies"
	    for group in $groups
	    do
	        echo $group
	        aws iam list-attached-group-policies --group-name $group --output table
	    done

    	echo "User $user - groups inline policies"
	    for group in $groups
	    do
	        aws iam list-group-policies --group-name $group --output table
	    done
    fi

	echo "User $user attached policies"
	aws iam list-attached-user-policies --user-name $user --output table

	echo "User $user inline policies"
	aws iam list-user-policies --user-name $user --output table

	echo  "*******************************************************************************"
done
