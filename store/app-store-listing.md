# App Store listing (draft)

Everything App Store Connect asks for that the game itself can answer, ready to paste. Placeholders
in CAPITALS are yours to fill. Field limits are App Store Connect's; the counts are checked.

## App information

| Field | Value |
| --- | --- |
| Name (30) | Bannerfall (the working title: change it here and in `project.godot` before the first upload; the bundle ID stays) |
| Subtitle (30) | Squad battles on the Glass Sea (30) |
| Bundle ID | `com.anderson-sites.bannerfall` (the iOS preset) |
| Primary category | Games › Strategy |
| Secondary category | Games › Role Playing |
| Content rights | No third-party content beyond what the game is licensed to use (see Settings › Credits & licences) |
| Privacy policy URL | Where you host `store/privacy-policy.html` (fill `SUPPORT_EMAIL` first) |
| Support URL | SUPPORT_URL (a page with a contact address is enough) |
| Copyright | 2026 DEVELOPER_NAME |
| Price | Your choice. Selling upfront needs no code; in-app purchases need a StoreKit plugin (`docs/paid-features-plan.md`). |

## Version page

**Promotional text** (170; can change without a new build), 147:

> Lead a warband across the Glass Sea. Command real-time squad battles with one thumb, keep your captains alive, and carve out a kingdom of your own.

**Keywords** (100, commas, no spaces), 100:

> medieval,tactics,strategy,warband,rpg,sandbox,siege,kingdom,knights,army,squad,commander,offline,war

The name and subtitle are indexed already, so their words ("Bannerfall", "battles", "Glass Sea") stay out of the keywords. App Store Review doesn't allow other games' names in metadata, so there is no comparison to other titles here.

**Description** (4,000):

> Raise a warband and lead it in battle, on a phone, with one thumb.
>
> Bannerfall is a medieval sandbox around the Glass Sea. Pick one of three peoples (the Vardish of the northern keeps, the Kharzani of the desert cities, the Ryumon of the isles), hire your first companies, and ride out. Where you go, whom you serve and whom you fight is up to you.
>
> REAL-TIME SQUAD BATTLES
> Command your companies on a field you can read at a glance. Shield walls, braced spears, volleys, flank charges: tap a company to order it, drag a line to re-form the army, and hold your thumb on the edge of the field to slow time while you think. Ground matters. Hills, woods, fords and narrow passes change who wins.
>
> CAPTAINS WORTH KEEPING
> Every company has a captain with a name, a face and a story. They level up, take wounds, grow close to one another around the campfire, and in Mortal mode they can fall for good. Casual mode turns death into a long recovery.
>
> A WORLD THAT MOVES WITHOUT YOU
> Lords ride to war, besiege castles and change sides. Take contracts as a mercenary, swear fealty for a fief, or raise your own banner and take the crown. Win battles to earn renown, silver and the trust of the people you meet.
>
> FRIENDSHIP AND ROMANCE
> Court, befriend or ignore the people you meet. Share stories at the fire, dance at feasts, and if it comes to it, marry and found a house. Romance invitations can be turned off in Settings.
>
> MADE FOR IPHONE
> Plays in portrait, one-handed. No account, no ads, no internet needed. Your campaign saves as you go, and a battle interrupted by a call picks up where you left it.

**What's New** (later versions only).

## Screenshots and preview

- Screenshots, 6.9-inch iPhone (1290 x 2796): `store/screenshots/01_battle.jpg` to `08_home.jpg`, in that order. App Store Connect scales them for smaller iPhones. Remake them with `tools/store/screenshots.sh`.
- App preview, 6.9-inch (886 x 1920, 25 s, 30 fps, H.264 and AAC): made by `tools/store/preview.sh` (not committed: 56 MB). Choose its poster frame in App Store Connect; a battle frame reads best.

## App privacy

Choose **Data Not Collected**. The game has no networking, accounts, analytics, ads or tracking. The iOS export's privacy manifest already says so (`export_presets.cfg`, `privacy/collected_data/*` all off, no tracking domains); its "required reason" API entries are Godot's own (file timestamps, system boot time, disk space).

## Export compliance

Already answered in the build: `ITSAppUsesNonExemptEncryption` is false in the Info.plist (the iOS preset's additional plist content), so an upload doesn't ask. The game uses no encryption.

## Age rating

Apple works the rating out from your answers. What's in the game, for each question (match to the questionnaire's current wording):

| Question | Answer | Why |
| --- | --- | --- |
| Cartoon or fantasy violence | Frequent/Intense | Battles are the game: small pixel-art soldiers fight and fall, with a little red on the ground. |
| Realistic violence | None | Nothing realistic; no gore. |
| Prolonged graphic or sadistic violence | None | |
| Profanity or crude humour | Infrequent/Mild | A wounded captain's "Damn it, my leg!"; nothing stronger. |
| Mature or suggestive themes | Infrequent/Mild | Courtship and marriage (nothing sexual), grief for fallen captains, war. |
| Horror or fear themes | None | |
| Alcohol, tobacco or drug use or references | Infrequent/Mild | Toasts with ale, wine, mead and sake at feasts and weddings; no drunkenness. |
| Simulated gambling | None | The die on screen when a captain falls is a roll for their fate, not a wager. |
| Sexual content or nudity | None | |
| Medical or treatment information | None | |
| Contests, user-generated content, messaging, web access, advertising | None | The game is single-player and offline. |

Expect 12+ under the older ratings, which is 13+ under the current ones.

## Notes for App Review

> Bannerfall is a single-player game that works entirely offline. There is no sign-in, no purchase and no account. To reach a battle quickly: on Home, tap "Begin as the Vardish", then "Lead the Vardish", then "Skip tutorial"; on the map, ride at a bandit band near your town and, when it stops you, choose Fight. In the battle, tap Auto-place, then Fight. Settings › Credits & licences lists the engine's and the fonts' licences.
