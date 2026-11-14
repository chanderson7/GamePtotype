# Bannerfall: the YouTube marketing plan

- **Date:** 2026-11-14
- **Status:** proposed. Nothing here is published; the channel does not exist yet.
- **In one line:** announce with the trailer on the day there is somewhere to send people,
  then keep a steady run of vertical Shorts cut from the game's own portrait footage and a
  monthly long video, each one pointing at the store pages, with creators brought in once
  there is a build they can play.

## Three things to settle before anything is public

These come first because each one wastes the trailer if it is skipped.

1. **The name is taken.** There is a Steam page for another game called *Bannerfall*
   ([app 3198250](https://store.steampowered.com/app/3198250/Bannerfall/)): a single-player
   roguelike RTS about squads carrying banners, by Chris Popieluch, published by Duckloud
   Studio, release date to be announced. It has an X account under the same name. The two
   games sit in the same search results, and theirs has the store page first. On YouTube that
   means our trailer would compete with theirs for the exact title, and viewers who search
   the name after a Short would land on the wrong game. Whether they hold a trademark on it
   has not been checked; if they do, a rename could be forced after money has been spent on
   the name. The README already calls *Bannerfall* a working title.
   **Decide the name before the trailer goes public**: the wordmark, the end card and the
   thumbnail all carry it, and a renamed video loses the links people have shared. A rename
   is three files (`assets/branding/wordmark.png`, the splash, `project.godot`) and a
   re-render of the trailer.
2. **Somewhere to send people.** A view is only worth something if the viewer can do
   something with it. Before the trailer goes public there should be at least one of: a
   Steam page (wishlists), an App Store pre-order, a Google Play pre-registration, or, if
   the stores are months off, a one-page site with an email sign-up. The roadmap puts Steam
   early access and the App Store after the phone playtest, so the realistic first target is
   **a Steam "coming soon" page plus an email sign-up**, with the App Store pre-order added
   when the build is ready (Apple takes pre-orders from 180 days before release).
3. **A build people can play.** Creator coverage (the section below) needs a TestFlight
   build or Steam keys. Until the phone playtest in `docs/NEXT.md` has happened, plan for
   our own videos only.

## Who it is for, and what to say to them

| Audience | What they want to hear | Where they are on YouTube |
| --- | --- | --- |
| Mount & Blade, Battle Brothers and Total War players | A warband sandbox with real-time squad battles that plays on a phone: lords, sieges, fiefs, a crown | Bannerlord and Total War battle channels, strategy let's-plays |
| Premium mobile players | No ads, timers, energy or bought silver; one-time purchases only (if `docs/paid-features-plan.md` is adopted, also free to start and whole as the Vardish) | iOS and Android review channels, "best premium mobile games" lists |
| Players who like captains with names | Captains who can die on a d100, bonds, scars that stay on their faces, courtship and a wedding | Fire Emblem, tactics RPG and narrative strategy channels |
| Developers | Godot 4, every sprite and every note of music made by scripts in the repo | Godot and devlog channels |

**The pitch, in the order it should be said:** *Lead a warband. Real-time squad battles
sized for your hand, in a sandbox campaign across three realms. Your captains can die. No
ads, and nothing sold that wins a fight.*

The pricing lines rest on `docs/paid-features-plan.md`, which is still a proposal. Say
"free to start" only once that is decided, and only about the phone versions: the same plan
sells the Steam version as one paid game.

"Mount & Blade" is the comparison viewers will make themselves, and it is fair to say "in
the spirit of Mount & Blade" in a description or out loud. Keep it out of video titles and
thumbnails: it is someone else's trademark, and a title reading "Mount & Blade on mobile"
promises their game.

## The channel

- **Name and handle:** the game's final name. One channel for the game, not a studio
  channel, until there is a second game.
- **Banner and avatar:** the wordmark over the night ridge of the opening
  (`tools/render_splash.gd` renders it); the app icon as the avatar.
- **Channel trailer:** the announcement trailer, set for both new and returning viewers.
- **Links on the channel page:** Steam first, then App Store, Google Play, the sign-up page.
- **Playlists:** *Trailers*, *Battles* (uncut fights), *The three realms*, *Devlog*, *Shorts*.
- **Every description and every pinned comment** opens with the store links. Shorts hide
  their description on phones, so the link goes in a pinned comment there too.
- **Track where viewers come from:** give each video its own tagged link (Steam's UTM
  parameters, an App Store campaign link) so a wishlist can be traced to the video that
  earned it.

## What to publish

Four kinds of video. Each exists for a different job.

### 1. Trailers (the shop window)

| Video | Length | When | What it is |
| --- | --- | --- | --- |
| **Announcement trailer** | 1:20 | The day the first store page is live | The cut `tools/trailer/edit.py` makes: the Glass Sea, the warband, the lords, the wedding, then thirty seconds of battles. Built already. |
| **Battle trailer** | 0:30–0:45 | Two to four weeks later | Battles only, no cards before the first clash. For Steam's first trailer slot (which should be gameplay from the first second) and as the default link for creators. A second `EDL` in `edit.py` from the battle shots. |
| **A realm each** | 0:30 × 3 | Spread through the build-up | Vardmark, Kharzan, Ryumon: its country on the map, its lord's talk, its troops in a fight, its music (`vardish.ogg`, `kharzani.ogg`, `ryumon.ogg`). The Kharzani and Ryumon spots are also the adverts for the paid peoples. |
| **Launch trailer** | 1:00 | Launch day | The announcement cut again with the newest footage, review quotes if there are any, and "Out now" on the end card. |

### 2. Shorts (how strangers find it)

The game is drawn in portrait at 9:16, which is exactly a Short. `tools/trailer/record.sh
<shot> <seconds> portrait` records 1080×1920 with the game's HUD, so a Short is a recorded
shot, a line of text burned in at the top, and nothing reframed. That is rare for a
strategy game and it is the cheapest advantage this plan has.

Rules for every Short: the action starts in the first second; one idea; 15 to 35 seconds;
a caption a muted viewer can read; the title says what happens ("A cavalry charge into the
back of a spear line"), not what the game is called; it ends where it can loop.

A first batch of twelve, each from something the game already does:

| # | Short | The hook on screen | What to record |
| --- | --- | --- | --- |
| 1 | The death roll | "45% to die. Watch the die." | A captain falling and the d100 rolling against the odds, to FALLEN or wounded |
| 2 | Hammer and anvil | "Pin them with foot. Then send the horse." | Foot locks a spear company; cavalry lands on its rear |
| 3 | Don't charge spears | "This is why you don't charge spears." | Cavalry into a schiltron, and breaking |
| 4 | The shield wall | "A volley comes down. The shield wall walks on." | Infantry raise the wall under a volley and walk through it |
| 5 | Hold to slow time | "One thumb slows the battle. The other gives orders." | The hourglass held, a flag dragged onto an enemy flank |
| 6 | Draw the line | "Draw a line. The army forms on it." | A drag across the field and the companies taking their stretches |
| 7 | Out of arrows | "Eight arrows a man. Then what?" | Archers running dry and falling back behind the foot |
| 8 | A face that remembers | "Every scar on this captain happened." | One captain's portrait across a campaign: scars, grey, a cloak at twenty battles |
| 9 | The lord remembers | "This lord remembers what you did." | A lord's talk where an earlier deed comes back |
| 10 | The wedding | "A strategy game where you can marry into a great house." | The vows and the toast to the fallen |
| 11 | Three realms, three sounds | "The music changes when you cross the border." | A ride across a border with the realm's tune crossfading |
| 12 | The siege | "Ladders up. The gate is next." | The ram at the gate, men topping a ladder, the breach |

After the first twelve, the best-performing two decide what the next twelve are. Short
series work: *One order a week* (each ability), *A captain's life* (one captain from hire
to memorial).

### 3. Long videos (what turns a viewer into a wishlist)

One a month. People who watch eight minutes about a game are the ones who follow it.

- **"A full battle, explained"** (6–8 min). One uncut fight with the HUD on and a voice
  saying why each order was given. This is the video that answers "but what do you
  actually do?" and it is the one to link under every Short.
- **"The first hour"** (15–20 min). A campaign from the choice of people to the first
  contract, lightly cut.
- **Devlogs** (8–12 min each), each of which is already written down in `docs/`:
  - *Why my soldiers flickered, and how other games do melee* (`combat-simplification-plan.md`).
  - *Every soldier on the field in one draw* (the MultiMesh atlas; README, "Drawing a battle cheaply").
  - *An orchestra from a Python script* (`tools/orchestral.py`, the CC0 samples, a theme built up layer by layer).
  - *Every face in this game is generated* (`tools/portrait_faces.py`, scars and age).
  - *What this game will never sell you* (`paid-features-plan.md`). The honest-pricing video; premium mobile players share these.
- **"No commentary" battles** (3–5 min) for the *Battles* playlist: a dawn fight on the
  river, a night fight on the hills, a siege. Cheap to make, and they are what the
  strategy-battle audience searches for.

### 4. Other people's videos (reach we can't make ourselves)

Only once there is a build. See *Creators* below.

## The trailer's upload

Ready to paste once the name and the links are final.

- **Title:** `Bannerfall | Announcement Trailer | iPhone, Android & Steam`
  (the name first; under 60 characters so it is not cut off on a phone).
- **Thumbnail:** `bannerfall_thumbnail.jpg`, written by `edit.py`: the fight at the ford
  with the wordmark across the top. Upload a second one (a close shot of a cavalry charge,
  no wordmark, three words: "LEAD EVERY COMPANY") and let YouTube's *Test & compare* pick.
- **Description:**

  ```
  Raise a warband and lead every company yourself. Real-time squad battles sized for your
  hand, in a sandbox campaign across three realms of the Glass Sea.
  Wishlist on Steam: <link>   ·   App Store: <link>   ·   Google Play: <link>

  Three realms share one inland sea: the stone keeps of Vardmark, the desert courts of
  Kharzan, the island castles of the Ryumon Shogunate. Start with five companies and a
  purse of silver. Ride the roads, take contracts, win the lords' regard, marry into a
  great house, hold a fief, and raise a crown of your own.

  • Real-time battles: shield walls, schiltrons, volleys and cavalry charges, with every
    company yours to place and order. Hold a thumb to slow time.
  • Captains with names, faces and tempers. When one falls, a d100 decides if they live.
  • A living world: lords and armies on the map, wars and truces, sieges that change who
    holds what.
  • No ads, no timers, and nothing sold that wins a battle.

  Coming to iPhone, Android and Steam.

  0:00 The Glass Sea
  0:17 Your warband and the lords
  0:35 The battles
  1:05 Make your name

  Music: "The Glass Sea", composed for the game.
  ```

- **Tags:** the name, `strategy game`, `mobile strategy game`, `squad battles`,
  `real-time tactics`, `sandbox RPG`, `medieval strategy`, `iOS game`, `Android game`,
  `indie game trailer`, `Godot`. Tags matter little; the title, thumbnail and first two
  lines of the description do the work.
- **Settings:** category Gaming; game title set once YouTube lists the game; not made for
  kids; captions uploaded (the captions on screen, as an `.srt`, so the text is searchable
  and translatable); added to the *Trailers* playlist.
- **End screen** over the last ten seconds (the end card holds for eleven): a subscribe
  button and one video, *A full battle, explained* once it exists.
- **Pinned comment:** the store links again, and one question that is easy to answer
  ("Which realm would you start in?"). Answer every comment in the first two days.
- **Upload as Unlisted first**, watch it on a phone with the sound off and on, then
  schedule it as a **Premiere** for the announcement hour so the first viewers arrive
  together.
- **The file:** 1920×1080, 30 fps, H.264 with AAC at 48 kHz, loudness set to −14 LUFS, as
  `edit.py` writes it. Nothing to convert.

## When

Keyed to milestones, not dates, because the release date isn't set.

| Phase | Starts when | What goes out | Done when |
| --- | --- | --- | --- |
| **0. Groundwork** | Now | Nothing public. Settle the name; make the channel; record the first twelve Shorts and *A full battle, explained*; upload the trailer unlisted | A store page or sign-up page is ready to go live |
| **1. Announcement** | Store page live | Day 0: the trailer as a Premiere. Day 1–7: a Short a day from the first batch. Posts to the communities below, once each, on the day | A week has passed |
| **2. Build-up** | Week 2 | Two Shorts a week; one long video a month; the battle trailer in week 3; a realm spot every six weeks | A playable build exists |
| **3. Playable** | TestFlight or a Steam demo | *The first hour*; keys to creators; a Short for every creator video that lands | Four weeks before release |
| **4. Launch** | Release minus four weeks | Release-date Short; three Shorts a week; the launch trailer on the day; a pinned "out now" comment on every older video | Two weeks after release |
| **5. After** | Launch plus two weeks | One Short a week; a devlog for each update; a spot for each paid people when it ships | — |

Two Shorts a week and one long video a month is about a day of work a week once the first
batch is recorded. If that is more than the team has, drop the long videos to every six
weeks before dropping the Shorts.

**Where else the trailer goes on day 0** (once each, following each place's rules on
self-promotion): r/iosgaming, r/AndroidGaming, r/godot, r/indiegames, r/mountandblade
(read their rules first; a "made a phone game inspired by this" post is usually welcome, an
advert is not), the Godot Discord's showcase, and the Steam page itself.

## Creators

Start when there is a build to hand over; a trailer alone rarely earns a video.

- **Who:** small and middling channels (roughly 5,000 to 200,000 subscribers) that already
  cover one of the four audiences above. They answer, and their viewers are the right ones.
  Three lists to build, about fifteen channels each:
  1. Premium mobile reviewers (iOS and Android "games of the week" channels).
  2. Indie strategy first-looks and Mount & Blade / Total War battle channels.
  3. Godot and devlog channels, for the developer story.

  Names to start checking: SNAPP Attack and MiniReview for mobile; SplatterCatGaming,
  Nookrium and Wanderbots for indie first-looks; Pixelated Apollo for cinematic battles.
  These are from memory, not from research: confirm each is still active and still covers
  this kind of game before writing to them.
- **What to send:** four lines. What the game is in one sentence, why their viewers in
  particular would care (name one of their videos), a key or TestFlight link, and a link
  to a press folder (the trailer file, the battle trailer, ten screenshots, the wordmark,
  a fact sheet). No attachments, no embargo, no request for a positive word.
- **Paid coverage:** not at this stage. If it ever happens, the creator must mark it as a
  paid promotion in YouTube's own setting.
- **Adverts:** hold until launch. In launch week the battle trailer can run as an in-feed
  advert to viewers of strategy channels; before there is something to download, an advert
  buys views that can't do anything.

## Knowing whether it's working

Look once a week, in YouTube Studio and the store dashboards.

| Number | Where | What it tells us | If it's low |
| --- | --- | --- | --- |
| Impressions click-through rate | Studio › Reach | Whether the title and thumbnail earn the click. YouTube's own help page says half of all channels sit between 2% and 10% | Change the thumbnail first, then the title; use *Test & compare* |
| Audience retention at 0:30, and the shape of the curve | Studio › Engagement | Whether the trailer's first half holds. A cliff before the battles means the opening is too slow | Recut: battles earlier, or use the battle trailer as the channel trailer |
| Viewed versus swiped away (Shorts) | Studio › Engagement | Whether the first second works | Start the Short later in the action; put the hook line on frame one |
| Wishlists and sign-ups per 1,000 views, by video | Steam UTM report, App Store campaigns, the sign-up form | The only number that matters in the end | More of whatever kind of video scores highest; fewer of the rest |
| Returning viewers and subscribers | Studio › Audience | Whether there is an audience for the launch day Premiere | Series (*One order a week*) and replies to comments |

Subscriber count is not a goal. A hundred wishlists from a video with two thousand views
beats ten from one with fifty thousand.

A commonly quoted rule of thumb is that a game wants several thousand Steam wishlists
before launch to be shown by Steam itself. Treat it as a direction, not a target: the phone
stores are the first platform here, and they have no public equivalent.

## What not to do

- Don't publish before the name and a store link are settled.
- Don't show what isn't built. Every shot in the trailer is recorded from the game; keep
  it that way, and don't promise a date.
- Don't post the 16:9 trailer as a Short with bars. Cut a vertical one.
- Don't put "Mount & Blade" in a title or thumbnail.
- Don't buy views, subscribers or comments, and don't ask creators for anything but an
  honest look.
- Don't let a month pass in silence after the announcement. A dead channel reads as a dead
  game; if time is short, one Short a week keeps it alive.

## Making the footage

Everything above is cut from the game by the tools in `tools/trailer/` (see its README):
`record.sh` records a shot in portrait (for Shorts and framed screens) or landscape (for
battles and the map, HUD away), `capture.gd` sets up the campaign, hour, ground and camera
for each shot, and `edit.py` cuts the trailer to the theme and writes the thumbnail. A new
Short is a new entry in `SHOTS`; a new trailer is a new `EDL`.

## Sources

- The other *Bannerfall*: [Steam page](https://store.steampowered.com/app/3198250/Bannerfall/), [its X account](https://x.com/Bannerfallgame).
- App Store pre-orders (2 to 180 days before release): [App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/publish-for-pre-order).
- Trailer length and gameplay-first openings: [steampageanalyzer.com](https://www.steampageanalyzer.com/blog/steam-trailer-best-practices), [gameworldobserver.com](https://gameworldobserver.com/2022/09/22/common-game-trailer-mistkaes-indie-developers-steam), [bugnet.io](https://bugnet.io/blog/what-makes-a-game-trailer-convert). These are marketing blogs; their numbers are rules of thumb.
- Shorts for reach and long videos for wishlists: [strayspark.studio](https://www.strayspark.studio/blog/devlog-marketing-build-wishlists), [bugnet.io](https://bugnet.io/blog/youtube-shorts-for-indie-game-marketing). Also opinion, not measurement.
