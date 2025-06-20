#!/bin/bash
#
# This script does a full Vulkan CTS run, but using deqp runner.

V3D_DEBUG=opt_compile_time deqp-runner run --deqp ./deqp-vk --output vulkan.log --caselist ~/mesa/source/vk-gl-cts/external/vulkancts/mustpass/main/vk-default.txt
