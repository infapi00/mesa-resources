#!/bin/bash
#
# This script is intended to run automatically as a cronjob, making
# use of full-piglit-run.sh
#
# Example:
#
# $ crontab -e
# ...
# 0 3 * * * <path_to>/f-p-r-cronjob.sh "mesa-remote/mesa-branch" "vk-gl-cts-remote/vk-gl-cts-branch" "piglit-remote/piglit-branch" wrapper

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
    ln -sf $(ls -d $CFPR_BASE_PATH/piglit-results/results/all-i965*| tail -1) $CFPR_BASE_PATH/piglit-results/reference/all-i965

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
    pushd "$CFPR_PIGLIT_PATH"
    git worktree prune
    git branch -D cfpr
    popd

    return 0
}


CFPR_TEMP_PATH="$HOME/cfpr-temp"
CFPR_MESA_PATH="$HOME/i965/mesa.git"
CFPR_MESA_BRANCH="$1"
CFPR_VK_GL_CTS_PATH="$HOME/i965/vk-gl-cts.git"
CFPR_VK_GL_CTS_BRANCH="$2"
CFPR_PIGLIT_PATH="$HOME/i965/piglit.git"
CFPR_PIGLIT_BRANCH="$3"
CFPR_BASE_PATH="$HOME/i965"

CFPR_VERBOSITY="${CFPR_VERBOSITY:-false}"

if $CFPR_VERBOSITY; then
    CFPR_OUTPUT=1
else
    CFPR_OUTPUT=/dev/null
fi

if [ "x$CFPR_MESA_BRANCH" == "x" ] || [ "x$CFPR_VK_GL_CTS_BRANCH" == "x" ] || [ "x$CFPR_PIGLIT_BRANCH" == "x" ]; then
    printf "%s\n" "Missing parameters."
    exit 2
fi

if [ "x$4" = "xwrapper" ]; then
    pushd "$HOME/mesa-resources.git/jhbuild/" >&"${CFPR_OUTPUT}" 2>&1
    ./jhbuild.sh i965 run "$0" "$1" "$2" "$3" >&"${CFPR_OUTPUT}" 2>&1
    popd >&"${CFPR_OUTPUT}" 2>&1
    exit 0
fi

export VK_ICD_FILENAMES="$CFPR_BASE_PATH/install/share/vulkan/icd.d/intel_icd.x86_64.json"

mkdir -p "$CFPR_TEMP_PATH/jail"

pushd "$CFPR_TEMP_PATH/jail"

build_mesa true
clean_mesa

build_piglit

$HOME/mesa-resources.git/testing/full-piglit-run.sh \
    --verbose \
    --driver i965 \
    --commit "$CFPR_MESA_COMMIT" \
    --base-path "$CFPR_BASE_PATH" \
    --piglit-path "$CFPR_TEMP_PATH/piglit" \
    --run-piglit

create_piglit_reference

build_mesa false
clean_mesa

$HOME/mesa-resources.git/testing/full-piglit-run.sh \
    --verbose \
    --create-piglit-report \
    --driver i965 \
    --commit "$CFPR_MESA_COMMIT" \
    --base-path "$CFPR_BASE_PATH" \
    --piglit-path "$CFPR_TEMP_PATH/piglit" \
    --run-piglit

clean_piglit

build_vk_gl_cts

$HOME/mesa-resources.git/testing/full-piglit-run.sh \
    --verbose \
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
