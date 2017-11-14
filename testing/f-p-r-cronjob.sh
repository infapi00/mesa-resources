#!/bin/bash
#
# This script is intended to run automatically as a cronjob, making
# use of full-piglit-run.sh
#
# Example:
#
# $ crontab -e
# ...
# 0 3 * * * <path_to>/f-p-r-cronjob.sh --mesa-commit "mesa-remote/mesa-branch" --vk-gl-cts-commit "vk-gl-cts-remote/vk-gl-cts-branch" --piglit-commit "piglit-remote/piglit-branch"

export LC_ALL=C

PATH=${HOME}/.local/bin$(echo :$PATH | sed -e s@:${HOME}/.local/bin@@g)

DISPLAY="${DISPLAY:-:0.0}"
export -p DISPLAY

MAKEFLAGS=-j$(getconf _NPROCESSORS_ONLN)
export MAKEFLAGS


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
	printf "Error: the '$option' option is missing its required argument.\n" >&2
	usage
	exit 2
    fi

    # does the argument look like an option?
    echo $arg | $CFPR_GREP "^-" > /dev/null
    if [ $? -eq 0 ]; then
	printf "Error: the argument '$arg' of option '$option' looks like an option itself.\n" >&2
	usage
	exit 3
    fi
}


#------------------------------------------------------------------------------
#			Function: sanity_check
#------------------------------------------------------------------------------
#
# perform sanity check on the passed parameters:
# arguments:
#   $1 - an existing mesa's commit id
#   $2 - an existing VK-GL-CTS' commit id
#   $3 - an existing piglit's commit id
# returns:
#   0 is success, an error code otherwise
function sanity_check() {
    if [ "x$1" == "x" ] || [ "x$2" == "x" ] || [ "x$3" == "x" ]; then
	printf "Error: Missing parameters.\n" >&2
	usage
	return 2
    fi

    pushd "$CFPR_MESA_PATH"
    git fetch gogs
    git fetch origin
    git show -s --pretty=format:%h "$1" > /dev/null
    CFPR_RESULT=$?
    popd
    if [ $CFPR_RESULT -ne 0 ]; then
	printf "%s\n" "" "Error: mesa's commit id doesn't exist in the repository." "" >&2
	usage
	return 3
    fi

    pushd "$CFPR_VK_GL_CTS_PATH"
    git fetch origin
    git show -s --pretty=format:%h "$2" > /dev/null
    CFPR_RESULT=$?
    popd
    if [ $CFPR_RESULT -ne 0 ]; then
	printf "%s\n" "" "Error: VK-GL-CTS' commit id doesn't exist in the repository." "" >&2
	usage
	return 4
    fi

    pushd "$CFPR_PIGLIT_PATH"
    git fetch origin
    git show -s --pretty=format:%h "$3" > /dev/null
    CFPR_RESULT=$?
    popd
    if [ $CFPR_RESULT -ne 0 ]; then
	printf "%s\n" "" "Error: piglit's commit id doesn't exist in the repository." "" >&2
	usage
	return 5
    fi

    return 0
}


#------------------------------------------------------------------------------
#			Function: header
#------------------------------------------------------------------------------
#
# prints a header, if not quiet
#   $1 - name to print out
# returns:
#   0 is success, an error code otherwise
function header {
    CFPR_TIMESTAMP=$(date +%Y%m%d%H%M%S)
    CFPR_SPACE=$(df -h)
    printf "%s\n" "Running $1 at $CFPR_TIMESTAMP" "" "$CFPR_SPACE" "" >&9

    return 0
}


#------------------------------------------------------------------------------
#			Function: build_mesa
#------------------------------------------------------------------------------
#
# builds a specific commit of mesa or the latest common commit with master
#   $1 - whether to build the merge base against master or not
# outputs:
#   the requested commit hash
# returns:
#   0 is success, an error code otherwise
function build_mesa() {
    rm -rf "$CFPR_TEMP_PATH/mesa"
    mkdir -p "$CFPR_TEMP_PATH/mesa"
    pushd "$CFPR_MESA_PATH"
    if $1; then
	COMMIT=$(git merge-base origin/master "$CFPR_MESA_BRANCH")
    else
	COMMIT="$CFPR_MESA_BRANCH"
    fi
    git worktree add -b cfpr "$CFPR_TEMP_PATH/mesa" "$COMMIT"
    CFPR_MESA_COMMIT=$(git show -s --pretty=format:%h "$COMMIT")
    popd
    pushd "$CFPR_TEMP_PATH/mesa"
    ./autogen.sh --prefix /home/igalia/agomez/i965/install \
		 --disable-Werror \
		 --enable-gles2 \
		 --disable-gallium-egl \
		 --with-egl-platforms=x11,drm \
		 --enable-gbm \
		 --enable-shared-glapi \
		 --disable-static \
		 --enable-debug \
		 --with-dri-drivers=swrast,i965 \
		 --with-gallium-drivers=swrast \
		 --with-vulkan-drivers=intel
    make && make install
    popd

    return 0
}


