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

#Not root check
if [[ "$(whoami)" == "root" ]]; then
	echo "Cannot run as root."
	exit 1
fi
#Force run from script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ $PWD != $SCRIPT_DIR ]]; then
	cd "$SCRIPT_DIR"
fi

#Vars
JAVA_BIN=""
INSTALL_DIR="/opt/weblogic-openshift/"
WL_JDK="$PWD/jdk/"
WL_INSTALLER=""
FPMRPM=1
RPMVERSION="0.1.0"
RPM_DIR="$PWD/"
CART_DIR="/usr/libexec/openshift/cartridges/openshift-weblogic-cartridge/"
SILENTXML="$PWD/silent.xml"
DOMAINSCRIPT="$PWD/createdomain.py"
DOMAINPROP="$PWD/domain.properties"
CARTTEMPLATE="$PWD/cartridge-template/"
RPMNAME="openshift-weblogic-cartridge"
RPMNAMECOMMON="${RPMNAME}-common"
TEMPFILE="$$"

#Functions
mkdirerr() {
	echo "Unable to create directory '$1'. Stopping."
	exit 3
}

echoquit () {
	echo "$1"
	ec=1
	if [[ -n "$2" ]]; then
		ec="$2"
	fi
	exit "$ec"
}

usage () {
	echo "Usage: $0 [OPTIONS] WLSJAR"
}

sed_safe () {
	echo "$@" | sed -e 's/[\/&]/\\&/g'
}

os_bash_replace () {
	FINDWHAT="$1"
	REPLACEWITH="$2"
	INWHATFILE="$3"
	if [[ ! -f "$INWHATFILE" ]]; then
		echo "WARNING: Unable to find '$INWHATFILE' to make changes to it, the cartridge might be broken."
		return
	fi
	sed -i "s/$(sed_safe "$FINDWHAT")/$(sed_safe "$REPLACEWITH")/g" "$INWHATFILE"
	return "$?"
}

os_erb_replace () {
	FINDWHAT="$1"
	REPLACEWITH="$2"
	INWHATFILE="$3"
	DORENAME=0
	
	if [[ ! -f "$INWHATFILE" ]]; then
		OLDWHATFILE="$INWHATFILE"
		INWHATFILE="${INWHATFILE}.erb"
		DORENAME=1
		if [[ ! -f "$INWHATFILE" ]]; then
			echo "WARNING: Unable to find '$OLDWHATFILE' or '$INWHATFILE' to make changes to it, the cartridge might be broken."
			return
		fi
	fi
	sed -i "s/$(sed_safe "$FINDWHAT")/$(sed_safe "$REPLACEWITH")/g" "$INWHATFILE"
	SEDRETURN="$?"
	#only rename if not already erb
	if [[ "$DORENAME" -eq 0 ]]; then
		mv "$INWHATFILE" "${INWHATFILE}.erb"
	fi
	return "$SEDRETURN"
}

no_double_slash () {
	echo "$@" | sed -e 's/\/\//\//g'
}

show_help() {
	echo "Setup script for WebLogic OpenShift cartridge."
	echo
	usage
	echo
	echo "-j JRE
    Path to the java binary to run the WebLogic installer. 
    Default 'java'."
	echo
	echo "-i WLINSTALLPATH
    Path to write the shared WebLogic files. 
    Default '$INSTALL_DIR'"
	echo
	echo "-J JDKDIR
    Path to the jdk directory to be used by WebLogic. Will be copied
    to the path specified with -i in the jdk/ subdirectory.
    Default '$WL_JDK'"
	echo
	echo "-c CARTPATH
    Path to write cartridge files to. 
    Default '$CART_DIR'"
	echo
	echo "-h
    Show this help."
	echo
	echo "-r
    Create RPMs with FPM after setup. Requires FPM to be installed
    and available in the user's PATH. See https://github.com/jordansissel/fpm
    for more details."
	echo
	echo "-R RPMPATH
    Path to store generated RPMs. 
    Default '$RPM_DIR'"
	echo
	echo "This has been tested with WebLogic 12.1.2."
	echo
	echo "<<<more legal here>>>"
	exit 0
}

