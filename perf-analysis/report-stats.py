#!/usr/bin/env python3
#
# This script creates a performance report based on a before.csv and
# after.csv file, that contains a stat of running a given demo, trace,
# etc. Each of those execution can be run several times (samples), so
# the script computes an average of the stat. This sis the format of
# the csv file:
#
#   name_demo_0, stat0
#   name_demo_0, stat1
#   name_demo_1, stat3
#   name_demo_1, stat4
#
# This script is heavily inspired on shader-db/report.py script, but
# simplified, and focused on just one stat at a time.
#
# To print the outcome it uses a label. The default value of the label
# is "fps", but can be configured when executed.

import re
import argparse
import math
import csv
import pathlib
import sys
import statistics

def format_percent(frac):
    """Converts a factional value (typically 0.0 to 1.0) to a string as a percentage"""
    if 0.0 < abs(frac) < 0.0001:
        return "<.01%"
    else:
        return f"{frac * 100:.2f}%"


def get_delta(b, a):
    if b != 0 and a != 0:
        frac = float(a) / float(b) - 1.0
        return f' ({format_percent(frac)})'
    else:
        return ''


def format_num(n):
    assert n >= 0
    if n - math.floor(n) < 0.01:
        return str(math.floor(n))
    else:
        return f"{n:.2f}"


def get_avg_std_deviation_string(b):
    return f"({format_num(b[0])} , {format_num(b[1])})"


def change(b, a):
    return f"{format_num(b)} -> {format_num(a)}{get_delta(b, a)}"


def change_with_std_deviation(b, a):
    return f"{get_avg_std_deviation_string(b)} -> {get_avg_std_deviation_string(a)}{get_delta(b[0], a[0])}"


def get_result_string(p, b, a, args):
    p = (p + ": ").ljust(50)
    if args.show_std_deviation:
        return p + change_with_std_deviation(b, a)
    else:
        return p + change(b[0], a[0])


def get_results(filename, include_filter, exclude_filter):
    results = {}

    # Each line has the format "trace_name,stat", and can be more that one trace_name entry
    with open(filename) as file_obj:
        reader_obj = csv.reader(file_obj)
        for row in reader_obj:
            # We assume that if not include filter is provided, we want to process all of them
            if include_filter and not any(r.search(row[0]) for r in include_filter):
                    continue

            if any(r.search(row[0]) for r in exclude_filter):
                continue

            result_list = results.setdefault(row[0], [])
            result_list.append(float(row[1]))

    return results

def process_results(raw, args, measurement_key):
    results = {}

    for key in raw:
        stats_min = min(raw[key])
        stats_max = max(raw[key])

        if args.skip_min_max and len(raw[key]) >= 3:
            raw[key].remove(stats_min)
            raw[key].remove(stats_max)

        stats_avg = statistics.mean(raw[key])
        std_deviation = statistics.pstdev(raw[key], stats_avg)

        result_group = {}
        result_group[measurement_key] = [ stats_avg, std_deviation ]
        results[key] = result_group

    return results


