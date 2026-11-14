#!/usr/bin/env bash
# Records every shot in shots.txt (or the ones named), three at a time.
#   tools/trailer/record_all.sh [shot ...]
set -euo pipefail
cd "$(dirname "$0")/../.."
export TRAILER_OUT="${TRAILER_OUT:-/tmp/bannerfall-trailer}" TRAILER_TMP="${TRAILER_TMP:-/tmp}"
mkdir -p "$TRAILER_OUT/logs"
grep -v '^#' tools/trailer/shots.txt | awk 'NF' | while read -r shot secs shape; do
	if [ $# -eq 0 ] || printf '%s\n' "$@" | grep -qx "$shot"; then echo "$shot $secs $shape"; fi
done | xargs -P "${JOBS:-3}" -L 1 sh -c 'tools/trailer/record.sh "$0" "$1" "$2" > "$TRAILER_OUT/logs/$0.log" 2>&1 && echo "recorded $0" || echo "FAILED $0"'
