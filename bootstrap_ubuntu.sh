#!/bin/bash

read -r -d '' HELP_CONTENT << EOM
Usage: sudo boostrap_ubuntu.sh [OPTIONS]

This script is used to bootstrap a new Ubuntu or Unbuntu-derivative system
for JEDI development.

Options:
  --spack,-s     Install the base requirements for spack-stack.
  --nospack      Do not install requirements for spack-stack

  --intel,-i     Install Intel/OneAPI compilers and IntelMPI (default false).

  --lmod,-l      Install lua and lmod. If not set, environment-modules will be
                 installed instead

  --docker,-d    Install and configure docker (default false).

  --eap-auth,-e  Setup auth helpers and environment specific to @eap. This
                 requires the "push_secrets.sh" script as a prerequisite
                 and is customized to my user and is not intended to be
                 generally applicable (default false).

  --user         The target linux user to setup. This defaults to 'ubuntu'
                 but can be overridden. Do not use "$USER" since this may
                 be interpreted as 'root' depending on how this script is run.

  --user-home    The home directory of the target user. If not set, defaults to
                 /home/<user-name>.

  --help, -h     Display this help message
EOM


print_help () {
    echo "${HELP_CONTENT}"
    exit
}


# Default values for flags
INSTALL_SPACK_REQUIREMENTS="not-set"
INSTALL_INTEL=false
INSTALL_INTEL_HPC=false
INSTALL_DOCKER=false
EAP_AUTH=false
INSTALL_LMOD=false
TARGET_USER=ubuntu
TARGET_USER_DIR='not-set'


# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --spack|-s)
            INSTALL_SPACK_REQUIREMENTS=true
            shift 1
            ;;
        --nospack)
            INSTALL_SPACK_REQUIREMENTS=false
            shift 1
            ;;
        --lmod|-l)
            INSTALL_LMOD=true
            shift 1
            ;;
        --intel|-i)
            INSTALL_INTEL=true
            shift 1
            ;;
        --intelhpc|-ih)
            INSTALL_INTEL_HPC=true
            shift 1
            ;;
        --nointel)
            INSTALL_INTEL=false
            shift 1
            ;;
        --docker|-d)
            INSTALL_DOCKER=true
            shift 1
            ;;
        --nodocker)
            INSTALL_DOCKER=false
            shift 1
            ;;
        --eap-auth|-e)
            EAP_AUTH=true
            shift 1
            ;;
        --noeap-auth)
            EAP_AUTH=false
            shift 1
            ;;
        --user-home)
            TARGET_USER_DIR="${2}"
            shift 2
            ;;
        --user|-u)
            TARGET_USER="${2}"
            shift 2
            ;;
        --help|-h)
            echo "${HELP_CONTENT}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo ""
            echo "${HELP_CONTENT}"
            exit 1
            ;;
    esac
done


if [ $INSTALL_SPACK_REQUIREMENTS == "not-set" ]; then
    echo "Must run with --spack or --nospack"
    echo ""
    echo "${HELP_CONTENT}"
    exit 1
fi

if [ $TARGET_USER_DIR == "not-set" ]; then
    TARGET_USER_DIR="/home/${TARGET_USER}"
fi

export DEBIAN_FRONTEND=noninteractive


echo "Bootstrapping an ubuntu instance."



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
                tcl-dev \
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
                gdb \
                build-essential \
                libkrb5-dev \
                m4 \
                automake \
                cmake \
                xterm \
                autopoint \
                texlive \
                gettext \
                meson \
                libcurl4-openssl-dev \
                libssl-dev \
                mysql-server \
                libmysqlclient-dev \
                libmysqlclient21 \
                python3-dev

    apt install -y qtbase5-dev \
               qt5-qmake \
               libqt5svg5-dev \
               qt5dxcb-plugin

    echo
    echo "Installing aws CLI using instructions below"
    echo 
}

setup_eap_auth_and_env () {
    if grep -q "eap-dev-setup-complete" $TARGET_USER_DIR/.bashrc; then
        echo "-eap-auth setup should not be run twice; exiting."
        exit 1
    fi
    echo "Setting up ${TARGET_USER} home at ${TARGET_USER_DIR}"
    if grep -q "AWS_PROFILE" $TARGET_USER_DIR/.bashrc ; then
        echo "++ User directory already setup"
        return 0
    fi
    echo "${BASHRC_CONTENT}" >> "${TARGET_USER_DIR}/.bashrc"

    GITHUB_TOKEN_FILE=${TARGET_USER_DIR}/.config/gh/eap_pat.txt
    GITHUB_TOKEN="$(cat $GITHUB_TOKEN_FILE)"
    echo '#!/bin/bash' > ${TARGET_USER_DIR}/.config/gh/askpass.sh
    echo "echo ${GITHUB_TOKEN}" >> ${TARGET_USER_DIR}/.config/gh/askpass.sh
    chmod +x ${TARGET_USER_DIR}/.config/gh/askpass.sh

    sudo -u $TARGET_USER git config --global user.name "eap"
    sudo -u $TARGET_USER git config --global core.askPass ${TARGET_USER_DIR}/.config/gh/askpass.sh
}


install_after_download() {
    local pid=$1
    local description=$2
    shift 2

    # take the script file name like "tbb.sh" and convert to "install.tbb.log".
    local log_file="install.$(echo "$1" | sed s#\.sh#\.log#g)"

    # Wait for the background process to complete
    wait $pid
    local exit_status=$?

    if [ $exit_status -eq 0 ]; then
        echo "Download for $description was successful."
        # Execute the install command
        sh "$@" 2>&1 | tee $log_file
    else
        echo "Download for $description failed."
        exit 1
    fi
}

