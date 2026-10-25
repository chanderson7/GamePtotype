# Bannerfall

*Working title.* Real-time squad battles sized for a phone, inside a sandbox campaign in the spirit of Mount & Blade, set in an invented world. Built with **Godot 4.7** in GDScript, targeting iPhone first, with Steam and Android from the same project.

This slice is the start of a campaign: pick a people, ride the map of the Glass Sea, and fight the bandits on its roads in real-time battles, or send your men in without you. Your warband carries over between battles and has to be paid and fed: the men you lose stay lost until you pay to reinforce them in a town, bandit bounties and spoils keep the purse full, squads that kill can be trained, and renown lets you lead more squads.

## What's in it

### The campaign

- **The Glass Sea.** An invented inland sea shared by three realms: the **Kingdom of Vardmark** on the northwest shore (stone keeps and armored knights), the **Sultanate of Kharzan** across the southern deserts (walled cities and swift riders), and the **Ryumon Shogunate** on the islands beyond the eastern strait (disciplined archers and spearmen). Twelve settlements, towns, castles and villages, joined by roads and three sea lanes.
- **Choose your people.** A new campaign starts with a choice of culture. Your captains take its names, your companies its words ("Brann's Pikes", "Tariq's Spears", "Hideo's Yari"), your troops its names (Men-at-arms, Askari, Samurai), and you start at its capital. Cultures fight alike for now; their stats will differ later.
- **Ride the roads.** Tap a settlement to see it and ride there. Time passes only while you ride or wait, an hour a second (two at 2x), and stops the moment anything needs you. Sea lanes are slower than roads. Drag to look around, pinch or scroll to zoom, double-tap to find your party.
- **A living map.** A ragged coastline with beaches and surf breathing against it, turquoise shallows over a deep sea, hills shaded by the light, and each realm's own country: Vardmark's meadows, woods and grey peaks, Kharzan's sand, dunes, palms and red mesas, the Ryumon isles' pines, cherry blossom and snow-capped mountains, with fields, dry plots or paddies around every village. Each culture builds its own towns, castles and villages: Vardish stone keeps under slate and red tile, Kharzani sandstone walls, domes and minarets, Ryumon castles of stacked black roofs on stone bases. Your rider trots along the road under your banner, kicking up dust; bandit bands march under ragged ones. The light follows the clock, gold at dawn and dusk and blue at night, when the settlements' lamps are lit, and cloud shadows drift across land and sea. A campaign starts at eight in the morning.
- **Bandits.** A band roams the villages of each realm. When one blocks your road you can lead the fight, in a full battle against an army led by captains of that realm; send your men in without you, settled on the spot at the cost of a few more men; or withdraw to the last settlement you passed. Your scouts size up the fight first: who's stronger, and about how many men you'd lose sending them in. A beaten band is gone; another rises in its realm a day later. If they beat you, your survivors regroup at your capital half a day later, and the band keeps only the men it had left.
- **Silver, food and wages.** You start with 400 silver and five days of food. Every day costs each man a ration and his wages (more for archers, more again for horse, half again for each level of training). Men who go unpaid or hungry desert, about one in ten a day, fewer if you're only a little short, and the map tells you when it happens. The top bar shows your silver, how many days of food you have and your renown, in red when you're running short.
- **Spoils and renown.** Beating a band pays a bounty plus silver and food for every man cut down, and wins renown. You can lead six squads at first, and one more for every 60 renown, up to twelve.
- **Settlements.** Enter any settlement to buy food (cheapest in villages) and hire the recruits looking for work: a full squad of fresh men of that place's own culture under a captain of their own, so a Vardish warband can field Ryumon archers. Villages raise foot and bows, castles spears and horse, towns anything; recruits taken come back three days later. In a town you can also refill your squads (fresh men water down a squad's experience) and train squads that have earned it to the next level, which makes their men tougher and deadlier and raises their wages. Wait for a few hours anywhere.
- **Saved as you go**, on the device (`user://campaign.json`): after every arrival, encounter and battle, and every few seconds on the road. Continue from the title screen.

### The battles

