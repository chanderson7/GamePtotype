#!/bin/sh
# Fetches the recorded instruments tools/music.py plays its orchestral pieces with: a few
# folders of the VS Chamber Orchestra Community Edition (public domain, CC0), into
# tools/samples/vsco. Only needed to render the music again; the game ships the result.
set -e
cd "$(dirname "$0")"
mkdir -p samples
if [ ! -d samples/vsco/.git ]; then
	git clone --filter=blob:none --no-checkout --depth 1 https://github.com/sgossner/VSCO-2-CE samples/vsco
fi
cd samples/vsco
git sparse-checkout init --no-cone
cat > .git/info/sparse-checkout <<'LIST'
/LICENSE
/Brass/F Horn/sus/
/Brass/F Horn/stac/
/Brass/Trumpet/sus/
/Brass/Trumpet/stac/
/Brass/Tenor Trombone/sus/
/Strings/Violin Section/susVib/
/Strings/Violin Section/Trem/
/Strings/Violin Section/Spic/
/Strings/Viola Section/susvib/
/Strings/Cello Section/susvib/
/Strings/Cello Section/spic/
/Strings/Cello Section/trem/
/Strings/Harp/
/Woodwinds/Flute/susvib/
/Percussion/Glock/
/Percussion/Timpani/
/Percussion/BDrumNewhit*
/Percussion/Snare2-*
/Percussion/cymbal-crash1*
/Percussion/susCymb1-cresc*
/Percussion/gongHit*
/Percussion/Tamb1-Hit*
/VSCO 1 Percussion/drums/tenor/
/VSCO 1 Percussion/drums/bass/
/Percussion/Anvil*
/Percussion/BrakeDrum*
/Percussion/Claves*
/Percussion/LogDrum*
/Percussion/Ratchet*
/Percussion/gongscrape*
/Percussion/susCymb1-scrape*
/Percussion/susCymb1-hitstick*
/Percussion/cymbal-crashshort*
/VSCO 1 Percussion/varMetal/Cymbals/
/VSCO 1 Percussion/varMetal/Gong/gong_smack*
/VSCO 1 Percussion/varMetal/Gong/gong_scrape*
/VSCO 1 Percussion/varWood/log_drum/
/VSCO 1 Percussion/varWood/Camo's Shaker/
LIST
git -c gc.auto=0 checkout -q HEAD
echo "Samples ready in tools/samples/vsco"
