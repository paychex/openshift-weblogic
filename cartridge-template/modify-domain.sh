#!/bin/bash
#
# Copyright 2015 Paychex, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#modify-domain.sh
#This script simplifies the process of changing some of the core WebLogic settings for a cartridge instance.
#This script allows can be used to change the WebLogic domain and the administrative user.
#Run with -h for addition help.

#functions
function passwordprompt {
	
	local newpassword1="asdf"
	local newpassword2="asdf"
	while [ 0 ]
	do
		read -s -p "Enter the new password: " newpassword1
		echo
		read -s -p "Retype to confirm: " newpassword2
		echo 
		if [[ $newpassword1 == $newpassword2 ]] 
		then
			if [[ ${#newpassword1} -gt 7 ]]
			then
				newpassword=${newpassword1}
				break
			else
				echo "Error: Password must be at least 8 characters long."
			fi
		else
			echo "Passwords do not match."
		fi
	done

}
function getnewuserinfo {

	while [ 0 ]
	do
		read -p "Enter new username: " newusername
		if [[ ${#newusername} -gt 4 ]]
		then
			break
		fi
		echo "Error: Username must be at least 5 characters long."
	done
	passwordprompt

}

function passwordchange {

	#scan current files and determine the old username
	AUTHFILE=${OPENSHIFT_WEBL_DIR}domain/security/DefaultAuthenticatorInit.ldift
	local tailnum=$(grep -n "description: This user is the default administrator." $AUTHFILE | cut -f1 -d:)
	local numline=$(wc -l < $AUTHFILE)
	local tailnum=$(expr $numline - $tailnum)
	oldusername=$(tail -n $tailnum $AUTHFILE | head -n 13 | grep "uid: " | awk '{print $2}')
	
	newusername="asdf"
	newpassword="asdf"
	if [[ -z $1 && -z $2 ]]
	then
		while [ 0 ]
		do
			
			getnewuserinfo
			read -p "Changing username to '$newusername', is this ok? " -n 1 -r
			echo
			if [[ $REPLY == 'y' || $REPLY == 'Y' ]]
			then
				break
			fi
		
		done
	else
		#check username and set var
		if [[ ${#1} -gt 4 ]]
		then
			newusername=$1
		else
			echo "Username must be at least 5 characters long."
			exit 5
		fi
		
		#check password and set var
		if [[ ${#2} -gt 7 ]]
		then
			newpassword=$2
		else
			echo "Password must be at least 8 characters."
			exit 5
		fi
		
	fi
	
	BOOTPROP=${OPENSHIFT_WEBL_DIR}domain/servers/AdminServer/security/boot.properties
	#removing the ldap db
	rm -rf ${OPENSHIFT_WEBL_DIR}domain/servers/AdminServer/data/ldap 2>/dev/null
	#write the username and password to auto start the server
	cp -f $BOOTPROP $BACKUPDIR/boot.properties.bak
	echo "username=${newusername}" > $BOOTPROP
	echo "password=${newpassword}" >> $BOOTPROP
	cp -f $BOOTPROP $BACKUPDIR/boot.properties
	cp -f $BOOTPROP ${OPENSHIFT_WEBL_DIR}domain/servers/AdminServer/security/cred
	
	#find where the admin user is located from the description entry
	headend=$(grep -n "description: This user is the default administrator." $AUTHFILE | cut -f1 -d:)
	headend=$(expr $headend - 2)
	tailend=$(wc -l < $AUTHFILE)
	tailend=$(expr $tailend - $headend)
	head -n $headend $AUTHFILE > ${OPENSHIFT_WEBL_DIR}/tmp/authtemp
	tail -n $tailend $AUTHFILE | sed "s/${oldusername}/${newusername}/g" > ${OPENSHIFT_WEBL_DIR}/tmp/authtemp2

	cp -f $AUTHFILE $BACKUPDIR/DefaultAuthenticatorInit.ldift.bak
	
	cat ${OPENSHIFT_WEBL_DIR}/tmp/authtemp2 | sed "s/userpassword.*/userpassword: ${newpassword}/g" > ${OPENSHIFT_WEBL_DIR}/tmp/authtemp3
	#write the new values to initialize the ldap db
	cat ${OPENSHIFT_WEBL_DIR}/tmp/authtemp > $AUTHFILE
	cat ${OPENSHIFT_WEBL_DIR}/tmp/authtemp3 >> $AUTHFILE
	rm ${OPENSHIFT_WEBL_DIR}/tmp/authtemp3 ${OPENSHIFT_WEBL_DIR}/tmp/authtemp2 ${OPENSHIFT_WEBL_DIR}/tmp/authtemp 
	cp -f $AUTHFILE $BACKUPDIR/DefaultAuthenticatorInit.ldift

}

#xml parser http://stackoverflow.com/a/7052168
function read_dom {
	local IFS=\>
	read -d \< ENTITY CONTENT
}

#usage message
function usage {
	echo "Usage: $0 [OPTIONS] NEW_DOMAIN_NAME"
	echo
}

#
##end functions
#

#If no ARGs quit
if [ "$#" == "0" ]; then
	usage
	exit 1;
fi

#check if wl is running before proceeding any further
WLPID=$(cat $OPENSHIFT_WEBL_DIR/pid/webl.pid 2> /dev/null)
if [[ -n "$WLPID" ]]
then
	ps -p $WLPID 2>&1 > /dev/null
	ret=$?
	if [[ $ret -eq 0 ]]
	then
		echo "WebLogic is running. Please stop the cartridge and try again."
		exit 2
	fi
fi
NMPID=$(cat $OPENSHIFT_WEBL_DIR/pid/nm.pid 2> /dev/null)
if [[ -n "$NMPID" ]]
then
	ps -p $NMPID 2>&1 > /dev/null
	ret=$?
	if [[ $ret -eq 0 ]]
	then
		echo "NodeManager is running. Please stop the cartridge and try again."
		exit 2
	fi
fi

BACKUPDIR=$OPENSHIFT_WEBL_DIR/backups/

#skip to user/password change and exit
if [[ "$1" == '-p' ]]
then
	passwordchange
	exit 0
fi

#help
if [[ "$1" == '-h' ]]
then
	echo "$0"
	echo "Changes the WebLogic cartridge domain name."
	echo "Usage: $0 NEW_DOMAIN_NAME"
	echo "Specify the new domain name to set."
	echo
	echo "Additional usage:"
	echo "$0 -h"
	echo "		Displays this help."
	echo "$0 -p"
	echo "		Skips changing the domain name and prompts to reset the administrative user."
	echo
	echo "Options:"
	echo
	echo "-P"
	echo "		Only change the domain name and exit."
	echo 
	echo "-q"
	echo "		Quiet mode. Only prints errors, implies -P."
	echo 
	echo "--user <username>"
	echo "		Silently set <username> as the administrative user. Must be used with --pass."
	echo
	echo "--pass <password>"
	echo "		Silently set <password> for the administrative user. Must be used with --user."
	echo
	echo "After changing the domain name, you may optionally change the administrative username and password."
	echo "Alternatively specifying the -p option will skip changing the domain name and prompt to change the username and password."
	echo "Note: changing the username and password will produce a Java error when restarting the WebLogic instance, this is normal."
	echo
	echo "Created by: Andrew Francis afrancis@paychex.com 2013-10-04"
	echo
	exit 0;
fi

#set variables to handle options
quiet_mode=1
change_user=0
set_user=""
set_pass=""

#further option handling
while (( "$#" )); do
	
	lastarg=$1
	if [[ "$1" == '-P' ]]
	then
		change_user=1
		shift
		continue
	fi
	
	if [[ "$1" == '-q' ]]
	then
		quiet_mode=0
		shift
		continue
	fi
	
	if [[ "$1" == '--pass' ]]
	then
		shift
		set_pass=$1
		if [[ -z $2 ]]
		then
			usage
			exit 1;
		fi
		shift
		continue
	fi
	
	if [[ "$1" == '--user' ]]
	then
		shift
		set_user=$1
		if [[ -z $2 ]]
		then
			usage
			exit 1;
		fi
		shift
		continue
	fi
	
	shift
done

NewDomain=$lastarg
config_xml_path=${OPENSHIFT_WEBL_DIR}domain/config/config.xml
AS_ldap=${OPENSHIFT_WEBL_DIR}domain/servers/AdminServer/data/ldap
NMDom=${OPENSHIFT_WEBL_DIR}/domain/nodemanager/nodemanager.domains

if [[ $NewDomain == 'AdminServer' ]]
then
	echo 'Fatal: Using the domain "AdminServer" is not allowed as it will break the script.'
	exit 99
fi

#the domain name should be listed twice in consecutive <name> entries, so find this and assume it
#is the old domain name and stop looking when we find it.
tempdomainname=''
founddomainname=1
while read_dom
do
	if [[ $ENTITY == "name" ]]
	then
		if [[ $CONTENT == $tempdomainname ]]
		then
			founddomainname=0
			OldDomain=$CONTENT
			break
		fi
		tempdomainname=$CONTENT
	fi
done < $config_xml_path 

#if for whatever reason we did not find the domain name exit out
if [[ $founddommainname ]]
then
	echo "Unable to detect the domain name from config.xml, there is a good chance the cartridge is already broken. Exiting."
	exit 3
fi

cp -f $config_xml_path $BACKUPDIR/config.xml.bak
sed "s/<name>${OldDomain}<\/name>/<name>${NewDomain}<\/name>/g" ${config_xml_path} > ${OPENSHIFT_WEBL_DIR}/tmp/configTemp && mv ${OPENSHIFT_WEBL_DIR}/tmp/configTemp ${config_xml_path} 
cp -f $config_xml_path $BACKUPDIR/config.xml
if [[ $? ]]
then
	#write domain info to nodemanager
	cp -f $NMDom ${NMDom}.bak
	echo "${NewDomain}=${OPENSHIFT_WEBL_DIR}domain/" > $NMDom
	[[ $quiet_mode -eq 0 ]] || echo "Done changing domain. Resetting local LDAP database..."
else
	#if either step fails there should be no change to the affected file *crossing fingers*
	echo "Something went wrong. The domain has not be updated. Exiting."
	exit 4
fi

#remove the noconf file that prevents the server from starting
[[ -f "$OPENSHIFT_WEBL_DIR/noconf" ]] && rm -f "$OPENSHIFT_WEBL_DIR/noconf"

mv -f $AS_ldap $BACKUPDIR/ldap.bak 2>/dev/null
[[ $quiet_mode -eq 0 ]] || echo
[[ $quiet_mode -eq 0 ]] || echo "Done."
[[ $quiet_mode -eq 0 ]] || echo

#set the username and password as they were passed in
if [[ $set_user != "" && $set_pass != "" ]]
then
	passwordchange $set_user $set_pass
	exit 0
fi

#if -P or -q was set, exit.
if [[ $quiet_mode -eq 0 || $change_user -eq 1 ]]
then
	exit 0
fi

#ask to change username & password
read -p "Change admin username & password? " -n 1 -r
echo
if [[ $REPLY == 'y' || $REPLY == 'Y' ]]
then
	passwordchange
else 
	exit 0
fi