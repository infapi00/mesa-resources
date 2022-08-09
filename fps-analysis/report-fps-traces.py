#!/usr/bin/env python3

import re
import argparse
import math
import statistics
import csv
from scipy import stats
import numpy as np
import pathlib
import sys

def gather_statistics(changes, before, after, m):
    stats = (0.0, 0, 0.0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0)

    if changes:
        absolute = [abs(before[p][m] - after[p][m]) for p in changes]
        relative = [0 if before[p][m] == 0 else abs(before[p][m] - after[p][m]) / before[p][m] for p in changes]

        stats = (statistics.mean(absolute),
                 statistics.median(absolute),
                 min(absolute),
                 max(absolute),
                 statistics.mean(relative),
                 statistics.median(relative),
                 min(relative),
                 max(relative))

    return stats


def format_percent(frac):
    """Converts a factional value (typically 0.0 to 1.0) to a string as a percentage"""
    if abs(frac) > 0.0 and abs(frac) < 0.0001:
        return "<.01%"
    else:
        return "{:.2f}%".format(frac * 100)


def get_delta(b, a):
    if b != 0 and a != 0:
        frac = float(a) / float(b) - 1.0
        return ' ({})'.format(format_percent(frac))
    else:
        return ''


def format_num(n):
    assert n >= 0
    if n - math.floor(n) < 0.01:
        return str(math.floor(n))
    else:
        return "{:.2f}".format(n)


def change(b, a):
    return format_num(b) + " -> " + format_num(a) + get_delta(b, a)


def get_result_string(p, b, a):
    p = p + ": "
    while len(p) < 50:
        p = p + ' '
    return p + change(b, a)


def get_results(filename):
    file = open(filename, "r")
    lines = file.read().split('\n')

    results = {}

    # Each line has the format "trace_name,fps", and can be more that one trace_name entry
    with open(filename) as file_obj:
        reader_obj = csv.reader(file_obj)
        for row in reader_obj:
            if row[0] in results:
                result_list = results[row[0]]
            else:
                result_list = []

            result_list.append(float(row[1]))
            results[row[0]] = result_list

    return results

def process_one_result(list):
    fps_accum = 0
    fps_max = 0
    fps_min = sys.float_info.max

    for fps in list:
        fps_accum += fps
        fps_max = max(fps, fps_max)
        fps_min = min(fps, fps_min)

    fps_avg = fps_accum / len(list)

    return [fps_min, fps_max, fps_avg]

def process_results(raw, args):
    results = {}

    for key in raw:
        [fps_min, fps_max, fps_avg] = process_one_result(raw[key])

        if args.skip_min_max and len(raw[key]) >= 3:
            raw[key].remove(fps_min)
            raw[key].remove(fps_max)

            [fps_min, fps_max, fps_avg] = process_one_result(raw[key])

        result_group = {}
        result_group['fps_min'] = fps_min
        result_group['fps_max'] = fps_max
        result_group['fps_avg'] = fps_avg
        results[key] = result_group

    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before", help="The output of the original code")
    parser.add_argument("after", help="The output of the new code")
    parser.add_argument("--summary-only", "-s", action="store_true", default=False,
                        help="Do not show the trace helped / hurt data")
    parser.add_argument("--skip-gfxrecon", action="store_true", help="If we should skip gfxreconstruct traces")
    parser.add_argument("--skip-apitrace", action="store_true", help="If we should skip apitrace traces")
    parser.add_argument("--skip-min-max", action="store_true", help="If we should remove one fps_min/max from the list of samples")

    args = parser.parse_args()


    measurements = ["fps_min", "fps_max", "fps_avg"]

    before_raw = get_results(args.before)
    before = process_results(before_raw, args)
    after_raw = get_results(args.after)
    after = process_results(after_raw, args)

    total_before = {}
    total_after = {}
    affected_before = {}
    affected_after = {}
    helped_statistics = {}
    hurt_statistics = {}
    num_hurt = {}
    num_helped = {}

    #FIXME: not measuring confidence intervals. It is not clear if
    #that is representative here, and in case of being, we need to
    #tweak the values for fps

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
            if (file_extension == '.gfxr' and args.skip_gfxrecon):
                continue

            if (file_extension == '.trace' and args.skip_apitrace):
                continue

            before_count = before[p][m]

            if after.get(p) is None:
                continue

            after_count = after[p][m]

            total_before[m] += before_count
            total_after[m] += after_count

            if before_count != after_count:
                affected_before[m] += before_count
                affected_after[m] += after_count

                # Measuring only FPS, higher is always better
                if (after_count > before_count):
                    helped.append(p)
                else:
                    hurt.append(p)

        if not args.summary_only:
            helped.sort(
                key=lambda k: after[k][m] if before[k][m] == 0 else float(before[k][m] - after[k][m]) / before[k][m])
            for p in helped:
                namestr = p
                print(m + " helped:   " +
                      get_result_string(namestr, before[p][m], after[p][m]))
            if helped:
                print("")

            hurt.sort(
                key=lambda k: after[k][m] if before[k][m] == 0 else float(after[k][m] - before[k][m]) / before[k][m])
            for p in hurt:
                namestr = p
                print(m + " HURT:   " +
                      get_result_string(namestr, before[p][m], after[p][m]))
            if hurt:
                print("")


        helped_statistics[m] = gather_statistics(helped, before, after, m)
        hurt_statistics[m] = gather_statistics(hurt, before, after, m)

        num_helped[m] = len(helped)
        num_hurt[m] = len(hurt)

    lost = []
    gained = []

    for p in before:
        if after.get(p) is None:
            lost.append(p)

    for p in after:
        if before.get(p) is None:
            gained.append(p)

    if not args.summary_only:
        lost.sort()
        for p in lost:
            print("LOST:   " + p)
        if lost:
            print("")

        gained.sort()
        for p in gained:
            print("GAINED: " + p)
        if gained:
            print("")

    any_helped_or_hurt = False
    for m in measurements:
        if num_helped[m] > 0 or num_hurt[m] > 0:
            any_helped_or_hurt = True

        if num_helped[m] > 0 or num_hurt[m] > 0:
            print("total {0} in shared programs: {1}\n"
                  "{0} in affected programs: {2}\n"
                  "helped: {3}\n"
                  "HURT: {4}".format(
                      m,
                      change(total_before[m], total_after[m]),
                      change(affected_before[m], affected_after[m]),
                      num_helped[m],
                      num_hurt[m]))

            # FIXME: not printing the abs/rel statistics
            print()


    if lost or gained:
        print("LOST:   " + str(len(lost)))
        print("GAINED: " + str(len(gained)))
    else:
        if not any_helped_or_hurt:
            print("No changes.")

if __name__ == "__main__":
    main()