installsummary() {
	#Please don't run me early, I don't do any checking.
	echo
	echo '===INSTALLATION COMPLETE==='
	echo
	echo "WebLogic has be installed to '$INSTALL_DIR'."
	echo "JDK has been copied into '$JDKPATH'"
	echo "Cartridge files have been written to '$CART_DIR'."
}
#end functions

#option parsing
lastarg=""
while (( "$#" )); do
	lastarg="$1"
	case "$1" in
		"-j")
			shift
			JAVA_BIN="$1"
			lastarg=""
			;;
		"-J")
			shift
			WL_JDK="$1"
			lastarg=""
			;;
		"-i")
			shift
			INSTALL_DIR="$1"
			lastarg=""
			;;
		"-r")
			FPMRPM=0
			lastarg=""
			;;
		"-R")
			shift
			RPM_DIR="$1"
			lastarg=""
			;;
		"-c")
			shift
			CART_DIR="$1"
			lastarg=""
			;;
		"-h")
			show_help
			;;
		"-"*)
			echo "Unknown option '$1', ignoring..."
			lastarg=""
			;;
	esac
	shift
done
WL_INSTALLER="$lastarg"

#Options testing

#Java for installer check.
if [[ "$JAVA_BIN" == "" ]]; then
	JAVA_BIN="java"
	which "$JAVA_BIN" 2>&1 > /dev/null
	if [ $? -ne 0 ]; then
		echo "Unable to find 'java' in your path, please use the '-j' option to specify a java binary to use for the WebLogic installer."
		exit 1
	fi
fi

#Check if the installer is set and is a file
if [[ "$WL_INSTALLER" == "" ]]; then
	usage
	exit 0
fi
if [[ ! -f "$WL_INSTALLER" ]]; then
	echo "Unable to find WebLogic installer. '$WL_INSTALLER' is not a file."
	exit 4
fi

#Checking if the install directory exists, if not create and check permissions
if [[ ! -d "$INSTALL_DIR" ]]; then
		mkdir -p "$INSTALL_DIR" || mkdirerr "$INSTALL_DIR"
fi
touch "$INSTALL_DIR/$TEMPFILE" || echoquit "Unable to write to '$INSTALL_DIR', please check the permissions." 2
rm -f "$INSTALL_DIR/$TEMPFILE" 

#Checking if the cartridge directory exists, if not create and check permissions
if [[ ! -d "$CART_DIR" ]]; then
		mkdir -p "$CART_DIR" || mkdirerr "$CART_DIR"
fi
touch "$CART_DIR/$TEMPFILE" || echoquit "Unable to write to '$CART_DIR', please check the permissions." 2
rm -f "$CART_DIR/$TEMPFILE" 

#Checks for JDK files by looking for some important files/directories
echo "Checking JDK files... ($WL_JDK)"
test -d "$WL_JDK" || echoquit "JDK at '$WL_JDK' does not seem to be a directory. Are you using the -J option?" 2

for i in "${WL_JDK}"/{bin,db,include,jre,lib}; do
	test -d "$i" || echoquit "Unable to locate JDK directory '$i', is this a JDK release?" 2
done
test -x "${WL_JDK}/bin/java" || echoquit "Unable to locate JDK executable '${WL_JDK}/bin/java', is this a JDK release?" 2
test -x "${WL_JDK}/jre/bin/java" || echoquit "Unable to locate JDK executable '${WL_JDK}/jre/bin/java', is this a JDK release?" 2



#Prep for WebLogic installer
echo "Preparing and running WebLogic installer..."
cp -rf "$SILENTXML" "${SILENTXML}.bak"
echo >> "$SILENTXML"
echo "###Installer path written by make-cart.sh###" >> "$SILENTXML"
echo "ORACLE_HOME=${INSTALL_DIR}" >> "$SILENTXML"
#Install WebLogic
ORAINV="/tmp/$$.oraInst.loc"
echo "inventory_loc=${INSTALL_DIR}/oraInventory" > "$ORAINV"
"$JAVA_BIN" -d64 -Xmx1024m -jar "${WL_INSTALLER}" -silent -force -novalidation -responseFile "$SILENTXML" -ignoreSysPrereqs -invPtrLoc "$ORAINV" || echoquit "WebLogic installation failed. check log above." 1
rm -f "$ORAINV"

