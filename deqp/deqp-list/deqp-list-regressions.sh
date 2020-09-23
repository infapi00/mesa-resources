#/bin/sh
#
# Returns a list of dEQP tests that passed first, but don't pass anymore, for
# any reason.
#

if [ "$2" == "" ] ; then
    echo "Usage: $0 <old_results_file> <new_results_file>" && exit 0
fi

# Get list of tests passed in old and new

OLD_PASSES=$(mktemp /tmp/deqp-regressions-XXX.txt)
NEW_PASSES=$(mktemp /tmp/deqp-regressions-XXX.txt)

deqp-list-pass.sh $1 > $OLD_PASSES
deqp-list-pass.sh $2 > $NEW_PASSES

DIFF=$(diff -au $OLD_PASSES $NEW_PASSES | grep "^- " | cut -d* -f2)

for CASE in $DIFF ; do
    awk "/#beginTestCaseResult $CASE/ { show=1 } show; /#endTestCaseResult/ { if (show==1) exit }" $2 | \
        grep StatusCode | \
        sed "s/.*StatusCode=\"\(.*\)\">\(.*\)<.*/$CASE  : \1 (\2)/g"
done

rm -f $OLD_PASSES
rm -f $NEW_PASSES
