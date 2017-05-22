#!/bin/bash
#
# This script is intended to run automatically as a cronjob, making
# use of full-piglit-run.sh
#
# Example:
#
# $ crontab -e
# ...
# 0 3 * * * <path_to>/f-p-r-cronjob.sh "mesa-remote/mesa-branch" "vk-gl-cts-remote/vk-gl-cts-branch" wrapper

CFPR_TEMP_PATH="$HOME/cfpr-temp"
CFPR_MESA_PATH="$HOME/i965/mesa.git"
CFPR_MESA_BRANCH="$1"
CFPR_VK_GL_CTS_PATH="$HOME/i965/vk-gl-cts.git"
CFPR_VK_GL_CTS_BRANCH="$2"
CFPR_BASE_PATH="$HOME/i965"

CFPR_VERBOSITY="${CFPR_VERBOSITY:-false}"

if $CFPR_VERBOSITY; then
    CFPR_OUTPUT=1
else
    CFPR_OUTPUT=/dev/null
fi

if [ "x$CFPR_MESA_BRANCH" == "x" ] || [ "x$CFPR_VK_GL_CTS_BRANCH" == "x" ]; then
    printf "%s\n" "Missing parameters."
    exit 2
fi

if [ "x$3" = "xwrapper" ]; then
    pushd "$HOME/mesa-resources.git/jhbuild/" >&"${CFPR_OUTPUT}" 2>&1
    ./jhbuild.sh i965 run "$0" "$1" "$2" >&"${CFPR_OUTPUT}" 2>&1
    popd >&"${CFPR_OUTPUT}" 2>&1
    exit 0
fi

export VK_ICD_FILENAMES="$CFPR_BASE_PATH/install/share/vulkan/icd.d/intel_icd.x86_64.json"

mkdir -p "$CFPR_TEMP_PATH/jail"
mkdir -p "$CFPR_TEMP_PATH/mesa"
mkdir -p "$CFPR_TEMP_PATH/vk-gl-cts"

pushd "$CFPR_TEMP_PATH/jail"
pushd "$CFPR_MESA_PATH"
git fetch gogs
git worktree add -b cfpr "$CFPR_TEMP_PATH/mesa" "$CFPR_MESA_BRANCH"
CFPR_MESA_COMMIT=`git show -s --pretty=format:%h`
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
#python2.7 -B ../framework/qphelper/gen_release_info.py --git --git-dir "$CFPR_VK_GL_CTS_PATH/.git" --out=../framework/qphelper/qpReleaseInfo.inl

cmake \
    -DCMAKE_INSTALL_PREFIX="$CFPR_BASE_PATH/install" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DDEQP_TARGET=x11_egl \
    -DGLCTS_GTF_TARGET=gl \
    ..
cmake --build .
find . -name link.txt -exec sed -i "s/;-/ -/g" {} \;
cmake --build .
popd
popd

$HOME/mesa-resources.git/testing/full-piglit-run.sh \
    --verbose \
    --create-piglit-report \
    --driver anv \
    --commit "$CFPR_MESA_COMMIT" \
    --base-path "$CFPR_BASE_PATH" \
    --vk-gl-cts-path "$CFPR_TEMP_PATH/vk-gl-cts/build" \
    --run-vk-cts \
    --invert-optional-patterns

popd
rm -rf "$CFPR_TEMP_PATH/"

pushd "$CFPR_MESA_PATH"
git worktree prune
git branch -D cfpr
popd
pushd "$CFPR_VK_GL_CTS_PATH"
git worktree prune
git branch -D cfpr
popd
