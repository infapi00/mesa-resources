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

git add .travis.yml
git commit -m "travis: added notifications"