#Open up permissions on the install so the cartridge can work
find "$INSTALL_DIR" -type d -exec chmod +rx {} \;
find "$INSTALL_DIR" -type f -exec chmod +r {} \;
chmod +x "$INSTALL_DIR"/wlserver/{common,server}/bin/*.sh "$INSTALL_DIR"/oracle_common/bin/*.sh "$INSTALL_DIR"/oracle_common/common/bin/*.sh

#Copy JDK
echo "Copying JDK files..."
JDKPATH=$(no_double_slash "${INSTALL_DIR}/jdk/")
mkdir -p "$JDKPATH"
cp -rf "$WL_JDK/"* "$JDKPATH"
echo "$JDKPATH" > "${INSTALL_DIR}/java"

#Prep for domain creation
echo "Preparing to generate domain..."
TEMPLATEPATH=$(no_double_slash "${INSTALL_DIR}/wlserver/common/templates/wls/")
DOMAINPATH=$(no_double_slash "${CART_DIR}/domain")
mkdir -p "$DOMAINPATH"

#Modify domain.properties with command line/discovered values
cp -f "$DOMAINPROP" "$DOMAINPROP".bak
if grep "javaHome" "$DOMAINPROP" > /dev/null; then
	sed -i "s/^javaHome=.*/javaHome=$(sed_safe "$JDKPATH")/" "$DOMAINPROP"
else
	echo "javaHome=$JDKPATH" >> "$DOMAINPROP"
fi
if grep "templatepath" "$DOMAINPROP" > /dev/null; then
	sed -i "s/^templatepath=.*/templatepath=$(sed_safe "$TEMPLATEPATH")/" "$DOMAINPROP"
else
	echo "templatepath=$TEMPLATEPATH" >> "$DOMAINPROP"
fi
if grep "domainpath" "$DOMAINPROP" > /dev/null; then
	sed -i "s/^domainpath=.*/domainpath=$(sed_safe "$DOMAINPATH")/" "$DOMAINPROP"
else
	echo "domainpath=$DOMAINPATH" >> "$DOMAINPROP"
fi
#checking for the required values and defaulting if not present
if ! grep "domainname" "$DOMAINPROP" > /dev/null; then
	echo "domainname=base_domain" >> "$DOMAINPROP"
fi
if ! grep "adminlistenaddress" "$DOMAINPROP" > /dev/null; then
	echo "adminlistenaddress=127.0.0.1" >> "$DOMAINPROP"
fi
if ! grep "adminlistenport" "$DOMAINPROP" > /dev/null; then
	echo "adminlistenport=7001" >> "$DOMAINPROP"
fi
if ! grep "adminuser" "$DOMAINPROP" > /dev/null; then
	echo "adminuser=admin" >> "$DOMAINPROP"
fi
if ! grep "adminpassword" "$DOMAINPROP" > /dev/null; then
	echo "adminpassword=admin123" >> "$DOMAINPROP"
fi


#Read the important values from domain.properties to output later.
DOMUSER=$(grep "adminuser" "$DOMAINPROP" | tail -1 | cut -d'=' -f2-)
DOMPASS=$(grep "adminpassword" "$DOMAINPROP" | tail -1 | cut -d'=' -f2-)
DOMIP=$(grep "adminlistenaddress" "$DOMAINPROP" | tail -1 | cut -d'=' -f2-)
DOMPORT=$(grep "adminlistenport" "$DOMAINPROP" | tail -1 | cut -d'=' -f2-)

#Running wlst to make the domain
echo "Generating domain in '$DOMAINPATH'..."
WLSTSH="${INSTALL_DIR}/wlserver/common/bin/wlst.sh"
"$WLSTSH" "$DOMAINSCRIPT" "$DOMAINPROP" || echoquit "Failed to create the domain, please check the above output." 1
echo "WebLogic domain creation process done, writing customizations..."

