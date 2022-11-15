#!/usr/bin/env python3
#
# Runs a list of CTS tests and get the peak bo usage (bo count and bo
# size) for each individual test.
#
# Notes:
#
#   * Peak bo count/size is not on mesa main. Ask apinheiro for his
#   * patches.
#
#   * This script assumes that you are passing a list of CTS tests
#   * that Passes.
#
#
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("caselist", help="File with the CTS case list")
    parser.add_argument("output", help="File with the executed CTS case list")

    args = parser.parse_args()

    caselist_file = open(args.caselist, 'r')
    caselist = [line.rstrip() for line in caselist_file.readlines()]
    caselist_file.close();

    peak_bo_stats_path = "/tmp/bo-peak-stats.txt"
    full_output = []
    for test in caselist:
        print(test)
        # Remove /tmp/bo-peak-stats.txt if around
        try:
            os.remove(peak_bo_stats_path)
        except FileNotFoundError as err:
            pass # We don't care. This happen often with the first test of the list

        # Execute CTS test
        command = ['./deqp-vk']
        command += ['--deqp-case', test]
        try:
            output = subprocess.run(command,
                                    capture_output=True,
                                    check=True)
        except Exception as err:
            print("ERROR executing test " + test + " : " + f"{type(err).__name__} was raised: {err}")


        # Get values from /tmp/bo-peak-stats.txt
        try:
            peak_bo_stats_file = open(peak_bo_stats_path, 'r')
            peak_bo_stats = [line.rstrip() for line in peak_bo_stats_file.readlines()]
            peak_bo_stats_file.close()

            # Store the value CTS, bo_count, bo_size
            new_line = [test, peak_bo_stats[0], peak_bo_stats[1]]
            full_output.append(new_line)
        except Exception as err:
            print("ERROR trying to get test " + test + " peak stats: " + f"{type(err).__name__} was raised: {err}")

    # Sort the list by bo_size
    full_output.sort(key = lambda k: float(k[2]), reverse=True)

    # Save to a file
    output_file = open(args.output, 'w')
    for entry in full_output:
        line = entry[0] + "," + entry[1] + "," + entry[2] + "\n"
        output_file.write(line)
    output_file.close()

if __name__ == "__main__":
    main()
