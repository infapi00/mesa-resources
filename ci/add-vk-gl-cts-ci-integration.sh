#!/bin/bash

cat <<CHANGES  > .travis.yml
notifications:
  email:
    recipients:
      - jasuarez+vk-gl-cts-travis@igalia.com
      - tanty+vk-gl-cts-travis@igalia.com

language: c++

sudo: required
dist: trusty

cache:
  apt: true
  ccache: true

env:
  global:
    - MAKEFLAGS="-j4"

matrix:
  include:
    - env:
        - RECIPE="clang-64-debug"
      addons:
        apt:
          sources:
            - llvm-toolchain-trusty-3.9
          packages:
            - clang-3.9

    - env:
        - RECIPE="gcc-32-debug"
      addons:
        apt:
          packages:
            - g++-multilib

    - env:
        - RECIPE="gcc-64-release"

    - env:
        - RECIPE="android-mustpass"

    - env:
        - RECIPE="vulkan-mustpass"

    - env:
        - RECIPE="gen-inl-files"
      addons:
        apt:
          packages:
            - python-lxml

script:
  - python2 ./scripts/check_build_sanity.py -r \$RECIPE
CHANGES

cat <<CHANGES  > appveyor.yml
version: '{build}'

clone_depth: 100

os: Visual Studio 2013

environment:
  matrix:
    - RECIPE: vs-64-debug
    - RECIPE: android-mustpass
    - RECIPE: vulkan-mustpass
    - RECIPE: gen-inl-files

install:
  # We need lmxl installed to build gen-inl-files
  - python -m pip install lxml

build_script:
  - python ./scripts/check_build_sanity.py -r %RECIPE%
CHANGES

cat <<CHANGES  >> .gitignore
!.travis.yml
CHANGES

git add .travis.yml appveyor.yml .gitignore
git commit -m "ci: added travis and appveyor integration"
