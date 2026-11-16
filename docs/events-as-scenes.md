# Events as scenes, not text

What happens to the player used to reach them as lines in the map's notice box, joined into
one block under "At X" with a Carry on button. Now it's shown with the game's own art.

## Event cards (`scripts/ui/event_cards.gd`)

Every `GameState._note(text, card)` keeps its words in `map_notice` (for the tests and the
toast) and records a card in `map_cards`: what kind of event it is and what to draw it with.
Back on the map, `EventCards.split()` sorts them:

- **Dealt as cards** (full screen, one at a time, Next / Skip all / Carry on): anything
  with art. Big news first and larger, with a stamped title, a sound and a buzz.
- **The ledger** (the notice sheet, a line each with its icon): taxes, building, squads
  stationed, contracts accepted, refunds, new bonds.
- **Not repeated**: a card marked `told` (a chief slain or a village saved, already on the
  battle's result card).

| Kind | Art |
| --- | --- |
| `taken`, `walls_held`, `place_lost`, `fief_lost`, `fief_freed` | the place (SettlementVista); with `was`, its old banner drops and the new one rises over it |
| `fief_burned`, `raid` | the place burning: embers and firelight, a red wash |
| `siege` | the place besieged; a night's events gathered as rows on one card |
| `fealty`, `grant`, `contract` | the place, and the lord or king's face over it |
| `lord_said`, `ransom` | the lord in their own hall (HallScene), close up |
| `captain_fallen`, `captain_wounded` | a memorial at the camp fire: the face, eyes shut, battles and foes |
| `war`, `peace_broken` | two banners slam together, a flash, the war horn |
| `peace`, `alliance` | the banners come together in a warm glow |
| `crown_raised`, `crown_fallen`, `crown_risk`, `renounce`, `deserted` | the banner rising, or falling |
| `deed` | the company's banner in turning rays of light |

Card keys: `kind, title, big, tone (good/bad/gold), place, owner, was, cond, face,
face_name, mood, captain, banners, tiles [[icon, amount, suffix]], reactions [[name,
regard]], rows, body, aside, told`. Helpers in GameState: `_place_art`, `_lord_art`,
`_spoils_tiles`, `_card_merge`, `_note_siege`.

## Battle results say what the fight was for

`GameState.battle_stakes(result)` reads the objective (chief, village, siege, raid) and
the battle screen adds a **Stakes** panel under the picture: the village painted saved or
burning, the city under its new banner, the chief's double bounty or escape.

## One crown (`scenes/victory.tscn`)

Holding all three capitals sets `victory_pending` (saved). The map hands over to the
victory scene once: the three capitals turn to the crown's banner one by one, then One
Crown with the victory music, the chronicle (days, battles, renown, holdings, lords sworn,
the fallen), the captains who rode to the end and the fallen remembered. Ride on returns
to the map.

## The lists (`scenes/lists.tscn`)

Ride the lists now opens the tourney itself: a grandstand with a crowd that jumps when
lances break, the tilt, two knights in their colours. Your captains' bouts are a timing
joust over three passes: tap as the lances meet (dead on shatters and may unhorse). A
better captain gets a wider strike zone. "Let it ride" leaves a bout to the dice; other
bouts run past at speed. The rules are CrownCourt's (`lists_field`, `lists_bout`,
`lists_finish`; `ride_tourney` still rides it all at once).

## Tests

`tests/event_cards_tests.gd`: cards kept and split, a castle taken dealt with its banner
change, siege nights gathered, fief burned and lost, the fallen captain's memorial, the
ledger sheet, battle stakes, the lists ridden (a strike dead on shatters), victory once.
