#!/bin/bash
#
# This script does a full Vulkan CTS run, with the options required by
# conformance, plus some additional options for convenience when
# running/debugging this runs

V3D_DEBUG=opt_compile_time ./deqp-vk --deqp-caselist-file=/home/pi/mesa/source/vk-gl-cts/external/vulkancts/mustpass/main/vk-default.txt --deqp-log-images=disable --deqp-log-shader-sources=disable --deqp-log-flush=disable --deqp-waiver-file=/home/pi/mesa/source/vk-gl-cts/external/vulkancts/mustpass/main/waivers.xml --deqp-terminate-on-device-lost=enable --deqp-log-filename=vk-conformance-run.qpa
