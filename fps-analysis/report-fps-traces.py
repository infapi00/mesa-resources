#!/usr/bin/env python3

import re
import argparse
import math
import csv
import pathlib
import sys

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


def get_avg_std_deviation_string(b):
    return "(" + format_num(b[0]) + " , " + format_num(b[1]) + ")"


def change(b, a):
    return format_num(b) + " -> " + format_num(a) + get_delta(b, a)


def change_with_std_deviation(b, a):
    return get_avg_std_deviation_string(b) + " -> " + get_avg_std_deviation_string(a) + get_delta(b[0], a[0])


def get_result_string(p, b, a, args):
    p = p + ": "
    while len(p) < 50:
        p = p + ' '
    if (args.show_std_deviation):
        return p + change_with_std_deviation(b, a)
    else:
        return p + change(b[0], a[0])


def get_results(filename, include_filter, exclude_filter):
    results = {}

    # Each line has the format "trace_name,fps", and can be more that one trace_name entry
    with open(filename) as file_obj:
        reader_obj = csv.reader(file_obj)
        for row in reader_obj:
            # We assume that if not include filter is provided, we want to process all of them
            if include_filter and not any(r.search(row[0]) for r in include_filter):
                    continue

            if any(r.search(row[0]) for r in exclude_filter):
                continue

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
    std_deviation = 0
    std_accum = 0

    for fps in list:
        fps_accum += fps
        fps_max = max(fps, fps_max)
        fps_min = min(fps, fps_min)

    fps_avg = fps_accum / len(list)

    for fps in list:
        std_accum += pow(fps - fps_avg, 2)

    std_deviation = math.sqrt(std_accum / len(list))

    return [fps_min, fps_max, fps_avg, std_deviation]

def process_results(raw, args):
    results = {}

    for key in raw:
        [fps_min, fps_max, fps_avg, std_deviation] = process_one_result(raw[key])

        # FIXME: we are calling process_one_result twice because we
        # need to compute min/max to remove it. Perhaps a different
        # method with just that
        if args.skip_min_max and len(raw[key]) >= 3:
            raw[key].remove(fps_min)
            raw[key].remove(fps_max)

            [fps_min, fps_max, fps_avg, std_deviation] = process_one_result(raw[key])

        result_group = {}
        result_group['fps_avg'] = [ fps_avg, std_deviation ]
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
    parser.add_argument("--show-std-deviation", action="store_true", help="If we should show the std deviation of the computed FPS average")
    parser.add_argument("--threshold", default=0.005, type=float, help="Threshold used to determine helped/HURT runs (default 0.005)")
    parser.add_argument("-x", "--exclude-traces", default=[], action="append", metavar="<regex>", help="Exclude matching traces (can be used more than once)")
    parser.add_argument("-t", "--include-traces", default=[], action="append", metavar="<regex>", help="Include matching traces (can be used more than once)")

    args = parser.parse_args()

    # For the final analysis only fps avg is relevant
    measurements = ["fps_avg"]

    include_filter = []
    exclude_filter = []
    if (args.exclude_traces):
        exclude_filter = [re.compile(f, flags=re.IGNORECASE) for f in args.exclude_traces]
    if (args.include_traces):
        include_filter = [re.compile(f, flags=re.IGNORECASE) for f in args.include_traces]

    before_raw = get_results(args.before, include_filter, exclude_filter)
    before = process_results(before_raw, args)
    after_raw = get_results(args.after, include_filter, exclude_filter)
    after = process_results(after_raw, args)

    total_before = {}
    total_after = {}
    affected_before = {}
    affected_after = {}
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

            # We compute the helped/HURT with the avg, std_deviation
            # right now is to hint how reliable that measure is
            total_before[m] += before_count[0]
            total_after[m] += after_count[0]

            kk = after_count[0] / before_count[0]
            if (abs(kk - 1.0) > args.threshold):
                affected_before[m] += before_count[0]
                affected_after[m] += after_count[0]

                # Measuring only FPS, higher is always better
                if (after_count > before_count):
                    helped.append(p)
                else:
                    hurt.append(p)

        if not args.summary_only:
            helped.sort(
                key=lambda k: after[k][m] if before[k][m][0] == 0 else float(before[k][m][0] - after[k][m][0]) / before[k][m][0])
            for p in helped:
                namestr = p
                print(f"{m}  helped:  {get_result_string(namestr, before[p][m], after[p][m], args)}")
            if helped:
                print("")

            hurt.sort(
                key=lambda k: after[k][m] if before[k][m][0] == 0 else float(after[k][m][0] - before[k][m][0]) / before[k][m][0])
            for p in hurt:
                namestr = p
                print(f"{m} HURT: {get_result_string(namestr, before[p][m], after[p][m], args)}")
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
            print("total {0} in all runs: {1}\n"
                  "total {0} in affected (through threshold) runs: {2}\n"
                  "helped: {3}\n"
                  "HURT: {4}".format(
                      m,
                      change(total_before[m], total_after[m]),
                      change(affected_before[m], affected_after[m]),
                      num_helped[m],
                      num_hurt[m]))

            # FIXME: not printing the abs/rel statistics
            print("")


    if lost or gained:
        print(f"LOST:   {str(len(lost))}")
        print(f"GAINED: {str(len(gained))}")
    else:
        if not any_helped_or_hurt:
            print("No changes.")

if __name__ == "__main__":
    main()
