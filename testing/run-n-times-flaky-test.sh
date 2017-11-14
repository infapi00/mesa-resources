#!/bin/bash
#
# This script runs a piglit test n times, and returns how many runs
# have passed. Useful for flaky tests.
#
# Syntax : run-n-times-flaky-test.sh [--pass-line <pass_line> | --suite [piglit|vk-gl-cts]] --times <n_times> <test_to_run>

export LC_ALL=C

PATH=${HOME}/.local/bin$(echo :$PATH | sed -e s@:${HOME}/.local/bin@@g)

DISPLAY="${DISPLAY:-:0.0}"
export -p DISPLAY


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
function check_option_args() {
    option=$1
    arg=$2

    # check for an argument
    if [ x"$arg" = x ]; then
	printf "%s\n" "Error: the '$option' option is missing its required argument." >&2
	usage
	exit 2
    fi

    # does the argument look like an option?
    echo $arg | $RNT_GREP "^-" > /dev/null
    if [ $? -eq 0 ]; then
	printf "%s\n" "Error: the argument '$arg' of option '$option' looks like an option itself." >&2
	usage
	exit 3
    fi
}


#------------------------------------------------------------------------------
#			Function: check_times
#------------------------------------------------------------------------------
#
# perform sanity check on the passed amount of times to run:
#   $1 - the intended amount of times to run
# returns:
#   0 is success, an error code otherwise
function check_times() {
    RNT_RE='^[0-9]+$'
    if ! [[ "$1" =~ $RNT_RE ]] ; then
	printf "%s\n" "Error: Not a number." >&2
	usage
	return 1
    fi

    return 0
}


#------------------------------------------------------------------------------
#			Function: check_suite
#------------------------------------------------------------------------------
#
# perform sanity check on the passed test suite to use:
#   $1 - the intended test suite to use
# returns:
#   0 is success, an error code otherwise
function check_suite() {
    if [ "x$RNT_PASS_LINE" != "x" ]; then
	printf "%s\n" "Error: --suite is incompatible with --pass-line." >&2
	usage
	return 1
    fi

    case "x$1" in
	"xpiglit" )
	    RNT_PASS_LINE="${RNT_PIGLIT_LINE}"
	    ;;
	"xvk-gl-cts" )
	    RNT_PASS_LINE="${RNT_VK_GL_CTS_LINE}"
	    ;;
	*)
	    printf "%s\n" "Error: A suite among [piglit|vk-gl-cts] has to be provided." >&2
	    usage
	    return 1
	    ;;
    esac

    return 0
}


#------------------------------------------------------------------------------
#			Function: run_test
#------------------------------------------------------------------------------
#
# performs the actual execution of the test
# returns:
#   0 is success, an error code otherwise
function run_test {
    RNT_PASS=0
    RNT_FAIL=0

    for (( i=1; i <= "${RNT_TIMES}"; i++ ));
    do
	if [ $($RNT_TEST | grep "${RNT_PASS_LINE}" | wc -l) -eq 1 ]
	then
            ((RNT_PASS=RNT_PASS+1))
	else
            ((RNT_FAIL=RNT_FAIL+1))
	fi
    done

    printf "Runs: %i, Pass: %i, Fail: %i\n" $RNT_TIMES $RNT_PASS $RNT_FAIL
    if [ $((RNT_TIMES-RNT_PASS)) -ne $RNT_FAIL ]
    then
	#This can happens because we are only checking for RNT_PASS, but there
	#are other status
	printf "Warning: pass+fail is different that the total number of runs\n"
    fi

    return 0
}


#------------------------------------------------------------------------------
#			Function: usage
#------------------------------------------------------------------------------
# Displays the script usage and exits successfully
#
function usage() {
    basename="`expr "//$0" : '.*/\([^/]*\)'`"
    cat <<HELP

Usage: $basename [--pass-line <pass_line> | --suite [piglit|vk-gl-cts]] --times <n_times> <test_to_run>

Options:
  --help                      Display this help and exit successfully
  --times <n_times>           Amount of <n_times> to run the provided test
  --suite [piglit|vk-gl-cts]  Whether this is a piglit or vk-gl-cts test.
  --pass-line <pass_line>     If different than the default one, provide the
                              <pass_line> to check

HELP
}


#------------------------------------------------------------------------------
#			Script main line
#------------------------------------------------------------------------------
#


RNT_PIGLIT_LINE='PIGLIT: {"result": "pass" }'
RNT_VK_GL_CTS_LINE='Passed:        1/1 (100.0%)'


# Choose which grep program to use (on Solaris, must be gnu grep)
if [ "x$RNT_GREP" = "x" ] ; then
    if [ -x /usr/gnu/bin/grep ] ; then
	RNT_GREP=/usr/gnu/bin/grep
    else
	RNT_GREP=grep
    fi
fi

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# Process command line args
while [ $# != 0 ]
do
    case $1 in
    # Display this help and exit successfully
    --help)
	usage
	exit 0
	;;
    # Amount of times to run the provided test
    --times)
	check_option_args $1 $2
	shift
	RNT_TIMES="$1"
	check_times "${RNT_TIMES}"
	if [ $? -ne 0 ]; then
	    exit 4
	fi
	;;
    # Whether this is a piglit or vk-gl-cts test
    --suite)
	check_option_args $1 $2
	shift
	RNT_SUITE="$1"
	check_suite "${RNT_SUITE}"
	if [ $? -ne 0 ]; then
	    exit 5
	fi
	;;
    # If different than the default one, provide the pass line to check
    --pass-line)
	check_option_args $1 $2
	shift
	if [ "x$RNT_PASS_LINE" != "x" ]; then
	    printf "%s\n" "Error: --suite is incompatible with --pass-line." >&2
	    usage
	    exit 6
	fi
	RNT_PASS_LINE="$1"
	;;
    --*)
	printf "%s\n" "Error: unknown option: $1" >&2
	usage
	exit 1
	;;
    -*)
	printf "%s\n" "Error: unknown option: $1" >&2
	usage
	exit 1
	;;
    *)
	if [ "x$RNT_TIMES" = "x" ] || [ "x$RNT_PASS_LINE" = "x" ]; then
	    printf "%s\n" "Error: unknown extra parameter: $1" >&2
	    usage
	    exit 1
	else
	    RNT_TEST="$@"
	    break
	fi
	;;
    esac

    shift
done


#---


run_test

exit $?
