#!/bin/bash

export DISPLAY=:0.0

CTSTEST=$1

TIMESTAMP=`date +%Y%m%d%H%M%S`
DEV_PATH="/home/guest/agomez/jhbuild"
MESA="${DEV_PATH}/mesa.git"
PIGLIT="${DEV_PATH}/piglit.git"
VK_GL_CTS_BUILD="${DEV_PATH}/vk-gl-cts.git/build"

RESULT=0
until false; do
  cd "${MESA}"
  # Rebuilding shouldn't be necessary
#  make -j12 || (RESULT=128 && break)
#  make install || (RESULT=129 && break)
  cd -
  cd "${VK_GL_CTS_BUILD}"
  # Rebuilding shouldn't be necessary
#  cmake --build . || (RESULT=130 && break)
  cd -
  echo 'MESA_GLES_VERSION_OVERRIDE=3.2 MESA_GL_VERSION_OVERRIDE="4.5" MESA_GLSL_VERSION_OVERRIDE="450" PIGLIT_SOURCE_DIR='"${PIGLIT}"' PIGLIT_PLATFORM="mixed_glx_egl" '"${VK_GL_CTS_BUILD}"'/cts/glcts --deqp-case='"${CTSTEST}"
  # Duplicate stdout
  exec 5>&1
  CTS_OUTPUT=$(MESA_GLES_VERSION_OVERRIDE=3.2 MESA_GL_VERSION_OVERRIDE="4.5" MESA_GLSL_VERSION_OVERRIDE="450" PIGLIT_SOURCE_DIR="${PIGLIT}" PIGLIT_PLATFORM="mixed_glx_egl" "${VK_GL_CTS_BUILD}"/external/openglcts/modules/glcts --deqp-case="${CTSTEST}" | tee >(cat - >&5))
  echo "${CTS_OUTPUT}" | grep "Passed" | grep "100.00%"
  RESULT=$?
  break
done

exit $RESULT
