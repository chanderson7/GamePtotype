#!/usr/bin/env bash
# Records one trailer shot with Godot's Movie Maker: PNG frames and a WAV of the game's sound.
#   tools/trailer/record.sh <shot> <seconds> [portrait|landscape]
# Needs `godot` (4.7) and, without a display, xvfb-run. Frames are 30 fps, 1080x1920
# portrait (the game's 720x1280 canvas drawn 1.5x) or 1920x1080 landscape (the battle
# shots, full frame); "store" is 1290x2796, the App Store's 6.9-inch iPhone screenshot
# (tools/store/screenshots.sh records those at FPS=5, for stills). An override.cfg sizes
# the window for the run only.
set -euo pipefail
cd "$(dirname "$0")/../.."
shot="$1"
seconds="${2:-10}"
shape="${3:-portrait}"
out="${TRAILER_OUT:-/tmp/bannerfall-trailer}/clips/$shot"
fps="${FPS:-30}"
mkdir -p "$out"
rm -f "$out"/*.png "$out"/*.wav
export TRAILER_TMP="${TRAILER_TMP:-/tmp}"
if [ "$shape" = landscape ]; then w=1920; h=1080; elif [ "$shape" = store ]; then w=1290; h=2796; else w=1080; h=1920; fi
frames=$((seconds * fps))
run=(godot --path . --write-movie "$out/f.png" --fixed-fps "$fps" --quit-after "$frames"
	-s tools/trailer/capture.gd -- "--shot=$shot")
if [ -z "${DISPLAY:-}" ]; then
	run=(xvfb-run -a -s "-screen 0 3000x3000x24" "${run[@]}")
fi
# The window size is read from override.cfg once, at start; recordings running side by side
# take turns writing it.
exec 9>"$TRAILER_TMP/trailer-record.lock"
flock 9
printf '[display]\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n' "$w" "$h" > override.cfg
"${run[@]}" &
pid=$!
sleep 6
rm -f override.cfg
flock -u 9
wait "$pid"
