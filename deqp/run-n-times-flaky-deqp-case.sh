#!/bin/bash
#
# The purpose of this script is run a deqp/cts test n times
# counting the number of times that pass and fail. It is
# useful to debug flaky tests. In order to not lose the
# test debug info (on TestResults.qpa) for each execution
# it copies it to TestResults_PASS or TestResults_FAILS
# respectively.

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
    if [ $($@ | grep "Passed:        1/1"  | wc -l) -eq 1 ]
    then
        ((PASS=PASS+1))
        mv "TestResults.qpa" "TestResults_PASS"$PASS".qpa"
    else
        ((FAIL=FAIL+1))
        mv "TestResults.qpa" "TestResults_FAIL"$FAIL".qpa"
    fi
done

printf "Runs: %i, Pass: %i, Fail: %i\n" $n $PASS $FAIL
if [ $((n-PASS)) -ne $FAIL ]
then
    #This can happens because we are only checking for PASS, but there
    #are other status
    printf "Warning: pass+fail is different that the total number of runs\n"
fi

