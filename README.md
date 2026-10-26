# Bannerfall

*Working title.* Real-time squad battles sized for a phone, inside a sandbox campaign in the spirit of Mount & Blade, set in an invented world. Built with **Godot 4.7** in GDScript, targeting iPhone first, with Steam and Android from the same project.

This slice is the start of a campaign: pick a people, ride the map of the Glass Sea, and fight the bandits on its roads in real-time battles, or send your men in without you. Your warband carries over between battles and has to be paid and fed: the men you lose stay lost until you pay to reinforce them in a town, bandit bounties and spoils keep the purse full, squads that kill can be trained, and renown lets you lead more squads.

## What's in it

### The campaign

- **The Glass Sea.** An invented inland sea shared by three realms: the **Kingdom of Vardmark** on the northwest shore (stone keeps and armored knights), the **Sultanate of Kharzan** across the southern deserts (walled cities and swift riders), and the **Ryumon Shogunate** on the islands beyond the eastern strait (disciplined archers and spearmen). Twenty-one settlements: in each realm a town, two castles and four villages, every village bound to a castle or town, joined by roads and three sea lanes. Who holds each place, and who is at war with whom, are the world's own and kept in your save, ready for the realms to fight over them.
- **Choose your people.** A new campaign starts with a choice of culture. Your captains take its names, your companies its words ("Brann's Pikes", "Tariq's Spears", "Hideo's Yari"), your troops its names (Footmen, Askari, Samurai), and you start at its capital. Cultures fight alike for now; their stats will differ later.
- **Ride the roads.** Tap a settlement to see it and ride there. Time passes only while you ride or wait, an hour a second (two at 2x), and stops the moment anything needs you. Sea lanes are slower than roads. Drag to look around, pinch or scroll to zoom, double-tap to find your party.
- **A living map.** A ragged coastline with beaches and surf breathing against it, turquoise shallows over a deep sea, hills shaded by the light, and each realm's own country: Vardmark's meadows, woods and grey peaks, Kharzan's sand, dunes, palms and red mesas, the Ryumon isles' pines, cherry blossom and snow-capped mountains, with fields, dry plots or paddies around every village. Three rivers run down to the sea: the Raven past Ravensford, the Qamar through the desert, and the Kumo on the isles, each forded where a road crosses it. Each culture builds its own towns, castles and villages: Vardish stone keeps under slate and red tile, Kharzani sandstone walls, domes and minarets, Ryumon castles of stacked black roofs on stone bases. Your rider trots along the road under your banner, kicking up dust; bandit bands march under ragged ones. The light follows the clock, gold at dawn and dusk and blue at night, when the settlements' lamps are lit, and cloud shadows drift across land and sea. A campaign starts at eight in the morning.
- **Lords on the map.** Each realm has its ruler and four lords, two of them holding its castles, riding the roads with warbands of five to nine squads under captains of their people, more of them trained as their renown grows. Each has a bearing that steers him (*Daring*, *Cautious*, *Honorable*, *Cruel*). They keep watch on their lands, drive off bandits caught raiding their villages, ride to defend a village the enemy is burning, raid the villages of realms they're at war with (a village left burning pays nothing and offers no recruits for a week), and go home to refill when their warbands are spent. Lords of realms at war who meet fight it out, settled as a fight you send your men into would be, and the loser regroups at his seat. A realm's treasury takes in what its places pay and pays its lords. Tap a lord to see who he is, how strong, and what he's about; zoom in to see their names. For now they leave your warband be.
- **Bandits.** Two bands roam the villages of each realm. When one blocks your road you can lead the fight, in a full battle against an army led by captains of that realm; send your men in without you, settled on the spot at the cost of a few more men; or withdraw to the last settlement you passed. Your scouts size up the fight first: who's stronger, and about how many men you'd lose sending them in. A beaten band is gone; another rises in its realm a day later. If they beat you, your survivors regroup at your capital half a day later, and the band keeps only the men it had left.
- **Silver, food and wages.** You start with 400 silver and five days of food. Every day costs each man a ration and his wages (more for archers, more again for horse, half again for each level of training). Men who go unpaid or hungry desert, about one in ten a day, fewer if you're only a little short, and the map tells you when it happens. The top bar shows your silver, how many days of food you have and your renown, in red when you're running short.
- **Spoils and renown.** Beating a band pays a bounty plus silver and food for every man cut down, and wins renown. You can lead six squads at first, and one more for every 60 renown, up to twelve.
- **Culture troop trees and training.** Training a squad to level 2 in any town presents a two-card choice between two distinct branches for that troop type and culture (e.g., Vardish Men-at-arms vs Sergeants, Knights vs Mounted Sergeants; Kharzani Javelin Askari vs Guard Askari, Horse Archers vs Faris Lancers; Ryumon Hatamoto vs Ronin, Naginata vs Yari Ashigaru). Level 3 strengthens the chosen branch. Six specialized mechanics: armor and piercing, pre-contact javelins, horse archer skirmishing and saddle-shooting, melee sweeps hitting secondary foes, and steady morale.
- **Varied encounter objectives.** Not every battle is an open field rout:
  - *Slay the Bandit Chief*: Led by a named chieftain at the head of a tier-2 bodyguard squad, which waits behind his line until the fight turns. Felling or routing the bodyguard drops the entire host's morale by 35. Break the guard while your men are on it and the chief goes down in the rout, with no one to drag him clear, and the death roll decides his fate: slain, for double bounty and +10 renown, or carried off by his men after all. A chief who gets away comes back five days later at the head of a new band.
  - *Ambush*: Caught on a wooded road, your warband is strung out in a column three abreast, unbraced, with the enemy coming at both ends and no time to form up. You cannot withdraw. Strike back at once, before they close in.
  - *Village Defense*: Arriving at a village being raided by bandits triggers a timed defense: the village lies behind your line, and you hold its square for 2 minutes while more raiders come at it in waves from east and west. If they hold the square two to one for 25 seconds in all, they fire the village and the fight is lost; a ring of flame round the square shows how near they are.
