#!/bin/bash
#
# This script uses piglit to run a whole test suite (VK-GL-CTS, dEQP,
# piglit) against the currently installed GL driver.
#
# Follow the steps below to use:
#
# 1. If needed tweak the DISPLAY env variable.
# 2. Set the paths to the piglit, vk-gl-cts and deqp builds or set the
#    following env variables:
#    * FPR_DEV_PATH
#    * FPR_PIGLIT_PATH
#    * FPR_PIGLIT_REPORTS_PATH
#    * FPR_VK_GL_CTS_BUILD_PATH
#    * FPR_DEQP_BUILD_PATH
# 3. Choose the prefixes to use for each test suite or set the
#    following env variables:
#    * FPR_VK_CTS_PREFIX
#    * FPR_GL_CTS_PREFIX
#    * FPR_DEQP_GLES2_PREFIX
#    * FPR_DEQP_GLES3_PREFIX
#    * FPR_DEQP_GLES31_PREFIX
#    * FPR_PIGLIT_PREFIX
# 4. Choose which test suites to run or set to true at least one of
#    the following env variables:
#    * FPR_RUN_VK_CTS
#    * FPR_RUN_GL_CTS
#    * FPR_RUN_DEQP_GLES2
#    * FPR_RUN_DEQP_GLES3
#    * FPR_RUN_DEQP_GLES31
#    * FPR_RUN_PIGLIT
# 5. Optionally, set the following env variables:
#    * FPR_VK_CTS_REFERENCE_SUFFIX
#    * FPR_GL_CTS_REFERENCE_SUFFIX
#    * FPR_DEQP_GLES2_REFERENCE_SUFFIX
#    * FPR_DEQP_GLES3_REFERENCE_SUFFIX
#    * FPR_DEQP_GLES31_REFERENCE_SUFFIX
#    * FPR_PIGLIT_REFERENCE_SUFFIX
# 6. Whether to create or not a summary against the reference run or
#    set to true/false the following env variable:
#    * FPR_CREATE_PIGLIT_REPORT
#
# Run:
#
# $ ./full-piglit-run.sh <driver> <mesa-commit-id>

usage()
{
    echo -e "\e[31mUSAGE:"
    echo -e "\e[31m$0 <driver> <mesa-commit-id>"
    echo "            Driver:i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe"
}

if ! [ $1 ]; then
    usage
    exit -1
fi

GL_DRIVER="${1}"
shift

if ! [ $1 ]; then
    usage
    exit -2
fi

MESA_COMMIT="${1}"
shift

case "x${GL_DRIVER}" in
"xi965" | "xnouveau" | "xnvidia" | "xradeon" | "xamd" )
    export -p GL_DRIVER
    ;;
"xllvmpipe" | "xswr" | "xsoftpipe" )
    LIBGL_ALWAYS_SOFTWARE=1
    GALLIUM_DRIVER=${GL_DRIVER}
    export -p GL_DRIVER LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER
    ;;
*)
    usage
    exit -3
    ;;
esac


# SETTINGS
# ========

DISPLAY="${DISPLAY:-:0.0}"
export -p DISPLAY

# Paths ...
# ---------

FPR_DEV_PATH="${FPR_DEV_PATH:-/home/guest/agomez/jhbuild}"
FPR_PIGLIT_PATH="${FPR_PIGLIT_PATH:-${FPR_DEV_PATH}/piglit.git}"
FPR_PIGLIT_REPORTS_PATH="${FPR_PIGLIT_REPORTS_PATH:-${FPR_DEV_PATH}/piglit-results}"
FPR_VK_GL_CTS_BUILD_PATH="${FPR_VK_GL_CTS_BUILD_PATH:-${FPR_DEV_PATH}/vk-gl-cts.git/build}"
FPR_DEQP_BUILD_PATH="${FPR_DEQP_BUILD_PATH:-${FPR_DEV_PATH}/android-deqp/external/deqp/}"

# Prefixes:
# ---------

FPR_VK_CTS_PREFIX="${FPR_VK_CTS_PREFIX:-VK-CTS}"
FPR_GL_CTS_PREFIX="${FPR_GL_CTS_PREFIX:-GL-CTS}"
FPR_DEQP_GLES2_PREFIX="${FPR_DEQP_GLES2_PREFIX:-DEQP2}"
FPR_DEQP_GLES3_PREFIX="${FPR_DEQP_GLES3_PREFIX:-DEQP3}"
FPR_DEQP_GLES31_PREFIX="${FPR_DEQP_GLES31_PREFIX:-DEQP31}"
FPR_PIGLIT_PREFIX="${FPR_PIGLIT_PREFIX:-all}"

