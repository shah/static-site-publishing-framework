#!/usr/bin/env bash
#
# Install or upgrade SSPF files from GitHub
#

SSPF_REPO_HOME=shah/static-site-publishing-framework
SSPF_REPO_RAW_URL_HOME=https://raw.githubusercontent.com/$SSPF_REPO_HOME/master

sudo apt install -qq make curl git jq

SSPF_PROJECT_HOME=`pwd`
SSPF_PROJECT_NAME=`basename $SSPF_PROJECT_HOME`

echo "Setting up $SSPF_PROJECT_NAME in $SSPF_PROJECT_HOME"

# Create the bin directory if it doesn't already exist
mkdir -p $SSPF_PROJECT_HOME/bin

# If we're upgrading, remove any older versions of Makefile, hugo, jsonnet
rm -f Makefile
rm -f $SSPF_PROJECT_HOME/bin/hugo-*
rm -f $SSPF_PROJECT_HOME/bin/jsonnet-*

curl -s --output $SSPF_PROJECT_HOME/Makefile $SSPF_REPO_RAW_URL_HOME/Makefile

HUGO=hugo-0.54
curl -s --output $SSPF_PROJECT_HOME/bin/$HUGO $SSPF_REPO_RAW_URL_HOME/bin/$HUGO
chmod a+x $SSPF_PROJECT_HOME/bin/$HUGO

JSONNET=jsonnet-v0.11.2
curl -s --output $SSPF_PROJECT_HOME/bin/$JSONNET $SSPF_REPO_RAW_URL_HOME/bin/$JSONNET
chmod a+x $SSPF_PROJECT_HOME/bin/$JSONNET

make doctor