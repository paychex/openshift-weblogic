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
#=======================================================================================
# gather the user input
#=======================================================================================
# load the global properties
loadProperties( sys.argv[1] )


#=======================================================================================
# Open a domain template.
#=======================================================================================
fullTemplatePath=templatepath + "wls.jar"


readTemplate( fullTemplatePath )

#=======================================================================================
# Update some domain settings
#=======================================================================================
set('Name', domainname)

#=======================================================================================
# Configure the Administration Server
#=======================================================================================
cd('Servers/AdminServer')
set('ListenAddress', adminlistenaddress)
set('ListenPort', int( adminlistenport ) )

#=======================================================================================
# Change the name of the weblogic default user and set the password
#=======================================================================================
cd('/Security/' + domainname + '/User/weblogic')
cmo.setName(adminuser)
cmo.setPassword(adminpassword)

#=======================================================================================
# Write the domain and close the domain template.
#=======================================================================================
setOption('OverwriteDomain', 'false')
setOption('ServerStartMode', 'prod')
setOption('JavaHome', javaHome)
writeDomain(domainpath)
closeTemplate()

#=======================================================================================
# Exit WLST.
#=======================================================================================

exit()
