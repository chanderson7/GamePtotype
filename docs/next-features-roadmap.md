# Bannerfall: recommended next features

**Planning date:** 2026-10-28

**Status:** proposed roadmap, based on the current working tree, including the local Edda
personal-conversation implementation. This document does not mean the proposed features
are implemented, committed, or published.

## 1. Recommendation

Finish the **living-world campaign loop** next: armies gather, settlements change hands,
peace creates breathing room, and the player can earn a living fighting for a realm.
Support that loop with a journal that explains what changed and where the player can act.
Then deepen the captains and relationships the player has reasons to care about.

The immediate implementation task should remain **Phase 4.3 army formation**. Ship a small
working muster/march/disband cycle before adding siege resolution. Build the journal's
first useful page alongside the first visible world changes. Once sieges and basic peace
work, prioritize contracts over adding more autonomous simulation.

A good next playable milestone would let someone say:

> I saw a neighboring castle come under siege, checked who was fighting, signed a contract,
> defended one of my employer's villages, and understood how that affected my company and
> the people I knew there.

This follows the existing [Phase 4 plan](phase-4-plan.md). It adds priorities, smaller
release boundaries, and later feature recommendations rather than replacing its rules.

## 2. What already exists

Do not schedule these as entirely new features:

| Existing foundation | What the next work should add |
| --- | --- |
| Real-time battles, terrain, culture troop branches, objectives, reinforcements and auto-resolve | Battles with persistent allied ownership and reserve limits |
| Three realms, 21 settlements, ownership/war APIs, roaming lords, raids and treasury-funded garrisons | Coordinated armies, siege decisions and autonomous diplomacy |
| Food, wages, recruiting, training, renown, desertion warnings | New ways to earn money and understand future expenses |
| Captain traits, deaths, battle-count wounds, replacement captains, C/B/A bonds and memorials | Earned specializations, richer histories and optional bond scenes |
| Home, separate Settings, optional tutorial, resource icons and first-bond introduction | Consistent navigation, meaningful map links and campaign information |
| People & Letters, Edda's main story, house pacts, grants and replacement sponsorship | Clear political eligibility, military assistance and the other candidates' routes |
| Edda's six optional personal scenes, summaries, replay and capped trust | Additional authored characters after their main routes work |
| Local campaign persistence and atomic save replacement | Visible recovery options and coverage for new long-running states |

Captain wounds already exist. Recoverable **troop casualties** would be a new system.
War declarations and peace can already be represented; autonomous decisions about when to
make them are still future work. Farid and Kaede have records, not complete playable routes.

## 3. Priority and dependency order

Sizes are relative implementation scope, including focused verification: **S** is a small
slice, **M** spans a few components, **L** needs several independently playable slices.
They are not calendar estimates.

| Order | Feature | Priority | Size | Depends on |
| --- | --- | --- | --- | --- |
| 0 | Integration and save-readiness pass | Release gate | S–M | Current local changes |
| 1 | Marshal armies | Next | M | Existing lords, routes and garrisons |
| 2 | Siege campaigns and captures | Next | L | 1 |
| 3 | Campaign journal and useful map links | Next, incremental | M | Existing events; extend with 1–5 |
| 4 | War, peace and a readable war overview | Next | M | 2 |
| 5 | Mercenary contracts and lord encounters | Next major player feature | L | 4 and journal basics |
| 6 | Allied battles and real house assistance | Following | L | 1, 5 and political eligibility |
| 7 | Prisoners, ransom and remembered rivals | Following | M–L | 5; ownership rules from 6 |
| 8 | Small settlement jobs for independent companies | Following | M | Journal; reuses current encounters |
| 9 | Captain development and optional bond stories | Following | M–L | Current captain IDs/bonds; stable campaign economy |
| 10 | Farid and Kaede's complete routes | Following, one character at a time | L | Shared social eligibility and journal |
| 11 | Recovery options and campaign achievements | Later | M–L | Stable battle results and campaign statistics |
| 12 | A first fief, then playable sieges | Later expansion | L | Stable complete Phase 4 loop |