#------------------------------------------------------------------------------
#			Function: clean_mesa
#------------------------------------------------------------------------------
#
# cleans the used mesa's worktree
# returns:
#   0 is success, an error code otherwise
function clean_mesa() {
    rm -rf "$CFPR_TEMP_PATH/mesa"
    pushd "$CFPR_MESA_PATH"
    git worktree prune
    git branch -D cfpr
    popd

    return 0
}


#------------------------------------------------------------------------------
#			Function: build_vk_gl_cts
#------------------------------------------------------------------------------
#
# builds a specific commit of vk-gl-cts
# returns:
#   0 is success, an error code otherwise
function build_vk_gl_cts() {
    rm -rf "$CFPR_TEMP_PATH/vk-gl-cts"
    mkdir -p "$CFPR_TEMP_PATH/vk-gl-cts"
    pushd "$CFPR_VK_GL_CTS_PATH"
    git worktree add -b cfpr "$CFPR_TEMP_PATH/vk-gl-cts" "$CFPR_VK_GL_CTS_BRANCH"
    popd
    pushd "$CFPR_TEMP_PATH/vk-gl-cts"
    mkdir build
    pushd build
    python3 ../external/fetch_sources.py

    # This is needed because framework/qphelper/CMakeLists.txt has a bug
    # that doesn't allow builds after a git worktree
    CFPR_VK_GL_CTS_RELEASE=`git -C . rev-parse HEAD`
    python2.7 -B ../framework/qphelper/gen_release_info.py --name "git-$CFPR_VK_GL_CTS_RELEASE" --id "0x${CFPR_VK_GL_CTS_RELEASE:0:8}" --out=../framework/qphelper/qpReleaseInfo.inl

    cmake \
	-DCMAKE_INSTALL_PREFIX="$CFPR_BASE_PATH/install" \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DGLCTS_GTF_TARGET=gl \
	..
    cmake --build .

    # Unfortunately, there is a problem by which some "link.txt"
    # helper scripts are incorrectly generated
    find . -name link.txt -exec sed -i "s/;-/ -/g" {} \;
    cmake --build .

    popd
    popd

    return 0
}


#------------------------------------------------------------------------------
#			Function: clean_vk_gl_cts
#------------------------------------------------------------------------------
#
# cleans the used vk_gl_cts's worktree
# returns:
#   0 is success, an error code otherwise
function clean_vk_gl_cts() {
    rm -rf "$CFPR_TEMP_PATH/vk-gl-cts"
    pushd "$CFPR_VK_GL_CTS_PATH"
    git worktree prune
    git branch -D cfpr
    popd

    return 0
}


#------------------------------------------------------------------------------
#			Function: build_piglit
#------------------------------------------------------------------------------
#
# builds a specific commit of piglit
# returns:
#   0 is success, an error code otherwise
function build_piglit() {
    rm -rf "$CFPR_TEMP_PATH/piglit"
    mkdir -p "$CFPR_TEMP_PATH/piglit"
    pushd "$CFPR_PIGLIT_PATH"
    git worktree add -b cfpr "$CFPR_TEMP_PATH/piglit" "$CFPR_PIGLIT_BRANCH"
    popd
    pushd "$CFPR_TEMP_PATH/piglit"
    cmake .
    cmake --build .
    popd

    return 0
}


#------------------------------------------------------------------------------
#			Function: create_piglit_reference
#------------------------------------------------------------------------------
#
# creates the soft link to the piglit reference run
# returns:
#   0 is success, an error code otherwise
function create_piglit_reference() {
    ln -sfr $(ls -d $CFPR_BASE_PATH/piglit-results/results/all-i965*| tail -1) -T $CFPR_BASE_PATH/piglit-results/reference/all-i965

    return 0
}


#------------------------------------------------------------------------------
#			Function: clean_piglit
#------------------------------------------------------------------------------
#
# cleans the used piglit's worktree
# returns:
#   0 is success, an error code otherwise
function clean_piglit() {
    rm -rf "$CFPR_TEMP_PATH/piglit"
    pushd "$CFPR_PIGLIT_PATH"
    git worktree prune
    git branch -D cfpr
    popd

    return 0
}