# What tests to run?
# ------------------

FPR_RUN_VK_CTS="${FPR_RUN_VK_CTS:-false}"
FPR_RUN_GL_CTS="${FPR_RUN_GL_CTS:-false}"
FPR_RUN_DEQP_GLES2="${FPR_RUN_DEQP_GLES2:-false}"
FPR_RUN_DEQP_GLES3="${FPR_RUN_DEQP_GLES3:-false}"
FPR_RUN_DEQP_GLES31="${FPR_RUN_DEQP_GLES31:-false}"
FPR_RUN_PIGLIT="${FPR_RUN_PIGLIT:-false}"

# Create a report against the reference result?
# ---------------------------------------------

FPR_CREATE_PIGLIT_REPORT="${FPR_CREATE_PIGLIT_REPORT:-false}"


# RUNNING
# =======

if ${FPR_RUN_VK_CTS} || ${FPR_RUN_GL_CTS}; then
    cd "${FPR_VK_GL_CTS_BUILD_PATH}"
    VK_GL_CTS_COMMIT=$(git show --pretty=format:"%h" --no-patch)
    cd -
    if [ "x${VK_GL_CTS_COMMIT}" = "x" ]; then
	printf "Couldn\'t get vk-gl-cts\'s commit ID\n"
	exit -4
    fi
fi

if ${FPR_RUN_DEQP_GLES2} || ${FPR_RUN_DEQP_GLES3} || ${FPR_RUN_DEQP_GLES31}; then
    cd "${FPR_DEQP_BUILD_PATH}"
    DEQP_COMMIT=$(git show --pretty=format:"%h" --no-patch)
    cd -
    if [ "x${DEQP_COMMIT}" = "x" ]; then
	printf "Couldn\'t get dEQP\'s commit ID\n"
	exit -5
    fi
fi

if ${FPR_RUN_PIGLIT}; then
    cd "${FPR_PIGLIT_PATH}"
    PIGLIT_COMMIT=$(git show --pretty=format:"%h" --no-patch)
    cd -
    if [ "x${PIGLIT_COMMIT}" = "x" ]; then
	printf "Couldn\'t get piglit\'s commit ID\n"
	exit -6
    fi
fi

TIMESTAMP=`date +%Y%m%d%H%M%S`

VK_CTS_NAME="${FPR_VK_CTS_PREFIX}-${GL_DRIVER}-${TIMESTAMP}-${VK_GL_CTS_COMMIT}-mesa-${MESA_COMMIT}"
GL_CTS_NAME="${FPR_GL_CTS_PREFIX}-${GL_DRIVER}-${TIMESTAMP}-${VK_GL_CTS_COMMIT}-mesa-${MESA_COMMIT}"
DEQP_GLES2_NAME="${FPR_DEQP_GLES2_PREFIX}-${GL_DRIVER}-${TIMESTAMP}-${DEQP_COMMIT}-mesa-${MESA_COMMIT}"
DEQP_GLES3_NAME="${FPR_DEQP_GLES3_PREFIX}-${GL_DRIVER}-${TIMESTAMP}-${DEQP_COMMIT}-mesa-${MESA_COMMIT}"
DEQP_GLES31_NAME="${FPR_DEQP_GLES31_PREFIX}-${GL_DRIVER}-${TIMESTAMP}-${DEQP_COMMIT}-mesa-${MESA_COMMIT}"
PIGLIT_NAME="${FPR_PIGLIT_PREFIX}-${GL_DRIVER}-${TIMESTAMP}-${PIGLIT_COMMIT}-mesa-${MESA_COMMIT}"