**Minimum useful release:** 1–5 with a simple journal. The world changes and the player can
participate. Allied reserve battles, prisoners, new romance routes and land ownership can
wait. Independent bandit hunting must remain viable throughout.

## 4. Integration gate before adding more systems

Keep this bounded to defects and contracts needed by the next features.

- Exercise a complete Edda route, optional conversations, saving/loading, and a capture
  that relocates her. Keep personal trust, house standing, realm standing and captain bonds
  distinct; they measure different relationships.
- Apply location and political access checks in simulation commands as well as menu buttons.
  The current People audience entry is offered remotely; first establish which actions
  require a visit and which may explicitly be handled by letter. Personal scenes already
  enforce visits. Extend consistent rules to relevant core audiences and financial actions.
- Show financial and relationship consequences before irreversible choices. Prevent repeat
  submissions from awarding the same benefit twice.
- Preserve old saves and the current atomic-write behavior. Add a visible save-failure
  message wherever a new action depends on persistence; do not show success after failure.
- Recheck the performance issues recorded in [NEXT.md](NEXT.md) on a consistent machine.
  Address reproducible regressions before increasing party counts.

**Done when:** existing menu, relationship and personal-conversation checks pass; new access
rules have targeted tests; the current local work can be reviewed as one coherent baseline.
Do not fold a wholesale UI or simulation rewrite into this gate.

## 5. Feature specifications

### 1 — Marshal armies

**Player value:** several independent lords become a recognizable military threat with a
purpose the player can see.

**First slice**

- Choose a realm's highest-renown eligible free lord as marshal, following Phase 4.
- Recruit two or three eligible lords into a timed muster at a reachable gathering place.
- Show a single army marker once gathered, with member names, strength, destination and
  status: gathering, marching, besieging or returning.
- Preserve each member's troops, identity and finances. An army groups existing forces.
- Choose one reachable hostile town/castle using distance, value and defensive strength.
- Define timeout, member defeat, peace, target capture and marshal-unavailable behavior.
  An incomplete muster should depart if viable or disband with a reason.

**Leave for later:** player army command, competing marshals, political voting and custom
formation orders on the campaign map.

**Acceptance checks:** a seeded realm forms and disbands an army; members cannot appear in
two parties or armies; all troops reconcile before/after grouping; save/load during muster
or travel continues the same decisions; no unreachable target leaves an army stuck forever.

**Implementation:** extend `scripts/world/world_sim.gd` and `scripts/data/lords.gd`, with a
focused pure-logic army module if necessary; draw state in `scripts/world/map_screen.gd`.
Avoid duplicating the authoritative troop arrays inside the aggregate marker.

### 2 — Siege campaigns and captures

**Player value:** a campaign battle changes the map and the lives attached to a settlement.

**First slice**

- A hostile army establishes a visible siege with preparation, supplies and an assault
  decision. Show the expected preparation window and defender strength.
- Use the planned auto-resolve wall multipliers: castle ×1.6 and town ×1.4. Keep modifiers
  in data and clearly distinguish raw troop strength from effective defensive strength.
- Resolve relief, withdrawal, starvation and assault as explicit outcomes. Recheck war and
  ownership before applying an outcome.
- Use `world.set_owner()` for capture so bound villages, capitals and social relocation
  follow the existing transfer path.
- After transfer, station a bounded portion of surviving attackers as the new garrison.
  Remove those soldiers from the attacking army: they must not exist in both places.
- Integrate village militia and siege food accounting here, as the existing plan requires.
- Preserve sponsorship refunds, letters, resident identities and completed memories when
  ownership changes. Capture must not silently delete an ongoing relationship.

**Leave for later:** controllable ladders, destructible gates and bespoke siege battle maps.

**Acceptance checks:** at the Phase 4 defined strength ratios, a twice-as-strong attacking
force wins at least 80% and an inferior force at most 20% over a declared seed batch;
transfers and casualties conserve soldiers; reload cannot award capture twice; relief and
peace cancel incompatible siege work; resident relocation and escrow refunds occur once.

**Implementation:** `world_sim.gd`, `scripts/battle/auto_resolve.gd`, a siege-rules data file,
settlement/map screens and `scripts/world/social_sim.gd` integration checks.

