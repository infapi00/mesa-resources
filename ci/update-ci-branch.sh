#!/bin/bash
#
# This script updates a specific ci branch in a specified origin
# repository from another specified upstream repository. The ci branch
# also receives some custom changes.
#
# Run:
#
# $ ./update-ci-branch.sh --origin <url-origin-git-repository> --origin-branch <origin-repository-ci-branch> --upstream  <url-upstream-git-repository>


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
	UCB_PROGRESS_FLAG="-q"
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
    echo $arg | $UCB_GREP "^-" > /dev/null
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
# performs the changes to be done in the current origin branch
# returns:
#   0 is success, an error code otherwise
function apply_changes {
    UCB_TMP_FILE=$(mktemp)
    cat <<CHANGES | cat - .travis.yml > $UCB_TMP_FILE
notifications:
  email:
    recipients:
      - jasuarez+mesa-travis@igalia.com
      - tanty+mesa-travis@igalia.com

CHANGES

    cat $UCB_TMP_FILE > .travis.yml
    rm  $UCB_TMP_FILE

    git add .travis.yml
    git commit -m "travis: added notifications"
}

#------------------------------------------------------------------------------
#			Function: update_branch
#------------------------------------------------------------------------------
#
# performs the execution of the piglit tests
# returns:
#   0 is success, an error code otherwise
function update_branch {
    if [ "${UCB_ORIGIN:-x}" == "x" ]; then
	printf "%s\n" "Error: an origin repository must be provided." >&2
	usage
	return 4
    fi

    if [ "${UCB_UPSTREAM:-x}" == "x" ]; then
	printf "%s\n" "Error: an upstream repository must be provided." >&2
	usage
	return 5
    fi

    if [ "${UCB_ORIGIN_BRANCH:-x}" == "x" ]; then
	printf "%s\n" "Error: an origin branch must be provided." >&2
	usage
	return 6
    fi

    if [ "x${UCB_ORIGIN_BRANCH}" == "xmaster" ]; then
	printf "%s\n" "Error: master cannot be the origin branch." >&2
	usage
	return 7
    fi

    mkdir -p "$UCB_TEMP_PATH"
    pushd "$UCB_TEMP_PATH"

    git clone $UCB_PROGRESS_FLAG -b "$UCB_ORIGIN_BRANCH" --single-branch --depth 10 "$UCB_ORIGIN" "$UCB_TEMP_PATH/origin"

    pushd "$UCB_TEMP_PATH/origin"
    $UCB_DRY_RUN && git config remote.origin.pushurl "You really didn't want to do that"
    git remote add upstream "$UCB_UPSTREAM"
    git config remote.upstream.pushurl "You really didn't want to do that"
    git fetch $UCB_PROGRESS_FLAG upstream "$UCB_UPSTREAM_BRANCH"

    UCB_ORIGIN_COMMIT=$(git show -s --pretty=format:%h origin/"$UCB_ORIGIN_BRANCH"~1)
    UCB_UPSTREAM_COMMIT=$(git show -s --pretty=format:%h upstream/"$UCB_UPSTREAM_BRANCH")

    if [ $UCB_ORIGIN_COMMIT != $UCB_UPSTREAM_COMMIT ]; then
	git checkout $UCB_PROGRESS_FLAG -b upstream-branch upstream/"$UCB_UPSTREAM_BRANCH"

	apply_changes

	if ! $UCB_DRY_RUN; then
	    git push -f $UCB_PROGRESS_FLAG origin upstream-branch:"$UCB_ORIGIN_BRANCH"
	fi
    else
	printf "%s\n" "Not applying changes. The upstream branch $UCB_UPSTREAM_BRANCH has not changed since last time."
    fi
    popd

    popd
    rm -rf "$UCB_TEMP_PATH/"

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

Usage: $basename [options] --origin <url-origin-git-repository> --origin-branch <origin-repository-ci-branch> --upstream  <url-upstream-git-repository>

Options:
  --dry-run                   Does everything except running the tests
  --verbosity                 Which verbosity level to use [full|normal|quite]. Default, normal.
  --help                      Display this help and exit successfully
  --tmp-path                  PATH in which to do the temporary work
  --origin                    The URL of the origin git repository to be updated
  --origin-branch             The name of the branch in the origin repository to be updated
  --upstream                  The URL of the upstream git repository from which to update
  --upstream-branch           The name of the branch in the upstream repository from which to update

HELP
}

#------------------------------------------------------------------------------
#			Script main line
#------------------------------------------------------------------------------
#

# Choose which grep program to use (on Solaris, must be gnu grep)
if [ "x$UCB_GREP" = "x" ] ; then
    if [ -x /usr/gnu/bin/grep ] ; then
	UCB_GREP=/usr/gnu/bin/grep
    else
	UCB_GREP=grep
    fi
fi

# Process command line args
while [ $# != 0 ]
do
    case $1 in
    # Does everything except running the tests
    --dry-run)
	UCB_DRY_RUN=true
	;;
    # Which verbosity level to use [full|normal|quite]. Default, normal.
    --verbosity)
	check_option_args $1 $2
	shift
	UCB_VERBOSITY=$1
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
	UCB_TEMP_PATH=$1
	;;
    # The URL of the origin git repository to be updated
    --origin)
	check_option_args $1 $2
	shift
	UCB_ORIGIN=$1
	;;
    # The name of the branch in the origin repository to be updated
    --origin-branch)
	check_option_args $1 $2
	shift
	UCB_ORIGIN_BRANCH=$1
	;;
    # The URL of the upstream git repository from which to update
    --upstream)
	check_option_args $1 $2
	shift
	UCB_UPSTREAM=$1
	;;
    # The name of the branch in the upstream repository from which to update
    --upstream-branch)
	check_option_args $1 $2
	shift
	UCB_UPSTREAM_BRANCH=$1
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
	printf "%s\n" "Error: unknown extra parameter: $1" >&2
	usage
	exit 1
	;;
    esac

    shift
done

# Defaults ...
# ---------

UCB_TEMP_PATH="${UCB_TEMP_PATH:-${HOME}/ucb-temp}"
UCB_UPSTREAM_BRANCH="${UCB_UPSTREAM_BRANCH:-master}"

# Verbose?
# --------

UCB_VERBOSITY="${UCB_VERBOSITY:-normal}"

check_verbosity "$UCB_VERBOSITY"
if [ $? -ne 0 ]; then
    return 13
fi

apply_verbosity "$UCB_VERBOSITY"

# dry run?
# --------

UCB_DRY_RUN="${UCB_DRY_RUN:-false}"

update_branch

exit $?
