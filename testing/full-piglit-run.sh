#!/bin/bash
#
# This script uses piglit to run a whole test suite (VK-GL-CTS, dEQP,
# piglit) against the currently installed GL driver.
#
# Follow the steps below to use:
#
# 1. If needed tweak the DISPLAY env variable.
# 2. Set the paths to the piglit, vk-gl-cts and deqp builds.
# 3. Choose the prefixes to use for each test suite.
# 4. Set the paths to existing reference results for each test suite.
# 5. Choose which test suites to run.
# 6. Whether to create or not a summary against the reference run.
#
# Run:
#
# $ ./full-piglit-run.sh


# SETTINGS
# ========

export DISPLAY=:0.0

# Paths ...
# ---------

DEV_PATH="/home/guest/agomez/jhbuild"
PIGLIT="${DEV_PATH}/piglit.git"
PIGLIT_REPORTS="${DEV_PATH}/piglit-results"
VK_GL_CTS_BUILD="${DEV_PATH}/vk-gl-cts.git/build"
DEQP_BUILD="${DEV_PATH}/android-deqp/external/deqp/"

# Prefixes:
# ---------

VK_GL_CTS_PREFIX="VK-GL-CTS"
DEQP_GLES2_PREFIX="DEQP2"
DEQP_GLES3_PREFIX="DEQP3"
DEQP_GLES31_PREFIX="DEQP31"
PIGLIT_PREFIX="all"

# Reference run results:
# ----------------------

VK_GL_CTS_REFERENCE="${PIGLIT_REPORTS}/reference/${VK_GL_CTS_PREFIX}-20161118173616"
DEQP_GLES2_REFERENCE="${PIGLIT_REPORTS}/reference/${DEQP_GLES2_PREFIX}-20160927194922"
DEQP_GLES3_REFERENCE="${PIGLIT_REPORTS}/reference/${DEQP_GLES3_PREFIX}-20160927233138"
DEQP_GLES31_REFERENCE="${PIGLIT_REPORTS}/reference/${DEQP_GLES31_PREFIX}-20160928061503"
PIGLIT_REFERENCE="${PIGLIT_REPORTS}/reference/${PIGLIT_PREFIX}-20160928132005"

# What tests to run?
# ------------------

RUN_VK_GL_CTS=true
RUN_DEQP_GLES2=false
RUN_DEQP_GLES3=false
RUN_DEQP_GLES31=false
RUN_PIGLIT=false

# Create a report against the reference result?
# ---------------------------------------------

CREATE_PIGLIT_REPORT=false


# RUNNING
# =======

TIMESTAMP=`date +%Y%m%d%H%M%S`

VK_GL_CTS_NAME="${VK_GL_CTS_PREFIX}-${TIMESTAMP}"
DEQP_GLES2_NAME="${DEQP_GLES2_PREFIX}-${TIMESTAMP}"
DEQP_GLES3_NAME="${DEQP_GLES3_PREFIX}-${TIMESTAMP}"
DEQP_GLES31_NAME="${DEQP_GLES31_PREFIX}-${TIMESTAMP}"
PIGLIT_NAME="${PIGLIT_PREFIX}-${TIMESTAMP}"

VK_GL_CTS_RESULTS="${PIGLIT_REPORTS}/results/${VK_GL_CTS_NAME}"
DEQP_GLES2_RESULTS="${PIGLIT_REPORTS}/results/${DEQP_GLES2_NAME}"
DEQP_GLES3_RESULTS="${PIGLIT_REPORTS}/results/${DEQP_GLES3_NAME}"
DEQP_GLES31_RESULTS="${PIGLIT_REPORTS}/results/${DEQP_GLES31_NAME}"
PIGLIT_RESULTS="${PIGLIT_REPORTS}/results/${PIGLIT_NAME}"

VK_GL_CTS_SUMMARY="${PIGLIT_REPORTS}/summary/${VK_GL_CTS_NAME}"
DEQP_GLES2_SUMMARY="${PIGLIT_REPORTS}/summary/${DEQP_GLES2_NAME}"
DEQP_GLES3_SUMMARY="${PIGLIT_REPORTS}/summary/${DEQP_GLES3_NAME}"
DEQP_GLES31_SUMMARY="${PIGLIT_REPORTS}/summary/${DEQP_GLES31_NAME}"
PIGLIT_SUMMARY="${PIGLIT_REPORTS}/summary/${PIGLIT_NAME}"