def get_sort_key(before, after, m, k, invert):
    before_avg = before[k][m][0]
    after_avg = after[k][m][0]

    if before_avg == 0:
        return after[k][m]

    delta = (after_avg - before_avg) / before_avg
    return -delta if invert else delta


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before", help="The output of the original code")
    parser.add_argument("after", help="The output of the new code")
    parser.add_argument("--label", default="fps", help="Label used for the stat being compared (default: fps)")
    parser.add_argument("--smaller-is-better", action="store_true", default=False,
                        help="If a smaller value of the stat is better (default: a bigger value is better)")
    parser.add_argument("--summary-only", "-s", action="store_true", default=False,
                        help="Do not show the trace helped / hurt data")
    parser.add_argument("--skip-gfxrecon", action="store_true", help="If we should skip gfxreconstruct traces")
    parser.add_argument("--skip-apitrace", action="store_true", help="If we should skip apitrace traces")
    parser.add_argument("--skip-min-max", action="store_true", help="If we should remove one stats_min/max from the list of samples")
    parser.add_argument("--show-std-deviation", action="store_true", help="If we should show the std deviation of the computed stats average")
    parser.add_argument("--sort-by-std-deviation", action="store_true", help="If we should sort the results based on after std-deviation")
    parser.add_argument("--threshold", default=0.005, type=float, help="Threshold used to determine helped/HURT runs (default 0.005)")
    parser.add_argument("-x", "--exclude-traces", default=[], action="append", metavar="<regex>", help="Exclude matching traces (can be used more than once)")
    parser.add_argument("-t", "--include-traces", default=[], action="append", metavar="<regex>", help="Include matching traces (can be used more than once)")

    args = parser.parse_args()

    higher_is_better = not args.smaller_is_better

    # For the final analysis only the stat avg is relevant
    measurement_key = f"{args.label}_avg"
    measurements = [measurement_key]

    include_filter = []
    exclude_filter = []
    if args.exclude_traces:
        exclude_filter = [re.compile(f, flags=re.IGNORECASE) for f in args.exclude_traces]
    if args.include_traces:
        include_filter = [re.compile(f, flags=re.IGNORECASE) for f in args.include_traces]

    before_raw = get_results(args.before, include_filter, exclude_filter)
    before = process_results(before_raw, args, measurement_key)
    after_raw = get_results(args.after, include_filter, exclude_filter)
    after = process_results(after_raw, args, measurement_key)

    total_before = {}
    total_after = {}
    affected_before = {}
    affected_after = {}
    num_hurt = {}
    num_helped = {}

    #FIXME: not measuring confidence intervals. It is not clear if
    #that is representative here, and in case of being, we need to
    #tweak the values for the stat

    # Filling up helper/hurt
    for m in measurements:
        helped = []
        hurt = []

        total_before[m] = 0
        total_after[m] = 0
        affected_before[m] = 0
        affected_after[m] = 0

        for p in before:
            file_extension = pathlib.Path(p).suffix
            if file_extension == '.gfxr' and args.skip_gfxrecon:
                continue

            if file_extension == '.trace' and args.skip_apitrace:
                continue

            before_count = before[p][m]

            if after.get(p) is None:
                continue

            after_count = after[p][m]

            # We compute the helped/HURT with the avg, std_deviation
            # right now is to hint how reliable that measure is
            total_before[m] += before_count[0]
            total_after[m] += after_count[0]

            kk = after_count[0] / before_count[0]
            if abs(kk - 1.0) >= args.threshold:
                affected_before[m] += before_count[0]
                affected_after[m] += after_count[0]

                # Whether a bigger or a smaller value is an improvement
                # depends on --smaller-is-better
                if higher_is_better:
                    improved = after_count[0] > before_count[0]
                else:
                    improved = after_count[0] < before_count[0]

                if improved:
                    helped.append(p)
                else:
                    hurt.append(p)

        if not args.summary_only:
            if not args.sort_by_std_deviation:
                helped.sort(key=lambda k: get_sort_key(before, after, m, k, higher_is_better))
            else:
                helped.sort(key=lambda k: after[k][m][1])

            for p in helped:
                print(f"{m}  helped:  {get_result_string(p, before[p][m], after[p][m], args)}")
            if helped:
                print("")

            if not args.sort_by_std_deviation:
                hurt.sort(key=lambda k: get_sort_key(before, after, m, k, not higher_is_better))
            else:
                hurt.sort(key=lambda k: after[k][m][1])
            for p in hurt:
                print(f"{m} HURT: {get_result_string(p, before[p][m], after[p][m], args)}")
            if hurt:
                print("")


        num_helped[m] = len(helped)
        num_hurt[m] = len(hurt)

    lost = []
    gained = []

    for p in before:
        if p not in after:
            lost.append(p)

    for p in after:
        if p not in before:
            gained.append(p)

    if not args.summary_only:
        lost.sort()
        for p in lost:
            print(f"LOST:   {p}")
        if lost:
            print("")

        gained.sort()
        for p in gained:
            print(f"GAINED: {p}")
        if gained:
            print("")

    any_helped_or_hurt = False
    for m in measurements:
        if num_helped[m] > 0 or num_hurt[m] > 0:
            any_helped_or_hurt = True

        if num_helped[m] > 0 or num_hurt[m] > 0:
            print(f"total {m} in all runs: {change(total_before[m], total_after[m])}\n"
                  f"total {m} in affected (through threshold) runs: {change(affected_before[m], affected_after[m])}\n"
                  f"helped: {num_helped[m]}\n"
                  f"HURT: {num_hurt[m]}")

            # FIXME: not printing the abs/rel statistics
            print("")


    if lost or gained:
        print(f"LOST:   {len(lost)}")
        print(f"GAINED: {len(gained)}")
    else:
        if not any_helped_or_hurt:
            print("No changes.")

if __name__ == "__main__":
    main()
