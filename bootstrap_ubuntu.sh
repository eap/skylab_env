#!/bin/bash

TARGET_USER=ubuntu
TARGET_USER_DIR=/home/ubuntu


read -r -d '' HELP_CONTENT << EOM
This script is used to bootstrap a new ubuntu or ubuntu-derivative system.
This script is controlled with shell variables. Many have reasonable assumptions
but a few are required. This script must be run as root.

Required:
  * SPACK|NOSPACK: If SPACK is set, then prerequisites for installing
                   spack-stack will be installed. If NOSPACK is set then
                   they will not be installed.

Optional:
  * BASHRC=1: Update the bashrc.
  * DOCKER=1: add a docker install.
  * EAP_GIT=1: Use @eap custom git credentials.
  * TARGET_USER: Override "ubuntu" target user.
  * TARGET_USER_DIR: Override /home/ubuntu target user dir.

Use:
  sudo NOSPACK=1 ./bootstrap_ubuntu.sh
EOM

print_help () {
    echo "${HELP_CONTENT}"
}

if [ -z "${SPACK}" ] && [ -z "${NOSPACK}" ] ; then
    print_help
    echo
    echo "ERROR: required SPACK/NOSPACK parameter missing"
    exit 1
fi

if [[ $1 == "-h" ]] ||  [[ $1 == "help" ]] ; then
    print_help
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive

echo "Bootstrapping an ubuntu instance."

if grep -q "eap-dev-setup-complete" $TARGET_USER_DIR/.bashrc; then
    echo "This script should not be run twice; exiting now"
    exit 1
fi

if [[ $USER != "root" ]]; then
    echo "This script Must be run with sudo."
    exit 1
fi


BASHRC_CONTENT="$(cat << 'EOF'
# Indicator string to prevent redundant setup: eap-dev-setup-complete
aws_usaf () {
    export AWS_PROFILE=jcsda-usaf-us-east-2
    export EC2_PEM=${HOME}}/.ssh/eparker-usaf-us-east-2.pem
    export AWS_DEFAULT_REGION=us-east-2
    aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 747101682576.dkr.ecr.us-east-2.amazonaws.com
}
aws_noaa () {
    export AWS_PROFILE=jcsda-noaa-us-east-1
    export EC2_PEM=${HOME}/.ssh/eparker-noaa-us-east-1.pem
    export AWS_DEFAULT_REGION=us-east-1
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 469205354006.dkr.ecr.us-east-1.amazonaws.com
}
aws_usaf
export GITHUB_APP_PRIVATE_KEY=${HOME}/.ssh/jcsda-ci.2023-04-19.private-key.pem
export GITHUB_APP_ID=321361
export GITHUB_INSTALL_ID=36634387
export GITHUB_TOKEN_FILE=${HOME}/.config/gh/eap_pat.txt
export GITHUB_TOKEN=$(cat $GITHUB_TOKEN_FILE)
EOF
)"

set -o errexit
set -x

install_basics () {
    echo "updating apt"
    apt update
    echo "installing true basics"
    apt install -y \
                ca-certificates \
                curl \
                gnupg \
                git \
                git-lfs \
                bzip2 \
                unzip \
                python3 \
                python3-pip \
                nano
    sudo -u $TARGET_USER git lfs install
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    pushd /tmp
    unzip awscliv2.zip
    ./aws/install
    popd

    # Uncomment the history search stuff in the inputrc.
    sudo sed -i 's/# "\\e\[5~": history-search/"\\e\[5~": history-search/' /etc/inputrc
    sudo sed -i 's/# "\\e\[6~": history-search/"\\e\[6~": history-search/' /etc/inputrc
}

install_spack_prereq () {
    echo "installing compilers"
    apt install -y \
                gcc \
                g++ \
                gfortran \
                gdb

    #echo "installing environment modules"
    #apt install -y lmod
    apt install -y environment-modules

    apt install -y build-essential \
                 libkrb5-dev \
                 m4 \
                 automake \
                 xterm \
                 libcurl4-openssl-dev \
                 libssl-dev \
                 mysql-server=8.0.28-0ubuntu4 \
                 libmysqlclient-dev=8.0.28-0ubuntu4 \
                 libmysqlclient21=8.0.28-0ubuntu4 \
                 python3-dev

    echo
    echo "Installing aws CLI using instructions below"
    echo 
}

setup_bashrc () {
    echo "Setting up ${TARGET_USER} home at ${TARGET_USER_DIR}"
    if grep -q "AWS_PROFILE" $TARGET_USER_DIR/.bashrc ; then
        echo "++ User directory already setup"
        return 0
    fi
    echo "${BASHRC_CONTENT}" >> "${TARGET_USER_DIR}/.bashrc"
}

setup_git () {
    GITHUB_TOKEN_FILE=${TARGET_USER_DIR}/.config/gh/eap_pat.txt
    GITHUB_TOKEN="$(cat $GITHUB_TOKEN_FILE)"
    echo '#!/bin/bash' > ${TARGET_USER_DIR}/.config/gh/askpass.sh
    echo "echo ${GITHUB_TOKEN}" >> ${TARGET_USER_DIR}/.config/gh/askpass.sh
    chmod +x ${TARGET_USER_DIR}/.config/gh/askpass.sh

    sudo -u $TARGET_USER git config --global user.name "eap"
    sudo -u $TARGET_USER git config --global core.askPass ${TARGET_USER_DIR}/.config/gh/askpass.sh
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

    apt-get install -y docker-ce \
                       docker-ce-cli \
                       containerd.io \
                       docker-buildx-plugin \
                       docker-compose-plugin

    docker run hello-world

    echo
    echo "success installing docker"
    echo "running post-install"
    echo

    if ! grep -q -E "^docker:" /etc/group ; then
        groupadd docker
    fi
    usermod -aG docker $TARGET_USER
    usermod -aG docker $USER
    newgrp docker
    echo
    echo "Success. In order to use docker in your current shell, please"
    echo "run 'newgrp docker', alternatively start a new login session."
    echo
}


install_basics

if [ -n "${BASHRC}" ]; then
    setup_bashrc
else
    echo "skipping bashrc edits"
fi
if [ -n "${SPACK}" ]; then
    install_spack_prereq
else
    echo "skipping spack prerequisites install"
fi
if [ -n "${DOCKER}" ]; then
    installdocker
else
    echo "skipping docker install"
fi
if [ -n "${EAP_GIT}" ]; then
    setup_git
else
    echo "skipping git install"
fi

