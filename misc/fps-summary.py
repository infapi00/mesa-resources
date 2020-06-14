#!/usr/bin/env python3
#
# For an vulkan application run using the overlay layers like this:
#
# VK_INSTANCE_LAYERS=VK_LAYER_MESA_overlay VK_LAYER_MESA_OVERLAY_CONFIG=output_file=/tmp/output.txt ./vk-app
#
# it computes the average, min and max fps
#
import argparse

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("fps_file", help="fps file")

    args = parser.parse_args()

    file = open(args.fps_file, "r")
    lines = file.read().split('\n')

    num_lines = 0
    total_value = 0
    min_fps = 666
    max_fps = 0

    for line in lines:
        if line and line != "fps, frame_timing(us)":
            parsed_line = line.split(',')

            fps = parsed_line[0]
            frame_timing = parsed_line[1]

            total_value += float(fps)
            min_fps = min(min_fps, float(fps))
            max_fps = max(max_fps, float(fps))

            num_lines += 1

    avg_fps = total_value / num_lines

    print("avg_fps: ", avg_fps)
    print("min_fps: ", min_fps)
    print("max_fps: ", max_fps)

if __name__ == "__main__":
    main()
