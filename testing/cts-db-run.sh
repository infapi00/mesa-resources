#!/bin/bash

# Emulates shader-db run output using Vulkan or OpenGL CTS deqp runner instead.
# As it captures vertex/fragment/computer shader NIR/ASM output, it only works
# with Intel.  Then you can use shader-db report to generate final report.
#
# WARNING: it executes each test separately 3 times, in order to get results for
# each of the shader; try to keep the list of tests limited.
#
# Example of use:
#
# cts-db-run.sh  Projects/mesa/vk-gl-cts/_build/external/vulkancts/modules/vulkan/deqp-vk  dEQP-VK.glsl.builtin.precision.asin.* | tee original
# # Do proper changes in code
# cts-db-run.sh  Projects/mesa/vk-gl-cts/_build/external/vulkancts/modules/vulkan/deqp-vk  dEQP-VK.glsl.builtin.precision.asin.* | tee modified
# # Create report
# ~/shader-db/report original modified


if [ $# != 2 ]; then
    echo "Usage: $0 <path-to-deqp-runner> <list-of-tests>"
    exit 0
fi

RUNNER=$1
TESTS=$2

TESTLIST=`$1 -n $2 --deqp-runmode=stdout-caselist | grep TEST: | cut -c 7-`
for t in $TESTLIST ; do
    export INTEL_DEBUG=vs
    RESULTS=`$1 -n $t 2>&1 | grep instructions | sed "s/\./,/g"`
    if [ -n "$RESULTS" ]; then
        echo "$t - VS $RESULTS"
    fi
    export INTEL_DEBUG=fs
    RESULTS=`$1 -n $t 2>&1 | grep instructions | sed "s/\./,/g"`
    if [ -n "$RESULTS" ]; then
        echo "$t - FS $RESULTS"
    fi
    export INTEL_DEBUG=cs
    RESULTS=`$1 -n $t 2>&1 | grep instructions | sed "s/\./,/g"`
    if [ -n "$RESULTS" ]; then
        echo "$t - CS $RESULTS"
    fi
done
