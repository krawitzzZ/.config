#!/usr/bin/env bash
# recording-indicator.sh — i3status-rust "custom" block (json = true).
# Prints a red REC indicator while wf-recorder is running, and nothing when
# idle so the block disappears (hide_when_empty = true).

if pgrep -x wf-recorder >/dev/null 2>&1; then
    printf '{"state":"Critical","text":"\u25cf REC"}\n'
else
    printf '{"text":""}\n'
fi
