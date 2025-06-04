#!/usr/bin/env python3
#
# Runs all the gfxrecon captures to check for fps measures
#
# As usually this is done after a mesa rebuild, we do this twice, to
# check the fps measures with a hot shader disk cache.
#
import argparse
from datetime import datetime
import os
import pathlib
import re
import shutil
import subprocess
import time

# Sometimes we get a xcb failures on the gfxrecon replay, that we are
# not sure how to fix or when we would be able to work on it. For now
# we just retry a maximum amount of attempts.
#
# FIXME: hardcoded, perhaps a new command line parameter?

MAX_ATTEMPTS = 3

def run_trace(args, filename, fps_file, num_samples):
    if args.verbose:
        print(f"Current trace: {filename}")

    file_extension = pathlib.Path(filename).suffix
    if file_extension == '.gfxr':
        if args.skip_gfxrecon:
            print("\tskipped")
            return

        command = ['gfxrecon-replay']
        command += ['--log-level', 'fatal']
        if args.rebind:
            command += ['-m', 'rebind']
        if args.headless:
            command += ['--wsi', 'headless']
    elif file_extension == '.trace':
        if args.skip_apitrace:
            print("\tskipped")
            return
        command = ['apitrace']
        command += ['replay']
        command += ['-b']
        if args.headless:
            command += ['--headless']
    else:
        print(f"File {filename} skipped: extension {file_extension} not recognized")
        return

    command += [filename]
    remaining_attempts = MAX_ATTEMPTS

    for sample in range(num_samples):
        if remaining_attempts <= 0:
            continue
        for attempt in range(remaining_attempts):
            try:
                output = subprocess.run(command,
                                        capture_output=True,
                                        check=True)
                if args.verbose and args.sleep_time > 0:
                    print(f"Waiting {args.sleep_time} seconds")
                time.sleep(args.sleep_time)

                # Parse FPS value. Note that the stdout of the
                # gfxrecon-replay is not always the same, as for some
                # samples there are no load time stats, so we use regex to
                # find the string with "Replay FPS" header.

                split = output.stdout.splitlines()
                fps = 0.0

                # FIXME: this seems somewhat convoluted. I bet that
                # there is way to get the FPS from the string with
                # just one regex, without an index, and without
                # tweaking based on gfxr vs apitrace. This works for
                # now.
                for line in split:
                    if file_extension == '.gfxr':
                        search = re.compile('Replay FPS')
                        fps_index = 0
                    else:
                        search = re.compile('Rendered')
                        fps_index = 2
                    line_str = line.decode('utf-8')
                    match = search.search(line_str)
                    if match is not None:
                        float_search = re.findall(r"[-+]?\d*\.\d+|\d+", line_str)
                        if float_search is not None:
                            fps = float(float_search[fps_index])

                if fps_file is not None:
                    new_line = os.path.basename(filename)
                    new_line += ',' + str(fps)
                    new_line += '\n'
                    fps_file.write(new_line)

            except Exception as err:
                print(f"ERROR executing trace {filename} : {type(err).__name__} was raised: {err}")
                if attempt < MAX_ATTEMPTS:
                    print(f"\tRetrying to execute trace {filename}. Remaining attempts {str(remaining_attempts)}")
                remaining_attempts = remaining_attempts - 1
            else:
                break
        else:
            print(f"Consumed {str(MAX_ATTEMPTS)} attempts for trace {filename}. Discarding trace")

# Note that although we provide a number of samples on the command
# line arguments, we still need to pass it as a parameter, in order to
# configure the initial cache warmup with a value of 1.
def run_traces(args, fps_file, num_samples):
    for directory in args.traces_directory_list:
        full_directory = os.path.expanduser(directory)
        if args.verbose:
            print(f"******* Current traces directory: {full_directory} *******")
        for filename in os.listdir(full_directory):
            f = os.path.join(full_directory, filename)
            if os.path.isfile(f):
                run_trace(args, f, fps_file, num_samples)
            else:
                if args.verbose:
                    print(f"{f} is not a file")