#------------------------------------------------------------------------------
#			Function: run_tests
#------------------------------------------------------------------------------
#
# performs the execution of the tests
# returns:
#   0 is success, an error code otherwise
function run_tests {
    header

    export VK_ICD_FILENAMES="$CFPR_BASE_PATH/install/share/vulkan/icd.d/intel_icd.x86_64.json"

    mkdir -p "$CFPR_TEMP_PATH/jail"

    pushd "$CFPR_TEMP_PATH/jail"

    if $CFPR_RUN_PIGLIT; then
	printf "%s\n" "" "Checking for regressions in piglit ..." "" >&9

	build_mesa true
	clean_mesa

	build_piglit

	$HOME/mesa-resources.git/testing/full-piglit-run.sh \
	    --verbosity "$CFPR_VERBOSITY" \
	    --driver i965 \
	    --commit "$CFPR_MESA_COMMIT" \
	    --base-path "$CFPR_BASE_PATH" \
	    --piglit-path "$CFPR_TEMP_PATH/piglit" \
	    --run-piglit

	create_piglit_reference
    fi

    if $CFPR_RUN_PIGLIT || $CFPR_RUN_VK_CTS; then
	build_mesa false
	clean_mesa
    fi

    if $CFPR_RUN_PIGLIT; then
	$HOME/mesa-resources.git/testing/full-piglit-run.sh \
	    --verbosity "$CFPR_VERBOSITY" \
	    --create-piglit-report \
	    --driver i965 \
	    --commit "$CFPR_MESA_COMMIT" \
	    --base-path "$CFPR_BASE_PATH" \
	    --piglit-path "$CFPR_TEMP_PATH/piglit" \
	    --run-piglit

	clean_piglit
    fi

    if $CFPR_RUN_VK_CTS; then
	printf "%s\n" "" "Checking VK CTS progress ..." "" >&9

	build_vk_gl_cts

	$HOME/mesa-resources.git/testing/full-piglit-run.sh \
	    --verbosity "$CFPR_VERBOSITY" \
	    --create-piglit-report \
	    --driver anv \
	    --commit "$CFPR_MESA_COMMIT" \
	    --base-path "$CFPR_BASE_PATH" \
	    --vk-gl-cts-path "$CFPR_TEMP_PATH/vk-gl-cts/build" \
	    --run-vk-cts \
	    --invert-optional-patterns

	clean_vk_gl_cts
    fi

    popd
    rm -rf "$CFPR_TEMP_PATH/"

    return 0
}


#------------------------------------------------------------------------------
#			Function: usage
#------------------------------------------------------------------------------
# Displays the script usage and exits successfully
#
usage() {
    basename="`expr "//$0" : '.*/\([^/]*\)'`"
    cat <<HELP

Usage: $basename [options] --mesa-commit <mesa-commit-id> --vk-gl-cts-commit <vk-gl-cts-commit-id> --piglit-commit <piglit-commit-id>

Options:
  --help                           Display this help and exit successfully
  --verbosity [full|normal|quite]  Which verbosity level to use
                                   [full|normal|quite]. Default, normal.
  --force-clean                    Forces the cleaning of the working env
  --base-path <path>               <path> from which to create the rest of the
                                   relative paths
  --tmp-path <path>                <path> in which to do the temporary work
  --mesa-path <path>               <path> to the mesa repository
  --vk-gl-cts-path <path>          <path> to the vk-gl-cts repository
  --piglit-path <path>             <path> to the piglit repository
  --mesa-commit <commit>           mesa <commit> to use
  --vk-gl-cts-commit <commit>      VK-GL-CTS <commit> to use
  --piglit-commit <commit>         piglit <commit> to use
  --run-vk-cts                     Run vk-cts
  --run-piglit                     Run piglit

HELP
}


#------------------------------------------------------------------------------
#			Script main line
#------------------------------------------------------------------------------
#

