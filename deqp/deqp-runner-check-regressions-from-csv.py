#!/usr/bin/env python3

import csv
import argparse

# We only load the fail, timeout, crashes, as we want changes on
# that. No need to load the pass files (also, usually we would take
# the failures.csv from deqp-runner)

def load_status(file_path):
    failures = set()
    timeouts = set()
    crashes = set()
    with open(file_path, newline='') as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            if len(row) == 2 and row[1].strip().lower() == 'fail':
                failures.add(row[0].strip())
            if len(row) == 2 and row[1].strip().lower() == 'crash':
                crashes.add(row[0].strip())
            if len(row) == 2 and row[1].strip().lower() == 'timeout':
                timeouts.add(row[0].strip())

    return [failures, crashes, timeouts]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before", help="The deqp-runner outcome before")
    parser.add_argument("after", help="The deqp-runner outcome after")

    args = parser.parse_args()

    [before_failures, before_crashes, before_timeouts] = load_status(args.before)
    [after_failures, after_crashes, after_timeouts] = load_status(args.after)

    # FIXME: do we really need three different sets?
    fail_regressions = after_failures - before_failures
    crash_regressions = after_crashes - before_crashes
    timeout_regressions = after_timeouts - before_timeouts

    # Print the results
    if fail_regressions:
        print("** Fail regressions ** ")
        print("\n".join(sorted(fail_regressions)) or "None")
    else:
        print("\n** No fail regressions ** ")

    if crash_regressions:
        print("** Crash regressions ** ")
        print("\n".join(sorted(crash_regressions)) or "None")
    else:
        print("\n** No crash regressions ** ")

    if crash_regressions:
        print("** Timeout regressions ** ")
        print("\n".join(sorted(timeout_regressions)) or "None")
    else:
        print("\n** No timeout regressions ** ")


if __name__ == "__main__":
    main()

