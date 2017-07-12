#!/bin/bash
#
# This script runs a piglit test n times, and returns how many runs
# have passed. Useful for flaky tests.
#
# Syntax : run-n-times-flaky-test.sh number command

if [ $# -lt 2 ]
then
    printf "Error - wrong number of parameters"
    printf "Syntax : $0 number command"
    exit 1
fi
n=$1
shift
PASS=0
FAIL=0
for (( i=1; i <= "$n"; i++ ));
do
    if [ $($@ | grep 'PIGLIT: {"result": "pass" }' | wc -l) -eq 1 ]
    then
        ((PASS=PASS+1))
    else
        ((FAIL=FAIL+1))
    fi
done

printf "Runs: %i, Pass: %i, Fail: %i\n" $n $PASS $FAIL
if [ $((n-PASS)) -ne $FAIL ]
then
    #This can happens because we are only checking for PASS, but there
    #are other status
    printf "Warning: pass+fail is different that the total number of runs\n"
fi
