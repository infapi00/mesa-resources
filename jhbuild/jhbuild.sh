#!/bin/bash
#
# Set the JHBuild environment with the jhbuild-compile.sh
# script. Check the usage documentation there.
#
# Once the environment has been created, you can use this script to
# wrap the JHBuild command for a specific driver. For example, for
# entering into the shell for the i965 one, run:
#
# $ ./jhbuild.sh i965 shell

source ./jhbuild-helper.sh

${JHBUILD_MESA_ROOT}/jhbuild-install/bin/jhbuild -f ${FULL_BASE_PATH}/jhbuildrc-expert $@