VK_CTS_RESULTS="${FPR_PIGLIT_REPORTS_PATH}/results/${VK_CTS_NAME}"
GL_CTS_RESULTS="${FPR_PIGLIT_REPORTS_PATH}/results/${GL_CTS_NAME}"
DEQP_GLES2_RESULTS="${FPR_PIGLIT_REPORTS_PATH}/results/${DEQP_GLES2_NAME}"
DEQP_GLES3_RESULTS="${FPR_PIGLIT_REPORTS_PATH}/results/${DEQP_GLES3_NAME}"
DEQP_GLES31_RESULTS="${FPR_PIGLIT_REPORTS_PATH}/results/${DEQP_GLES31_NAME}"
PIGLIT_RESULTS="${FPR_PIGLIT_REPORTS_PATH}/results/${PIGLIT_NAME}"

VK_CTS_SUMMARY="${FPR_PIGLIT_REPORTS_PATH}/summary/${VK_CTS_NAME}"
GL_CTS_SUMMARY="${FPR_PIGLIT_REPORTS_PATH}/summary/${GL_CTS_NAME}"
DEQP_GLES2_SUMMARY="${FPR_PIGLIT_REPORTS_PATH}/summary/${DEQP_GLES2_NAME}"
DEQP_GLES3_SUMMARY="${FPR_PIGLIT_REPORTS_PATH}/summary/${DEQP_GLES3_NAME}"
DEQP_GLES31_SUMMARY="${FPR_PIGLIT_REPORTS_PATH}/summary/${DEQP_GLES31_NAME}"
PIGLIT_SUMMARY="${FPR_PIGLIT_REPORTS_PATH}/summary/${PIGLIT_NAME}"

VK_CTS_REFERENCE="${FPR_PIGLIT_REPORTS_PATH}/reference/${FPR_VK_CTS_PREFIX}-${GL_DRIVER}${FPR_VK_CTS_REFERENCE_SUFFIX:+-}${FPR_VK_CTS_REFERENCE_SUFFIX}"
GL_CTS_REFERENCE="${FPR_PIGLIT_REPORTS_PATH}/reference/${FPR_GL_CTS_PREFIX}-${GL_DRIVER}${FPR_GL_CTS_REFERENCE_SUFFIX:+-}${FPR_GL_CTS_REFERENCE_SUFFIX}"
DEQP_GLES2_REFERENCE="${FPR_PIGLIT_REPORTS_PATH}/reference/${FPR_DEQP_GLES2_PREFIX}-${GL_DRIVER}${FPR_DEQP_GLES2_REFERENCE_SUFFIX:+-}${FPR_DEQP_GLES2_REFERENCE_SUFFIX}"
DEQP_GLES3_REFERENCE="${FPR_PIGLIT_REPORTS_PATH}/reference/${FPR_DEQP_GLES3_PREFIX}-${GL_DRIVER}${FPR_DEQP_GLES3_REFERENCE_SUFFIX:+-}${FPR_DEQP_GLES3_REFERENCE_SUFFIX}"
DEQP_GLES31_REFERENCE="${FPR_PIGLIT_REPORTS_PATH}/reference/${FPR_DEQP_GLES31_PREFIX}-${GL_DRIVER}${FPR_DEQP_GLES31_REFERENCE_SUFFIX:+-}${FPR_DEQP_GLES31_REFERENCE_SUFFIX}"
PIGLIT_REFERENCE="${FPR_PIGLIT_REPORTS_PATH}/reference/${FPR_PIGLIT_PREFIX}-${GL_DRIVER}${FPR_PIGLIT_REFERENCE_SUFFIX:+-}${FPR_PIGLIT_REFERENCE_SUFFIX}"