### 3 — Campaign journal, navigation and clearer decisions

**Player value:** the player can answer “what happened, what can I do, and where do I go?”
without remembering transient notices or searching several menus.

**First slice**

- Add a map-menu **Journal** with Active commitments and Chronicle views. Keep People &
  Letters as the contact view; cross-link it rather than copy its records.
- Each commitment shows its objective, destination, reward, accepted cost, deadline if any,
  and reason it is blocked. Optional backstory should not look like a timed duty.
- **Show on map** focuses/highlights the actual current destination without starting travel.
  Follow relocated people rather than a hard-coded original seat.
- Retain the last 30 significant world events, following Phase 4.7, plus unresolved
  commitments and personal milestones in their own durable records.
- Pin one objective to a small map card. Empty states suggest a nearby opportunity without
  accepting it automatically.
- Display net daily income beside wages once contracts exist. Keep food-days visible.
- Add larger-text support and consistent touch targets, focus/back behavior and wrapping to
  the new screens; reuse the existing menu theme.

**Notification rule:** encounters and actual losses can interrupt; distant wars, optional
letters and new dialogue use a badge or chronicle entry. Do not add a new modal for every
army movement. Acknowledging a notice must not erase the underlying history.

**Acceptance checks:** map links resolve after relocation/capture; expired commitments
explain their outcome; journal reading consumes no time; history survives the map consuming
its transient event queue; phone-sized layouts and large text remain usable.

**Implementation:** a saved journal/event record, `map_screen.gd`, `scripts/ui/scenes.gd`,
new menu scene, and links from `scripts/menu/people.gd`. Add stable event IDs and campaign
hours for deduplication; do not treat the current drained `world.events` queue as an archive.

### 4 — War, peace and political visibility

**Player value:** war has causes, costs and an end, giving the player time to recover and
choose their next employer.

**First slice**

- Daily war weariness from elapsed war, losses, raids and lost settlements; later add
  prisoner effects when prisoners exist.
- Peace and the planned 30-day truce. Handle active armies, sieges and accepted obligations
  when peace takes effect.
- A War overview with participants, duration, recent captures, broad strength and the main
  reason for peace or continued war.
- Add strength-based declarations and Ryumon balancing after the basic war/peace cycle is
  stable. Add tribute only with explicit payer, recipient and insolvency behavior.

**Acceptance checks:** use the existing multi-year Phase 4 gates, including no realm lost
in year one and meaningful periods of both war and peace. Truces survive saves; a realm
cannot declare and immediately make peace repeatedly to farm events or rewards.

**Implementation:** proposed `scripts/data/politics.gd`, daily world decisions, journal and
War overview. Tune once per simulated day, not per rendered frame.

### 5 — Mercenary contracts and lord encounters

**Player value:** a second viable career beyond bandit hunting, with deliberate political
commitments and a reliable reason to take risks.

**First slice**

- At an eligible town/castle, offer a 30-day contract with daily pay, eligibility,
  employer/enemies, end date and early-exit consequences shown before acceptance.
- Any culture may serve any realm. Culture, employer and personal friendships stay separate.
- Pay on campaign-day boundaries, once per owed day. Specify handling of a treasury shortfall
  and arrears; never silently create silver or leave the player guessing about missed pay.
- Enable hostile lord encounters and friendly audiences. Show why a lord is hostile, rough
  strength, withdrawal conditions and projected losses for Send in.
- Let the player aid an employer's threatened village using the existing defense objective.
- On expiration offer renewal without trapping the player in another term. Peace, employer
  defeat and early exit must have explicit settlement rules.
- Keep a neutral independent company possible; being born in a realm does not enlist it.

**Acceptance checks:** a 60-day scripted mercenary campaign satisfies Phase 4's solvency and
army-size gate; pay and expiry survive a reload around midnight; expired hostility clears
where appropriate; neutral attacks have a consequence preview; skipping contracts remains
viable; required story access is not accidentally made impossible by employment.

**Implementation:** a contract model and tunables, world hostility/encounters, GameState
transaction wrappers, settlement offers and journal. Realm/lord standing must not reuse
Edda's trust or a house's standing as a substitute.

