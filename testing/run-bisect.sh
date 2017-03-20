#!/bin/bash
#
# This script runs a specific tests from a test suite against mesa, in
# which an ongoing bisect is happening.
#
# Follow the steps below to use:
#
# 1. If needed tweak the DISPLAY env variable.
# 2. Set the paths to the mesa, piglit and vk-gl-cts builds.
# 3. Choose whether you want to force the rebuild of the test suite.
#
# Run a bisect. This is a simple example of usage:
#
# <path_to_mesa>$ git bisect start
# <path_to_mesa>$ git bisect bad    # Current version is bad
# <path_to_mesa>$ git bisect good <known_good_revision>
# <path_to_mesa>$ git bisect run <path_to>/run-bisect.sh GL44-CTS.shading_language_420pack.initializer_list_negative
#
# It will stop either when:
#    1. A compilation in mesa fails (error code 128).
#    2. An installation in mesa fails (error code 129).
#       * Optionally, the compilation of the CTS tests fail with a
#         specific mesa version (error code 130).
#    3. It has found the last good version of mesa for the specific
#       CTS test.
#
# In the 2 first steps it will need interactive action from the user.
# Usually just:
#
# <path_to_mesa>$ git bisect skip
#
# Normally, it only will stop when 3. is reached.


# SETTINGS
# ========

export DISPLAY=:0.0

# Paths ...
# ---------

DEV_PATH="/home/guest/agomez/jhbuild"
MESA="${DEV_PATH}/mesa.git"
PIGLIT="${DEV_PATH}/piglit.git"
VK_GL_CTS_BUILD="${DEV_PATH}/vk-gl-cts.git/build"

# Rebuild the test suite?
# -----------------------

FORCE_REBUILD=false


# RUNNING
# =======

usage()
{
    echo -e "\e[31mUSAGE:"
    echo -e "\e[31m$0 <test>"
}

if ! [ $1 ]
then
    usage
    exit 131
fi

TIMESTAMP=`date +%Y%m%d%H%M%S`
CTSTEST=$1
RESULT=0
until false; do
  cd "${MESA}"
  make -j12 || (RESULT=128 && break)
  make install || (RESULT=129 && break)
  cd -
  cd "${VK_GL_CTS_BUILD}"
  if [ $FORCE_REBUILD ]; then
      # Rebuilding shouldn't be necessary but we can force it ...
      cmake --build . || (RESULT=130 && break)
  fi
  cd -
  echo 'MESA_GLES_VERSION_OVERRIDE=3.2 MESA_GL_VERSION_OVERRIDE="4.5" MESA_GLSL_VERSION_OVERRIDE="450" '"${VK_GL_CTS_BUILD}"'/cts/glcts --deqp-case='"${CTSTEST}"
  # Duplicate stdout
  exec 5>&1
  CTS_OUTPUT=$(MESA_GLES_VERSION_OVERRIDE=3.2 MESA_GL_VERSION_OVERRIDE="4.5" MESA_GLSL_VERSION_OVERRIDE="450" "${VK_GL_CTS_BUILD}"/external/openglcts/modules/glcts --deqp-case="${CTSTEST}" | tee >(cat - >&5))
  echo "${CTS_OUTPUT}" | grep "Passed" | grep "100.00%"
  RESULT=$?
  break
done

exit $RESULT
