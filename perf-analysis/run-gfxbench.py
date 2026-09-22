#!/usr/bin/env python3
#
# Runs a list of gfxbench demos (read from a csv file) to check for
# fps/score measures.
#
import argparse
import csv
import json
import os
import subprocess
from datetime import datetime

GFXBENCH_BINARY = "tfw-pkg/bin/gfxbench-wayland-release"

# We usually execute the binary from gfxbench main directory, so the
# "results" directory we pass when we execute it, is later really
# placed on the directory the binary is. This is somewhat ugly though
GFXBENCH_RESULTDIR_ARG = "results"
GFXBENCH_RESULTS_DIRECTORY = "tfw-pkg/results"


def run_benchmark(args, name, width, height, fps_file, score_file, num_samples):
    if args.verbose:
        print(f"Current benchmark: {name} ({width}x{height})")

    command = [GFXBENCH_BINARY]
    command += ['--gfx', 'egl']
    command += ['--gl_api', 'gles']
    command += ['--width', width]
    command += ['--height', height]
    command += ['--resultdir', GFXBENCH_RESULTDIR_ARG]
    command += ['-t', name]

    json_result_file = os.path.join(GFXBENCH_RESULTS_DIRECTORY, f"{name}.json")
    result_key = f"{name}_{width}_{height}"

    for sample in range(num_samples):
        try:
            # Remove previous execution, to be sure this run actually
            # produced a new one.
            if os.path.exists(json_result_file):
                os.remove(json_result_file)

            subprocess.run(command, capture_output=True, check=True)

            if not os.path.exists(json_result_file):
                raise RuntimeError(f"no result file generated at {json_result_file}")

            with open(json_result_file) as f:
                data = json.load(f)

            result = data['results'][0]
            if result['status'] != 'OK':
                raise RuntimeError(f"status {result['status']}: {result['error_string']}")

            fps = result['gfx_result']['fps']
            score = result['score']

            if fps_file is not None:
                fps_file.write(f"{result_key},{fps}\n")
            if score_file is not None:
                score_file.write(f"{result_key},{score}\n")

        except Exception as err:
            print(f"ERROR executing benchmark {name} : {type(err).__name__} was raised: {err}")


def run_benchmarks(args, fps_file, score_file, num_samples):
    full_csv_file = os.path.expanduser(args.config_file)
    with open(full_csv_file, newline='') as csv_obj:
        reader_obj = csv.reader(csv_obj)
        for row in reader_obj:
            if not row:
                continue
            name, width, height = (field.strip() for field in row[:3])
            run_benchmark(args, name, width, height, fps_file, score_file, num_samples)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--config-file", required=True, type=str, help="csv file with the gfxbench demos to run: name,width,height")
    parser.add_argument("--num-samples", nargs='?', default=1, type=int, help="Number of times each demo is executed to get the (averaged) fps/score value")
    parser.add_argument("--verbose", action="store_true", default=False, help="Enable to print additional debug messages")

    args = parser.parse_args()

    # FIXME: hardcoded. Perhaps a new command line argument (but we already have a lot)
    results_directory = "results"

    if not os.path.exists(results_directory):
        os.mkdir(results_directory)
    if not os.path.exists(GFXBENCH_RESULTS_DIRECTORY):
        os.mkdir(GFXBENCH_RESULTS_DIRECTORY)

    timestamp = datetime.now().strftime('%Y-%m-%d_%H:%M:%S')
    fps_file_name = f"{results_directory}/fps-stats-{timestamp}.csv"
    score_file_name = f"{results_directory}/score-stats-{timestamp}.csv"

    with open(fps_file_name, 'w') as fps_file, open(score_file_name, 'w') as score_file:
        if args.verbose:
            print(f"Starting run. Writing FPS stats on file {fps_file_name}")
            print(f"Starting run. Writing score stats on file {score_file_name}")
        run_benchmarks(args, fps_file, score_file, args.num_samples)


if __name__ == "__main__":
    main()
