#!/bin/bash
#
# This script uses piglit to run a whole test suite (VK-GL-CTS, dEQP,
# piglit) against the currently installed GL driver.
#
# Run:
#
# $ ./full-piglit-run.sh --run-piglit --driver <driver> --commit <mesa-commit-id>

export LC_ALL=C

PATH=${HOME}/.local/bin$(echo :$PATH | sed -e s@:${HOME}/.local/bin@@g)

DISPLAY="${DISPLAY:-:0.0}"
export -p DISPLAY

#------------------------------------------------------------------------------
#			Function: check_driver
#------------------------------------------------------------------------------
#
# perform sanity check on the passed GL driver to run:
#   $1 - the intended GL driver to run
# returns:
#   0 is success, an error code otherwise
check_driver() {
    case "x$1" in
	"xi965" | "xnouveau" | "xnvidia" | "xradeon" | "xamd"  | "xllvmpipe" | "xswr" | "xsoftpipe" )
	    ;;
	*)
	    printf "\nA driver among [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe] has to be provided.\n"
	    usage
	    return 1
	    ;;
    esac

    return 0
}

#------------------------------------------------------------------------------
#			Function: check_option_args
#------------------------------------------------------------------------------
#
# perform sanity checks on cmdline args which require arguments
# arguments:
#   $1 - the option being examined
#   $2 - the argument to the option
# returns:
#   if it returns, everything is good
#   otherwise it exit's
check_option_args() {
    option=$1
    arg=$2

    # check for an argument
    if [ x"$arg" = x ]; then
	printf "\nError: the '$option' option is missing its required argument.\n"
	usage
	exit 2
    fi

    # does the argument look like an option?
    echo $arg | $FPR_GREP "^-" > /dev/null
    if [ $? -eq 0 ]; then
	printf "\nError: the argument '$arg' of option '$option' looks like an option itself.\n"
	usage
	exit 3
    fi
}

#------------------------------------------------------------------------------
#			Function: inner_run_tests
#------------------------------------------------------------------------------
#
# performs the actual execution of the piglit tests
# returns:
#   0 is success, an error code otherwise
function inner_run_tests {
    printf "\n" >&"${FPR_OUTPUT}" 2>&1
    test "x$FPR_INNER_RUN_MESSAGE" = "x" || printf "$FPR_INNER_RUN_MESSAGE " >&"${FPR_OUTPUT}" 2>&1
    printf "$FPR_PIGLIT_PATH/piglit run $FPR_INNER_RUN_SET $FPR_INNER_RUN_PARAMETERS -n $FPR_INNER_RUN_NAME $FPR_INNER_RUN_RESULTS\n" >&"${FPR_OUTPUT}" 2>&1
    $FPR_DRY_RUN && return 0
    "$FPR_PIGLIT_PATH"/piglit run $FPR_INNER_RUN_SET $FPR_INNER_RUN_PARAMETERS -n "$FPR_INNER_RUN_NAME" "$FPR_INNER_RUN_RESULTS" >&"${FPR_OUTPUT}" 2>&1
    if [ $? -ne 0 ]; then
	return 9
    fi
    if $FPR_CREATE_PIGLIT_REPORT; then
	printf "\n$FPR_PIGLIT_PATH/piglit summary console -d $FPR_INNER_RUN_REFERENCE $FPR_INNER_RUN_RESULTS\n" >&"${FPR_OUTPUT}" 2>&1
	FPR_INNER_SUMMARY=$("$FPR_PIGLIT_PATH"/piglit summary console -d "$FPR_INNER_RUN_REFERENCE" "$FPR_INNER_RUN_RESULTS")
	if [ $? -ne 0 ]; then
	    return 10
	fi
	read -ra FPR_INNER_RESULTS <<< $(echo "$FPR_INNER_SUMMARY" | $FPR_GREP ^regressions)
	if [ "x${FPR_INNER_RESULTS[2]}" != "x0" ]; then
	    printf "\n%s\n" "Run name: $FPR_INNER_RUN_NAME" "$FPR_INNER_SUMMARY"
	    printf "\nRegressions: ${FPR_INNER_RESULTS[2]}" >&"${FPR_OUTPUT}" 2>&1
	    printf "\n${FPR_PIGLIT_PATH}/piglit summary html -o -e pass $FPR_INNER_RUN_SUMMARY $FPR_INNER_RUN_REFERENCE $FPR_INNER_RUN_RESULTS\n" >&"${FPR_OUTPUT}" 2>&1
	    "${FPR_PIGLIT_PATH}"/piglit summary html -o -e pass "$FPR_INNER_RUN_SUMMARY" "$FPR_INNER_RUN_REFERENCE" "$FPR_INNER_RUN_RESULTS" > /dev/null 2>&1
	    if [ $? -ne 0 ]; then
		return 11
	    fi
	fi
    fi

    return 0
}

