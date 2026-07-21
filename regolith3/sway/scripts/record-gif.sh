#!/usr/bin/env bash
# record-gif.sh — toggle region GIF recording on Wayland/Sway.
#
# First press : pick a region with slurp, then record it with wf-recorder.
# Second press: stop recording and convert the clip to a GIF with gifski.
#
# Deps: slurp, wf-recorder, gifski, wl-copy, notify-send.

set -u

# gifski is typically installed via `cargo install` under ~/.cargo/bin,
# which is not always on PATH for processes launched by sway.
export PATH="$HOME/.cargo/bin:$PATH"

FPS=12          # GIF frame rate (lower = smaller file)
QUALITY=80      # gifski quality (1-100)
MAXW=800        # cap output width in px (only downscales larger regions)

# If a recording is already running, stop it. wf-recorder needs SIGINT
# (not SIGTERM) to flush the y4m trailer, so the file stays valid.
if pkill -INT -x wf-recorder; then
    notify-send -t 2000 "GIF" "Recording stopped, converting…"
    exit 0
fi

# --- Start a new recording ---
geom="$(slurp)" || exit 0          # aborted selection -> do nothing
[ -n "$geom" ] || exit 0

ts="$(date +%F-%H%M%S)"
tmp="${XDG_RUNTIME_DIR:-/tmp}/record-gif-$ts.y4m"
out="$HOME/Videos/gif-$ts.gif"

# Downscale only if the selected region is wider than MAXW (slurp prints
# geometry as "X,Y WxH"). gifski upscales when given a larger --width, so we
# pass it only when it actually shrinks the output.
gif_width="${geom##* }"   # "WxH"
gif_width="${gif_width%x*}"
width_args=()
if [ "${gif_width:-0}" -gt "$MAXW" ] 2>/dev/null; then
    width_args=(--width "$MAXW")
fi

notify-send -t 2000 "GIF" "Recording… press the shortcut again to stop"

# Record at a constant frame rate into a gifski-compatible y4m container.
# -r forces CFR so the frame count matches FPS; this blocks until the second
# key press sends SIGINT (handled above).
wf-recorder -r "$FPS" --muxer=yuv4mpegpipe --codec=rawvideo -x yuv420p \
    -g "$geom" -f "$tmp" >/dev/null 2>&1

if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    notify-send -u critical "GIF" "Recording failed (no data captured)"
    exit 1
fi

# wf-recorder hardcodes a bogus "F90000:1" frame rate in the y4m header, which
# makes gifski treat the whole clip as a few milliseconds long and collapse it
# to a single (static) frame. Rewrite the header's frame-rate field to the real
# capture rate and stream it straight into gifski (no second temp file).
hdr="$(head -1 "$tmp")"
newhdr="${hdr/F90000:1/F$FPS:1}"
if { printf '%s\n' "$newhdr"; tail -c +"$(( ${#hdr} + 2 ))" "$tmp"; } \
        | gifski --fps "$FPS" -Q "$QUALITY" "${width_args[@]}" -o "$out" - >/dev/null 2>&1; then
    wl-copy --type image/gif < "$out"
    notify-send -t 4000 "GIF saved" "$out (copied to clipboard)"
else
    notify-send -u critical "GIF" "gifski conversion failed"
fi

rm -f "$tmp"
