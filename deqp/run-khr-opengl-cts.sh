#!/bin/bash
#
# This script is a wrapper over deqp-runner to run all the mandatory
# tests for gles/egl/gl. For the case of gl, up to gl31, as this
# script is tailored to be used on drivers for embedded, like v3d,
# panfrost, etc.
#
# In order to run it on a reasonable time, this script only runs one
# configuration. It let the default options for most of the
# parameters, except for deqp-gl-config name, that uses explicitly
# rgba8888d24s8ms0 configuration, to ensure that we are using a
# conformance-required option. But note that for conformance runs,
# cts-runner uses several configurations.
#
# For GL we also need to use the option
# --deqp-terminate-on-device-lost=disable to avoid crashes on drivers
# that lacks KHR_robustness. This is a workaround, and the problem
# needs to be solved on CTS. There is already a CTS issue to track it.
#
# We also set the option --deqp-waiver-file, to avoid warnings due a
# waivers file that could not be opened. This started to happen after
# CTS commit 6ca88d8e0d9c, that adds additional checks and warnings
# related to the Waiver file, that includes a warning is the waiver
# file is not found. As the default value for that option is '', it
# raises that warning if not specified.

deqp-runner run --deqp ./glcts --output gles2.log  --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/khronos_mustpass/main/gles2-khr-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml
deqp-runner run --deqp ./glcts --output gles3.log  --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/khronos_mustpass/main/gles3-khr-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml
deqp-runner run --deqp ./glcts --output gles31.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/khronos_mustpass/main/gles31-khr-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml
deqp-runner run --deqp ./glcts --output gl30.log   --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gl/khronos_mustpass/main/gl30-main.txt -- --deqp-terminate-on-device-lost=disable --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml
deqp-runner run --deqp ./glcts --output gl31.log   --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gl/khronos_mustpass/main/gl31-main.txt -- --deqp-terminate-on-device-lost=disable --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml
deqp-runner run --deqp ./glcts --output egl.log    --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/egl/aosp_mustpass/main/egl-main.txt -- --deqp-terminate-on-device-lost=disable --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml

cat gles2.log/failures.csv gles3.log/failures.csv gles31.log/failures.csv gl30.log/failures.csv gl31.log/failures.csv egl.log/failures.csv > all-khr-cts-failures.csv
