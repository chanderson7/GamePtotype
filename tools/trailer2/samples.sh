#!/bin/sh
# Fetches the recorded instruments score.py plays: folders of the VS Chamber Orchestra
# Community Edition (public domain, CC0), into tools/samples/vsco (not committed). It adds
# to whatever tools/fetch_samples.sh already put there. About 1.9 GB. Only needed to render
# the trailer's score again.
set -e
cd "$(dirname "$0")/.."
mkdir -p samples
if [ ! -d samples/vsco/.git ]; then
	git clone --filter=blob:none --no-checkout --depth 1 https://github.com/sgossner/VSCO-2-CE samples/vsco
fi
cd samples/vsco
git sparse-checkout init --no-cone
want="$(mktemp)"
cat > "$want" <<'LIST'
/LICENSE
/Brass/F Horn/sus/
/Brass/F Horn/stac/
/Brass/Trumpet/sus/
/Brass/Trumpet/stac/
/Brass/Tenor Trombone/sus/
/Brass/Tenor Trombone/stac/
/Brass/Tuba/sus/
/Brass/Tuba/stac/
/Strings/Violin Section/susVib/
/Strings/Violin Section/Trem/
/Strings/Violin Section/Spic/
/Strings/Viola Section/susvib/
/Strings/Viola Section/spic/
/Strings/Viola Section/trem/
/Strings/Cello Section/susvib/
/Strings/Cello Section/spic/
/Strings/Cello Section/trem/
/Strings/Solo Contrabass/SusVib/
/Strings/Solo Contrabass/Spic/
/Strings/Harp/
/Woodwinds/Flute/susvib/
/Percussion/Timpani/
/Percussion/BDrumNewhit*
/Percussion/Snare2-*
/Percussion/cymbal-crash1*
/Percussion/susCymb1-cresc*
/Percussion/gongHit*
/Percussion/TB_hit*
/Percussion/Anvil*
/VSCO 1 Percussion/drums/tenor/
/VSCO 1 Percussion/drums/bass/
/VSCO 1 Percussion/varMetal/Gong/
LIST
touch .git/info/sparse-checkout
sort -u "$want" .git/info/sparse-checkout > "$want.all"
cp "$want.all" .git/info/sparse-checkout
rm -f "$want" "$want.all"
git -c gc.auto=0 checkout -q HEAD
echo "Samples ready in tools/samples/vsco"
