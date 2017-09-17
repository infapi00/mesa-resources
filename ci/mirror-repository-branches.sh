#!/bin/bash
#
# This script mirrors a list of branches in a specified origin
# repository from another specified upstream repository. If no
# branches list is provided, only master is updated by default.
#
# Run:
#
# $ ./mirror-repository-branches.sh --origin <url-origin-git-repository> --upstream  <url-upstream-git-repository>


export LC_ALL=C

PATH=${HOME}/.local/bin$(echo :$PATH | sed -e s@:${HOME}/.local/bin@@g)


#------------------------------------------------------------------------------
#			Function: backup_redirection
#------------------------------------------------------------------------------
#
# backups current stout and sterr file handlers
function backup_redirection() {
        exec 7>&1            # Backup stout.
        exec 8>&2            # Backup sterr.
        exec 9>&1            # New handler for stout when we actually want it.
}


#------------------------------------------------------------------------------
#			Function: restore_redirection
#------------------------------------------------------------------------------
#
# restores previously backed up stout and sterr file handlers
function restore_redirection() {
        exec 1>&7 7>&-       # Restore stout.
        exec 2>&8 8>&-       # Restore sterr.
        exec 9>&-            # Closing open handler.
}


#------------------------------------------------------------------------------
#			Function: check_verbosity
#------------------------------------------------------------------------------
#
# perform sanity check on the passed verbosity level:
#   $1 - the verbosity to use
# returns:
#   0 is success, an error code otherwise
function check_verbosity() {
    case "x$1" in
	"xfull" | "xnormal" | "xquiet" )
	    ;;
	*)
	    printf "%s\n" "Error: Only verbosity levels among [full|normal|quiet] are allowed." >&2
	    usage
	    return 1
	    ;;
    esac

    return 0
}


#------------------------------------------------------------------------------
#			Function: apply_verbosity
#------------------------------------------------------------------------------
#
# applies the passed verbosity level to the output:
#   $1 - the verbosity to use
function apply_verbosity() {

    backup_redirection

    if [ "x$1" != "xfull" ]; then
	exec 1>/dev/null
	MRB_PROGRESS_FLAG="-q"
    fi

    if [ "x$1" == "xquiet" ]; then
	exec 2>/dev/null
	exec 9>/dev/null
    fi
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
    echo $arg | $MRB_GREP "^-" > /dev/null
    if [ $? -eq 0 ]; then
	printf "%s\n" "Error: the argument '$arg' of option '$option' looks like an option itself." >&2
	usage
	exit 3
    fi
}

#------------------------------------------------------------------------------
#			Function: apply_changes
#------------------------------------------------------------------------------
#
# performs the changes in a specific branch
# arguments:
#   $1 - the branch to update
# returns:
#   0 is success, an error code otherwise
function apply_changes {
    git fetch $MRB_PROGRESS_FLAG --depth 1 upstream $1
    git fetch $MRB_PROGRESS_FLAG --depth 1 origin $1

    MRB_UPSTREAM_COMMIT=$(git show $MRB_PROGRESS_FLAG -s --pretty=format:%h upstream/$1)
    MRB_ORIGIN_COMMIT=$(git show $MRB_PROGRESS_FLAG -s --pretty=format:%h origin/$1)

    test $MRB_UPSTREAM_COMMIT == $MRB_ORIGIN_COMMIT && return 0

    git fetch $MRB_PROGRESS_FLAG --unshallow upstream $1
    git fetch $MRB_PROGRESS_FLAG origin $1

    git merge-base --is-ancestor origin/$1 upstream/$1
    if test $? -eq 0; then
	if ! $MRB_DRY_RUN; then
	    git push $MRB_PROGRESS_FLAG origin upstream/$1:$1
	fi
    else
	printf "%s\n" "Error: the origin branch '$1' is not an ancestor of the upstream one." >&2
    fi
}

#------------------------------------------------------------------------------
#			Function: update_branch
#------------------------------------------------------------------------------
#
# performs the execution of the piglit tests
# returns:
#   0 is success, an error code otherwise
function update_branch {
    if [ "${MRB_ORIGIN:-x}" == "x" ]; then
	printf "%s\n" "Error: an origin repository must be provided." >&2
	usage
	return 4
    fi

    if [ "${MRB_UPSTREAM:-x}" == "x" ]; then
	printf "%s\n" "Error: an upstream repository must be provided." >&2
	usage
	return 5
    fi

    mkdir -p "$MRB_TEMP_PATH"
    pushd "$MRB_TEMP_PATH"

    git clone $MRB_PROGRESS_FLAG --single-branch --depth 10 "$MRB_ORIGIN" "origin"

    pushd "origin"
    $MRB_DRY_RUN && git config remote.origin.pushurl "You really didn't want to do that"
    git remote add upstream "$MRB_UPSTREAM"
    git config remote.upstream.pushurl "You really didn't want to do that"

    for i in $MRB_BRANCHES; do
	apply_changes $i
    done
    popd

    popd
    rm -rf "$MRB_TEMP_PATH/"

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

Usage: $basename [options] --origin <url-origin-git-repository> --upstream  <url-upstream-git-repository> [branches]

Options:
  --dry-run                   Does everything except running the tests
  --verbosity                 Which verbosity level to use [full|normal|quite]. Default, normal.
  --help                      Display this help and exit successfully
  --tmp-path                  PATH in which to do the temporary work
  --origin                    The URL of the origin git repository to be updated
  --upstream                  The URL of the upstream git repository from which to update

HELP
}

#------------------------------------------------------------------------------
#			Script main line
#------------------------------------------------------------------------------
#

# Choose which grep program to use (on Solaris, must be gnu grep)
if [ "x$MRB_GREP" = "x" ] ; then
    if [ -x /usr/gnu/bin/grep ] ; then
	MRB_GREP=/usr/gnu/bin/grep
    else
	MRB_GREP=grep
    fi
fi

# Process command line args
while [ $# != 0 ]
do
    case $1 in
    # Does everything except running the tests
    --dry-run)
	MRB_DRY_RUN=true
	;;
    # Which verbosity level to use [full|normal|quite]. Default, normal.
    --verbosity)
	check_option_args $1 $2
	shift
	MRB_VERBOSITY=$1
	;;
    # Display this help and exit successfully
    --help)
	usage
	exit 0
	;;
    # PATH in which to do the temporary work
    --tmp-path)
	check_option_args $1 $2
	shift
	MRB_TEMP_PATH=$1
	;;
    # The URL of the origin git repository to be updated
    --origin)
	check_option_args $1 $2
	shift
	MRB_ORIGIN=$1
	;;
    # The URL of the upstream git repository from which to update
    --upstream)
	check_option_args $1 $2
	shift
	MRB_UPSTREAM=$1
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
	MRB_BRANCHES="${MRB_BRANCHES} $1"
	;;
    esac

    shift
done

# Defaults ...
# ---------

MRB_TEMP_PATH="${MRB_TEMP_PATH:-${HOME}/mrb-temp}"
MRB_BRANCHES="${MRB_BRANCHES:-master}"

# Verbose?
# --------

MRB_VERBOSITY="${MRB_VERBOSITY:-normal}"

check_verbosity "$MRB_VERBOSITY"
if [ $? -ne 0 ]; then
    return 13
fi

apply_verbosity "$MRB_VERBOSITY"

# dry run?
# --------

MRB_DRY_RUN="${MRB_DRY_RUN:-false}"

update_branch

exit $?
