#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -o errexit
set -o nounset
# print command before executing
#set -o xtrace

CURR_DIR=`pwd`
if [[ `basename $CURR_DIR` != "scripts" ]] ; then
  echo "You have to call the script from the scripts/ dir"
  exit 1
fi

REDIRECT=' > /dev/null 2>&1'
if [[ $# -lt 1 ]]; then
    echo "This script will validate source release candidate published in dist for apache xtable (incubating)"
    echo "You can set 3 args to this script: release version is mandatory, while rest two are optional. Default release_type is \"dev\". Or you can set to \"release\""
    echo "--release=\${CURRENT_RELEASE_VERSION}"
    echo "--rc_num=\${RC_NUM}"
    echo "--release_type=release"
    exit
else
    for param in "$@"
    do
	if [[ $param =~ --release\=([0-9]\.[0-9]*\.[0-9].*) ]]; then
		RELEASE_VERSION=${BASH_REMATCH[1]}
	fi
	if [[ $param =~ --rc_num\=([0-9]*) ]]; then
                RC_NUM=${BASH_REMATCH[1]}
        fi
        if [[ $param =~ --release_type\="release" ]]; then
                RELEASE_TYPE="release"
        fi
	if [[ $param =~ --verbose ]]; then
               REDIRECT=""
        fi
    done
fi

if [ -z ${RC_NUM+x} ]; then
   RC_NUM=-1
fi

if [ -z ${RELEASE_TYPE+x} ]; then
   RELEASE_TYPE=dev
fi

# Get to a scratch dir
RELEASE_TOOL_DIR=`pwd`
WORK_DIR=/tmp/validation_scratch_dir_001
rm -rf $WORK_DIR
mkdir $WORK_DIR
pushd $WORK_DIR

# Checkout dist repo
LOCAL_SVN_DIR=local_svn_dir
ROOT_SVN_URL=https://dist.apache.org/repos/dist/
REPO_TYPE=${RELEASE_TYPE}
XTABLE_REPO=incubator/xtable

if [ $RC_NUM == -1 ]; then
    ARTIFACT_SUFFIX=${RELEASE_VERSION}
else
    ARTIFACT_SUFFIX=${RELEASE_VERSION}-rc${RC_NUM}
fi

if [ $RELEASE_TYPE == "release" ]; then
  ARTIFACT_PREFIX=
elif [ $RELEASE_TYPE == "dev" ]; then
  ARTIFACT_PREFIX='xtable-'
else
  echo "Unexpected RELEASE_TYPE: $RELEASE_TYPE"
  exit 1;
fi

rm -rf $LOCAL_SVN_DIR
mkdir $LOCAL_SVN_DIR
cd $LOCAL_SVN_DIR

echo "Current directory: `pwd`"

FULL_SVN_URL=${ROOT_SVN_URL}/${REPO_TYPE}/${XTABLE_REPO}/${ARTIFACT_SUFFIX}

echo "Downloading from svn co $FULL_SVN_URL"

(bash -c "svn co $FULL_SVN_URL $REDIRECT") || (echo -e "\t\t Unable to checkout  $FULL_SVN_URL to $REDIRECT. Please run with --verbose to get details\n" && exit -1)

echo "Validating apache-xtable-${RELEASE_VERSION} with release type \"${REPO_TYPE}\""
cd ${ARTIFACT_SUFFIX}
shasum -a 512 apache-xtable-${RELEASE_VERSION}.src.tgz > got.sha512

echo "Checking Checksum of Source Release"
diff -u apache-xtable-${RELEASE_VERSION}.src.tgz.sha512 got.sha512
echo -e "\t\tChecksum Check of Source Release - [OK]\n"

# Download KEYS file
curl https://dist.apache.org/repos/dist/dev/incubator/xtable/KEYS > ../KEYS

# GPG Check
echo "Checking Signature"
(bash -c "gpg --import ../KEYS $REDIRECT" && bash -c "gpg --verify apache-xtable-${RELEASE_VERSION}.src.tgz.asc apache-xtable-${RELEASE_VERSION}.src.tgz $REDIRECT" && echo -e "\t\tSignature Check - [OK]\n") || (echo -e "\t\tSignature Check - [ERROR]\n\t\t Run with --verbose to get details\n" && exit 1)

# Untar
(bash -c "tar -zxf apache-xtable-${RELEASE_VERSION}.src.tgz $REDIRECT") || (echo -e "\t\t Unable to untar apache-xtable-${RELEASE_VERSION}.src.tgz - [ERROR]\n\t\t Please run with --verbose to get details\n" && exit 1)
cd apache-xtable-${RELEASE_VERSION}

### BEGIN: Binary Files Check
$CURR_DIR/validate_source_binary_files.sh
### END: Binary Files Check

### Checking for DISCLAIMER, LICENSE, NOTICE and source file license
$CURR_DIR/validate_source_copyright.sh

### Checking for RAT
$CURR_DIR/validate_source_rat.sh

popd
