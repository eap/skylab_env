#!/bin/bash


read -r -d '' HELP_CONTENT << EOM
This script will build a spack-stack environment from scratch.

Required:
  * VERSION: a numbered version, must be a git tag
  * SKYLAB: a numbered skylab version used in the
  * TEMPLATE: the name of the template, defaults to "skylab-dev"

Use:
  VERSION=1.3.1 SKYLAB=4 ./build_spack_env.sh
  VERSION=develop SKYLAB=dev ./build_spack_env.sh
EOM

if [ -z "${TEMPLATE}" ]; then
    TEMPLATE=skylab-dev
fi

set -o errexit
set -x


cd $HOME
git clone -b $VERSION --recursive https://github.com/noaa-emc/spack-stack $VERSION
cd spack-stack-$VERSION

source setup.sh


spack stack create env --site=linux.default --template=$TEMPLATE --name=skylab-$SKYLAB
spack env activate -p envs/skylab-$SKYLAB

export SPACK_SYSTEM_CONFIG_PATH="${HOME}/spack-stack-${VERSION}/envs/skylab-${SKLYAB}/site"


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

GCC_VERSION="$(gcc --version | grep -o -m1 -P "\d{1,2}\.\d{1,2}\.\d{1,2}$")"


# Ubuntu 22.04 do this.
sed -i 's/tcl/lmod/g' ${HOME}/spack-stack-${VERSION}/envs/skylab-${SKYLAB}/site/modules.yaml
spack config add "packages:all:providers:mpi:[mpich@4.0.2]"
spack config add "packages:all:compiler:[gcc@${GCC_VERSION}]"

read -r -d '' END_CONTENT << EOM
# Run the following commands.
cd ~/spack-stack-${VERSION}
spack concretize > concretize.log
nohup bash -c "spack env activate -p envs/skylab-$SKYLAB & spack install --verbose --fail-fast 2>&1 > install.log" &
EOM

echo $END_CONTENT
