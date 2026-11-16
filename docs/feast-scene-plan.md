# The feast as an event: plan

Today a feast is a card on the settlement's Feast tab: chips, a line of text, four buttons
(Toast, Gift, Gossip, Dance) and a list of names. Nothing looks like a feast, and nothing
happens when you press a button except a line of text changing. This plan turns it into a
place you walk into: a full-screen hall with the guests in it, light and music, things you do
with the people there, and small moments that only happen at a feast.

The rules stay as they are. Every number (renown, Regard, silver, hours) still comes from
`GameState` and `scripts/data/gatherings.gd`; this is a new way in and a new way to show it.

Mockup (made from the game's own art; not the finished look): `docs/mockups/feast_scene_mock.png`.

## Status: built

Packages 1 to 7 are in: `scripts/ui/hall_life.gd`, `scenes/feast.tscn` + `scripts/menu/feast.gd`,
`scripts/data/hall_moments.gd`, the hall's GameState functions (`feast_*`, `hall_moment*`), the
town's *Enter the hall* card, and `tests/feast_scene_tests.gd`. Where it differs from the plan below:

- **Guests** are each lord's own portrait without its backdrop, seated behind two tables (the
  host's high table at the back, a near table in front), half the guests at each. On a tall
  phone the hall gets more floor and the near guests sit larger.
- **The arm-wrestle** is an even chance (there's no Might stat); a loss still earns +1 Regard.
- **"Too much wine"** became *Another round*: stand the hall a round for 20 silver, +1 Regard
  with every lord.
- **Sleeping** to the next dusk runs the world clock like waiting on the map; if something on the
  road needs you (brigands at the gate), the hall sends you to the map.
- **Not done:** the map's prompt when you arrive at a town with a feast on (the town's Feast tab
  is gold and leads in), and a raised-cup pose (guests laugh instead).

## What's wrong now

1. **No place.** The feast is the same dark panel as the market. `HallScene` already draws a
   hall for each culture (stone hall, arched courtyard, screened room), but only the dance uses it.
2. **No people.** The lords at the feast are a list of names under IN THE HALL. You can't see
   who is there, who is the host, or who wants a word.
3. **No event.** Pressing Toast changes a line of text. No cups go up, no faces react, nothing
   is heard. Three nights pass with nothing to mark them.
4. **No arrival or end.** You don't walk in, and you don't leave; the feast is just there on a tab.

## What other games do

- **Crusader Kings III** (feasts): an event chain. You arrive, things happen to guests one after
  another, each with a choice, and you leave with a summary of what changed.
- **Persona / Fire Emblem** (social hubs): a room with people standing in it. Tap one, talk,
  come back to the room. Marks over heads show who has something new.
- **Mount & Blade** (feasts): mostly what we have now. It is the part players say is dull.
- **Stardew Valley** (festivals): the town transformed for one day, music changed, everyone
  in one place, one special thing to do.

What we take: a room you see, people in it you can tap, marks for who wants you, an arrival,
a few small events with choices, and a summary at the end of each night.

## The design

### Arrival (once per feast)

A 3-second moment when you first enter while a feast is on:

1. The hall fades up from black; the culture's music starts (`assets/audio/music/feast_<culture>.ogg`).
2. A herald line across the bottom: *"Captain Aldric of the Thornwall company, sworn to …"*
   (your name, company, title or realm). The guests' faces turn (a one-frame "look" pose).
3. If you are **uninvited**, the herald instead says *"You were not asked here."* and you get one
   choice at the door: *Walk in anyway* (current uninvited rules) or *Leave*.

Tap skips. Shown once per feast (`g["arrived"] = true` on the player's record of it).

### The hall (the main screen)

Full screen, phone-shaped (portrait). From top to bottom:

- **Head chips**: *Night 1 of 3*, guest count, *Invited / Uninvited / Your own*. Rules `?` for your own.
- **The hall**: `HallScene` for the host's culture, night, filling the top ~60% of the screen.
- **The guests in it**: each lord as a seated bust (portrait art from `CaptainArt` / `CourtUI.face`,
  without the card frame) at a seat for that culture. The host sits highest and largest, centre.
  Each blinks and breathes (`PortraitLife`). Up to `MAX_GUESTS` (8).
- **Marks over heads**:
  - gold *"a word?"* where a lord has an unspent First Word (`first_word(l) > 0`);
  - *"· · ·"* between two lords when gossip is to be had (`gossip_check(g).ok`);
  - a heart for a romance match who is here (existing romance data);
  - a red mark for an enemy of yours.
- **Title and a line** under the hall: the feast's name and one line of the room
  (`Gatherings.HALL[culture]`, plus a different line each night).
- **Actions bar**: big buttons (min `Style.TOUCH`), the same checks as today:
  Toast, Gift, Listen (was Gossip), Dance (lit on the last night). For your own feast:
  Speech, King's Gifts, Dance. Each shows its cost or gain, or why not.
- **Leave the feast** (primary) and *Rest until tomorrow's dusk*.

**Tapping a guest** opens the existing hall talk (`LordConversation.open(self, gs, id, "hall")`)
over the scene; closing it returns to the hall with the guest's mark updated.

### The life of the hall (effects)

A new `scripts/ui/hall_life.gd`, built the same way as `scripts/ui/camp_life.gd` (a Control drawn
over the art in its own pixels; `HallLife.over(art, culture)`), one set per culture:

| Culture | Effects |
| --- | --- |
| Vardish (stone hall) | hearth flames and embers (as camp fire), torch flicker on the wall sconces, warm light breathing, a dog crossing the floor now and then |
| Kharzani (courtyard) | lanterns swaying slightly on their chains (x 30/90/150/210), brazier flames and sparks at (120, 92), a thin curl of incense smoke, stars over the arches |
| Ryumon (screens) | paper lanterns glowing, candle flames on the low tables, petals drifting across, a moon behind the screens |

All: a slow warm "breath" of light; dimmer on night 3 (*the candles are low*). Reduced motion:
steady glow only (as CampLife).

### The actions, shown not told

Each action keeps its `GameState` call; what changes is what you see:

- **Toast** (`raise_toast`): your cup rises at the bottom; the guests' busts tilt up (raised-cup
  pose); a float *"+2 Regard"* rises from each face that counted; horn. (A toast *needs*
  120 renown; it doesn't give any. The old card's "+120" was misleading.)
- **Gift** (`bring_gift`): a chest (or sack of food) slides to the host; the host's face changes
  to pleased; *"+5 Regard"* over the host, *"Kharzan +2"* under the title; coins.
- **Listen** (`hear_gossip`): the two lords marked *"· · ·"* lean together; a speech card rises
  with what you heard (same text as now) and a *"1 hour passes"* tick.
- **Dance** (`dance_check`): unchanged, goes to `scenes/dance.tscn` with
  `Scenes.dance_return = "res://scenes/feast.tscn"`.
- **Speech / King's Gifts** (your own feast): you stand at the high seat; the hall's guests react
  as with Toast; existing `CrownCourt` calls.

### Hall moments (the event part)

Once per night, after your first action of that night, a small moment may happen (chance 60%,
never the same one twice in a feast). A card over the hall with a picture line and 2 choices.
Each uses existing stats only. Starting set:

| Moment | Choices and results |
| --- | --- |
| **The bard sings** a song of a battle you won (or lost) | *Stand and be cheered*: +renown (small). *Wave it off*: +1 Regard with the host (modest) |
| **A challenge**: a lord offers to arm-wrestle | *Accept*: roll on your Might; win +Regard with him and +renown, lose −renown (small). *Decline politely*: nothing |
| **An insult** from a lord who dislikes you | *Answer in kind*: −Regard with him, +renown. *Let it pass*: +1 Regard with the host |
| **The host asks for news** of the road | *Tell of your deeds*: +Regard with the host. *Tell of an enemy's moves*: −Regard of that realm's lords present, +Regard with the host |
| **A quiet word**: a lord takes you aside | opens his hall talk with a first-word bonus |
| **Too much wine** | *Keep up*: +Regard with all present, next morning a slow start (−2 h). *Water it*: nothing |

Moments live in a new `scripts/data/hall_moments.gd` (id, text per culture, choices, a pure
`resolve(gs, g, choice)` that calls existing GameState changes). Numbers are small, kept with the
other gathering numbers in `gatherings.gd`.

### End of a night

When you press *Rest until tomorrow's dusk* (or the clock passes dawn while in the hall):

- A summary card: *Night 1 of 3 · Sultan Rustam's feast*; the faces whose Regard moved with
  `+n`/`−n` under each; renown gained; silver spent; anything learned.
- Then the hall again at the next dusk (night 2), or, after night 3, *The feast is over* and back
  to the settlement.

### The way in

- On the Feast tab, the card becomes a single large *Enter the hall* card: the hall picture,
  the host's face, *Night 1 of 3*, *Invited*, and one button. The actions move into the scene.
- On the map, arriving at a town where a feast you are invited to is on: a toast offer
  *"Sultan Rustam's feast is on. Enter the hall?"*.

## Packages (for implementation)

Each is one commit with its tests. Do them in order.

1. **HallLife** — `scripts/ui/hall_life.gd` modelled on `camp_life.gd`; anchors per culture
   measured on `HallScene.image(culture, realm, "night", 3)` (240x150). Add it over the hall in
   `dance.gd` too. *Check:* render all three at 540x1170 under xvfb; flames move between frames
   (pixel diff > 0); reduced motion draws only glow.
2. **Feast scene shell** — `scenes/feast.tscn` + `scripts/menu/feast.gd`; `Scenes.feast_return`.
   Hall backdrop + HallLife, head chips, title/line, actions bar wired to the existing calls, Leave.
   Settlement Feast tab: *Enter the hall* card. *Check:* each action has the same result as from
   the old card (same GameState values after).
3. **Guests** — seat anchors per culture (const table in `feast.gd`), busts from portrait art,
   host larger and centred, `PortraitLife` blink, marks (first word, gossip, romance, enemy),
   tap → `LordConversation.open(…, "hall")` and back. *Check:* 1 to 8 guests all placed on
   screen without overlap at 540x1170 and 720x1280; every bust is ≥ `Style.TOUCH` tall.
4. **Arrival** — fade, music, herald line, uninvited door choice, `arrived` flag saved.
   *Check:* shown once; skipping works; uninvited *Leave* returns with nothing changed.
5. **Shown actions** — toast/gift/listen animations and floating numbers, sounds. *Check:*
   floats show the same numbers the GameState call returned.
6. **Hall moments** — `hall_moments.gd`, one per night at most, no repeats, saved.
   *Check:* each moment's every choice applies its stated change and nothing else.
7. **Night end** — summary card, rest to next dusk, end of feast. *Check:* Regard deltas in the
   card equal the real changes over that night.

## Tests

New `tests/feast_scene_tests.gd`, added to `run_tests.gd`:

- the scene builds for each culture, as guest, as uninvited, and as host;
- every action button calls the same GameState function as before and is disabled with the same
  reason when not allowed;
- guests: count on screen = `gathering_lords(g).size()` (capped at `MAX_GUESTS`), host is the
  largest;
- arrival shows once per feast and survives save/load;
- moments: none twice, at most one per night, each choice's effects;
- night summary deltas match;
- reduced motion: HallLife does not process.

Existing gathering tests must still pass unchanged (rules have not moved).

## Not in this plan

Tourneys (their own scene), new portrait art for raised cups (use a 2-pixel lift of the bust
until there is art), voice.
