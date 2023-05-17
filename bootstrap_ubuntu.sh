#!/bin/bash

TARGET_USER=ubuntu
TARGET_USER_DIR=/home/ubuntu


read -r -d '' HELP_CONTENT << EOM
This script is used to bootstrap a new ubuntu or ubuntu-derivative system.
This script is controlled with shell variables. Many have reasonable assumptions
but a few are required. This script must be run as root.

Required:
  * SPACK|NOSPACK: If SPACK is set, then prerequisisites for installing
                   spack-stack will be installed. If NOSPACK is set then
                   they will not be installed.

Optional:
  * TARGET_USER: Override "ubuntu" target user.
  * TARGET_USER_DIR: Override /home/ubuntu target user dir.

Use:
  NOSPACK=1 sudo ./bootstrap_ubuntu.sh
EOM

print_help () {
    echo "${HELP_CONTENT}"
}

if [ -z "${SPACK}" ] && [ -z "${NOSPACK}" ] ; then
    print_help
    exit 1
fi

if [[ $1 == "-h" ]] ||  [[ $1 == "help" ]] ; then
    print_help
    exit 0
fi


set -o errexit

echo "Bootstrapping an ubuntu instance."
if [[ $USER != "root" ]]; then
    echo "This script Must be run with sudo."
    exit 1
fi


read -r -d '' BASHRC_CONTENT << EOM
aws_usaf () {
    export AWS_PROFILE=jcsda-usaf-us-east-2
    export EC2_PEM="${TARGET_USER_DIR}/.ssh/eparker-usaf-us-east-2.pem"
}

aws_noaa () {
    export AWS_PROFILE=jcsda-noaa-us-east-1
    export EC2_PEM="${TARGET_USER_DIR}/.ssh/eparker-noaa-us-east-1.pem"
}

aws_usaf

export GITHUB_APP_PRIVATE_KEY=${TARGET_USER_DIR}/.ssh/jcsda-ci.2023-04-19.private-key.pem
export GITHUB_APP_ID=321361
export GITHUB_INSTALL_ID=36634387
export GITHUB_TOKEN_FILE="${TARGET_USER_DIR}/.config/gh/eap_pat.txt"
export GITHUB_TOKEN="$(cat $GITHUB_TOKEN_FILE)" 
EOM


install_basics () {
    apt update
    echo "installing true basics"
    apt install -y \
                ca-certificates \
                curl \
                gnupg \
                awscli \
                git \
                git-lfs \
                bzip2 \
                unzip \
                python3 \
                python3-pip \
                pico
}

install_spack_prereq () {
    echo "installing compilers"
    apt install -y \
                gcc \
                g++ \
                gfortran \
                gdb

    echo "installing environment modules"
    apt install -y environment-modules

    apt install -y build-essential \
                 libkrb5-dev \
                 m4 \
                 automake \
                 xterm \
                 libcurl4-openssl-dev \
                 libssl-dev \
                 mysql-server \
                 libmysqlclient-dev \
                 python3-dev

    echo
    echo "Installing aws CLI using instructions below"
    echo 
}

setup_environ () {
    echo "Setting up ${TARGET_USER} home at ${TARGET_USER_DIR}"
    if [[ grep -q "AWS_PROFILE" $TARGET_USER_DIR/.bashrc ]]; then
        echo "++ User directory already setup"
        return 0
    fi
    echo "${BASHRC_CONTENT}" >> "${TARGET_USER_DIR}/.bashrc"

}

installdocker () {
    echo "installing docker based on the instructions linked below"
    echo "main install: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository"
    echo "post install: https://docs.docker.com/engine/install/linux-postinstall/"

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
         | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update

    apt-get install docker-ce \
                    docker-ce-cli \
                    containerd.io \
                    docker-buildx-plugin \
                    docker-compose-plugin

    docker run hello-world

    echo
    echo "success installing docker"
    echo "running post-install"
    echo

    groupadd docker
    usermod -aG docker $TARGET_USER
    usermod -aG docker $USER
    newgrp docker
    echo
    echo "Success. In order to use docker in your current shell, please"
    echo "run 'newgrp docker', alternatively start a new login session."
    echo
}


install_basics
setup_environ
if [ -n $SPACK ]; then
    install_spack_prereq
}
installdocker