##Domain modifications to make it work in OpenShift
#Write boot.properties
mkdir -p "$DOMAINPATH/servers/AdminServer/security"
echo "username=$DOMUSER" > "$DOMAINPATH/servers/AdminServer/security/boot.properties"
echo "password=$DOMPASS" >> "$DOMAINPATH/servers/AdminServer/security/boot.properties"
cp "$DOMAINPATH/servers/AdminServer/security/boot.properties" "$DOMAINPATH/servers/AdminServer/security/cred"

#Replace important parts of files with OpenShift variables
SHFILES="bin/startManagedWebLogic.sh bin/stopWebLogic.sh bin/stopManagedWebLogic.sh bin/startNodeManager.sh bin/startWebLogic.sh bin/setDomainEnv.sh bin/stopComponent.sh bin/startComponent.sh startWebLogic.sh"
for i in $SHFILES; do
	os_bash_replace "$DOMIP" '$OPENSHIFT_WEBL_IP' "$DOMAINPATH/$i"
	os_bash_replace "localhost" '$OPENSHIFT_WEBL_IP' "$DOMAINPATH/$i"
	os_bash_replace "$DOMPORT" '$OPENSHIFT_WEBL_ADMIN_PORT' "$DOMAINPATH/$i"
	os_bash_replace "$DOMAINPATH" '$OPENSHIFT_WEBL_DOMAIN_DIR' "$DOMAINPATH/$i"
done
ERBFILES="nodemanager/nodemanager.properties nodemanager/nodemanager.domains init-info/startscript.xml init-info/nodemanager-properties.xml init-info/tokenValue.properties init-info/config-nodemanager.xml config/config.xml"
for i in $ERBFILES; do
	os_erb_replace "$DOMIP" '<%= ENV["OPENSHIFT_WEBL_IP"] %>' "$DOMAINPATH/$i"
	os_erb_replace "localhost" '<%= ENV["OPENSHIFT_WEBL_IP"] %>' "$DOMAINPATH/$i"
	os_erb_replace "$DOMPORT" '<%= ENV["OPENSHIFT_WEBL_ADMIN_PORT"] %>' "$DOMAINPATH/$i"
	os_erb_replace "5556" '<%= ENV["OPENSHIFT_WEBL_NM_PORT"] %>' "$DOMAINPATH/$i"
	os_erb_replace "$DOMAINPATH" '<%= ENV["OPENSHIFT_WEBL_DOMAIN_DIR"] %>' "$DOMAINPATH/$i"	
done

#Copy template files in
cp -rf "$CARTTEMPLATE"/* "$CART_DIR"

#Minor cosmetic update to the template
sed -i "s/username.*/username: $DOMUSER/" "${CART_DIR}/httpd/public_html/erb.index.html"
sed -i "s/password.*/password: ******/" "${CART_DIR}/httpd/public_html/erb.index.html"

#Write some variables we depend on in OpenShift scripts
echo "$WLSTSH" > "${CART_DIR}/env/OPENSHIFT_WEBL_WLST"
echo "$INSTALL_DIR/wlserver" > "${CART_DIR}/env/OPENSHIFT_WEBL_WLHOME"
echo "$JDKPATH" > "${CART_DIR}/env/OPENSHIFT_WEBL_JDK"
echo "$JDKPATH" > "${CART_DIR}/java/current"

#Check if we should make RPMs 
echo
if [ $FPMRPM -eq 0 ]; then
	which fpm 2>&1 > /dev/null
	if [ $? -ne 0 ]; then
		echo "fpm not found in path, RPMs will not be created."
		installsummary
		exit 0
	fi
	echo "Creating common files RPM in '$RPM_DIR'..."
	fpm -s dir -t rpm -n "$RPMNAMECOMMON" -v "$RPMVERSION" --epoch 1 -d "glibc" --directories="${INSTALL_DIR}"  -C / "$INSTALL_DIR"
	echo "Creating cartridge RPM in '$RPM_DIR'..."
	fpm -s dir -t rpm -n "$RPMNAME" -v "$RPMVERSION" --epoch 1 -d "$RPMNAMECOMMON" --directories="${CART_DIR}"  -C / "$CART_DIR"
	echo 
	echo 'RPMs created.'
fi

installsummary
