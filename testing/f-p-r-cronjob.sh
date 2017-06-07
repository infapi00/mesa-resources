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
	    printf "Error: Only verbosity levels among [full|normal|quiet] are allowed.\n" >&2
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
# returns:
#   0 is success, an error code otherwise
function sanity_check() {
    if [ "x$1" == "x" ] || [ "x$2" == "x" ] || [ "x$3" == "x" ]; then
	printf "Error: Missing parameters.\n" >&2
	usage
	return 2
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
    printf "%s\n" "Running $1 at $CFPR_TIMESTAMP" "" "$CFPR_SPACE" "" >&2

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
    git fetch gogs
    git fetch origin
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
    git fetch origin
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
    git fetch origin
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
#			Function: usage
#------------------------------------------------------------------------------
# Displays the script usage and exits successfully
#
usage() {
    basename="`expr "//$0" : '.*/\([^/]*\)'`"
    cat <<HELP

Usage: $basename [options] --mesa-commit <mesa-commit-id> --vk-gl-cts-commit <vk-gl-cts-commit-id> --piglit-commit <piglit-commit-id>

Options:
  --help                  Display this help and exit successfully
  --verbosity             Which verbosity level to use [full|normal|quite]. Default, normal.
  --force-clean           Forces the cleaning of the working env
  --base-path             PATH from which to create the rest of the relative paths
  --tmp-path              PATH in which to do the temporary work
  --mesa-path             PATH to the mesa repository
  --vk-gl-cts-path        PATH to the vk-gl-cts repository
  --piglit-path           PATH to the piglit repository
  --mesa-commit           mesa commit to use
  --vk-gl-cts-commit      VK-GL-CTS commit to use
  --piglit-commit         piglit commit to use

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

check_verbosity $CFPR_VERBOSITY
if [ $? -ne 0 ]; then
    exit 13
fi

if [ "x$CFPR_VERBOSITY" != "xfull" ]; then
    exec > /dev/null
fi

if [ "x$CFPR_VERBOSITY" == "xquiet" ]; then
    exec 2>&1
fi


# Running wrapped ...
# -------------------

header

export VK_ICD_FILENAMES="$CFPR_BASE_PATH/install/share/vulkan/icd.d/intel_icd.x86_64.json"

mkdir -p "$CFPR_TEMP_PATH/jail"

pushd "$CFPR_TEMP_PATH/jail"

build_mesa true
clean_mesa

printf "%s\n" "" "Checking for regressions in piglit ..." "" >&2

build_piglit

$HOME/mesa-resources.git/testing/full-piglit-run.sh \
    --verbosity "$CFPR_VERBOSITY" \
    --driver i965 \
    --commit "$CFPR_MESA_COMMIT" \
    --base-path "$CFPR_BASE_PATH" \
    --piglit-path "$CFPR_TEMP_PATH/piglit" \
    --run-piglit

create_piglit_reference

build_mesa false
clean_mesa

$HOME/mesa-resources.git/testing/full-piglit-run.sh \
    --verbosity "$CFPR_VERBOSITY" \
    --create-piglit-report \
    --driver i965 \
    --commit "$CFPR_MESA_COMMIT" \
    --base-path "$CFPR_BASE_PATH" \
    --piglit-path "$CFPR_TEMP_PATH/piglit" \
    --run-piglit

clean_piglit

printf "%s\n" "" "Checking VK CTS progress ..." "" >&2

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

popd
rm -rf "$CFPR_TEMP_PATH/"
