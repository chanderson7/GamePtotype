# Store

What the App Store needs from the game, kept with it. Godot ignores this folder (`.gdignore`), so none of it is imported or shipped in the app.

| Path | What it is |
| --- | --- |
| `app-store-listing.md` | The listing to paste into App Store Connect: name, subtitle, keywords, description, privacy and age-rating answers, notes for App Review. |
| `privacy-policy.html` | The privacy policy (the game collects nothing). Fill `SUPPORT_EMAIL`, then host it anywhere public and give App Store Connect its URL. |
| `screenshots/` | Eight 6.9-inch iPhone screenshots (1290 x 2796), in upload order. |

Make them again from the game itself (Godot 4.7, ffmpeg, and xvfb-run without a display):

- `tools/store/screenshots.sh [out]`: the screenshots, plus a contact sheet. Battles are fought afresh each run, so look the stills over and move a time in the script if a moment misses; then save them here as JPEG.
- `tools/store/preview.sh [out]`: the 25-second app preview, 886 x 1920 at 30 fps (not committed: about 56 MB).

The shots are defined in `tools/trailer/capture.gd` (`store_battle`, `store_river` and the trailer's own).