- **Battlefield terrain.** The ground comes from where the fight happens on the world map: hills in high country, woods where the map is wooded, and a river with its fords wherever the fight is near one of the map's rivers:
  - *Hills & Ridges*: Vantage grants archers up to +25% range. Blows struck down a slope land up to 40% harder, and up one as much softer; uphill charges yield no bonus.
  - *Woods & Forests*: Slows foot by 25% and horse by 50%. Treetops deflect 50% of incoming arrows, halve volley shock, and prevent charges; blows struck into the trees from outside land 20% softer. Each stand of trees is drawn on its own dark forest floor.
  - *River Fords*: Impassable deep water forces armies through shallow fords where troops are slowed, take 25% more damage, deal 20% less, and cannot brace.
  - *Rocky Passes*: Natural bottlenecks with rock formations that block movement while letting arrows arc over.
  - *Village Streets*: Buildings and walls channel combat into tight streets and defense perimeters.
- **Chosen ground.** A band met on hills or in woods has sometimes picked its ground first (three times in ten when it isn't raiding or ambushing): it waits for you on the brow of a ridge or at the edge of a wood, and your scouts tell you so. Attacking it there costs you; going round or drawing it off is up to you.
- **Settlements.** Enter any settlement to buy food (cheapest in villages) and hire the recruits looking for work: a full squad of fresh men of that place's own culture under a captain of their own, so a Vardish warband can field Ryumon archers. Villages raise foot and bows, castles spears and horse, towns anything; recruits taken come back three days later. In a town you can also refill your squads (fresh men water down a squad's experience) and train squads that have earned it to the next level, which makes their men tougher and deadlier and raises their wages. Wait for a few hours anywhere.
- **Saved as you go**, on the device (`user://campaign.json`): after every arrival, encounter and battle, and every few seconds on the road. Continue from the title screen.

### The battles