#------------------------------------------------------------------------------
#			Function: run_tests
#------------------------------------------------------------------------------
#
# performs the execution of the piglit tests
# returns:
#   0 is success, an error code otherwise
function run_tests {
    if [ "${FPR_MESA_COMMIT:-x}" == "x" ]; then
	printf "\nA commit id has to be provided.\n"
	usage
	return 4
    fi

    check_driver $FPR_GL_DRIVER
    if [ $? -ne 0 ]; then
	return 5
    fi

    case "x${FPR_GL_DRIVER}" in
	"xllvmpipe" | "xswr" | "xsoftpipe" )
	    LIBGL_ALWAYS_SOFTWARE=1
	    GALLIUM_DRIVER=${FPR_GL_DRIVER}
	    export -p LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER
	    ;;
	*)
	    ;;
    esac

    if ${FPR_RUN_VK_CTS} || ${FPR_RUN_GL_CTS}; then
	cd "${FPR_VK_GL_CTS_BUILD_PATH}"
	VK_GL_CTS_COMMIT=$(git show --pretty=format:"%h" --no-patch)
	cd - > /dev/null
	if [ "x${VK_GL_CTS_COMMIT}" = "x" ]; then
	    printf "\nCouldn\'t get vk-gl-cts\'s commit ID\n"
	    return 6
	fi
    fi

    if ${FPR_RUN_DEQP_GLES2} || ${FPR_RUN_DEQP_GLES3} || ${FPR_RUN_DEQP_GLES31}; then
	cd "${FPR_DEQP_BUILD_PATH}"
	DEQP_COMMIT=$(git show --pretty=format:"%h" --no-patch)
	cd - > /dev/null
	if [ "x${DEQP_COMMIT}" = "x" ]; then
	    printf "\nCouldn\'t get dEQP\'s commit ID\n"
	    return 7
	fi
    fi

    if ${FPR_RUN_PIGLIT}; then
	cd "${FPR_PIGLIT_PATH}"
	PIGLIT_COMMIT=$(git show --pretty=format:"%h" --no-patch)
	cd - > /dev/null
	if [ "x${PIGLIT_COMMIT}" = "x" ]; then
	    printf "\nCouldn\'t get piglit\'s commit ID\n"
	    return 8
	fi
    fi

    TIMESTAMP=`date +%Y%m%d%H%M%S`

    VK_CTS_NAME="${FPR_VK_CTS_PREFIX}-${FPR_GL_DRIVER}-${TIMESTAMP}-${VK_GL_CTS_COMMIT}-mesa-${FPR_MESA_COMMIT}"
    GL_CTS_NAME="${FPR_GL_CTS_PREFIX}-${FPR_GL_DRIVER}-${TIMESTAMP}-${VK_GL_CTS_COMMIT}-mesa-${FPR_MESA_COMMIT}"
    DEQP_GLES2_NAME="${FPR_DEQP_GLES2_PREFIX}-${FPR_GL_DRIVER}-${TIMESTAMP}-${DEQP_COMMIT}-mesa-${FPR_MESA_COMMIT}"
    DEQP_GLES3_NAME="${FPR_DEQP_GLES3_PREFIX}-${FPR_GL_DRIVER}-${TIMESTAMP}-${DEQP_COMMIT}-mesa-${FPR_MESA_COMMIT}"
    DEQP_GLES31_NAME="${FPR_DEQP_GLES31_PREFIX}-${FPR_GL_DRIVER}-${TIMESTAMP}-${DEQP_COMMIT}-mesa-${FPR_MESA_COMMIT}"
    PIGLIT_NAME="${FPR_PIGLIT_PREFIX}-${FPR_GL_DRIVER}-${TIMESTAMP}-${PIGLIT_COMMIT}-mesa-${FPR_MESA_COMMIT}"

    VK_CTS_RESULTS="${FPR_PIGLIT_RESULTS_PATH}/results/${VK_CTS_NAME}"
    GL_CTS_RESULTS="${FPR_PIGLIT_RESULTS_PATH}/results/${GL_CTS_NAME}"
    DEQP_GLES2_RESULTS="${FPR_PIGLIT_RESULTS_PATH}/results/${DEQP_GLES2_NAME}"
    DEQP_GLES3_RESULTS="${FPR_PIGLIT_RESULTS_PATH}/results/${DEQP_GLES3_NAME}"
    DEQP_GLES31_RESULTS="${FPR_PIGLIT_RESULTS_PATH}/results/${DEQP_GLES31_NAME}"
    PIGLIT_RESULTS="${FPR_PIGLIT_RESULTS_PATH}/results/${PIGLIT_NAME}"

    VK_CTS_SUMMARY="${FPR_PIGLIT_RESULTS_PATH}/summary/${VK_CTS_NAME}"
    GL_CTS_SUMMARY="${FPR_PIGLIT_RESULTS_PATH}/summary/${GL_CTS_NAME}"
    DEQP_GLES2_SUMMARY="${FPR_PIGLIT_RESULTS_PATH}/summary/${DEQP_GLES2_NAME}"
    DEQP_GLES3_SUMMARY="${FPR_PIGLIT_RESULTS_PATH}/summary/${DEQP_GLES3_NAME}"
    DEQP_GLES31_SUMMARY="${FPR_PIGLIT_RESULTS_PATH}/summary/${DEQP_GLES31_NAME}"
    PIGLIT_SUMMARY="${FPR_PIGLIT_RESULTS_PATH}/summary/${PIGLIT_NAME}"

    VK_CTS_REFERENCE="${FPR_PIGLIT_RESULTS_PATH}/reference/${FPR_VK_CTS_PREFIX}-${FPR_GL_DRIVER}${FPR_VK_CTS_REFERENCE_SUFFIX:+-}${FPR_VK_CTS_REFERENCE_SUFFIX}"
    GL_CTS_REFERENCE="${FPR_PIGLIT_RESULTS_PATH}/reference/${FPR_GL_CTS_PREFIX}-${FPR_GL_DRIVER}${FPR_GL_CTS_REFERENCE_SUFFIX:+-}${FPR_GL_CTS_REFERENCE_SUFFIX}"
    DEQP_GLES2_REFERENCE="${FPR_PIGLIT_RESULTS_PATH}/reference/${FPR_DEQP_GLES2_PREFIX}-${FPR_GL_DRIVER}${FPR_DEQP_GLES2_REFERENCE_SUFFIX:+-}${FPR_DEQP_GLES2_REFERENCE_SUFFIX}"
    DEQP_GLES3_REFERENCE="${FPR_PIGLIT_RESULTS_PATH}/reference/${FPR_DEQP_GLES3_PREFIX}-${FPR_GL_DRIVER}${FPR_DEQP_GLES3_REFERENCE_SUFFIX:+-}${FPR_DEQP_GLES3_REFERENCE_SUFFIX}"
    DEQP_GLES31_REFERENCE="${FPR_PIGLIT_RESULTS_PATH}/reference/${FPR_DEQP_GLES31_PREFIX}-${FPR_GL_DRIVER}${FPR_DEQP_GLES31_REFERENCE_SUFFIX:+-}${FPR_DEQP_GLES31_REFERENCE_SUFFIX}"
    PIGLIT_REFERENCE="${FPR_PIGLIT_RESULTS_PATH}/reference/${FPR_PIGLIT_PREFIX}-${FPR_GL_DRIVER}${FPR_PIGLIT_REFERENCE_SUFFIX:+-}${FPR_PIGLIT_REFERENCE_SUFFIX}"

    if $FPR_RUN_VK_CTS; then
	export -p PIGLIT_DEQP_VK_BIN="$FPR_VK_GL_CTS_BUILD_PATH"/external/vulkancts/modules/vulkan/deqp-vk
	export -p PIGLIT_DEQP_VK_EXTRA_ARGS="--deqp-log-images=disable --deqp-log-shader-sources=disable"
	FPR_INNER_RUN_SET=deqp_vk
	FPR_INNER_RUN_PARAMETERS=""
	FPR_INNER_RUN_NAME=$VK_CTS_NAME
	FPR_INNER_RUN_RESULTS=$VK_CTS_RESULTS
	FPR_INNER_RUN_REFERENCE=$VK_CTS_REFERENCE
	FPR_INNER_RUN_SUMMARY=$VK_CTS_SUMMARY
	FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_DEQP_VK_BIN=\"$PIGLIT_DEQP_VK_BIN\" \
			      PIGLIT_DEQP_VK_EXTRA_ARGS=\"$PIGLIT_DEQP_VK_EXTRA_ARGS\""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
        unset PIGLIT_DEQP_VK_BIN
        unset PIGLIT_DEQP_VK_EXTRA_ARGS
    fi

    if $FPR_RUN_GL_CTS; then
	export -p PIGLIT_CTS_GL_BIN="${FPR_VK_GL_CTS_BUILD_PATH}"/external/openglcts/modules/glcts
	export -p PIGLIT_CTS_GL_EXTRA_ARGS="--deqp-case=GL45*"
	export -p MESA_GLES_VERSION_OVERRIDE=3.2
	export -p MESA_GL_VERSION_OVERRIDE=4.5
	export -p MESA_GLSL_VERSION_OVERRIDE=450
	FPR_INNER_RUN_SET=cts_gl
	FPR_INNER_RUN_PARAMETERS="-t GL45"
	FPR_INNER_RUN_NAME=$GL_CTS_NAME
	FPR_INNER_RUN_RESULTS=$GL_CTS_RESULTS
	FPR_INNER_RUN_REFERENCE=$GL_CTS_REFERENCE
	FPR_INNER_RUN_SUMMARY=$GL_CTS_SUMMARY
	FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_CTS_GL_BIN=\"$PIGLIT_CTS_GL_BIN\" \
			      PIGLIT_CTS_GL_EXTRA_ARGS=\"$PIGLIT_CTS_GL_EXTRA_ARGS\" \
			      MESA_GLES_VERSION_OVERRIDE=\"$MESA_GLES_VERSION_OVERRIDE\" \
			      MESA_GL_VERSION_OVERRIDE=\"$MESA_GL_VERSION_OVERRIDE\" \
			      MESA_GLSL_VERSION_OVERRIDE=\"$MESA_GLSL_VERSION_OVERRIDE\""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
        unset PIGLIT_CTS_GL_BIN
        unset PIGLIT_CTS_GL_EXTRA_ARGS
        unset MESA_GLES_VERSION_OVERRIDE
        unset MESA_GLSL_VERSION_OVERRIDE
        unset MESA_GLSL_VERSION_OVERRIDE
    fi

    if $FPR_RUN_DEQP_GLES2; then
	export -p PIGLIT_DEQP_GLES2_BIN="${FPR_DEQP_BUILD_PATH}"/modules/gles2/deqp-gles2
	export -p PIGLIT_DEQP_GLES2_EXTRA_ARGS="--deqp-visibility hidden"
	export -p MESA_GLES_VERSION_OVERRIDE=2.0
	FPR_INNER_RUN_SET=deqp_gles2
	FPR_INNER_RUN_PARAMETERS="-t dEQP-GLES2"
	FPR_INNER_RUN_NAME=$DEQP_GLES2_NAME
	FPR_INNER_RUN_RESULTS=$DEQP_GLES2_RESULTS
	FPR_INNER_RUN_REFERENCE=$DEQP_GLES2_REFERENCE
	FPR_INNER_RUN_SUMMARY=$DEQP_GLES2_SUMMARY
	FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_DEQP_GLES2_BIN=\"$PIGLIT_DEQP_GLES2_BIN\" \
			      PIGLIT_DEQP_GLES2_EXTRA_ARGS=\"$PIGLIT_DEQP_GLES2_EXTRA_ARGS\" \
			      MESA_GLES_VERSION_OVERRIDE=\"$MESA_GLES_VERSION_OVERRIDE\""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
        unset PIGLIT_DEQP_GLES2_BIN
        unset PIGLIT_DEQP_GLES2_EXTRA_ARGS
        unset MESA_GLES_VERSION_OVERRIDE
    fi

    if $FPR_RUN_DEQP_GLES3; then
	export -p PIGLIT_DEQP_GLES3_EXE="${FPR_DEQP_BUILD_PATH}"/modules/gles3/deqp-gles3
	export -p PIGLIT_DEQP_GLES3_EXTRA_ARGS="--deqp-visibility hidden"
	export -p MESA_GLES_VERSION_OVERRIDE=3.0
	FPR_INNER_RUN_SET=deqp_gles3
	FPR_INNER_RUN_PARAMETERS="-t dEQP-GLES3"
	FPR_INNER_RUN_NAME=$DEQP_GLES3_NAME
	FPR_INNER_RUN_RESULTS=$DEQP_GLES3_RESULTS
	FPR_INNER_RUN_REFERENCE=$DEQP_GLES3_REFERENCE
	FPR_INNER_RUN_SUMMARY=$DEQP_GLES3_SUMMARY
	FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_DEQP_GLES3_EXE=\"$PIGLIT_DEQP_GLES3_EXE\" \
			      PIGLIT_DEQP_GLES3_EXTRA_ARGS=\"$PIGLIT_DEQP_GLES3_EXTRA_ARGS\" \
			      MESA_GLES_VERSION_OVERRIDE=\"$MESA_GLES_VERSION_OVERRIDE\""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
        unset PIGLIT_DEQP_GLES3_EXE
        unset PIGLIT_DEQP_GLES3_EXTRA_ARGS
        unset MESA_GLES_VERSION_OVERRIDE
    fi

    if $FPR_RUN_DEQP_GLES31; then
	export -p PIGLIT_DEQP_GLES31_BIN="${FPR_DEQP_BUILD_PATH}"/modules/gles31/deqp-gles31
	export -p PIGLIT_DEQP_GLES31_EXTRA_ARGS="--deqp-visibility hidden"
	export -p MESA_GLES_VERSION_OVERRIDE=3.1
	FPR_INNER_RUN_SET=deqp_gles31
	FPR_INNER_RUN_PARAMETERS="-t dEQP-GLES31"
	FPR_INNER_RUN_NAME=$DEQP_GLES31_NAME
	FPR_INNER_RUN_RESULTS=$DEQP_GLES31_RESULTS
	FPR_INNER_RUN_REFERENCE=$DEQP_GLES31_REFERENCE
	FPR_INNER_RUN_SUMMARY=$DEQP_GLES31_SUMMARY
	FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_DEQP_GLES31_BIN=\"$PIGLIT_DEQP_GLES31_BIN\" \
			      PIGLIT_DEQP_GLES31_EXTRA_ARGS=\"$PIGLIT_DEQP_GLES31_EXTRA_ARGS\" \
			      MESA_GLES_VERSION_OVERRIDE=\"$MESA_GLES_VERSION_OVERRIDE\""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
        unset PIGLIT_DEQP_GLES31_BIN
        unset PIGLIT_DEQP_GLES31_EXTRA_ARGS
        unset MESA_GLES_VERSION_OVERRIDE
    fi

    if $FPR_RUN_PIGLIT; then
	FPR_INNER_RUN_SET=all
	FPR_INNER_RUN_PARAMETERS="-x texcombine -x texCombine"
	FPR_INNER_RUN_NAME=$PIGLIT_NAME
	FPR_INNER_RUN_RESULTS=$PIGLIT_RESULTS
	FPR_INNER_RUN_REFERENCE=$PIGLIT_REFERENCE
	FPR_INNER_RUN_SUMMARY=$PIGLIT_SUMMARY
	FPR_INNER_RUN_MESSAGE=""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
    fi
}

