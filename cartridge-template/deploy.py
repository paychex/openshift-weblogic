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
import java.util as util
import java.io as javaio
import os

adminip = os.environ['OPENSHIFT_WEBL_IP'] 
adminport = int(os.environ['OPENSHIFT_WEBL_ADMIN_PORT'])
classpathdir = os.environ['OPENSHIFT_WEBL_DIR'] + '/classpath'
servername = sys.argv[1]
appname = sys.argv[2]
apppath = sys.argv[3]

loadProperties(os.environ['OPENSHIFT_WEBL_DOMAIN_DIR'] + '/servers/AdminServer/security/boot.properties')
adminuser = username
adminpass = password
# static variables - we'll hard-code them for now 
javahome = ''
javavendor = ''
beahome = ''

# build some variables
adminurl = 't3://' + adminip + ':' + str(adminport)
classpath = '$CLASSPATH:' + classpathdir

# let's try to connect
try:
  connect( adminuser, adminpass, adminurl)
except WLSTException:
  print '==> Error Connecting to The URL ' + adminurl
  print '==== Exiting Because Of Connectivity Error ===='
  CancelEdit('y')
  exit()

deploy( appname, apppath, servername )
startApplication( appname )

disconnect()

exit()