- **Four troop types with a counter loop.** Spearmen stop cavalry, cavalry ride down archers, archers shred infantry, infantry cut through spear lines.
- **Squads of live soldiers.** Twenty men to a squad (sixteen horse), three ranks deep. Each man fights on his own, keeps formation on the march, and breaks ranks when the lines meet. Cavalry hit hard on the charge, except into spears.
- **Battles that take their time.** Two even squads grind at each other for the best part of a minute, and a full battle runs a minute or two, so there's time to see a fight turning and send help.
- **Archers with a quiver.** Eight arrows a man: deadly against troops marching at them, but they run dry, and then they're poor fighters. Arrows aimed into a melee with your own men mostly go wide.
- **Morale and routing.** A squad that takes heavy losses breaks and runs for its own edge. Men who escape survive the battle.
- **Deploy your whole army.** Every squad in your warband is a card. Before the fight, place each one anywhere in your half of the field, with the enemy's line in plain view. Tap a placed squad to move it, or tap *Auto-place* for a battle line (swords and spears in front, bows behind, horse on the wings). Time stands still until you press *Fight*.
- **Two orders: Advance and Hold.** Squads hold their ground until ordered. *Advance* sends them at the enemy at marching pace, each going for the enemy it fights best, then charging when close. *Hold* stops them where they stand to fight whoever comes. The buttons command the whole army, or one squad once you select it (tap its card, its standard or its men); with a squad selected you can also tap an enemy squad to attack it (crossed swords and a pulsing ring mark every squad you've sent someone after, and the attackers stay on it until it breaks), or open ground to march there. Squads on the march go around enemy squads in their way instead of through them.
- **Draw a line.** Drag across the field and the whole army, or the squad you've picked, forms up along the line: each squad takes its own stretch in the order they already stand, so their paths don't cross, and faces away from the line toward the enemy. While you drag, the ground each squad will cover is outlined. A squad on its own widens or deepens its ranks to fill the line (never under two ranks). Before the battle, a line places the whole army at once.
- **Hold fire.** Archers can keep their arrows: they loose none, and draw blades if the enemy reaches them. A volley ends the hold.
- **Braced lines.** A squad that has stood its ground on *Hold* for two seconds is braced, and hits a third harder for the first six seconds of the fight that reaches it. Letting the enemy come is often the right call; *Advance* gives up the brace.
- **Flanks and rear.** A squad locked in one fight can't turn to meet a second enemy. Blows from beside or behind it land harder and shake its nerve, and horse that take spearmen from behind land their charge. Pin them with foot, then send in the horse.
- **One ability per squad.** Infantry raise a *Shield wall* (arrows and blows from the front barely land, but they move at half pace). Spearmen form a *Schiltron* (a ring of spears with no flank or rear, and no charge lands). Archers loose a *Volley* (every bow at once, harder, and it shakes the target's nerve). Cavalry *Wheel* (break off, ride clear, charge the same enemy again). Each has a cooldown.
- **Win by breaking their army.** The battle ends when one side has no squad left standing. After five minutes, the side with more of its army still fighting wins.
- **Enemy commanders with a temperament**, which your scouts report while you deploy. *Reckless* comes straight at you. *Patient* holds a braced line, takes your charge, then sends in the rest. *Hammer* pins you with foot and holds its horse until the lines meet, then rides for your archers and flanks. All of them use their squads' abilities, and all but the reckless use the ground: they shift their whole line onto the best footing in reach (the crest of a rise, the edge of a wood, the near bank of a ford), put their archers on the heights, and keep that ground for a while rather than wade a river or leave a ridge to come at you. A chief's bodyguard stands behind his line and rides out only to finish a fight or meet a threat.
- **A battle you can read on a phone.** The camera follows the fighting. Every squad carries a standard showing its type, morale and men, swallowtails for you and square flags for them; a squad's standard topples when it breaks. Select a squad and the enemy standards show which ones it beats and which beat it. A tray of squad cards along the bottom shows every squad's morale and whether its ability is ready. A strength bar replaces the clock. Pause any time (orders still work while paused), play at double speed, and the battle pauses itself if you leave the app.
- **Pixel-art troops, dressed by culture and by training.** Original top-down sprites for each type in both team colors, different for each people: Vardish footmen with kite shields and steel helms, kettle-hatted spearmen, hooded bowmen and horsemen in steel caps; Kharzani askari in white turbans with round shields and scimitars, spearmen, recurve bowmen and faris on grey horses; Ryumon samurai in black lacquer with crested helmets and sashimono banners at their backs, ashigaru under wide straw hats, long-bowed yumi archers and riders on dark horses. Each of the 24 trained branches wears its own kit, on the field and in its portrait: men-at-arms in plate with great helms, sergeants with maces and plumes, pikemen, halberdiers with poleaxes, crossbowmen with pavises on their backs, longbowmen, barded knights; javelin askari, gilded guard askari, spear guard in mail, shieldless levy spears, veiled desert archers, horse archers and faris lancers with pennons; hatamoto under horned crests, ronin with no banner, yari ashigaru and ashigaru archers under black lacquered hats, naginata, yumi samurai with a katana at the hip, mounted samurai with the horo billowing behind them, and mounted archers. The upgrade choice shows both. A squad you hire abroad wears its own culture's gear. Two walk frames and a strike pose each, a white flash when hit, shadows, fallen bodies, trampled and bloodied ground where they fell, and arrows that arc in flight and stick in the turf where they miss. Charges shake the screen and land with a jolt.
- **Fields by land.** A battle is fought on the ground of the realm it's in: Vardish meadow, Kharzani steppe with pebbles and scrub, Ryumon moss with fallen petals, with rocks, bushes and patches of lighter and darker ground.
- **Captains who can die.** Every squad is led by a named captain ("Brann's Shields"), a tougher man at the heart of the formation marked by a gold ring, with a temperament (Vengeful, Steadfast, Fragile) and sometimes a quirk (Lucky, Mentor, Bold). The squad holds its nerve better under them and reels when they go down.
- **The death roll.** A fallen captain rolls a d100 against a death chance of 45%, less 15 each if their own squad still has half its men, another squad is close enough to drag them clear, or they're Lucky. Over the chance: wounded, and they sit out the next two battles. At or under: dead. The battle all but stops while the die rolls on screen against the odds, with each modifier shown, then their fate and last words; the dead go on the memorial in camp while a veteran takes over the company.
- **Bonds.** Captains who fight side by side build a bond, rank C, B then A. Bonded pairs fighting near each other regain nerve and, from B, hit harder. When one falls, the other reacts by temperament: fury, a steadied line, or a squad that starts to break.
- **A persistent warband** with its bonds and the memorial of the fallen, on the Warband screen from the map.

### Sound and feel

- **Music for every place**, composed and synthesized for the game (`tools/music.py`): a horn theme over harp and strings on the title screen; on the map, the music of the realm you're riding through, crossfading as you cross a border: lute and recorder over a hurdy-gurdy drone in Vardmark, oud and ney over a frame drum's rhythm in Kharzan, koto and shakuhachi with taiko on the Ryumon isles. Battle music has two layers, war drums and a driving ostinato always, horns and snares swelling in as more of the field is fighting, and ends with a victory or defeat call.
- **Sounds**: a horn to start the battle, steel ringing faster the more squads are locked in melee, the rush of a volley, the snap and twang of crossbows, the whoosh of thrown javelins, horse archers loosing on the move, hooves thundering into a charge, a fanfare when a chief's guard breaks or he falls, the river running through a ford and birds in a wood under the battle music, the shout of a breaking squad, the rattle of the death roll's die and a bell when it lands on death; on the map, hoofbeats on the road, an alarm horn when bandits block it, coins when you buy or hire.
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
| `scripts/data/units.gd` | Culture unit upgrade trees (24 tier-2 branch options), mechanics (armor, piercing, javelins, horse archers, sweep, steady), stats and wages. |
| `scripts/data/terrain_rules.gd` | Movement and combat modifiers across height, woods, water, and obstacles. |
| `scripts/battle/terrain.gd` | Battlefield ground representations: elevations, forests, rivers, shallow fords, and rocks. |
| `scripts/battle/battle_site.gd` | Battlefield site generation based on world map location, biome, and encounter objective. |
| `scripts/battle/pathing.gd` | Grid A* formation pathfinding navigating around rocks, deep water, and across fords. |
| `scripts/battle/battle_sim.gd` | Battle rules as pure logic: deployment, orders, movement, combat, morale, objectives, reinforcements, win conditions. No drawing. |
| `scripts/battle/commander_ai.gd` | The computer's commanders: how each temperament lines up, when it commits, uses abilities, handles terrain, and reacts to objectives. |
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
| `scripts/data/lords.gd` | The lords: names and titles by people, bearings, warband sizes, treasuries and dues, and how far they ride for each job. **Tune the lords here.** |
| `scripts/data/economy.gd` | Prices, wages, food, desertion, spoils, renown and the squad cap. **Tune the campaign's pace here.** |
| `scripts/data/cultures.gd` | The three cultures: names, colors, captain name pools, and what each calls its troops. |
| `scripts/world/world_data.gd` | The map as data: factions, settlements, roads, sea lanes, rivers and their fords, coastlines (with their ragged shores) and bandit bands, and who holds what and who is at war when a campaign starts. |
| `scripts/world/world_sim.gd` | The world as pure logic: the clock, travel by road, who holds each settlement and which realms are at war, the lords and what they do, bandits, encounters, saving. No drawing. |
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

It checks the deployment rules (no placing in the enemy half, squads dropped on each other get nudged apart, Auto-place fits everyone, the clock waits for *Fight*), that *Hold* keeps a squad in place and *Advance* sends it forward, that archers run out of arrows, lines (squads share a drawn line in the order they stand, without overlaps, centered where it was drawn; they march there, hold and face the enemy; one squad alone widens or deepens to fill it; before the battle a line places everyone where the preview showed, and stays in your half), hold fire (archers keep every arrow and fight with blades; a volley ends the hold), the tactics (only a pinned squad can be flanked; horse in the rear of a pinned squad break it sooner and lose fewer riders; a braced line wins the even fight it receives; horse sent at archers ride around the spears in front of them), each ability, that each kind of enemy commander behaves as its scouts say, the cultures (each warband's captains and companies come from its own culture, and it starts at its capital), the world (every settlement reaches every other by road, settlements and roads lie on land and sea lanes cross water, travel takes exactly the time the map says, the clock stands still when you do, a band on the road stops you and the clock, a beaten band comes back a day later in its own realm, a saved world loads back exactly and carries on exactly as the original, a castle that changes hands takes its villages along and a realm that loses its capital rules from what it has left, owners and wars are saved, a save from before they could change still loads, sixty days of riding never puts more than two bands in one realm, and battle results reach the map), the economy (a day costs a day's wages and a ration a man; hungry or unpaid men desert in proportion to the shortfall; hiring brings a full squad of the offering place's culture, only where you stand and only under the squad cap, which renown raises; offers come back after three days; reinforcing costs silver and waters down experience; training raises level and wages; spoils and renown are paid; a band that beats you keeps only its survivors), auto-resolve (the side it reckons stronger wins the full battle at least 85% of the time over sixteen random battles, with about the same losses; every man is accounted for; men sent in without you lose more; captains can fall), six scripted 30-day campaigns that settle every fight unled (`Plans.campaign`: every warband lasts the month without dropping below 50 men, rarely deserts or goes broke, makes a name, and most grow), that each counter wins its duel at least 80% of the time, that mirror matches are close to even, that full AI-vs-AI battles finish with an army breaking and last about a minute, and that every man is accounted for in the battle result. It takes a few minutes and exits with code 1 if anything fails.

Add `-- --balance` to also fight three scripted players against every kind of commander, twelve battles each (`tests/plans.gd`): one who presses *Advance all* and nothing else, one who holds all battle, and a tactician who receives the charge braced, uses volleys and shield walls, and sends the horse into flanks. It checks that skill pays: *Advance all* wins about half the time at most, the tactician at least 70%. It also checks the Phase 3 gates: mirrored maps of every kind are fair both ways round; attacking a band that holds a ridge, a ford or a wood's edge with 15% more men wins at least 15 points less often than on open ground; each culture's trained army is a match for each other's; the tactician wins each objective at least 60% of the time, and clearly more often than *Advance all*; and neither branch of a role outclasses the other. It takes the best part of an hour.

## Roadmap

- [x] One battle that plays well on a phone
- [x] A world to ride: three cultures around the Glass Sea, travel, bandits on the roads
- [x] Reasons to ride: silver, food and wages, recruiting by culture, training, renown, auto-resolve
- [x] A first look and sound: troops dressed by culture, a living map, music and sound for every place
- [x] Phase 3: battlefield terrain, culture troop trees, objectives and encounter variety (`docs/phase-3-plan.md`)
- [ ] Phase 4, a living world: lords and armies on the map, war and peace, sieges that change who holds what, mercenary contracts, prisoners and ransom (`docs/phase-4-plan.md`)
- [ ] Captains and men: wounded men, captain skills and promotions, Casual mode (Phase 5)
- [ ] Land of your own and the crown: fiefs, vassalage, playable sieges, your own kingdom and alliances; a second art and sound pass, then Steam early access and the App Store (Phase 6 and launch)
