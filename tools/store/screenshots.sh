#!/usr/bin/env bash
# App Store screenshots: 1290x2796, the 6.9-inch iPhone size, taken from the game itself
# (the shots in tools/trailer/capture.gd). Each shot is recorded with Movie Maker at 10
# fps (the battle screen steps at most 0.1 s a frame, so it fights at its own pace) into an
# MJPEG .avi, and the frame at the given second is kept as a PNG.
#   tools/store/screenshots.sh [out_dir]          (default /tmp/bannerfall-store)
# Needs godot (4.7), ffmpeg and, without a display, xvfb-run. Battles are fought afresh
# each run, so look over the stills (contact.png) and move a time if a moment misses.
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${1:-/tmp/bannerfall-store}"
mkdir -p "$out/clips"
export TRAILER_TMP="${TRAILER_TMP:-$out}"
fps=10
# name : shot : seconds recorded : second kept
SHOTS=(
	"01_battle:store_battle:14:7"
	"02_river:store_river:16:10"
	"03_map:map_ride:8:6"
	"04_lords:talk_ravensford:10:8"
	"05_town:town_highcliff:7:5.5"
	"06_victory:battle_result:100:96"
	"07_wedding:wedding:12:10"
	"08_home:home:6:5"
)
xvfb=()
if [ -z "${DISPLAY:-}" ]; then
	xvfb=(xvfb-run -a -s "-screen 0 3000x3000x24")
fi
for entry in "${SHOTS[@]}"; do
	IFS=: read -r name shot seconds keep <<< "$entry"
	printf '[display]\nwindow/size/window_width_override=1290\nwindow/size/window_height_override=2796\n[editor]\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
	"${xvfb[@]}" godot --path . --write-movie "$out/clips/$shot.avi" --fixed-fps "$fps" \
		--quit-after $((seconds * fps)) -s tools/trailer/capture.gd -- "--shot=$shot" > "$out/clips/$shot.log" 2>&1 || true
	rm -f override.cfg
	ffmpeg -v error -y -ss "$keep" -i "$out/clips/$shot.avi" -frames:v 1 "$out/$name.png"
	echo "$name: $shot at ${keep}s"
done
python3 - "$out" <<'PY'
import glob, os, sys
from PIL import Image
out = sys.argv[1]
files = sorted(glob.glob(os.path.join(out, "0*.png")))
thumbs = [Image.open(f).resize((258, 559)) for f in files]
sheet = Image.new("RGB", (258 * len(thumbs), 559))
for i, t in enumerate(thumbs):
	sheet.paste(t, (i * 258, 0))
sheet.save(os.path.join(out, "contact.png"))
PY