def run_helper(args, results_directory):
    if os.path.exists(results_directory) is False:
        os.mkdir(results_directory)

    if args.disable_cache_run is False:
        if args.verbose:
            print("Warming up shader cache")
        run_traces(args, None, 1)
    fps_file_name = results_directory + '/fps-stats-' + datetime.now().strftime("%Y-%m-%d_%H:%M:%S")+'.txt'
    with open(fps_file_name, 'w') as fps_file:
        if args.verbose:
            print(f"Starting FPS run. Writing stats on file {fps_file_name}")
        run_traces(args, fps_file, args.num_samples)

def main():
    parser = argparse.ArgumentParser()

    # Keep command line options sorted alphabetically
    parser.add_argument("--disable-cache-run", action="store_true",
                        help="By default we do a first run to ensure a hot shader cache, not included for the fps stats")
    parser.add_argument("--headless", action="store_true", help="If we run both apitrace/gfxrecon-replay headless")
    parser.add_argument("--num-samples", nargs='?', default=1, type=int, help="Number of times each trace is executed to get the (averaged) fps value. Not include the shaderdb run")
    parser.add_argument("--mesa-commit-list", nargs='+', action="extend", type=str, help="List of mesa commits to execute the script against")
    parser.add_argument("--mesa-directory", nargs='?', type=str, help="Mesa directory. Useful if we pass a list of mesa commits")
    parser.add_argument("--rebind", action="store_true", help="If we call gfxrecon-replay with -m rebind")
    parser.add_argument("--skip-apitrace", action="store_true", help="If we should skip running the apitrace traces")
    parser.add_argument("--skip-gfxrecon", action="store_true", help="If we should skip running the gfxreconstruct traces")
    parser.add_argument("--sleep-time", nargs='?', default=0, type=int, help="Sleep time between trace execution (not applied on cache warmup")
    parser.add_argument("--traces-directory-list", nargs='+', default=["traces"], type=str, help="List of directories with the traces")
    parser.add_argument("--verbose", action="store_true", default=False, help="Enable to print additional debug messages")

    args = parser.parse_args()

    if args.mesa_commit_list is not None and len(args.mesa_commit_list) > 10:
        print("List of mesa commits too big (maximum value is 10)")
        return

    if args.skip_gfxrecon and args.skip_apitrace:
        print("Both --skip-gfxrecon and --skip-apitrace options used. Nothing to do")
        return

    # We ensure that the on-disk-cache is enabled, as we want hot-cache fps numbers
    os.unsetenv("MESA_GLSL_CACHE_DISABLE")
    os.unsetenv("MESA_SHADER_CACHE_DISABLE")

    # FIXME: hardcoded. Perhaps a new command line argument (but we already have a lot)
    base_results_directory = "results"

    if (args.mesa_commit_list is None):
        run_helper(args, base_results_directory)
    else:
        index = 0
        for commit in args.mesa_commit_list:
            results_directory = base_results_directory + "-" + str(index) + "-" + commit
            mesa_directory = os.path.expanduser(args.mesa_directory)
            command =  ['git', 'checkout', commit]
            print(command)

            try:
                subprocess.run(command, cwd=mesa_directory, check=True)
            except Exception as err:
                print(f"ERROR moving to commit {commit} : {type(err).__name__} was raised: {err}")
                return

            #FIXME: this only works if you are using jhbuild to build mesa
            try:
                subprocess.run(['jhbuild', 'buildone', '-fn', 'mesa'], check=True)
            except Exception as err:
                print(f"ERROR building mesa at commit {commit} : {type(err).__name__} was raised: {err}")
                return

            run_helper(args, results_directory)

            try:
                subprocess.run(['git', 'switch', '-'], cwd=mesa_directory, check=True)
            except Exception as err:
                print(f"ERROR moving back to current mesa branch : {type(err).__name__} was raised: {err}")
                return

            index = index + 1


if __name__ == "__main__":
    main()

