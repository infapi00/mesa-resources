#!/bin/bash
#
# This script is a wrapper over deqp-runner to run all the mandatory
# tests for gles/egl/gl. Note that this would run only with the
# default configuration, while a conformance run (ie: ./cts-runner
# --type=es31), would run only for es31 but with a lot of different
# configurations.

deqp-runner run --deqp ./glcts --output gles2.log  --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/khronos_mustpass/main/gles2-khr-main.txt
deqp-runner run --deqp ./glcts --output gles3.log  --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/khronos_mustpass/main/gles3-khr-main.txt
deqp-runner run --deqp ./glcts --output gles31.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/khronos_mustpass/main/gles31-khr-main.txt
deqp-runner run --deqp ./glcts --output gl30.log   --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gl/khronos_mustpass/main/gl30-main.txt
deqp-runner run --deqp ./glcts --output gl31.log   --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gl/khronos_mustpass/main/gl31-main.txt
deqp-runner run --deqp ./glcts --output egl.log    --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/egl/aosp_mustpass/main/egl-main.txt
cat gles2.log/failures.csv gles3.log/failures.csv gles31.log/failures.csv gl30.log/failures.csv gl31.log/failures.csv egl.log/failures.csv > all-opengl-cts.csv