#------------------------------------------------------------------------------
#			Function: usage
#------------------------------------------------------------------------------
# Displays the script usage and exits successfully
#
usage() {
    basename="`expr "//$0" : '.*/\([^/]*\)'`"
    cat <<HELP

Usage: $basename [options] --driver [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe] --commit <mesa-commit-id>

Options:
  --dry-run               Does everything except running the tests
  --verbose               Be verbose
  --help                  Display this help and exit successfully
  --driver                Which driver with which to run the tests [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe]
  --commit                Mesa commit to output
  --base-path             PATH from which to create the rest of the relative paths
  --piglit-path           PATH to the built piglit binaries
  --piglit-results-path   PATH to the piglit results
  --vk-gl-cts-path        PATH to the built vk-gl-cts binaries
  --deqp-path             PATH to the built dEQP binaries
  --vk-cts-prefix         Prefix to use with the vk-cts run
  --gl-cts-prefix         Prefix to use with the gl-cts run
  --deqp-gles2-prefix     Prefix to use with the dEQP GLES2 run
  --deqp-gles3-prefix     Prefix to use with the dEQP GLES3 run
  --deqp-gles31-prefix    Prefix to use with the dEQP GLES3.1 run
  --piglit-prefix         Prefix to use with the piglit run
  --run-vk-cts            Run vk-cts
  --run-gl-cts            Run gl-cts
  --run-deqp-gles2-cts    Run dEQP GLES2
  --run-deqp-gles3-cts    Run dEQP GLES3
  --run-deqp-gles31-cts   Run dEQP GLES31
  --run-piglit            Run piglit
  --create-piglit-report  Create results report

HELP
}

