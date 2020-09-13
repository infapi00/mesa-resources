#!/bin/bash

# This script is intended to quickly check whether each commit in a
# series of commits leading up to HEAD successfully builds. This is
# useful for example before submitting a pull request to check that
# none of the commits would break the build.
#
# Use it with a command like this when in the root directory of the
# git checkout:
#
# check-unpushed-build.sh origin/master
#
# Then for example if you are on master, it will check out all of the
# commits from origin/master to master in turn and try to build them.
# If any of them fail then it will stop.
#
# The script tries to guess the appropriate build command by looking
# at what files are in the directory.

set -e

branch=`git branch | sed -n '/\* /s///p'`

if test -z "$1"; then
    base="github/master"
else
    base="$1"
fi

revs=(`git rev-list --reverse "$base".."$branch"~1` "$branch")

for rev in "${revs[@]}"; do
    git checkout "$rev"
    if test -d android-build; then
        ( cd android-build &&
              $ANDROID_NDK/ndk-build -C ../android_test     \
                                     NDK_PROJECT_PATH=.      \
                                     NDK_LIBS_OUT=`pwd`/libs \
                                     NDK_APP_OUT=`pwd`/app \
                  )
    elif test -f build/Makefile; then
        make -C build
    elif test -f build/build.ninja; then
        if test -f CMakeLists.txt; then
            ninja -C build clean
        fi
        ninja -C build
    elif test -f build.gradle; then
        gradle assembleDebug
    else
        make -j4
    fi
done