( ! ${FPR_RUN_VK_CTS} \
    || ( echo PIGLIT_DEQP_VK_BIN="${FPR_VK_GL_CTS_BUILD_PATH}"/external/vulkancts/modules/vulkan/deqp-vk  \
              PIGLIT_DEQP_VK_EXTRA_ARGS="--deqp-log-images=disable --deqp-log-shader-sources=disable" \
             "${FPR_PIGLIT_PATH}"/piglit run deqp_vk -n "${VK_CTS_NAME}" "${VK_CTS_RESULTS}" \
         && PIGLIT_DEQP_VK_BIN="${FPR_VK_GL_CTS_BUILD_PATH}"/external/vulkancts/modules/vulkan/deqp-vk \
            PIGLIT_DEQP_VK_EXTRA_ARGS="--deqp-log-images=disable --deqp-log-shader-sources=disable" \
            "${FPR_PIGLIT_PATH}"/piglit run deqp_vk -n "${VK_CTS_NAME}" "${VK_CTS_RESULTS}" \
         && unset PIGLIT_DEQP_VK_BIN \
         && unset PIGLIT_DEQP_VK_EXTRA_ARGS \
         && ( ! ${FPR_CREATE_PIGLIT_REPORT} \
                || "${FPR_PIGLIT_PATH}"/piglit summary html --overwrite "${PIGLIT_SUMMARY}" "${VK_CTS_REFERENCE}" "${FPR_PIGLIT_REPORTS_PATH}" ) ) ) \
  && ( ! ${FPR_RUN_GL_CTS} \
    || ( echo PIGLIT_CTS_GL_BIN="${FPR_VK_GL_CTS_BUILD_PATH}"/external/openglcts/modules/glcts \
              PIGLIT_CTS_GL_EXTRA_ARGS="--deqp-case=GL45*" \
              MESA_GLES_VERSION_OVERRIDE=3.2 \
              MESA_GL_VERSION_OVERRIDE=4.5 \
              MESA_GLSL_VERSION_OVERRIDE=450 \
             "${FPR_PIGLIT_PATH}"/piglit run cts_gl -t GL45 -n "${GL_CTS_NAME}" "${GL_CTS_RESULTS}" \
         && PIGLIT_CTS_GL_BIN="${FPR_VK_GL_CTS_BUILD_PATH}"/external/openglcts/modules/glcts \
            PIGLIT_CTS_GL_EXTRA_ARGS="--deqp-case=GL45*" \
            MESA_GLES_VERSION_OVERRIDE=3.2 \
            MESA_GL_VERSION_OVERRIDE=4.5 \
            MESA_GLSL_VERSION_OVERRIDE=450 \
            "${FPR_PIGLIT_PATH}"/piglit run cts_gl -t GL45 -n "${GL_CTS_NAME}" "${GL_CTS_RESULTS}" \
         && unset PIGLIT_CTS_GL_BIN \
         && unset PIGLIT_CTS_GL_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && unset MESA_GLSL_VERSION_OVERRIDE \
         && unset MESA_GLSL_VERSION_OVERRIDE \
         && ( ! ${FPR_CREATE_PIGLIT_REPORT} \
                || "${FPR_PIGLIT_PATH}"/piglit summary html --overwrite "${PIGLIT_SUMMARY}" "${GL_CTS_REFERENCE}" "${FPR_PIGLIT_REPORTS_PATH}" ) ) ) \
  && ( ! ${FPR_RUN_DEQP_GLES2} \
    || ( echo PIGLIT_DEQP_GLES2_BIN="${FPR_DEQP_BUILD_PATH}"/modules/gles2/deqp-gles2 \
              PIGLIT_DEQP_GLES2_EXTRA_ARGS="--deqp-visibility hidden" \
              MESA_GLES_VERSION_OVERRIDE=2.0 \
              "${FPR_PIGLIT_PATH}"/piglit run deqp_gles2 -t dEQP-GLES2 -n "${DEQP_GLES2_NAME}" "${DEQP_GLES2_RESULTS}" \
         && PIGLIT_DEQP_GLES2_BIN="${FPR_DEQP_BUILD_PATH}"/modules/gles2/deqp-gles2 \
            PIGLIT_DEQP_GLES2_EXTRA_ARGS="--deqp-visibility hidden" \
            MESA_GLES_VERSION_OVERRIDE=2.0 \
            "${FPR_PIGLIT_PATH}"/piglit run deqp_gles2 -t dEQP-GLES2 -n "${DEQP_GLES2_NAME}" "${DEQP_GLES2_RESULTS}" \
         && unset PIGLIT_DEQP_GLES2_BIN \
         && unset PIGLIT_DEQP_GLES2_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && ( ! ${FPR_CREATE_PIGLIT_REPORT} \
                || "${FPR_PIGLIT_PATH}"/piglit summary html --overwrite "${DEQP_GLES2_SUMMARY}" "${DEQP_GLES2_REFERENCE}" "${DEQP_GLES2_RESULTS}" ) ) ) \
  && ( ! ${FPR_RUN_DEQP_GLES3} \
    || ( echo PIGLIT_DEQP_GLES3_EXE="${FPR_DEQP_BUILD_PATH}"/modules/gles3/deqp-gles3 \
              PIGLIT_DEQP_GLES3_EXTRA_ARGS="--deqp-visibility hidden" \
              MESA_GLES_VERSION_OVERRIDE=3.0 \
              "${FPR_PIGLIT_PATH}"/piglit run deqp_gles3 -t dEQP-GLES3 -n "${DEQP_GLES3_NAME}" "${DEQP_GLES3_RESULTS}" \
         && PIGLIT_DEQP_GLES3_EXE="${FPR_DEQP_BUILD_PATH}"/modules/gles3/deqp-gles3 \
            PIGLIT_DEQP_GLES3_EXTRA_ARGS="--deqp-visibility hidden" \
            MESA_GLES_VERSION_OVERRIDE=3.0 \
            "${FPR_PIGLIT_PATH}"/piglit run deqp_gles3 -t dEQP-GLES3 -n "${DEQP_GLES3_NAME}" "${DEQP_GLES3_RESULTS}" \
         && unset PIGLIT_DEQP_GLES3_EXE \
         && unset PIGLIT_DEQP_GLES3_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && ( ! ${FPR_CREATE_PIGLIT_REPORT} \
                || "${FPR_PIGLIT_PATH}"/piglit summary html --overwrite "${DEQP_GLES3_SUMMARY}" "${DEQP_GLES3_REFERENCE}" "${DEQP_GLES3_RESULTS}" ) ) ) \
  && ( ! ${FPR_RUN_DEQP_GLES31} \
    || ( echo PIGLIT_DEQP_GLES31_BIN="${FPR_DEQP_BUILD_PATH}"/modules/gles31/deqp-gles31 \
              PIGLIT_DEQP_GLES31_EXTRA_ARGS="--deqp-visibility hidden" \
              MESA_GLES_VERSION_OVERRIDE=3.1 \
              "${FPR_PIGLIT_PATH}"/piglit run deqp_gles31 -t dEQP-GLES31 -n "${DEQP_GLES31_NAME}" "${DEQP_GLES31_RESULTS}" \
         && PIGLIT_DEQP_GLES31_BIN="${FPR_DEQP_BUILD_PATH}"/modules/gles31/deqp-gles31 \
            PIGLIT_DEQP_GLES31_EXTRA_ARGS="--deqp-visibility hidden" \
            MESA_GLES_VERSION_OVERRIDE=3.1 \
	    "${FPR_PIGLIT_PATH}"/piglit run deqp_gles31 -t dEQP-GLES31 -n "${DEQP_GLES31_NAME}" "${DEQP_GLES31_RESULTS}" \
         && unset PIGLIT_DEQP_GLES31_BIN \
         && unset PIGLIT_DEQP_GLES31_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && ( ! ${FPR_CREATE_PIGLIT_REPORT} \
                || "${FPR_PIGLIT_PATH}"/piglit summary html --overwrite "${DEQP_GLES31_SUMMARY}" "${DEQP_GLES31_REFERENCE}" "${DEQP_GLES31_RESULTS}" ) ) ) \
  && ( ! ${FPR_RUN_PIGLIT} \
    || ( echo "${FPR_PIGLIT_PATH}"/piglit run all -x texcombine -x texCombine -n "${PIGLIT_NAME}" "${PIGLIT_RESULTS}" \
	       && "${FPR_PIGLIT_PATH}"/piglit run all -x texcombine -x texCombine -n "${PIGLIT_NAME}" "${PIGLIT_RESULTS}" \
	       && ( ! ${FPR_CREATE_PIGLIT_REPORT} \
			  || "${FPR_PIGLIT_PATH}"/piglit summary html --overwrite "${PIGLIT_SUMMARY}" "${PIGLIT_REFERENCE}" "${PIGLIT_RESULTS}" ) ) )

exit $?



# Reminder compilation line for VK-GL-CTS
# ---------------------------------------

# cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS="-Werror -Wno-error=unused-command-line-argument -m64" -DCMAKE_CXX_FLAGS="-Werror -Wno-error=unused-command-line-argument -m64" -DCMAKE_C_COMPILER=clang-3.9 -DCMAKE_CXX_COMPILER=clang++-3.9 -DDEQP_TARGET=x11_egl -DGLCTS_GTF_TARGET=gles32 -DCMAKE_LIBRARY_PATH=/home/agomez/devel/graphics/install/lib/ -DCMAKE_INCLUDE_PATH=/home/agomez/devel/graphics/install/include/