# Choose which grep program to use (on Solaris, must be gnu grep)
if [ "x$CDP_GREP" = "x" ] ; then
    if [ -x /usr/gnu/bin/grep ] ; then
	CFPR_GREP=/usr/gnu/bin/grep
    else
	CFPR_GREP=grep
    fi
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
    # Which verbosity level to use [full|normal|quite]. Default, normal.
    --verbosity)
	check_option_args $1 $2
	shift
	export CFPR_VERBOSITY=$1
	;;
    # Forces the cleaning of the working env
    --force-clean)
	CFPR_FORCE_CLEAN=true
	;;
    # Not run as a JHBuild wrapper
    --no-jhbuild-wrapper)
	CFPR_JHBUILD_WRAPPER=false
	;;
    # PATH from which to create the rest of the relative paths
    --base-path)
	check_option_args $1 $2
	shift
	export CFPR_BASE_PATH=$1
	;;
    # PATH in which to do the temporary work
    --tmp-path)
	check_option_args $1 $2
	shift
	export CFPR_TEMP_PATH=$1
	;;
    # PATH to the mesa repository
    --mesa-path)
	check_option_args $1 $2
	shift
	export CFPR_MESA_PATH=$1
	;;
    # PATH to the vk-gl-cts repository
    --vk-gl-cts-path)
	check_option_args $1 $2
	shift
	export CFPR_VK_GL_CTS_PATH=$1
	;;
    # PATH to the piglit repository
    --piglit-path)
	check_option_args $1 $2
	shift
	export CFPR_PIGLIT_PATH=$1
	;;
    # mesa commit to use
    --mesa-commit)
	check_option_args $1 $2
	shift
	export CFPR_MESA_BRANCH=$1
	;;
    # VK-GL-CTS commit to use
    --vk-gl-cts-commit)
	check_option_args $1 $2
	shift
	export CFPR_VK_GL_CTS_BRANCH=$1
	;;
    # piglit commit to use
    --piglit-commit)
	check_option_args $1 $2
	shift
	export CFPR_PIGLIT_BRANCH=$1
	;;
    # Run vk-cts
    --run-vk-cts)
	export CFPR_RUN_VK_CTS=true
	;;
    # Run piglit
    --run-piglit)
	export CFPR_RUN_PIGLIT=true
	;;
    --*)
	printf "Error: unknown option: $1\n" >&2
	usage
	exit 1
	;;
    -*)
	printf "Error: unknown option: $1\n" >&2
	usage
	exit 1
	;;
    *)
	printf "Error: unknown parameter: $1\n" >&2
	usage
	exit 1
	;;
    esac

    shift
done


# Paths ...
# ---------

CFPR_BASE_PATH="${CFPR_BASE_PATH:-$HOME/i965}"
CFPR_TEMP_PATH="${CFPR_TEMP_PATH:-$CFPR_BASE_PATH/cfpr-temp}"
CFPR_MESA_PATH="${CFPR_MESA_PATH:-$CFPR_BASE_PATH/mesa.git}"
CFPR_VK_GL_CTS_PATH="${CFPR_VK_GL_CTS_PATH:-$CFPR_BASE_PATH/vk-gl-cts.git}"
CFPR_PIGLIT_PATH="${CFPR_PIGLIT_PATH:-$CFPR_BASE_PATH/piglit.git}"


# What tests to run?
# ------------------

CFPR_RUN_VK_CTS="${CFPR_RUN_VK_CTS:-false}"
CFPR_RUN_PIGLIT="${CFPR_RUN_PIGLIT:-false}"


# Force clean
# ------------

CFPR_FORCE_CLEAN="${CFPR_FORCE_CLEAN:-false}"

if $CFPR_FORCE_CLEAN; then
    clean_mesa
    clean_piglit
    clean_vk_gl_cts
    printf "%s\n" "" "rm -Ir $CFPR_TEMP_PATH" ""
    rm -Ir "$CFPR_TEMP_PATH"

    exit 0
fi


# Sanity check
# ------------

sanity_check "$CFPR_MESA_BRANCH" "$CFPR_VK_GL_CTS_BRANCH" "$CFPR_PIGLIT_BRANCH"

if [ $? -ne 0 ]; then
    exit 2
fi


# Running wrapper ...
# -------------------

CFPR_JHBUILD_WRAPPER="${CFPR_JHBUILD_WRAPPER:-true}"

if $CFPR_JHBUILD_WRAPPER; then
    pushd "$HOME/mesa-resources.git/jhbuild/" > /dev/null
    ./jhbuild.sh i965 run "$0" --no-jhbuild-wrapper
    CFPR_RESULT=$?
    popd > /dev/null

    exit $CFPR_RESULT
fi


# Verbosity level
# ---------------

CFPR_VERBOSITY="${CFPR_VERBOSITY:-normal}"

check_verbosity "$CFPR_VERBOSITY"
if [ $? -ne 0 ]; then
    exit 13
fi

apply_verbosity "$CFPR_VERBOSITY"

# Running wrapped ...
# -------------------

run_tests

exit $?
