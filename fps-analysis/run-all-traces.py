#!/usr/bin/env python3
#
# Runs all the gfxrecon captures to check for fps measures
#
# As usually this is done after a mesa rebuild, we do this twice, to
# check the fps measures with a hot shader disk cache.
#
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys

# Sometimes we get a xcb failures on the gfxrecon replay, that we are
# not sure how to fix or when we would be able to work on it. For now
# we just retry a maximum amount of attempts.
#
# FIXME: hardcoded, perhaps a new command line parameter?

MAX_ATTEMPTS = 3

def run_trace(args, filename, fps_file, num_samples):
    #FIXME: add a verbose mode?
    print("Current trace: " + filename)

    file_extension = pathlib.Path(filename).suffix
    if file_extension == '.gfxr':
        if args.skip_gfxrecon:
            print("\tskipped")
            return

        command = ['gfxrecon-replay']
        command += ['--log-level', 'fatal']
        if args.rebind:
            command += ['-m', 'rebind']
    elif file_extension == '.trace':
        if args.skip_apitrace:
            print("\tskipped")
            return
        command = ['apitrace']
        command += ['replay']
        command += ['-b']
    else:
        print("File extension " + file_extension + " not recognized")
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
                print("ERROR executing trace " + filename + " : " + f"{type(err).__name__} was raised: {err}")
                if attempt < MAX_ATTEMPTS:
                    print("\tRetrying to execute trace " + filename + " Remaining attempts " + str(remaining_attempts))
                remaining_attempts = remaining_attempts - 1
            else:
                break
        else:
            print("Consumed " + str(MAX_ATTEMPTS) + " attempts for trace " + filename + ". Discarding trace")

# Note that although we provide a number of samples on the command
# line arguments, we still need to pass it as a parameter, in order to
# configure the initial cache warmup with a value of 1.
def run_traces(args, traces_directory, fps_file, num_samples):
    for filename in os.listdir(traces_directory):
        f = os.path.join(traces_directory, filename)
        if os.path.isfile(f):
            run_trace(args, f, fps_file, num_samples)

def run_helper(args, traces_directory, results_directory):
    if os.path.exists(results_directory):
        shutil.rmtree(results_directory)
    os.mkdir(results_directory)

    if args.disable_cache_run is False:
        #FIXME: add a verbose mode?
        print("Warming up shader cache")
        run_traces(args, traces_directory, None, 1)

    fps_file = open(results_directory + '/fps-stats.txt', 'w')

    #FIXME: add a verbose mode?
    print("Starting FPS run")
    run_traces(args, traces_directory, fps_file, args.num_samples)
    fps_file.close()

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--rebind", nargs='?', default=False, type=bool, help="If we call gfxrecon-replay with -m rebind")
    parser.add_argument("--disable-cache-run", nargs='?', default=False, type=bool, help="By default we do a first run to ensure a hot shader cache, not included for the fps stats")
    parser.add_argument("--traces-directory", nargs='?', default="traces", type=str, help="Directory with the traces")
    parser.add_argument("--num-samples", nargs='?', default=1, type=int, help="Number of times each trace is executed to get the (averaged) fps value. Not include the shaderdb run")
    parser.add_argument("--skip-gfxrecon", action="store_true", help="If we should skip running the gfxreconstruct traces")
    parser.add_argument("--skip-apitrace", action="store_true", help="If we should skip running the apitrace traces")
    parser.add_argument("--mesa-directory", nargs='?', type=str, help="Mesa directory. Useful if we pass a list of mesa commits")
    parser.add_argument("--mesa-commit-list", nargs='+', action="extend", type=str, help="List of mesa commits to execute the script against")

    args = parser.parse_args()

    if args.mesa_commit_list is not None and len(args.mesa_commit_list) > 10:
        print("List of mesa commits too big (maximum value is 10)")
        return

    if args.skip_gfxrecon and args.skip_apitrace:
        print("Both --skip-gfxrecon and --skip-apitrace options used. Nothing to do")
        return

    traces_directory = os.path.expanduser(args.traces_directory)
    print(traces_directory)

    # We ensure that the on-disk-cache is enabled, as we want hot-cache fps numbers
    os.unsetenv("MESA_GLSL_CACHE_DISABLE")
    os.unsetenv("MESA_SHADER_CACHE_DISABLE")

    # FIXME: perhaps further configuration on the results folder
    # through a command line option?
    base_results_directory = "results"

    if (args.mesa_commit_list is None):
        run_helper(args, traces_directory, base_results_directory)
    else:
        index = 0
        for commit in args.mesa_commit_list:
            results_directory = base_results_directory + "-" + str(index) + "-" + commit
            mesa_directory = os.path.expanduser(args.mesa_directory)
            command =  ['git', 'checkout', commit]
            print(command)

            try:
                output = subprocess.run(command,
                                        cwd=mesa_directory)
            except Exception as err:
                print("ERROR moving to commit  " + commit + " : " + f"{type(err).__name__} was raised: {err}")
                return

            #FIXME: this only works if you are using jhbuild to build mesa
            try:
                output = subprocess.run(['jhbuild', 'buildone', '-fn', 'mesa'])
            except Exception as err:
                print("ERROR building mesa  " + commit + " : " + f"{type(err).__name__} was raised: {err}")
                return

            run_helper(args, traces_directory, results_directory)

            try:
                output = subprocess.run(['git', 'switch', '-'],
                                        cwd=mesa_directory)
            except Exception as err:
                print("ERROR moving back to current mesa branch : " + f"{type(err).__name__} was raised: {err}")
                return

            index = index + 1


if __name__ == "__main__":
    main()