- **Four troop types with a counter loop.** Spearmen stop cavalry, cavalry ride down archers, archers shred infantry, infantry cut through spear lines.
- **Squads of live soldiers.** Twenty men to a squad (sixteen horse), three ranks deep. Each man fights on his own, keeps formation on the march, and breaks ranks when the lines meet. Cavalry hit hard on the charge, except into spears.
- **Battles that take their time.** Two even squads grind at each other for the best part of a minute, and a full battle runs a minute or two, so there's time to see a fight turning and send help.
- **Archers with a quiver.** Eight arrows a man: deadly against troops marching at them, but they run dry, and then they're poor fighters. Arrows aimed into a melee with your own men mostly go wide.
- **Morale and routing.** A squad that takes heavy losses breaks and runs for its own edge. Men who escape survive the battle.
- **Deploy your whole army.** Every squad in your warband is a card. Before the fight, place each one anywhere in your half of the field, with the enemy's line in plain view. Tap a placed squad to move it, or tap *Auto-place* for a battle line (swords and spears in front, bows behind, horse on the wings). Time stands still until you press *Fight*.
- **Two orders: Advance and Hold.** Squads hold their ground until ordered. *Advance* sends them at the enemy at marching pace, each going for the enemy it fights best, then charging when close. *Hold* stops them where they stand to fight whoever comes. The buttons command the whole army, or one squad once you select it (tap its card, its standard or its men); with a squad selected you can also tap an enemy squad to attack it, or open ground to march there. Squads on the march go around enemy squads in their way instead of through them.
- **Braced lines.** A squad that has stood its ground on *Hold* for two seconds is braced, and hits a third harder for the first six seconds of the fight that reaches it. Letting the enemy come is often the right call; *Advance* gives up the brace.
- **Flanks and rear.** A squad locked in one fight can't turn to meet a second enemy. Blows from beside or behind it land harder and shake its nerve, and horse that take spearmen from behind land their charge. Pin them with foot, then send in the horse.
- **One ability per squad.** Infantry raise a *Shield wall* (arrows and blows from the front barely land, but they move at half pace). Spearmen form a *Schiltron* (a ring of spears with no flank or rear, and no charge lands). Archers loose a *Volley* (every bow at once, harder, and it shakes the target's nerve). Cavalry *Wheel* (break off, ride clear, charge the same enemy again). Each has a cooldown.
- **Win by breaking their army.** The battle ends when one side has no squad left standing. After five minutes, the side with more of its army still fighting wins.
- **Enemy commanders with a temperament**, which your scouts report while you deploy. *Reckless* comes straight at you. *Patient* holds a braced line, takes your charge, then sends in the rest. *Hammer* pins you with foot and holds its horse until the lines meet, then rides for your archers and flanks. All of them use their squads' abilities.
- **A battle you can read on a phone.** The camera follows the fighting. Every squad carries a standard showing its type, morale and men, swallowtails for you and square flags for them; a squad's standard topples when it breaks. Select a squad and the enemy standards show which ones it beats and which beat it. A tray of squad cards along the bottom shows every squad's morale and whether its ability is ready. A strength bar replaces the clock. Pause any time (orders still work while paused), play at double speed, and the battle pauses itself if you leave the app.
- **Pixel-art troops, dressed by culture.** Original top-down sprites for each type in both team colors, different for each people: Vardish men-at-arms with kite shields and steel helms, kettle-hatted pikemen, crossbowmen and barded knights; Kharzani askari in white turbans with round shields and scimitars, spear guard, recurve bowmen and faris on grey horses; Ryumon samurai in black lacquer with crested helmets and sashimono banners at their backs, ashigaru under wide straw hats, long-bowed yumi archers and mounted samurai on dark horses. A squad you hire abroad wears its own culture's gear. Two walk frames and a strike pose each, a white flash when hit, shadows, fallen bodies, trampled and bloodied ground where they fell, and arrows that arc in flight and stick in the turf where they miss. Charges shake the screen and land with a jolt.
- **Fields by land.** A battle is fought on the ground of the realm it's in: Vardish meadow, Kharzani steppe with pebbles and scrub, Ryumon moss with fallen petals, with rocks, bushes and patches of lighter and darker ground.
- **Captains who can die.** Every squad is led by a named captain ("Brann's Shields"), a tougher man at the heart of the formation marked by a gold ring, with a temperament (Vengeful, Steadfast, Fragile) and sometimes a quirk (Lucky, Mentor, Bold). The squad holds its nerve better under them and reels when they go down.
- **The death roll.** A fallen captain rolls a d100 against a death chance of 45%, less 15 each if their own squad still has half its men, another squad is close enough to drag them clear, or they're Lucky. Over the chance: wounded, and they sit out the next two battles. At or under: dead. The battle all but stops while the die rolls on screen against the odds, with each modifier shown, then their fate and last words; the dead go on the memorial in camp while a veteran takes over the company.
- **Bonds.** Captains who fight side by side build a bond, rank C, B then A. Bonded pairs fighting near each other regain nerve and, from B, hit harder. When one falls, the other reacts by temperament: fury, a steadied line, or a squad that starts to break.
- **A persistent warband** with its bonds and the memorial of the fallen, on the Warband screen from the map.

### Sound and feel

- **Music for every place**, composed and synthesized for the game (`tools/music.py`): a horn theme over harp and strings on the title screen; on the map, the music of the realm you're riding through, crossfading as you cross a border: lute and recorder over a hurdy-gurdy drone in Vardmark, oud and ney over a frame drum's rhythm in Kharzan, koto and shakuhachi with taiko on the Ryumon isles. Battle music has two layers, war drums and a driving ostinato always, horns and snares swelling in as more of the field is fighting, and ends with a victory or defeat call.
- **Sounds**: a horn to start the battle, steel ringing faster the more squads are locked in melee, the rush of a volley, hooves thundering into a charge, the shout of a breaking squad, the rattle of the death roll's die and a bell when it lands on death; on the map, hoofbeats on the road, an alarm horn when bandits block it, coins when you buy or hire.
- **Feel**: screens fade into one another, every button clicks and gives under your finger, map sheets and the battle result ease into view, and the title screen drifts over the Glass Sea at dawn. Music and sound can each be switched off on the title and Warband screens; the choice is kept on the device.

## Run it

1. Download **Godot 4.7** (the standard build, not .NET) from [godotengine.org](https://godotengine.org/download).
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press **Play** (F5). The window is phone-shaped; a mouse click works as a tap. You start at the title screen: New campaign, then choose your people.

## Put it on your iPhone

You need a Mac with Xcode and an Apple ID (a free one works for your own phone).

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. **Project → Export → Add… → iOS.** Fill in **App Store Team ID** (your team ID from Xcode or developer.apple.com) and **Bundle Identifier** (for example `com.yourname.bannerfall`).
3. **Export Project** to a folder. Godot writes an Xcode project.
4. Open the `.xcodeproj` in Xcode, plug in your iPhone, pick it as the run destination, and press **Run**.

The project uses the Compatibility renderer, which also runs in the iOS Simulator. Godot's guide: [Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

## How it's built

| Path | What it does |
| --- | --- |
| `scenes/title.tscn` | The title screen: Continue or New campaign. The main scene. |
| `scenes/new_campaign.tscn` | Choose your people. |
| `scenes/world_map.tscn` | The map of the Glass Sea: travel, settlements, encounters. |
| `scenes/settlement.tscn` | A settlement: buy food, hire recruits, reinforce and train. |
| `scenes/main_menu.tscn` | The Warband screen: purse, squads, captains, bonds, the fallen, reinforcing. |
| `scenes/battle.tscn` | The battle screen. |
| `scripts/data/troops.gd` | Troop stats, the counter bonuses, abilities and veterancy. **Tune the game here.** |
| `scripts/battle/battle_sim.gd` | Battle rules as pure logic: deployment, orders, movement, combat, morale, win conditions. No drawing. |
| `scripts/battle/commander_ai.gd` | The computer's commanders: how each temperament lines up, when it commits, and how it uses abilities. |
| `scripts/battle/auto_resolve.gd` | Settles a fight without playing it, from each side's strength. Fitted to the battle sim; the tests check they still agree. |
| `scripts/battle/battle_screen.gd` | Drawing, touch input and the HUD. Reads the sim; never changes the rules. |
| `scripts/art/unit_art.gd` | Builds the sprite textures, unit portraits and battlefield ground at startup, by culture. |
| `scripts/art/sprite_data.gd` | The unit pixel art itself, as rows of palette letters. Generated: don't edit by hand. |
| `tools/unit_sprites.py` | Where the unit pixel art is drawn, culture by culture, with the battlefield's rocks and bushes. Edit this, then run `python3 tools/unit_sprites.py preview/` to regenerate `sprite_data.gd` and a preview sheet. |
| `scripts/art/map_art.gd`, `scripts/art/map_sprite_data.gd` | The same for the map: settlements by culture and type, terrain, and parties. |
| `tools/map_sprites.py` | Where the map's pixel art is drawn. `python3 tools/map_sprites.py preview/`. |
| `shaders/` | The map's sea, land and sky (the hour's light and cloud shadows). |
| `tools/music.py` | Composes and synthesizes all the music and sound effects with numpy, and encodes them to Ogg Vorbis with ffmpeg into `assets/audio/`. `python3 tools/music.py` renders everything, or name one piece or `sfx`. |
| `scripts/audio/sound.gd` | Music and sound (an autoload): crossfades, the battle's two layers, an effects pool, button clicks, and the music and sound switches. |
| `scripts/ui/scenes.gd` | Changes screens with a quick fade (an autoload). |
| `scripts/data/captains.gd` | Captain traits, the death roll and bond ranks. Tune the odds here. |
| `scripts/data/economy.gd` | Prices, wages, food, desertion, spoils, renown and the squad cap. **Tune the campaign's pace here.** |
| `scripts/data/cultures.gd` | The three cultures: names, colors, captain name pools, and what each calls its troops. |
| `scripts/world/world_data.gd` | The map as data: factions, settlements, roads, sea lanes, coastlines (with their ragged shores) and bandit bands. |
| `scripts/world/world_sim.gd` | The world as pure logic: the clock, travel by road, bandits, encounters, saving. No drawing. |
| `scripts/world/map_screen.gd` | Draws the map's settlements, parties, light and names, and turns taps into travel. Reads the world sim; never changes the rules. |
| `scripts/world/map_backdrop.gd` | The sea and the land under the map and the title screen. |
| `scripts/world/map_terrain.gd` | Works out the map's look once: the land picture its shaders read, and where woods, peaks, dunes and fields stand. |
| `scripts/world/settlement_screen.gd` | The settlement screen. Shows prices and passes taps to the campaign; never changes the rules. |
| `scripts/ui/heraldry.gd` | Flags and troop glyphs, shared by the battle's standards and the map's pennants. |
| `scripts/game_state.gd` | The campaign (an autoload): your culture, the warband, its purse, food and renown, hiring and training, daily upkeep, battle results and the save file. |
| `scripts/ui/style.gd` | Shared colors and UI theme. |
| `tests/run_tests.gd` | Headless checks of the rules. |
| `tests/plans.gd` | Scripted players for the balance check, and a scripted campaign for the economy check. |

The rules don't touch the screen, in battles and on the map alike, so both sims can be tested headless. Battles take and return plain data: an army goes in as `[{id, type, men, xp, level}]`, and `result_for()` hands back survivors and kills per squad. Auto-resolve returns the same shape, so a fight you send your men into lands on the warband exactly like one you led.

## Tests

From the project folder:

```
godot --headless --script res://tests/run_tests.gd
```

On a Mac, `godot` is the binary inside the app: `/Applications/Godot.app/Contents/MacOS/Godot`.

To smoke-test the whole loop, run the game with `-- --autoplay`: it starts a Vardish campaign, rides at the nearest bandits, lets the computer fight both sides of the battle, returns to the map, sends the men in against the next band, then enters the next settlement it reaches, buys food, hires and reinforces, and quits.

It checks the deployment rules (no placing in the enemy half, squads dropped on each other get nudged apart, Auto-place fits everyone, the clock waits for *Fight*), that *Hold* keeps a squad in place and *Advance* sends it forward, that archers run out of arrows, the tactics (only a pinned squad can be flanked; horse in the rear of a pinned squad break it sooner and lose fewer riders; a braced line wins the even fight it receives; horse sent at archers ride around the spears in front of them), each ability, that each kind of enemy commander behaves as its scouts say, the cultures (each warband's captains and companies come from its own culture, and it starts at its capital), the world (every settlement reaches every other by road, settlements and roads lie on land and sea lanes cross water, travel takes exactly the time the map says, the clock stands still when you do, a band on the road stops you and the clock, a beaten band comes back a day later in its own realm, a saved world loads back exactly and carries on exactly as the original, sixty days of riding never puts two bands in one realm, and battle results reach the map), the economy (a day costs a day's wages and a ration a man; hungry or unpaid men desert in proportion to the shortfall; hiring brings a full squad of the offering place's culture, only where you stand and only under the squad cap, which renown raises; offers come back after three days; reinforcing costs silver and waters down experience; training raises level and wages; spoils and renown are paid; a band that beats you keeps only its survivors), auto-resolve (the side it reckons stronger wins the full battle at least 85% of the time over sixteen random battles, with about the same losses; every man is accounted for; men sent in without you lose more; captains can fall), six scripted 30-day campaigns that settle every fight unled (`Plans.campaign`: every warband lasts the month without dropping below 50 men, rarely deserts or goes broke, makes a name, and most grow), that each counter wins its duel at least 80% of the time, that mirror matches are close to even, that full AI-vs-AI battles finish with an army breaking and last about a minute, and that every man is accounted for in the battle result. It takes a few minutes and exits with code 1 if anything fails.

Add `-- --balance` to also fight three scripted players against every kind of commander, twelve battles each (`tests/plans.gd`): one who presses *Advance all* and nothing else, one who holds all battle, and a tactician who receives the charge braced, uses volleys and shield walls, and sends the horse into flanks. It checks that skill pays: *Advance all* wins about half the time at most, the tactician at least 70% (it takes about five minutes more).

## Roadmap

- [x] One battle that plays well on a phone
- [x] A world to ride: three cultures around the Glass Sea, travel, bandits on the roads
- [x] Reasons to ride: silver, food and wages, recruiting by culture, training, renown, auto-resolve
- [x] A first look and sound: troops dressed by culture, a living map, music and sound for every place
- [ ] War map: AI lords on the move, towns and castles that change hands
- [ ] Kingdoms and diplomacy: war, peace, alliances, tribute
- [ ] Sieges, a second art and sound pass, then Steam early access and the App Store
