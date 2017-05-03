#!/bin/bash
#
# This script tries to save the dumped information from
# /sys/class/drm/card0/error as soon as it happens since it often
# leads to a total desktop hang. You could see a message like the one
# below in your logs when this happens:
#
# [drm] GPU HANG: ecode 6:0:0x85fffffc, in ositorWorkQueue [7301], reason: Hang on render ring, action: reset
# [drm] GPU hangs can indicate a bug anywhere in the entire gfx stack, including userspace.
# [drm] Please file a _new_ bug report on bugs.freedesktop.org against DRI -> DRM/Intel
# [drm] drm/i915 developers can then reassign to the right component if it's not a kernel issue.
# [drm] The gpu crash dump is required to analyze gpu hangs, so please always attach it.
# [drm] GPU crash dump saved to /sys/class/drm/card0/error
#
# Run:
#
# $ ./dump-gpu-error.sh


# Maybe you need to configure this.

CARD_NUMBER="0"
INOTIFYWAIT="/usr/bin/inotifywait"
GDBUS="/usr/bin/gdbus"


# You shouldn't need to touch from here ...

ERROR_PATH="/sys/class/drm/card${CARD_NUMBER}/error"

function inotify () {
    $INOTIFYWAIT -q -e modify "${ERROR_PATH}"
}

function poll () {
    printf "%s\n" \
	   "You don't have installed inotifywait (inotify-tools)." \
	   "You probably would want to install it." \
	   "Start polling every 60s instead ..."
    while : ; do
        ERROR=$(head -1 "${ERROR_PATH}")
        [[ "x${ERROR}" == "xno error state collected" ]] || break
        sleep 60
    done
}

if [ -x $INOTIFYWAIT ]; then
    inotify
else
    poll
fi

TIMESTAMP=$(date +%Y%m%d%H%M%S)
DUMP_FILE="${HOME}/error-${TIMESTAMP}"
cat "${ERROR_PATH}" > "${DUMP_FILE}"

MESSAGE=$(printf "%s\n" \
		 "Your GPU crashed!" \
		 "" \
		 "The crash from" \
		 "${ERROR_PATH}" \
		 "has been saved at" \
		 "${DUMP_FILE} .")

if [ -x $GDBUS ]; then
    gdbus call --session \
          --dest org.freedesktop.Notifications \
          --object-path /org/freedesktop/Notifications \
          --method org.freedesktop.Notifications.Notify \
          "${0}" \
          42 \
          dialog-warning-symbolic \
          "Your GPU crashed!" \
          "${MESSAGE}" \
          [] \
          "{'category': <'device.error'>, 'sound-name': <'dialog-error'>, 'urgency': <2>}" \
          0
else
    tput bel
    xmessage "${MESSAGE}"
fi

printf "%s\n" "${MESSAGE}"
