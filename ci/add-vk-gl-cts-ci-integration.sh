#!/bin/bash

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

git add .travis.yml appveyor.yml
git commit -m "ci: added travis notifications and appveyor integration"
