# Bannerfall

*Working title.* Real-time squad battles sized for a phone, with a war map, expansion and diplomacy to come. Built with **Godot 4.7** in GDScript, targeting iPhone first, with Steam and Android from the same project.

This first slice is one playable field battle plus a camp screen. Your warband carries over between battles: the men you lose stay lost until you reinforce, and squads that kill earn levels.

## What's in it

- **Four troop types with a counter loop.** Spearmen stop cavalry, cavalry ride down archers, archers shred infantry, infantry cut through spear lines.
- **Squads of live soldiers.** Each man fights on his own, keeps formation on the march, and breaks ranks when the lines meet. Cavalry hit hard on the charge, except into braced spears.
- **Morale and routing.** A squad that takes heavy losses breaks and runs for its own edge. Men who escape survive the battle.
- **Deploy your whole army.** Every squad in your warband is a card. Before the fight, place each one anywhere in your half of the field, with the enemy's line in plain view. Tap a placed squad to move it, or tap *Auto-place* for a battle line (swords and spears in front, bows behind, horse on the wings). Time stands still until you press *Fight*.
- **Two orders: Advance and Hold.** Squads hold their ground until ordered. *Advance* sends them at the enemy at marching pace, each going for the enemy it fights best, then charging when close. *Hold* stops them where they stand to fight whoever comes. The buttons command the whole army, or one squad once you tap it; with a squad selected you can also tap an enemy squad to attack it, or open ground to march there.
- **Win by breaking their army.** The battle ends when one side has no squad left standing. After three minutes, the side with more of its army still fighting wins.
- **An enemy commander** that lines up, holds for a few seconds, then advances with everything, sooner if you come close.
- **A persistent warband** saved on the device (`user://warband.json`).

## Run it

1. Download **Godot 4.7** (the standard build, not .NET) from [godotengine.org](https://godotengine.org/download).
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press **Play** (F5). The window is phone-shaped; a mouse click works as a tap.

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
| `scenes/main_menu.tscn` | Camp screen: the warband, reinforcing, starting a battle. Becomes the war map later. |
| `scenes/battle.tscn` | The battle screen. |
| `scripts/data/troops.gd` | Troop stats, the counter bonuses and veterancy. **Tune the game here.** |
| `scripts/battle/battle_sim.gd` | Battle rules as pure logic: deployment, orders, movement, combat, morale, win conditions. No drawing. |
| `scripts/battle/commander_ai.gd` | How the computer lines up its army and when it advances. |
| `scripts/battle/battle_screen.gd` | Drawing, touch input and the HUD. Reads the sim; never changes the rules. |
| `scripts/game_state.gd` | The persistent warband (an autoload), battle results and the save file. |
| `scripts/ui/style.gd` | Shared colors and UI theme. |
| `tests/run_tests.gd` | Headless checks of the rules. |

The rules don't touch the screen, so the sim can be tested headless and reused when the war map auto-resolves small fights. Battles take and return plain data: an army goes in as `[{id, type, men, xp}]`, and `result_for()` hands back survivors and kills per squad.

## Tests

From the project folder:

```
godot --headless --script res://tests/run_tests.gd
```

On a Mac, `godot` is the binary inside the app: `/Applications/Godot.app/Contents/MacOS/Godot`.

To watch the computer fight both sides (useful when tuning), run the game with `-- --autoplay`.

It checks the deployment rules (no placing in the enemy half, squads dropped on each other get nudged apart, Auto-place fits everyone, the clock waits for *Fight*), that *Hold* keeps a squad in place and *Advance* sends it forward, that each counter wins its duel at least 80% of the time, that mirror matches are close to even, that full AI-vs-AI battles finish with an army breaking, and that every man is accounted for in the battle result. It also prints how a player who only ever presses *Advance all* or *Hold all* fares against the computer. It exits with code 1 if anything fails.

## Roadmap

- [x] One battle that plays well on a phone
- [ ] Persistent army depth: recruiting in towns, wounded, upgrades, a cost to reinforce
- [ ] War map: towns and castles, AI lords on the move, auto-resolve for minor fights
- [ ] Kingdoms and diplomacy: war, peace, alliances, tribute
- [ ] Sieges, an art and sound pass, then Steam early access and the App Store
