#!/bin/bash


read -r -d '' HELP_CONTENT << EOM
This script will build a spack-stack environment from scratch.

Required:
  * VERSION: a numbered version, must be a git tag
  * SKYLAB: a numbered skylab version used in the
  * TEMPLATE: the name of the template, defaults to "skylab-dev"

Use:
  VERSION=1.4.0 SKYLAB=5 ./build_spack_env.sh
  VERSION=develop SKYLAB=dev ./build_spack_env.sh
EOM

read -r -d '' END_CONTENT << EOM
# Run the following commands.
cd ~/spack-stack-${VERSION}
source setup.sh
spack env activate -p envs/skylab-$SKYLAB
spack concretize > concretize.log
nohup bash -c "source setup.sh & spack env activate -p envs/skylab-$SKYLAB & spack install --verbose --fail-fast 2>&1 > install.log" &
# Only do this if using lmod: spack module lmod refresh
spack module tcl refresh
spack stack setup-meta-modules
EOM

read -r -d '' BASHRC_CONTENT << EOM
# Setup spack stack vars

export SPACK_STACK_DIR=${HOME}/spack-stack-${VERSION}
export SPACK_STACK_MODULE_ROOT=${HOME}/spack-stack-${VERSION}/envs/skylab-${SKYLAB}/install/modulefiles/Core

EOM


if [ -z "${VERSION}" ]; then
    echo "${HELP_CONTENT}"
    echo "Use error: VERSION not set"
fi
if [ -z "${SKYLAB}" ]; then
    echo "${HELP_CONTENT}"
    echo "Use error: SKYLAB NOT SET"
fi

if [ -z "${TEMPLATE}" ]; then
    TEMPLATE=skylab-dev
fi


set -o errexit
set -x

echo "${BASHRC_CONTENT}" >> "${HOME}/.bashrc"

cd $HOME
git clone -b $VERSION --recursive https://github.com/jcsda/spack-stack spack-stack-$VERSION
cd spack-stack-$VERSION

source setup.sh


spack stack create env --site=linux.default --template=$TEMPLATE --name=skylab-$SKYLAB
spack env activate -p envs/skylab-$SKYLAB

export SPACK_SYSTEM_CONFIG_PATH="${HOME}/spack-stack-${VERSION}/envs/skylab-${SKYLAB}/site"


spack external find --scope system
spack external find --scope system perl
# Don't use any external Python, let spack build it
# spack external find --scope system python
spack external find --scope system wget
spack external find --scope system mysql
spack external find --scope system texlive
# On ubuntu you must find curl, not on redhat.
spack external find --scope system curl
# Find compilers.
spack compiler find --scope system

#Do not forget to unset the SPACK_SYSTEM_CONFIG_PATH environment variable!
unset SPACK_SYSTEM_CONFIG_PATH

# Needed for some builds. Note the "-fPIC" flag is rarely harmful and often helpful.
# Adjust the optimization accordingly, this is set for balance of performance and
# acceptable build time. Setting to O3 is best for running experiments.
sed -i "s/flags: {}/flags:\n      cflags: -O2 -fPIC\n      cxxflags: -O2 -fPIC\n      cppflags: -O2 -fPIC/" \
       envs/skylab-$SKYLAB/site/compilers.yaml

GCC_VERSION="$(gcc --version | grep -o -m1 -P "\d{1,2}\.\d{1,2}\.\d{1,2}$")"


# Ubuntu 22.04 do this.
# sed -i 's/tcl/lmod/g' ${HOME}/spack-stack-${VERSION}/envs/skylab-${SKYLAB}/site/modules.yaml
spack config add "packages:all:providers:mpi:[mpich@4.1.1]"
spack config add "packages:all:compiler:[gcc@${GCC_VERSION}]"

set +x

sleep 2
echo
echo "${END_CONTENT}"
