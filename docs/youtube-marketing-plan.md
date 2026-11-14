# Bannerfall: the YouTube marketing plan

- **Date:** 2026-11-14
- **Status:** proposed. Nothing here is published; the channel does not exist yet.
- **Platform:** iPhone only. Every link in this plan leads to the App Store or to TestFlight.
- **In one line:** announce with the trailer on the day there is somewhere to send people,
  then keep a steady run of vertical Shorts cut from the game's own portrait footage and a
  monthly long video, each one pointing at the App Store page, with creators brought in
  once there is a TestFlight build they can play.

## Three things to settle before anything is public

These come first because each one wastes the trailer if it is skipped.

1. **The name is shared.** Another game called *Bannerfall* has a page on Steam
   ([app 3198250](https://store.steampowered.com/app/3198250/Bannerfall/)): a single-player
   roguelike RTS about squads carrying banners, by Chris Popieluch, published by Duckloud
   Studio, release date to be announced, with an X account under the same name. It is a PC
   game and this one is for iPhone, so the two are not in the same shop. They are in the
   same search results, though: on YouTube our trailer would sit beside theirs under the
   exact title, in a neighbouring genre, and a viewer who searches the name after a Short
   may land on the wrong game. Whether they hold a trademark on the name has not been
   checked; if they do, a rename could be forced after the name has been spent on. The
   README already calls *Bannerfall* a working title. **Decide the name before the trailer
   goes public**: the wordmark, the end card and the thumbnail all carry it, and a renamed
   video loses the links people have shared. Two checks to make either way: that the name
   is free on the App Store (app names there must be unique; creating the app's record in
   App Store Connect reserves it), and a trademark search. A rename is three files
   (`assets/branding/wordmark.png`, the splash, `project.godot`) and a re-render of the
   trailer.
2. **Somewhere to send people.** A view is only worth something if the viewer can do
   something with it. On iPhone there are three places, in the order they become possible:
   - **An email sign-up page** (a one-page site). Possible today.
   - **A TestFlight public link.** Up to 10,000 testers can join from a link once Apple
     has reviewed the first beta build. "Play the beta" is a stronger ask than "sign up".
   - **An App Store pre-order.** Apple takes pre-orders from 180 days before release, on a
     build that has passed App Review. From then on this is the only link that matters:
     a pre-order downloads itself on release day.

   The trailer should go public with at least the first of these, and ideally the second.
3. **A build people can play.** Creator coverage (below) needs a TestFlight build. Until
   the phone playtest in `docs/NEXT.md` has happened, plan for our own videos only.

## Who it is for, and what to say to them

| Audience | What they want to hear | Where they are on YouTube |
| --- | --- | --- |
| Premium iPhone players | A whole game with no ads, timers, energy or bought silver; one-time purchases only (if `docs/paid-features-plan.md` is adopted, also free to start and whole as the Vardish); plays in portrait, in one hand | iOS games-of-the-week and "best premium iPhone games" channels |
| Mount & Blade, Battle Brothers and Total War players who also own an iPhone | A warband sandbox with real-time squad battles that was built for a phone, not ported to one: lords, sieges, fiefs, a crown | "Games like Mount & Blade on mobile" lists; strategy channels |
| Players who like captains with names | Captains who can die on a d100, bonds, scars that stay on their faces, courtship and a wedding | Tactics RPG and narrative strategy channels |
| Developers | Godot 4 on iOS, every sprite and every note of music made by scripts in the repo | Godot and devlog channels |

**The pitch, in the order it should be said:** *Lead a warband on your iPhone. Real-time
squad battles sized for your hand, in a sandbox campaign across three realms. Your captains
can die. No ads, and nothing sold that wins a fight.*

Being only on iPhone is part of the pitch, not a limit to apologise for: "made for a
phone" is what the strategy audience has learned not to expect. Show the game in a hand at
least once in every long video.

The pricing lines rest on `docs/paid-features-plan.md`, which is still a proposal. Say
"free to start" only once that is decided.

"Mount & Blade" is the comparison viewers will make themselves, and it is fair to say "in
the spirit of Mount & Blade" in a description or out loud. Keep it out of video titles and
thumbnails: it is someone else's trademark, and a title reading "Mount & Blade on iPhone"
promises their game.

## The channel

- **Name and handle:** the game's final name. One channel for the game, not a studio
  channel, until there is a second game.
- **Banner and avatar:** the wordmark over the night ridge of the opening
  (`tools/render_splash.gd` renders it); the app icon as the avatar.
- **Channel trailer:** the announcement trailer, set for both new and returning viewers.
- **Link on the channel page:** one, whichever of the three destinations is current.
- **Playlists:** *Trailers*, *Battles* (uncut fights), *The three realms*, *Devlog*, *Shorts*.
- **Every description and every pinned comment** opens with that link. Shorts hide their
  description on phones, so the link goes in a pinned comment there too.
- **Track where viewers come from:** give each video its own App Store campaign link (the
  `ct` campaign token; App Analytics in App Store Connect then reports page views and
  pre-orders per campaign), so a pre-order can be traced to the video that earned it.

## What to publish

Four kinds of video. Each exists for a different job.

### 1. Trailers (the shop window)

| Video | Length | When | What it is |
| --- | --- | --- | --- |
| **Announcement trailer** | 1:10 | The day the first destination is live | *Captains* (`tools/trailer2/`): it opens on a charge in slow motion, tells the one thing the game does that others don't (every captain has a name, and any of them can fall: the die lands on Rowan of Thornwall), then the name, the battles, the world and victory, to a score written for it. Built already. |
| **A tour of the game** | 1:20 | A fortnight later, or not at all | The first cut (`tools/trailer/edit.py`): the Glass Sea, the warband, the lords, the wedding, then thirty seconds of battles, to the game's main theme. Slower and fuller: a second video for viewers who want to see more, not the one to lead with. |
| **Battle trailer** | 0:30 | Two to four weeks later | Battles only, in portrait with the HUD, no cards before the first clash. One recording serves three places: a Short, the default link for creators, and the first **App Store app preview** (Apple allows up to three, 15 to 30 seconds each, of footage from the app itself, at its own preview sizes). |
| **A realm each** | 0:30 × 3 | Spread through the build-up | Vardmark, Kharzan, Ryumon: its country on the map, its lord's talk, its troops in a fight, its music (`vardish.ogg`, `kharzani.ogg`, `ryumon.ogg`). The Kharzani and Ryumon spots are also the adverts for the paid peoples. |
| **Launch trailer** | 1:00 | Launch day | The announcement cut again with the newest footage, review quotes if there are any, and "Out now on the App Store" on the end card. |

### 2. Shorts (how strangers find it)

The game is drawn in portrait at 9:16, which is exactly a Short, and Shorts are watched on
the device the game is played on: a viewer is one tap from the App Store.
`tools/trailer/record.sh <shot> <seconds> portrait` records 1080×1920 with the game's HUD,
so a Short is a recorded shot, a line of text burned in at the top, and nothing reframed.
That is rare for a strategy game and it is the cheapest advantage this plan has.

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

### 3. Long videos (what turns a viewer into a pre-order)

One a month. People who watch eight minutes about a game are the ones who follow it.
Title these for what iPhone players type into the search box ("iPhone strategy game",
"premium iOS game", "no ads") as well as for what happens in them.

- **"A full battle, explained"** (6–8 min). One uncut fight with the HUD on and a voice
  saying why each order was given. This is the video that answers "but what do you
  actually do?" and it is the one to link under every Short.
- **"The first hour"** (15–20 min). A campaign from the choice of people to the first
  contract, lightly cut, recorded on a phone.
- **Devlogs** (8–12 min each), each of which is already written down in `docs/`:
  - *Why my soldiers flickered, and how other games do melee* (`combat-simplification-plan.md`).
  - *Every soldier on the field in one draw* (the MultiMesh atlas; README, "Drawing a battle cheaply").
  - *An orchestra from a Python script* (`tools/orchestral.py`, the CC0 samples, a theme built up layer by layer).
  - *Every face in this game is generated* (`tools/portrait_faces.py`, scars and age).
  - *What this game will never sell you* (`paid-features-plan.md`). The honest-pricing video; premium iPhone players share these.
- **"No commentary" battles** (3–5 min) for the *Battles* playlist: a dawn fight on the
  river, a night fight on the hills, a siege. Cheap to make, and they are what the
  strategy-battle audience searches for.

### 4. Other people's videos (reach we can't make ourselves)

Only once there is a build. See *Creators* below.

## The trailer's upload

Ready to paste once the name and the link are final.

- **Title:** `Bannerfall | Announcement Trailer | iPhone`
  (the name first; short enough not to be cut off on a phone).
- **Thumbnail:** `bannerfall_captains_thumbnail.jpg`, written by `cut.py`: the die landed
  on a captain, in a phone, with "Every captain can fall" and the name. Upload the first
  cut's thumbnail too (`bannerfall_thumbnail.jpg`: the fight at the ford under the
  wordmark) and let YouTube's *Test & compare* pick between them.
- **Description:**

  ```
  Every company has a captain. Every captain has a name. Any of them can fall. Lead them
  anyway: real-time squad battles sized for your hand, in a sandbox campaign across three
  realms of the Glass Sea. Coming to iPhone.
  Pre-order on the App Store: <link>

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

  0:00 The captains
  0:26 The battles
  0:42 The Glass Sea
  0:58 Victory

  Music: "Who Carries the Banner", composed for this trailer.
  ```

  Until the pre-order exists, the second line is the TestFlight link ("Play the beta") or
  the sign-up page.
- **Tags:** the name, `iPhone game`, `iOS game`, `iOS strategy game`, `premium mobile
  game`, `squad battles`, `real-time tactics`, `sandbox RPG`, `medieval strategy`,
  `indie game trailer`, `Godot`. Tags matter little; the title, thumbnail and first two
  lines of the description do the work.
- **Settings:** category Gaming; game title set once YouTube lists the game; not made for
  kids; captions uploaded (`bannerfall_captains.srt`, written by `cut.py`, so the words on
  screen are searchable and translatable); added to the *Trailers* playlist.
- **End screen** over the last ten seconds (the end card holds for ten): a subscribe
  button and one video, *A full battle, explained* once it exists.
- **Pinned comment:** the link again, and one question that is easy to answer
  ("Which realm would you start in?"). Answer every comment in the first two days.
- **Upload as Unlisted first**, watch it on a phone with the sound off and on, then
  schedule it as a **Premiere** for the announcement hour so the first viewers arrive
  together.
- **The file:** `bannerfall_captains.mp4`: 1920×1080, 30 fps, H.264 with AAC at 48 kHz,
  loudness set to −14 LUFS, as `cut.py` writes it. Nothing to convert.
- **Listen first.** The score was balanced by measurement (pitch, timing, loudness, the
  level of each section), not by ear. Play it on a phone speaker and on headphones before
  it is public; `tools/trailer2/README.md` says where each part of the music is.

## When

Keyed to milestones, not dates, because the release date isn't set.

| Phase | Starts when | What goes out | Done when |
| --- | --- | --- | --- |
| **0. Groundwork** | Now | Nothing public. Settle the name and reserve it in App Store Connect; make the channel and the sign-up page; record the first twelve Shorts and *A full battle, explained*; upload the trailer unlisted | The sign-up page (or TestFlight link) is ready to go live |
| **1. Announcement** | A destination is live | Day 0: the trailer as a Premiere. Day 1–7: a Short a day from the first batch. Posts to the communities below, once each, on the day | A week has passed |
| **2. Build-up** | Week 2 | Two Shorts a week; one long video a month; the battle trailer in week 3; a realm spot every six weeks | The public TestFlight is open |
| **3. Playable** | TestFlight public link | *The first hour*; the link to creators; a Short for every creator video that lands; every description now says "Play the beta" | The pre-order is live |
| **4. Pre-order to launch** | App Store pre-order live (up to 180 days ahead; four to eight weeks is plenty) | Release-date Short; three Shorts a week; every link on the channel switched to the pre-order; the launch trailer on the day; a pinned "out now" comment on every older video | Two weeks after release |
| **5. After** | Launch plus two weeks | One Short a week; a devlog for each update; a spot for each paid people when it ships | — |

Two Shorts a week and one long video a month is about a day of work a week once the first
batch is recorded. If that is more than the team has, drop the long videos to every six
weeks before dropping the Shorts.

**Where else the trailer goes on day 0** (once each, following each place's rules on
self-promotion): r/iosgaming, r/godot, r/indiegames, r/mountandblade (read their rules
first; a "made an iPhone game inspired by this" post is usually welcome, an advert is
not), and the Godot Discord's showcase.

**Outside YouTube, one thing worth the hour:** App Store Connect has a form for nominating
a launch to Apple's editors for featuring. Send it well ahead of release, with the trailer
linked. A feature on the App Store would reach more iPhone players than any video here.

## Creators

Start when the TestFlight link exists; a trailer alone rarely earns a video.

- **Who:** small and middling channels (roughly 5,000 to 200,000 subscribers) that cover
  iPhone games. They answer, and their viewers have the right device. Three lists to
  build, about fifteen channels each:
  1. iOS games-of-the-week and premium mobile reviewers. These are the core.
  2. Makers of "best strategy games on iPhone" and "games like Mount & Blade on mobile"
     lists. A place on one of those lists keeps sending viewers long after it is posted.
  3. Godot and devlog channels, for the developer story.

  PC strategy channels (the Bannerlord and Total War ones) are a long shot: their viewers
  are at a PC and the game isn't. Pitch them only with the novelty ("a warband sandbox
  that fits in a pocket"), and expect few replies.

  A name to start checking: SNAPP Attack, a weekly iOS round-up. That is from memory, not
  from research: confirm it is still active before writing, and build the rest of the list
  by searching YouTube for the last three premium iPhone strategy releases and noting who
  covered them.
- **What to send:** four lines. What the game is in one sentence, why their viewers in
  particular would care (name one of their videos), the TestFlight link, and a link to a
  press folder (the trailer file, the battle trailer, ten portrait screenshots, the
  wordmark, a fact sheet). No attachments, no embargo, no request for a positive word.
  The same folder goes to the sites that cover iPhone games in writing.
- **Paid coverage:** not at this stage. If it ever happens, the creator must mark it as a
  paid promotion in YouTube's own setting.
- **Adverts:** hold until launch. In launch week the battle trailer can run as a Shorts
  or in-feed advert shown on iPhones only, to viewers of mobile strategy videos; before
  there is something to download, an advert buys views that can't do anything.

## Knowing whether it's working

Look once a week, in YouTube Studio and App Store Connect.

| Number | Where | What it tells us | If it's low |
| --- | --- | --- | --- |
| Impressions click-through rate | Studio › Reach | Whether the title and thumbnail earn the click. YouTube's own help page says half of all channels sit between 2% and 10% | Change the thumbnail first, then the title; use *Test & compare* |
| Audience retention at 0:30, and the shape of the curve | Studio › Engagement | Whether the captains' story holds a stranger. A cliff in the first ten seconds means the slow-motion opening is too slow; a slide between 0:08 and 0:24 means the screens are | Shorten the opening to one bar, or lead with the battle trailer and keep *Captains* for viewers who already follow |
| Viewed versus swiped away (Shorts) | Studio › Engagement | Whether the first second works | Start the Short later in the action; put the hook line on frame one |
| Share of views on iPhone | Studio › Audience (device and operating system) | Whether the viewers can play it at all | More Shorts, fewer desktop-leaning devlogs; pitch iOS channels |
| Sign-ups, testers and pre-orders per 1,000 views, by video | The sign-up form, TestFlight, App Analytics by campaign | The only number that matters in the end | More of whatever kind of video scores highest; fewer of the rest |
| Returning viewers and subscribers | Studio › Audience | Whether there is an audience for the launch day Premiere | Series (*One order a week*) and replies to comments |

Subscriber count is not a goal. A hundred pre-orders from a video with two thousand views
beats ten from one with fifty thousand.

## What not to do

- Don't publish before the name and a link are settled.
- Don't show what isn't built. Every shot in the trailer is recorded from the game; keep
  it that way, and don't promise a date.
- Don't post the 16:9 trailer as a Short with bars. Cut a vertical one.
- Don't put "Mount & Blade" in a title or thumbnail.
- Don't buy views, subscribers or comments, and don't ask creators for anything but an
  honest look.
- Don't let a month pass in silence after the announcement. A dead channel reads as a dead
  game; if time is short, one Short a week keeps it alive.

## Making the footage

Everything above is cut from the game by two sets of tools, each with a README.

`tools/trailer2/` made *Captains* and is the one to build on. `shoot.sh` records a shot
tall (the game as it is on a phone: Shorts, app previews, screens shown in a phone) or wide
(the field or the map filling the frame, HUD away); `stage.gd` stages it, can fast-forward
a fight to a moment or run it in true slow motion, and names every fight's seed, so a shot
is the same each time it is recorded; `shoot.sh --probe` finds a moment (who falls, when a
gate breaks) without recording a frame; `score.py` writes the music; `cut.py` draws the
trailer, its captions and its thumbnail. Several of the first twelve Shorts are already
shots there: the death roll (`fall`), the siege (`gate`, `wall`), the wedding (`vows`), a
lord's talk (`emir`, `daimyo`), a battle with the HUD (`hand`).

`tools/trailer/` made the first cut. Its battles are not seeded, so its shots differ from
one recording to the next.

Footage "in a hand" for the long videos is the iPhone's own screen recording.

## Sources

- The other *Bannerfall*: [Steam page](https://store.steampowered.com/app/3198250/Bannerfall/), [its X account](https://x.com/Bannerfallgame).
- App Store pre-orders (2 to 180 days before release): [App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/publish-for-pre-order).
- Trailer length and gameplay-first openings: [steampageanalyzer.com](https://www.steampageanalyzer.com/blog/steam-trailer-best-practices), [gameworldobserver.com](https://gameworldobserver.com/2022/09/22/common-game-trailer-mistkaes-indie-developers-steam), [bugnet.io](https://bugnet.io/blog/what-makes-a-game-trailer-convert). These are marketing blogs written about PC store pages; their numbers are rules of thumb, and the parts used here (gameplay early, 60 to 90 seconds, one call to action) hold on any platform.
- Shorts for reach and long videos for conversion: [strayspark.studio](https://www.strayspark.studio/blog/devlog-marketing-build-wishlists), [bugnet.io](https://bugnet.io/blog/youtube-shorts-for-indie-game-marketing). Also opinion, not measurement.
- TestFlight's tester limit, the app preview rules, campaign links and the featuring
  nomination are from memory of Apple's documentation, not checked today: confirm each in
  App Store Connect before relying on it.
