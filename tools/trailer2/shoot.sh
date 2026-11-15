#!/usr/bin/env bash
# Records shots of the "Captains" trailer with Godot's Movie Maker (PNG frames at 30 fps and
# a WAV of the game's own sound), or probes one without drawing it.
#   tools/trailer2/shoot.sh <shot> [...]                 record these shots, four at a time
#   tools/trailer2/shoot.sh all                          record every shot in stage.gd
#   tools/trailer2/shoot.sh --probe <shot> [k=v;k=v] [seconds]   print what happens and when
#   SHAPE=tall tools/trailer2/shoot.sh <shot> [...]      record wide shots upright, for Shorts
# Output goes to $TRAILER_OUT/shots/<shot>/ (default /tmp/vaskaria-trailer2), or with
# SHAPE=tall to $TRAILER_OUT/tall/shots/<shot>/: 1080x1920, the camera keeping the soldiers
# the size they are in the wide shot. Needs Godot 4.7 as `godot`, and xvfb-run where there is
# no display.
set -euo pipefail
cd "$(dirname "$0")/../.."
export TRAILER_OUT="${TRAILER_OUT:-/tmp/vaskaria-trailer2}" TRAILER_TMP="${TRAILER_TMP:-/tmp}"
stage=tools/trailer2/stage.gd

if [ "${1:-}" = "--probe" ]; then
	shot="$2"; sets="${3:-}"; secs="${4:-40}"
	args=("--shot=$shot" --probe)
	[ -n "$sets" ] && args+=("--set=$sets")
	godot --headless --path . --fixed-fps 30 --quit-after $((secs * 30)) -s "$stage" -- "${args[@]}" 2>&1 | grep -E "^fight|ERROR|error" || true
	exit 0
fi

list="$(godot --headless --path . -s "$stage" -- --list 2>/dev/null | grep '^SHOT ' || true)"
[ "${1:-all}" = "all" ] && set -- $(echo "$list" | awk '{print $2}')
base="$TRAILER_OUT"
[ "${SHAPE:-}" = tall ] && base="$TRAILER_OUT/tall"
mkdir -p "$base/logs"

one() {
	local shot="$1" secs shape w h out extra=()
	read -r _ _ secs shape <<<"$(echo "$list" | awk -v s="$shot" '$2 == s')"
	[ -n "${secs:-}" ] || { echo "no such shot: $shot"; return 1; }
	if [ "${SHAPE:-}" = tall ] && [ "$shape" = wide ]; then shape=tall; extra=(--tall); fi
	if [ "$shape" = wide ]; then w=1920; h=1080; else w=1080; h=1920; fi
	out="$base/shots/$shot"
	mkdir -p "$out"; rm -f "$out"/*.png "$out"/*.wav
	local run=(godot --path . --write-movie "$out/f.png" --fixed-fps 30 --quit-after $((secs * 30)) -s "$stage" -- "--shot=$shot" "${extra[@]}")
	[ -n "${DISPLAY:-}" ] || run=(xvfb-run -a -s "-screen 0 2000x2000x24" "${run[@]}")
	# The window's size is read once, at start, from override.cfg: recordings take turns with it.
	(
		flock 9
		printf '[display]\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n' "$w" "$h" > override.cfg
		"${run[@]}" > "$base/logs/$shot.log" 2>&1 9>&- &
		pid=$!
		sleep 6
		rm -f override.cfg
		flock -u 9
		wait "$pid"
	) 9>"$TRAILER_TMP/trailer2-shoot.lock" && echo "shot $shot" || echo "FAILED $shot"
}
export -f one
export list stage base
printf '%s\n' "$@" | xargs -P "${JOBS:-4}" -I{} bash -c 'one {}'
