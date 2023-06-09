#!/bin/bash


# enable module usage for jedi-ufs.mymacos
# This uses built in clang 14.0.0 from xcode.
# You will need to source this file.

# This is only needed during initial setup.
#export SPACK_SYSTEM_CONFIG_PATH="${HOME}/git/spack-stack/envs/skylab-3.0.0/site"

if [ -z "${SPACK_STACK_DIR}" ]; then
    echo
    echo
    echo "Error: SPACK_STACK_DIR not set"
    echo
fi
if [ -z "${SPACK_STACK_MODULE_ROOT}" ]; then
    echo
    echo
    echo "Error: SPACK_STACK_MODULE_ROOT not set"
    echo
fi


if grep -q "Darwin" <<< "$(uname -a)" ; then
    source /usr/local/opt/lmod/init/profile
fi
module purge

# Not needed but can be useful if debugging or updating spack stack.
# source $SPACK_STACK_DIR/setup.sh
# spack env activate -p envs/skylab-dev

module use $SPACK_STACK_MODULE_ROOT/Core

if grep -q "Darwin" <<< "$(uname -a)" ; then
  module load stack-apple-clang
  module load stack-openmpi
  export PS1="\033[1;34m(skylab-dev)\033[0m $(cut -c 8- <<< $PS1)"
fi
if grep -q "Ubuntu" <<< "$(uname -a)" ; then
  module load stack-gcc
  module load stack-mpich
  export PS1="\033[1;34m(skylab-dev)\033[0m ${PS1}"
fi


module load stack-python
module load jedi-base-env
module load jedi-fv3-env
module load jedi-ewok-env

# Activate skylab venv
if [ -f $HOME/git/jedi-bundle/venv/bin/activate ]; then
  source $HOME/git/jedi-bundle/venv/bin/activate
fi
if [ -f $HOME/jedi-bundle/venv/bin/activate ]; then
  source $HOME/jedi-bundle/venv/bin/activate
fi








#!/bin/bash

# JEDI_ROOT var must be defined and must be a directory.
if [ ! -z $JEDI_ROOT ] && [ -d $JEDI_ROOT ]; then
  # Set host name for R2D2/EWOK

  # On Orion:
  #export R2D2_HOST=orion
  # On Discover:
  #export R2D2_HOST=discover
  # On Cheyenne:
  #export R2D2_HOST=cheyenne
  # On S4:
  #export R2D2_HOST=s4
  # On AWS Parallel Cluster
  #export R2D2_HOST=aws-pcluster
  # On your local machine / AWS single node
  unset R2D2_HOST

  if [ -z $JEDI_BUILD ]; then
    export JEDI_BUILD=${JEDI_ROOT}/build
  fi

  if [ -z $EWOK_WORKDIR ]; then
    export EWOK_WORKDIR=${JEDI_ROOT}/workdir
  fi

  if [ -z $EWOK_FLOWDIR ]; then
    export EWOK_FLOWDIR=${JEDI_ROOT}/ecflow
  fi

  # Add ioda python bindings to PYTHONPATH
  if [ -d "${JEDI_BUILD}/lib/python${PYTHON_VERSION}" ]; then
    PYTHON_VERSION=`python3 -c 'import sys; version=sys.version_info[:2]; print("{0}.{1}".format(*version))'`
    export PYTHONPATH="${JEDI_BUILD}/lib/python${PYTHON_VERSION}/pyioda:${PYTHONPATH}"
  fi

  # necessary user directories for ewok and ecFlow files
  mkdir -p $EWOK_WORKDIR $EWOK_FLOWDIR

  # ecFlow vars
  myid=$(id -u ${USER})
  if [[ $myid -gt 64000 ]]; then
    myid=$(awk -v min=3000 -v max=31000 -v seed=$RANDOM 'BEGIN{srand(seed); print int(min + rand() * (max - min + 1))}')
  fi
  export ECF_PORT=$((myid + 1500))


  # The ecflow hostname (e.g. a specific login node) is different from the R2D2/EWOK general host (i.e. system) name
  host=$(hostname | cut -f1 -d'.')
  export ECF_HOST=$host


  if [[ x"${R2D2_HOST}" == "x" ]]; then
    export EWOK_STATIC_DATA=${JEDI_ROOT}/static
  else
    case $R2D2_HOST in
      orion)
        export EWOK_STATIC_DATA=/work/noaa/da/role-da/static
        ;;
      discover)
        export EWOK_STATIC_DATA=/discover/nobackup/projects/jcsda/s2127/static
        ;;
      cheyenne)
        export EWOK_STATIC_DATA=/glade/p/mmm/jedipara/static
        ;;
      s4)
        export EWOK_STATIC_DATA=/data/prod/jedi/static
        ;;
      aws-pcluster)
        export EWOK_STATIC_DATA=${JEDI_ROOT}/static
        ;;
      *)
        echo "Unknown host name $R2D2_HOST"
        exit 1
        ;;
    esac
  fi
else
  echo "JEDI_ROOT not defined, skipping jedi and ewok setup"
fi