#------------------------------------------------------------------------------
#			Script main line
#------------------------------------------------------------------------------
#

# Choose which grep program to use (on Solaris, must be gnu grep)
if [ "x$FPR_GREP" = "x" ] ; then
    if [ -x /usr/gnu/bin/grep ] ; then
	FPR_GREP=/usr/gnu/bin/grep
    else
	FPR_GREP=grep
    fi
fi

# Process command line args
while [ $# != 0 ]
do
    case $1 in
    # Does everything except running the tests
    --dry-run)
	FPR_DRY_RUN=true
	;;
    # Be verbose
    --verbose)
	FPR_VERBOSE=true
	;;
    # Display this help and exit successfully
    --help)
	usage
	exit 0
	;;
    # Which driver with which to run the tests [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe]
    --driver)
	check_option_args $1 $2
	shift
	FPR_GL_DRIVER=$1
	;;
    # Mesa commit to output
    --commit)
	check_option_args $1 $2
	shift
	FPR_MESA_COMMIT=$1
	;;
    # PATH from which to create the rest of the relative paths
    --base-path)
	check_option_args $1 $2
	shift
	FPR_DEV_PATH=$1
	;;
    # PATH to the built piglit binaries
    --piglit-path)
	check_option_args $1 $2
	shift
	FPR_PIGLIT_PATH=$1
	;;
    # PATH to the piglit results
    --piglit-results-path)
	check_option_args $1 $2
	shift
	FPR_PIGLIT_RESULTS_PATH=$1
	;;
    # PATH to the built vk-gl-cts binaries
    --vk-gl-cts-path)
	check_option_args $1 $2
	shift
	FPR_VK_GL_CTS_BUILD_PATH=$1
	;;
    # PATH to the built dEQP binaries
    --deqp-path)
	check_option_args $1 $2
	shift
	FPR_DEQP_BUILD_PATH=$1
	;;
    # Prefix to use with the vk-cts run
    --vk-cts-prefix)
	check_option_args $1 $2
	shift
	FPR_VK_CTS_PREFIX=$1
	;;
    # Prefix to use with the gl-cts run
    --gl-cts-prefix)
	check_option_args $1 $2
	shift
	FPR_GL_CTS_PREFIX=$1
	;;
    # Prefix to use with the dEQP GLES2 run
    --deqp-gles2-prefix)
	check_option_args $1 $2
	shift
	FPR_DEQP_GLES2_PREFIX=$1
	;;
    # Prefix to use with the dEQP GLES3 run
    --deqp-gles3-prefix)
	check_option_args $1 $2
	shift
	FPR_DEQP_GLES3_PREFIX=$1
	;;
    # Prefix to use with the dEQP GLES3.1 run
    --deqp-gles31-prefix)
	check_option_args $1 $2
	shift
	FPR_DEQP_GLES31_PREFIX=$1
	;;
    # Prefix to use with the piglit run
    --piglit-prefix)
	check_option_args $1 $2
	shift
	FPR_PIGLIT_PREFIX=$1
	;;
    # Run vk-cts
    --run-vk-cts)
	FPR_RUN_VK_CTS=true
	;;
    # Run gl-cts
    --run-gl-cts)
	FPR_RUN_GL_CTS=true
	;;
    # Run dEQP GLES2
    --run-deqp-gles2-cts)
	FPR_RUN_DEQP_GLES2=true
	;;
    # Run dEQP GLES3
    --run-deqp-gles3-cts)
	FPR_RUN_DEQP_GLES3=true
	;;
    # Run dEQP GLES31
    --run-deqp-gles31-cts)
	FPR_RUN_DEQP_GLES31=true
	;;
    # Run piglit
    --run-piglit)
	FPR_RUN_PIGLIT=true
	;;
    # Create results report
    --create-piglit-report)
	FPR_CREATE_PIGLIT_REPORT=true
	;;
    --*)
	printf "\nError: unknown option: $1.\n"
	usage
	exit 1
	;;
    -*)
	printf "\nError: unknown option: $1.\n"
	usage
	exit 1
	;;
    *)
	printf "\nError: unknown extra parameter: $1.\n"
	usage
	exit 1
	;;
    esac

    shift
done

# Paths ...
# ---------

FPR_DEV_PATH="${FPR_DEV_PATH:-/home/guest/agomez/jhbuild}"
FPR_PIGLIT_PATH="${FPR_PIGLIT_PATH:-${FPR_DEV_PATH}/piglit.git}"
FPR_PIGLIT_RESULTS_PATH="${FPR_PIGLIT_RESULTS_PATH:-${FPR_DEV_PATH}/piglit-results}"
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

# Verbose?
# --------

FPR_VERBOSE="${FPR_VERBOSE:-false}"

# dry run?
# --------

FPR_DRY_RUN="${FPR_DRY_RUN:-false}"

# Create a report against the reference result?
# ---------------------------------------------

FPR_CREATE_PIGLIT_REPORT="${FPR_CREATE_PIGLIT_REPORT:-false}"

if ${FPR_VERBOSE}; then
    FPR_OUTPUT=1
else
    FPR_OUTPUT=/dev/null
fi

run_tests

exit $?