### 6 — Allied battles and real house assistance

**Player value:** strengthening an ally eventually produces help the player can see in the
world, while the ally remains a real force that can be occupied or defeated.

**First slice**

- Join/follow an employer's army with a clear leave action and visible supply costs.
- Keep at most 12 squads per side active, bringing reserves through the existing
  reinforcement mechanism. Mark allied squads and keep the player's controls unambiguous.
- Attribute every squad and casualty to its owning party; settle results once.
- Add one pact request: ask an eligible allied lord to defend a named friendly settlement.
  Use the eligibility, cooldown and cancellation policy in the
  [romance and allies plan](romance-and-allies-plan.md#8-how-the-side-quest-strengthens-allies).
- Dispatch actual troops by actual roads. Explain “rebuilding,” “already with the marshal,”
  “unreachable” or “politically opposed.” Friendship is not guaranteed availability.
- Recheck politics at acceptance, departure and battle participation. Suspend conflicting
  military cooperation without erasing the personal relationship.

**Acceptance checks:** no duplicated troops, rewards or ownership; reserve cap holds; allied
losses return to the correct lord; no help teleports; invalid requests consume no resources;
Send in agrees with full allied battles at the Phase 4 ≥85% target.

**Leave for later:** summoning arbitrary armies, controlling all allied squads and stacking
several household military requests. Start with one active assignment globally.

### 7 — Prisoners, ransom and remembered rivals

**Player value:** victories can create a recurring opponent, a valuable prisoner or a future
friend, rather than only another payment.

- Start with lord capture, a prisoner roster, paid ransom and voluntary release. Display the
  personal and realm effects separately before release or transfer.
- Captured lords leave the field; ransomed lords return through a defined recovery route.
- Persist the same person through defeat, captivity and release. Use stable person IDs for
  relationships, not temporary party IDs.
- Record encounters and captain losses in the journal and memorial. Present both sides of
  a rivalry accurately rather than labeling every past opponent hateful.
- Resolve political changes, player defeat and captivity expiration explicitly.
- Add the planned rare lord-death/succession path only with identity and house inheritance
  rules. No executions or capture of the player's captains in this phase.

**Acceptance checks:** ransom conserves money; release cannot be claimed twice; captivity
cannot coexist with a field party; save/load retains memories and prisoner ownership.
After this foundation, the planned “A Road Home” relationship rescue project becomes viable.

### 8 — Small settlement jobs for independent companies

**Player value:** meaningful peaceful or local work keeps a free company viable during
truces and gives visits to villages a purpose.

**Initial templates**

| Job | Existing systems used | Completion and failure |
| --- | --- | --- |
| Drive off a named nearby raiding band | Bands, raids, village defense | Complete on a qualifying encounter result; cancel fairly if another force removes it |
| Carry a letter between two named contacts | Roads, people, letters | Deliver through an eligible audience; follow relocation or explain cancellation |
| Contribute supplies to a recovering village | Food, money, burned villages | Preview the exact donation and fixed reward; one reward per accepted job |

- Use a shared small job state machine, not separate logic for every settlement.
- Offer a short visible list. Declare deadlines before acceptance; do not hide failure
  conditions behind dialogue. Cap active jobs to keep the phone UI manageable.
- Fund monetary rewards from a defined budget. Tune alongside bandit hunting and contract
  income; prevent accepting and canceling jobs from generating money or standing.
- Keep these optional and separate from romance access.

**Acceptance checks:** save every job state; changing owners and missing targets resolve
fairly; rewards pay once; deadlines use campaign time; a neutral company has useful work
without an invitation to a romance or a military contract.

**Leave for later:** simulated trade caravans, a full commodity market, escort AI and
procedural dialogue. They multiply scope beyond these reusable templates.

### 9 — Captain development and optional bond stories

**Player value:** the people leading each squad develop beyond their starting trait, and
battlefield history becomes visible in camp.

**First slice**

- A captain detail page with existing traits, bond partners, injuries, important battles,
  predecessor history and one next development choice.
- One earned specialization choice after a configurable service milestone. Initial tracks:
  **Scout** (better encounter information), **Quartermaster** (small bounded supply benefit),
  **Drillmaster** (small training benefit). Final numbers require economy/battle tests.
- Use the strongest eligible campaign effect per role, not an additive bonus from every
  captain. State whether a wounded captain's skill is active.
- Add optional C/B/A pair scenes tied to actual shared history. Begin with a small set of
  temperament combinations and event-based variants; do not promise bespoke dialogue for
  every generated pair.
- Keep existing battle-earned bond ranks authoritative. Watching a scene does not create
  another combat bonus or require the player to choose a correct answer.
- Allow replay and short summaries. Acknowledging a scene is separate from the existing
  first-C tutorial acknowledgment.

**Acceptance checks:** promotions and scenes cannot be claimed twice; a replacement captain
gets a new identity; death preserves an appropriate archive; no stale bond points transfer
to a successor; skill bonuses remain bounded; generated names and pair references are valid.

**Leave for later:** a large skill tree, individual equipment inventories, mandatory camp
chores and party jealousy that threatens the company's viability.

### 10 — Farid and Kaede as complete characters

**Player value:** social play reflects all three cultures, with different people and
problems instead of repeating Edda's story in different clothing.

- Ship **Farid first, then Kaede** so one full route can be tested before doubling content.
  Use Farid's diplomatic voice and Kaede's tension between duty and personal choice from
  the existing [personal-conversation plan](romance-personal-conversations-plan.md).
- Each needs a valid introduction, distinct shared obligation, honest/conflict resolution,
  friendship ending, romantic commitment and post-commitment follow-up.
- Only then enable that character's six planned optional personal scenes. Reuse the +1
  first-three/+3 lifetime cap per persistent person, equal replies, summaries and archive.
- Keep court residents anchored to households rather than requiring them to occupy a
  combat-party slot. They can relocate and send letters without becoming vulnerable to
  every ordinary battle.
- Friendship should unlock the same category of ally cooperation. Marriage adds narrative
  commitment, not an exclusive best combat build.
- Start with one post-commitment household project already justified by the world. Do not
  manufacture a feud solely to populate a romance quest.

**Acceptance checks:** each route works with invitations off; no scene copies Edda's quest
IDs, residence or house; relocation and war preserve continuity; neither neglect nor
skipping optional conversation causes relationship decay; all published dialogue is original.

### 11 — Recovery options and campaign achievements

Treat these as two separate releases after the campaign economy is stable.

**Recoverable troops and a Casual option**

- Distinguish surviving, wounded and dead soldiers in battle results before changing the
  reinforce screen. Preserve total headcount and the loss-report explanation.
- Add a bounded recovery rate and treatment/rest choice. Decide wages, food consumption,
  deployment eligibility and retreat behavior for wounded troops before implementation.
- Keep captain wounds' existing battle-count rules until an explicit migration replaces
  them; do not accidentally combine two recovery clocks.
- Offer Casual captain survival as an explicit campaign setting with a clear explanation.
  Preserve the current death-risk mode as the default unless a later design decision
  changes it. No retroactive resurrection or hidden mid-battle rule change.

**Company achievements**

- Optional goals such as completing a contract, saving several villages, keeping a veteran
  captain alive through a campaign, or forming a lasting house friendship.
- Show progress and a retrospective chronicle card. Start with narrative recognition or
  cosmetic titles, avoiding another source of stacking combat bonuses.
- Reaching a goal never ends the sandbox automatically. No forced conquest objective.

**Acceptance checks:** healing cannot duplicate soldiers; economy remains viable; existing
saves preserve current outcomes; goals reference real events, pay once if later rewarded,
and do not require romance or a particular culture.

### 12 — A first fief before a kingdom

**Player value:** a durable home gives the company a place worth defending.

Begin with one awarded fief, a small treasury view, garrison management and one repair or
supply investment. Define loss, recapture, obligations to the realm and resident relocation
before adding buildings. Vassalage should be a deliberate political commitment.

Then prototype one playable siege location using the same defenders and capture rules as
auto-resolve. Validate phone controls, navigation and performance before adding more maps.

A player-founded kingdom, succession politics and a large construction tree should follow
successful fief playtests. They should not be prerequisites for the next playable release.

## 6. Suggested delivery packages

| Package | Contents | What a player can do afterward |
| --- | --- | --- |
| A: Armies become visible | Integration gate; muster, march, disband; basic event history | Identify an army, its members and intended target |
| B: Borders change | Siege preparation/outcomes; safe ownership transfer; basic peace and truce; War overview | Understand a capture and the resulting political change |
| C: Serve a realm | Contracts, lord encounters, existing village defense, income/commitment journal | Play a paid military career and return to independence |
| D: Allies participate | Multi-party battles, reserves, one genuine military-help request | Fight beside troops belonging to people the player knows |
| E: Remember the campaign | Prisoners, rival memories, captain detail and first bond scenes | Make decisions shaped by earlier victories and losses |
| F: More ways to belong | Small local jobs; Farid's route, then Kaede's; later recovery and goals | Build a company and relationships outside constant conquest |

Do not wait for an entire package to merge before showing a working slice. Every step
should load old saves, have a playable entry point, and leave the game usable on its own.
Scope cuts should remove a later feature rather than publish buttons for unavailable actions.

## 7. Technical and verification rules

- Keep world decisions deterministic and in pure-logic simulation. Screens display state
  and issue validated commands; UI previews cannot authorize costs or rewards by themselves.
- Use stable IDs for people, houses, parties, jobs and events, with explicit ownership.
- Keep new numbers in data files. Reuse existing economy and relationship definitions.
- Extend the save schema when the shape requires it; use the next available version at
  implementation time rather than reserving a version number here.
- Test transitions at their difficult boundaries: midnight, target capture, peace, party
  defeat, save/reload during a task, and retry after a failed write.
- For armies/sieges, verify conservation of soldiers and money. For social content, verify
  optional scenes do not alter political eligibility or main quest progress.
- Run focused suites per change; run the existing long world/balance gates at meaningful
  integration points. Record seeds, machine and timing context for performance results.
- Inspect map readability and menus at the existing 405×720 preview size and on a real
  phone before declaring a mobile performance gate passed. Desktop renders are not a
  substitute for device performance measurements.

**Release playtest:** run an independent company and a mercenary company through the same
broad campaign period. Each should have viable work, understandable losses, recovery
options and a reason to travel. Separately play a friendship route and a romance route;
neither should be mandatory for military success.

## 8. Explicitly deferred

- Multiplayer, cloud accounts and a live-service economy.
- A much larger world map or additional cultures before current places have more purpose.
- Fully simulated trade markets, caravans and naval combat.
- Children, aging, inheritance dynasties and relationship maintenance meters.
- A large captain equipment or crafting system.
- Procedural/AI-written conversation at runtime.
- Monetization design before the core campaign is consistently enjoyable and readable.

These may become useful later. None resolves the immediate gap between a detailed battle
system and the player's limited ability to participate in the realm-level world.

## 9. Next implementation handoff

Implement **army formation only** first:

1. Add saved army membership and muster state with stable IDs.
2. Select eligible marshal/members and a reachable hostile target.
3. Implement gathering, timeout, march, interruption and disband behavior.
4. Show the aggregate party and a readable member/status sheet.
5. Verify troop conservation, deterministic continuation, peace/capture interruption and
   save compatibility; recheck world-step cost.
6. Update [NEXT.md](NEXT.md) with the as-built state and make siege resolution the next slice.

Do not silently resolve a capture in this first slice. Until siege behavior exists, reaching
the target ends the test expedition with a bounded return/disband transition; it must not
leave an army waiting indefinitely. The next slice supplies the explicit siege state and
outcome rules. Journal scaffolding can record the new events without
waiting for contracts or a full quest framework.

## Repository references

- [Current handoff and validation notes](NEXT.md)
- [Living-world mechanics and quantitative gates](phase-4-plan.md)
- [Existing battle/terrain foundations](phase-3-plan.md)
- [Romance, friendship and ally-support design](romance-and-allies-plan.md)
- [Personal conversations and remaining character content](romance-personal-conversations-plan.md)
- [Current project overview](../README.md)
