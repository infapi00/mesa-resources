#!/bin/bash
#
# This script is a wrapper over deqp-runner to run all the aosp tests
# for gles. We don't include gl, as for aosp, it goes up to 4.5, and
# this script is tailored to be used on drivers for embedded, like
# v3d, panfrost, etc.
#
# In order to run it on a reasonable time, this script only runs one
# configuration. It let the default options for most of the
# parameters, except for deqp-gl-config name, that uses explicitly
# rgba8888d24s8ms0 configuration, to ensure that we are using a
# conformance-required option. But note that for conformance runs,
# cts-runner uses several configurations.
#
# We also set the option --deqp-waiver-file, to avoid warnings due a
# waivers file that could not be opened. This started to happen after
# CTS commit 6ca88d8e0d9c, that adds additional checks and warnings
# related to the Waiver file, that includes a warning is the waiver
# file is not found. As the default value for that option is '', it
# raises that warning if not specified.

deqp-runner run --deqp ./glcts --output gles2-aosp.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/aosp_mustpass/main/gles2-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml
deqp-runner run --deqp ./glcts --output gles3-aosp.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/aosp_mustpass/main/gles3-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml
deqp-runner run --deqp ./glcts --output gles31-aosp.log --caselist ~/mesa/source/vk-gl-cts/external/openglcts/data/gl_cts/data/mustpass/gles/aosp_mustpass/main/gles31-main.txt -- --deqp-gl-config-name=rgba8888d24s8ms0 --deqp-waiver-file=gl_cts/data/mustpass/waivers/waivers.xml

cat gles2-aosp.log/failures.csv gles3-aosp.log/failures.csv gles31-aosp.log/failures.csv > all-aosp-cts-failures.csv