install_intel_hpc() {
    # Intel compiler
    wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list
    apt-get update
    apt-get install -y intel-hpckit-runtime-2023.2.0/all
}

install_intel() {

    # Following instructions from https://github.com/JCSDA-internal/jedi-tools/ : CI-tools/selfhosted/CI-testing-spack-stack-selfhosted-ubuntu-ci-x86_64.txt
    mkdir -p /opt/intel/src
    pushd /opt/intel/src

    # Download Intel install assets.
    # first download the C/C++ compiler so install can be run while other packages are downloading.
    wget --quiet -O cpp-compiler.sh https://registrationcenter-download.intel.com/akdlm/IRC_NAS/d85fbeee-44ec-480a-ba2f-13831bac75f7/l_dpcpp-cpp-compiler_p_2023.2.3.12_offline.sh
    wget --quiet -O fortran-compiler.sh https://registrationcenter-download.intel.com/akdlm/IRC_NAS/0ceccee5-353c-4fd2-a0cc-0aecb7492f87/l_fortran-compiler_p_2023.2.3.13_offline.sh &
    fortran_pid=$!
    wget --quiet -O tbb.sh https://registrationcenter-download.intel.com/akdlm/IRC_NAS/c95cd995-586b-4688-b7e8-2d4485a1b5bf/l_tbb_oneapi_p_2021.10.0.49543_offline.sh &
    tbb_pid=$!
    wget --quiet -O mpi.sh https://registrationcenter-download.intel.com/akdlm/IRC_NAS/4f5871da-0533-4f62-b563-905edfb2e9b7/l_mpi_oneapi_p_2021.10.0.49374_offline.sh &
    mpi_pid=$!
    wget --quiet -O math.sh https://registrationcenter-download.intel.com/akdlm/IRC_NAS/adb8a02c-4ee7-4882-97d6-a524150da358/l_onemkl_p_2023.2.0.49497_offline.sh &
    math_pid=$!

    # Install the Intel assets.
    sh cpp-compiler.sh -a --silent --eula accept 2>&1 | tee install.cpp-compiler.log
    install_after_download $fortran_pid "Intel Fortran compiler" fortran-compiler.sh -a --silent --eula accept
    install_after_download $tbb_pid "Intel Thread Building Blocks" tbb.sh -a --silent --eula accept
    install_after_download $mpi_pid "Intel MPI" mpi.sh -a --silent --eula accept
    install_after_download $math_pid "Intel Math Kernel Lib. (oneMKL)" math.sh -a --silent --eula accept

    popd
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

install_lmod() {
    # Install lua/lmod manually, because apt only has older versions
    # that are not compatible with the modern lua modules spack produces
    # https://lmod.readthedocs.io/en/latest/030_installing.html#install-lua-x-y-z-tar-gz
    mkdir -p /opt/lua/5.1.4.9/src
    cd /opt/lua/5.1.4.9/src
    wget https://sourceforge.net/projects/lmod/files/lua-5.1.4.9.tar.bz2
    tar -xvf lua-5.1.4.9.tar.bz2
    cd lua-5.1.4.9
    ./configure --prefix=/opt/lua/5.1.4.9 2>&1 | tee log.config
    make VERBOSE=1 2>&1 | tee log.make
    make install 2>&1 | tee log.install
    #
    echo "# Set environment variables for lua" >> /etc/profile.d/02-lua.sh
    echo "export PATH=\"/opt/lua/5.1.4.9/bin:\$PATH\"" >> /etc/profile.d/02-lua.sh
    echo "export LD_LIBRARY_PATH=\"/opt/lua/5.1.4.9/lib:\$LD_LIBRARY_PATH\"" >> /etc/profile.d/02-lua.sh
    echo "export CPATH=\"/opt/lua/5.1.4.9/include:\$CPATH\"" >> /etc/profile.d/02-lua.sh
    echo "export MANPATH=\"/opt/lua/5.1.4.9/man:\$MANPATH\"" >> /etc/profile.d/02-lua.sh
    #
    source /etc/profile.d/02-lua.sh
}


set -x
set -e


install_basics

echo -e "\n##\n##\nInstalled system base environment\n##\n##"
sleep 20

if $EAP_AUTH ; then
    setup_eap_auth_and_env
else
    echo "Skipping '@eap' authentication customization."
fi

if $INSTALL_SPACK_REQUIREMENTS ; then
    install_spack_prereq
    echo -e "\n##\n##\nInstalled spack prerequisites\n##\n##"
    sleep 20
else
    echo "skipping spack prerequisites install"
fi

if $INSTALL_INTEL ; then
    install_intel
    echo -e "\n##\n##\nInstalled intel\n##\n##"
    sleep 20
else
    echo "Skipping Intel stack installation"
fi

if $INSTALL_INTEL_HPC ; then
    install_intel_hpc
    echo -e "\n##\n##\nInstalled intel HPC packages\n##\n##"
    sleep 20
else
    echo "skipped intel hpc packages"
fi

if $INSTALL_LMOD ; then
    install_lmod
    echo -e "\n##\n##\nInstalled lmod\n##\n##"
    sleep 20
else
    apt install -y environment-modules
fi

if $INSTALL_DOCKER ; then
    installdocker
    echo -e "\n##\n##\nInstalled docker\n##\n##"
    sleep 20
else
    echo "skipping docker install"
fi
