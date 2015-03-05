WebLogic Cartridge for OpenShift
================================

Requirements
------------
* WebLogic >= 12.1.2 
* WebLogic compatible JDK (usually 1.5 or higher)
* OpenShift 2.x
* FPM >= 1.1.0 (for RPM creation)

Installation
------------
1. Copy your JDK into the `jdk/` directory.
2. Run `make-cart.sh`, passing in the path to your WebLogic installer.
3. Deploy to OpenShift nodes.

Notes
-----
We cannot run the WebLogic installer as root so please run create your install
directories prior to running and grant permissions to the installation user
to avoid errors. Default directories created are:

* `/opt/weblogic-openshift/`
* `/usr/libexec/openshift/cartridges/openshift-weblogic-cartridge/`

Advanced
--------
* Enabling rngd is highly recommended as WebLogic uses /dev/random a lot during
install and startup of domains.
`yum install rng-tools;
echo 'EXTRAOPTIONS="-r /dev/urandom -o /dev/random -b"' >> /etc/sysconfig/rngd;
chkconfig rngd on;
service rngd start`
* The domain login information can be set in `domain.properties`. Default is 
username `admin` with password `admin123`.
* Customizations can be made to `silent.xml` and `domain.properties` to change 
how the WebLogic and the domain is installed.

Replaced files
--------------
Below are the list of files that can be found in `cartridge-template/` but are
replace by `make-cart.sh` and are only included for reference.

* `env/OPENSHIFT_WEBL_JDK`
* `env/OPENSHIFT_WEBL_WLST`
* `env/OPENSHIFT_WEBL_WLHOME`
* `java/current`

make-cart.sh
------------
Usage: make-cart.sh [OPTIONS] WLSJAR

WLSJAR
    Path to the WebLogic installer jar

-j JRE
    Path to the java binary to run the WebLogic installer. 
    Default `java`.

-i WLINSTALLPATH
    Path to write the shared WebLogic files. 
    Default `/opt/weblogic-openshift/`

-J JDKDIR
    Path to the jdk directory to be used by WebLogic. Will be copied
    to the path specified with -i in the jdk/ subdirectory.
    Default `$PWD/jdk/`

-c CARTPATH
    Path to write cartridge files to. 
    Default `/usr/libexec/openshift/cartridges/openshift-weblogic-cartridge/`

-h
    Show this help.

-r
    Create RPMs with FPM after setup. Requires FPM to be installed
    and available in the user's PATH. See https://github.com/jordansissel/fpm
    for more details.

-R RPMPATH
    Path to store generated RPMs. 
    Default `$PWD`
