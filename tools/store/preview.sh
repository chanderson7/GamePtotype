#!/usr/bin/env bash
# The App Store app preview: 25 s, 886x1920 portrait (the 6.9-inch iPhone's), 30 fps,
# H.264 with AAC stereo, cut from the game itself (the shots in tools/trailer/capture.gd),
# each with its own sound. Recorded with Movie Maker into MJPEG .avi clips, then cut.
#   tools/store/preview.sh [out_dir]          (default /tmp/bannerfall-store)
# Needs godot (4.7), ffmpeg and, without a display, xvfb-run. Battles are fought afresh
# each run: look the cut over and move a start if a moment misses.
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${1:-/tmp/bannerfall-store}"
mkdir -p "$out/preview"
export TRAILER_TMP="${TRAILER_TMP:-$out}"
fps=30
# shot : seconds recorded : start of the cut : its length
CUTS=(
	"store_battle:12:3:8"
	"store_river:12:6:5"
	"map_ride:7:2:4"
	"talk_ravensford:9:4:4"
	"battle_result:100:91:4"
)
xvfb=()
if [ -z "${DISPLAY:-}" ]; then
	xvfb=(xvfb-run -a -s "-screen 0 1200x2200x24")
fi
parts=()
i=0
for entry in "${CUTS[@]}"; do
	IFS=: read -r shot seconds start length <<< "$entry"
	clip="$out/preview/$shot.avi"
	if [ ! -f "$clip" ]; then
		printf '[display]\nwindow/size/window_width_override=886\nwindow/size/window_height_override=1920\n[editor]\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
		"${xvfb[@]}" godot --path . --write-movie "$clip" --fixed-fps "$fps" \
			--quit-after $((seconds * fps)) -s tools/trailer/capture.gd -- "--shot=$shot" > "$out/preview/$shot.log" 2>&1 || true
		rm -f override.cfg
	fi
	part="$out/preview/part_$i.mp4"
	# Each cut fades its sound in and out over a quarter second, so the cuts don't click.
	ffmpeg -v error -y -ss "$start" -t "$length" -i "$clip" \
		-vf "scale=886:1920,fps=$fps,format=yuv420p" \
		-af "aresample=48000,afade=t=in:d=0.25,afade=t=out:st=$(echo "$length - 0.25" | bc):d=0.25" \
		-c:v libx264 -preset slow -crf 16 -c:a aac -b:a 256k -ac 2 "$part"
	parts+=("$part")
	i=$((i + 1))
done
list="$out/preview/parts.txt"
: > "$list"
for p in "${parts[@]}"; do echo "file '$p'" >> "$list"; done
ffmpeg -v error -y -f concat -safe 0 -i "$list" -c:v libx264 -preset slow -crf 16 -profile:v high -level 4.2 \
	-pix_fmt yuv420p -r "$fps" -c:a aac -b:a 256k -ar 48000 -ac 2 -movflags +faststart "$out/app_preview.mp4"
echo "$out/app_preview.mp4"