( ! ${RUN_VK_GL_CTS} \
    || ( echo PIGLIT_CTS_GL_BIN="${VK_GL_CTS_BUILD}"/external/openglcts/modules/glcts \
              PIGLIT_CTS_GL_EXTRA_ARGS="--deqp-case=GL45*" \
              MESA_GLES_VERSION_OVERRIDE=3.2 \
              MESA_GL_VERSION_OVERRIDE=4.5 \
              MESA_GLSL_VERSION_OVERRIDE=450 \
             "${PIGLIT}"/piglit run cts_gl -t GL45 -n "${VK_GL_CTS_NAME}" "${VK_GL_CTS_RESULTS}" \
         && PIGLIT_CTS_GL_BIN="${VK_GL_CTS_BUILD}"/external/openglcts/modules/glcts \
            PIGLIT_CTS_GL_EXTRA_ARGS="--deqp-case=GL45*" \
            MESA_GLES_VERSION_OVERRIDE=3.2 \
            MESA_GL_VERSION_OVERRIDE=4.5 \
            MESA_GLSL_VERSION_OVERRIDE=450 \
            "${PIGLIT}"/piglit run cts_gl -t GL45 -n "${VK_GL_CTS_NAME}" "${VK_GL_CTS_RESULTS}" \
         && unset PIGLIT_CTS_GL_BIN \
         && unset PIGLIT_CTS_GL_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && unset MESA_GLSL_VERSION_OVERRIDE \
         && unset MESA_GLSL_VERSION_OVERRIDE \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${PIGLIT_SUMMARY}" "${VK_GL_CTS_REFERENCE}" "${PIGLIT_REPORTS}" ) ) ) \
  && ( ! ${RUN_DEQP_GLES2} \
    || ( echo PIGLIT_DEQP_GLES2_BIN="${DEQP_BUILD}"/modules/gles2/deqp-gles2 \
              PIGLIT_DEQP_GLES2_EXTRA_ARGS="--deqp-visibility hidden" \
              MESA_GLES_VERSION_OVERRIDE=2.0 \
              "${PIGLIT}"/piglit run deqp_gles2 -t dEQP-GLES2 -n "${DEQP_GLES2_NAME}" "${DEQP_GLES2_RESULTS}" \
         && PIGLIT_DEQP_GLES2_BIN="${DEQP_BUILD}"/modules/gles2/deqp-gles2 \
            PIGLIT_DEQP_GLES2_EXTRA_ARGS="--deqp-visibility hidden" \
            MESA_GLES_VERSION_OVERRIDE=2.0 \
            "${PIGLIT}"/piglit run deqp_gles2 -t dEQP-GLES2 -n "${DEQP_GLES2_NAME}" "${DEQP_GLES2_RESULTS}" \
         && unset PIGLIT_DEQP_GLES2_BIN \
         && unset PIGLIT_DEQP_GLES2_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${DEQP_GLES2_SUMMARY}" "${DEQP_GLES2_REFERENCE}" "${DEQP_GLES2_RESULTS}" ) ) ) \
  && ( ! ${RUN_DEQP_GLES3} \
    || ( echo PIGLIT_DEQP_GLES3_EXE="${DEQP_BUILD}"/modules/gles3/deqp-gles3 \
              PIGLIT_DEQP_GLES3_EXTRA_ARGS="--deqp-visibility hidden" \
              MESA_GLES_VERSION_OVERRIDE=3.0 \
              "${PIGLIT}"/piglit run deqp_gles3 -t dEQP-GLES3 -n "${DEQP_GLES3_NAME}" "${DEQP_GLES3_RESULTS}" \
         && PIGLIT_DEQP_GLES3_EXE="${DEQP_BUILD}"/modules/gles3/deqp-gles3 \
            PIGLIT_DEQP_GLES3_EXTRA_ARGS="--deqp-visibility hidden" \
            MESA_GLES_VERSION_OVERRIDE=3.0 \
            "${PIGLIT}"/piglit run deqp_gles3 -t dEQP-GLES3 -n "${DEQP_GLES3_NAME}" "${DEQP_GLES3_RESULTS}" \
         && unset PIGLIT_DEQP_GLES3_EXE \
         && unset PIGLIT_DEQP_GLES3_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${DEQP_GLES3_SUMMARY}" "${DEQP_GLES3_REFERENCE}" "${DEQP_GLES3_RESULTS}" ) ) ) \
  && ( ! ${RUN_DEQP_GLES31} \
    || ( echo PIGLIT_DEQP_GLES31_BIN="${DEQP_BUILD}"/modules/gles31/deqp-gles31 \
              PIGLIT_DEQP_GLES31_EXTRA_ARGS="--deqp-visibility hidden" \
              MESA_GLES_VERSION_OVERRIDE=3.1 \
              "${PIGLIT}"/piglit run deqp_gles31 -t dEQP-GLES31 -n "${DEQP_GLES31_NAME}" "${DEQP_GLES31_RESULTS}" \
         && PIGLIT_DEQP_GLES31_BIN="${DEQP_BUILD}"/modules/gles31/deqp-gles31 \
            PIGLIT_DEQP_GLES31_EXTRA_ARGS="--deqp-visibility hidden" \
            MESA_GLES_VERSION_OVERRIDE=3.1 \
	    "${PIGLIT}"/piglit run deqp_gles31 -t dEQP-GLES31 -n "${DEQP_GLES31_NAME}" "${DEQP_GLES31_RESULTS}" \
         && unset PIGLIT_DEQP_GLES31_BIN \
         && unset PIGLIT_DEQP_GLES31_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${DEQP_GLES31_SUMMARY}" "${DEQP_GLES31_REFERENCE}" "${DEQP_GLES31_RESULTS}" ) ) ) \
  && ( ! ${RUN_PIGLIT} \
    || "${PIGLIT}"/piglit run all -x texcombine -x texCombine -n all-"${PIGLIT_NAME}" "${PIGLIT_SUMMAR}Y" \
       && ( ! ${CREATE_PIGLIT_REPORT} \
              || "${PIGLIT}"/piglit summary html --overwrite "${PIGLIT_SUMMARY}" "${PIGLIT_REFERENCE}" "${PIGLIT_RESULTS}" ) )

exit $?



# Reminder compilation line for VK-GL-CTS
# ---------------------------------------

# cmake .. -DCMAKE_C_FLAGS="-Werror -Wno-error=unused-command-line-argument -m64" -DCMAKE_CXX_FLAGS="-Werror -Wno-error=unused-command-line-argument -m64" -DCMAKE_C_COMPILER=clang-3.9 -DCMAKE_CXX_COMPILER=clang++-3.9 -DDEQP_TARGET=x11_egl -DGLCTS_GTF_TARGET=gles32 -DCMAKE_LIBRARY_PATH=/home/agomez/devel/graphics/install/lib/ -DCMAKE_INCLUDE_PATH=/home/agomez/devel/graphics/install/include/
