#!/bin/bash
#
# This script is a wrapper over deqp-runner to run all the aosp tests
# for gles. We don't include gl, as for aosp, it goes up to 4.5. Note
# that this only run the rgba8888d24s8ms0  configuration

deqp-runner run --deqp ./glcts --output gles2-aosp.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/aosp_mustpass/main/gles2-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0
deqp-runner run --deqp ./glcts --output gles3-aosp.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/aosp_mustpass/main/gles3-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0
deqp-runner run --deqp ./glcts --output gles31-aosp.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/aosp_mustpass/main/gles31-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0

cat gles2-aosp.log/failures.csv gles3-aosp.log/failures.csv gles31-aosp.log/failures.csv > all-aosp-cts-failures.csv
