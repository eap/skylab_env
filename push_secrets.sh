#!/bin/bash

# This shell script is to be run on the primary developer machine to
# push credentials and other secrets. These secrets are transiently
# used on the target host's elastic volume, but they should be deleted
# from the remote when the work is done. Ideally the remote itself
# will have its volumes garbage collected.


TARGET_USER=ubuntu
TARGET_USER_DIR=/home/ubuntu

if [ -z "${REMOTE}" ]; then
    echo "Call with remote IP or domain. Example:"
    echo "REMOTE=18.224.51.31 ./push_secrets.sh"
fi

set -o errexit
set -x
ssh -i $EC2_PEM $TARGET_USER@$REMOTE "mkdir -p $TARGET_USER_DIR/.ssh"
scp -i $EC2_PEM $HOME/.ssh/eparker-usaf-us-east-2.pem ${TARGET_USER}@${REMOTE}:${TARGET_USER_DIR}/.ssh/
scp -i $EC2_PEM $HOME/.ssh/jcsda-ci.2023-04-19.private-key.pem ${TARGET_USER}@${REMOTE}:${TARGET_USER_DIR}/.ssh/
ssh -i $EC2_PEM $TARGET_USER@$REMOTE "mkdir -p $TARGET_USER_DIR/.aws"
scp -i $EC2_PEM $HOME/.aws/config ${TARGET_USER}@${REMOTE}:${TARGET_USER_DIR}/.aws/
scp -i $EC2_PEM $HOME/.aws/credentials ${TARGET_USER}@${REMOTE}:${TARGET_USER_DIR}/.aws/
ssh -i $EC2_PEM $TARGET_USER@$REMOTE "mkdir -p $TARGET_USER_DIR/.config/gh"
scp -i $EC2_PEM $HOME/.config/gh/eap_pat.txt ${TARGET_USER}@${REMOTE}:${TARGET_USER_DIR}/.config/gh/eap_pat.txt
