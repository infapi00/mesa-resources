#/bin/sh

cat $1 | tr -d '\n' | \
    sed 's/#beginTestCaseResult \|#endSession/\n-----\n/g' | \
    sed -n 's/^\(.*\)<?xml.*StatusCode="Waiver".*/\1/p'
