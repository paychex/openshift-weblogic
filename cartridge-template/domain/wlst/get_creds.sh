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

CRED_FILE=${OPENSHIFT_WEBL_DIR}domain/servers/AdminServer/security/cred
ADMIN_USERNAME=$(egrep '^username' $CRED_FILE | tail -n 1 | cut -d'=' -f 2)
ADMIN_PASSWORD=$(egrep '^password' $CRED_FILE | tail -n 1 | cut -d'=' -f 2)

export ADMIN_USERNAME 
export ADMIN_PASSWORD