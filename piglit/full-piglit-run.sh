#!/bin/bash

export DISPLAY=:0.0

TIMESTAMP=`date +%Y%m%d%H%M%S`
DEV_PATH="/home/guest/agomez/jhbuild"
PIGLIT="${DEV_PATH}/piglit.git"
PIGLIT_RESULTS="${DEV_PATH}/piglit-results"
VK_GL_CTS_BUILD="${DEV_PATH}/vk-gl-cts.git/build"
DEQP_BUILD="${DEV_PATH}/android-deqp/external/deqp/"
RUN_VK_GL_CTS=true
RUN_DEQP_GLES2=false
RUN_DEQP_GLES3=false
RUN_DEQP_GLES31=false
RUN_PIGLIT=false
VK_GL_CTS_REFERENCE=reference/VK-GL-GL45-CTS-20161118173616
DEQP_GLES2_REFERENCE=reference/DEQP2-20160927194922
DEQP_GLES3_REFERENCE=reference/DEQP3-20160927233138
DEQP_GLES31_REFERENCE=reference/DEQP31-20160928061503
PIGLIT_REFERENCE=reference/all-20160928132005
CREATE_PIGLIT_REPORT=false

( ! ${RUN_VK_GL_CTS} \
    || ( echo PIGLIT_CTS_GL_BIN="${VK_GL_CTS_BUILD}"/external/openglcts/modules/glcts \
              PIGLIT_CTS_GL_EXTRA_ARGS="--deqp-case=GL45*" \
              MESA_GLES_VERSION_OVERRIDE=3.2 \
              MESA_GL_VERSION_OVERRIDE=4.5 \
              MESA_GLSL_VERSION_OVERRIDE=450 \
             "${PIGLIT}"/piglit run cts_gl -t GL45 -n VK-GL-GL45-CTS-BDW-GT2-"${TIMESTAMP}" "${PIGLIT_RESULTS}"/results/VK-GL-GL45-CTS-BDW-GT2-"${TIMESTAMP}" \
         && PIGLIT_CTS_GL_BIN="${VK_GL_CTS_BUILD}"/external/openglcts/modules/glcts \
            PIGLIT_CTS_GL_EXTRA_ARGS="--deqp-case=GL45*" \
            MESA_GLES_VERSION_OVERRIDE=3.2 \
            MESA_GL_VERSION_OVERRIDE=4.5 \
            MESA_GLSL_VERSION_OVERRIDE=450 \
            "${PIGLIT}"/piglit run cts_gl -t GL45 -n VK-GL-GL45-CTS-BDW-GT2-"${TIMESTAMP}" "${PIGLIT_RESULTS}"/results/VK-GL-GL45-CTS-BDW-GT2-"${TIMESTAMP}" \
         && unset PIGLIT_CTS_GL_BIN \
         && unset PIGLIT_CTS_GL_EXTRA_ARGS \
         && unset MESA_GLSL_VERSION_OVERRIDE \
         && unset MESA_GLSL_VERSION_OVERRIDE \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${PIGLIT_RESULTS}"/summary/VK-GL-GL45-CTS-BDW-GT2 "${PIGLIT_RESULTS}"/"${VK_GL_CTS_REFERENCE}" "${PIGLIT_RESULTS}"/results/VK-GL-GL45-CTS-BDW-GT2-"${TIMESTAMP}" ) ) ) \
  && ( ! ${RUN_DEQP_GLES2} \
    || ( echo PIGLIT_DEQP_GLES2_BIN="${DEQP_BUILD}"/modules/gles2/deqp-gles2 \
              PIGLIT_DEQP_GLES2_EXTRA_ARGS="--deqp-visibility hidden" \
              "${PIGLIT}"/piglit run deqp_gles2 -t dEQP-GLES2 "${PIGLIT_RESULTS}"/results/DEQP2-"${TIMESTAMP}" \
         && PIGLIT_DEQP_GLES2_BIN="${DEQP_BUILD}"/modules/gles2/deqp-gles2 \
            PIGLIT_DEQP_GLES2_EXTRA_ARGS="--deqp-visibility hidden" \
            "${PIGLIT}"/piglit run deqp_gles2 -t dEQP-GLES2 "${PIGLIT_RESULTS}"/results/DEQP2-"${TIMESTAMP}" \
         && unset PIGLIT_DEQP_GLES2_BIN \
         && unset PIGLIT_DEQP_GLES2_EXTRA_ARGS \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${PIGLIT_RESULTS}"/summary/DEQP2 "${PIGLIT_RESULTS}"/"${DEQP2_REFERENCE}" "${PIGLIT_RESULTS}"/results/DEQP2-"${TIMESTAMP}" ) ) ) \
  && ( ! ${RUN_DEQP_GLES3} \
    || ( echo PIGLIT_DEQP_GLES3_EXE="${DEQP_BUILD}"/modules/gles3/deqp-gles3 \
              PIGLIT_DEQP_GLES3_EXTRA_ARGS="--deqp-visibility hidden" \
              "${PIGLIT}"/piglit run deqp_gles3 -t dEQP-GLES3 "${PIGLIT_RESULTS}"/results/DEQP3-"${TIMESTAMP}" \
         && PIGLIT_DEQP_GLES3_EXE="${DEQP_BUILD}"/modules/gles3/deqp-gles3 \
            PIGLIT_DEQP_GLES3_EXTRA_ARGS="--deqp-visibility hidden" \
            "${PIGLIT}"/piglit run deqp_gles3 -t dEQP-GLES3 "${PIGLIT_RESULTS}"/results/DEQP3-"${TIMESTAMP}" \
         && unset PIGLIT_DEQP_GLES3_EXE \
         && unset PIGLIT_DEQP_GLES3_EXTRA_ARGS \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${PIGLIT_RESULTS}"/summary/DEQP3 "${PIGLIT_RESULTS}"/"${DEQP3_REFERENCE}" "${PIGLIT_RESULTS}"/results/DEQP3-"${TIMESTAMP}" ) ) ) \
  && ( ! ${RUN_DEQP_GLES31} \
    || ( echo MESA_GLES_VERSION_OVERRIDE=3.1 \
              PIGLIT_DEQP_GLES31_BIN="${DEQP_BUILD}"/modules/gles31/deqp-gles31 \
              PIGLIT_DEQP_GLES31_EXTRA_ARGS="--deqp-visibility hidden" \
              "${PIGLIT}"/piglit run deqp_gles31 -t dEQP-GLES31 "${PIGLIT_RESULTS}"/results/DEQP31-"${TIMESTAMP}" \
         && MESA_GLES_VERSION_OVERRIDE=3.1 \
            PIGLIT_DEQP_GLES31_BIN="${DEQP_BUILD}"/modules/gles31/deqp-gles31 \
            PIGLIT_DEQP_GLES31_EXTRA_ARGS="--deqp-visibility hidden" \
            "${PIGLIT}"/piglit run deqp_gles31 -t dEQP-GLES31 "${PIGLIT_RESULTS}"/results/DEQP31-"${TIMESTAMP}" \
         && unset PIGLIT_DEQP_GLES31_BIN \
         && unset PIGLIT_DEQP_GLES31_EXTRA_ARGS \
         && unset MESA_GLES_VERSION_OVERRIDE \
         && ( ! ${CREATE_PIGLIT_REPORT} \
                || "${PIGLIT}"/piglit summary html --overwrite "${PIGLIT_RESULTS}"/summary/DEQP31 "${PIGLIT_RESULTS}"/"${DEQP31_REFERENCE}" "${PIGLIT_RESULTS}"/results/DEQP31-"${TIMESTAMP}" ) ) ) \
  && ( ! ${RUN_PIGLIT} \
    || "${PIGLIT}"/piglit run all -x texcombine -x texCombine -n all-"${TIMESTAMP}" ../piglit-results/results/all-"${TIMESTAMP}" \
       && ( ! ${CREATE_PIGLIT_REPORT} \
              || "${PIGLIT}"/piglit summary html --overwrite "${PIGLIT_RESULTS}"/summary/all "${PIGLIT_RESULTS}"/"${PIGLIT_REFERENCE}" "${PIGLIT_RESULTS}"/results/all-"${TIMESTAMP}" ) )

exit $?



# Reminder compilation line for VK-GL-CTS
# cmake .. -DCMAKE_C_FLAGS="-Werror -Wno-error=unused-command-line-argument -m64" -DCMAKE_CXX_FLAGS="-Werror -Wno-error=unused-command-line-argument -m64" -DCMAKE_C_COMPILER=clang-3.9 -DCMAKE_CXX_COMPILER=clang++-3.9 -DDEQP_TARGET=x11_egl -DGLCTS_GTF_TARGET=gles32 -DCMAKE_LIBRARY_PATH=/home/agomez/devel/graphics/install/lib/ -DCMAKE_INCLUDE_PATH=/home/agomez/devel/graphics/install/include/
