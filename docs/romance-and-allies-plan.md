# Romance and allies: implementation plan

**Status:** R0–R3 and the complete three-woman cast are implemented. This remains the design
record for the system; numbers below are Bannerfall tuning values rather than Warband values.
Farah uses the legacy internal ID `farid` to preserve existing save compatibility.

## 1. What we are building

An optional personal quest that can grow into a romance, marriage, and a lasting connection
to an allied house. The partner has a life and responsibilities in a settlement. Helping
them means making decisions about people and the war, and can materially strengthen an
ally's troops, defenses, or willingness to help the player.

Start with **court residents attached to existing lords**, rather than romanceable combat
captains. This avoids making a long personal story depend on repeated captain death rolls.
It does not decide the separate question of whether captains should become immortal or
gain a Casual mode. Existing captain mortality and C/B/A battlefield bonds stay as they are.

The core loop is:

**Meet someone → learn what matters to them → undertake a shared obligation → navigate a
conflict of loyalties → choose a relationship → negotiate a house pact → maintain it through
occasional joint projects.**

Marriage establishes a personal partnership. A house pact establishes political obligations.
Either can exist without the other. An ally's realm does not automatically become friendly
because one member of its nobility marries the player.

### Recommended scope

- One complete five-chapter story first, then three candidates total: one per culture.
- Candidates are adults with explicit interests, responsibilities, boundaries, and opinions.
  Use the same courtship rules for every player gender; initially candidates are available
  regardless of player gender. This avoids requiring a new character-creation system.
- One active courtship or spouse at a time. Friendships and house pacts can coexist.
- Settlement conversations, letters, short illustrated scenes, and existing campaign actions.
- A friendship ending with access to the same essential alliance tools. Romance is optional
  both mechanically and narratively.
- No spouse combat deployment, children, inheritance, dynasties, procedural romance dialogue,
  tournament system, or full kingdom treaties in the first release.

## 2. What to learn from Mount & Blade: Warband

Warband explicitly presents marriage as both a romantic and political activity, with poetry
and bravery as ways to court someone. That connection between personal ambition and the
campaign is the main inspiration. [TaleWorlds' Warband description on Steam](https://store.steampowered.com/app/48700/Mount__Blade_Warband/)

| Warband precedent | Bannerfall adaptation |
|---|---|
| Meeting potential partners in noble courts | A visible Court entry at relevant settlements, with named residents |
| Poems and dedicated tournament victories | Personal conversations, a small optional verse/story scene, and remembered campaign deeds |
| Winning over a relative as well as the prospective spouse | Separate personal trust and house standing; family support affects the pact |
| Marriage at a feast; elopement as an alternative | A player-scheduled ceremony or private vows, with explicit political consequences |
| Spouses hosting feasts and suggesting mediation between lords | Joint projects that improve allied readiness and settle specific disputes |

The courtship and spouse activities above are described in the contemporary
[Warband FAQ, romance sections 00018–00022](https://gamefaqs.gamespot.com/pc/958942-mount-and-blade-warband/faqs/61448).
Personality-sensitive poems, family opposition, and different male/female courtship routes
are also documented in the [Marriage reference](https://mountandblade.fandom.com/wiki/Marriage)
and [Poems reference](https://mountandblade.fandom.com/wiki/Poems).

These community accounts are useful for the broad Native Warband loop; exact numerical
requirements vary across accounts and mods. Do not copy thresholds from them. This proposal's
explicit house pacts, resource accounting, gender-neutral routes, and recovery paths are new
Bannerfall mechanics, not claims about Warband's implementation. In particular, marriage
should not be represented as a guaranteed kingdom alliance or automatic military obedience.

### Design lessons

Keep the travel, anticipation, family interests, and usefulness after the wedding. Give
the player clear reasons for success or refusal, meaningful choices beyond repeating a
compliment, and a ceremony they can arrange without waiting indefinitely for an AI feast.
Use original characters and writing; do not copy Warband dialogue or poems.

## 3. Fit with the current game

| Current implementation | Consequence for this feature |
|---|---|
| Three cultures, 21 settlements, and five lords per realm | Enough locations and political contacts for three authored candidates |
| Lords have persistent numeric IDs, names, realm, fief, purse, and party reference | Reuse lord records, but introduce explicit person and house IDs before attaching relationships |
| House names currently appear in generated lord names, without a house model | A small house registry is required; do not infer kinship from string matching |
| Lords regroup after losing a party | Personal relationships must survive party destruction and replacement |
| Captains use personal IDs for C/B/A bonds and can die | Keep romantic progression separate from tactical bonds and the captain roster |
| Town/castle garrisons and lord recruitment spend real silver | Allied strengthening must use these budgets and recruitment limits |
| Save version 5, with old-save migration | Add a versioned social state and preserve existing worlds |
| Settlement menus pause time; the map consumes transient world events | Quest progress must be handled in simulation/state code and saved independently of UI notices |

The main roadmap still needs armies/sieges (4.3), war/peace behavior (4.4), player standing
and contracts (4.5), and prisoners/succession (4.6). These are **dependencies or later
integration points**, not existing capabilities.

Recommended placement: implement the relationship foundation alongside 4.5, then the first
complete romance after 4.5 works. Add rescue and succession integration after 4.6. Full
kingdom diplomacy remains later work. A development prototype can run against today's map,
but should not expose unfinished political promises to players.

## 4. People, trust, houses, and pacts

### Separate the quantities

| State | Range/type | Meaning and use |
|---|---|---|
| Personal trust | 0–100, per candidate | Whether this person believes the player's actions and promises |
| Romantic intent | Explicit mutual choice | Whether both people want courtship; trust alone never starts romance |
| House standing | −100 to 100, per house | The household's view of the player and willingness to make a pact |
| Lord/realm standing | Phase 4.5's existing planned values | Individual politics and faction hostility; do not replace these with house standing |
| House pact | Structured agreement | Named participants, supported actions, obligations, suspension reasons, cooldowns |
| Captain bond | Existing C/B/A | Battlefield cooperation only |

Use one trust number plus memories and state flags. Do not add separate affection,
attraction, jealousy, loyalty, and favor meters for the first release. Show descriptive
labels first, with exact values and recent changes available under Details.

### Persistent identity

- A person exists independently of their current settlement or party. The partner's ID
  stays the same through relocation, marriage, captivity, and a house changing allegiance.
- A house has its own ID, head, members, and seat. A settlement changing hands does not
  replace the people or rewrite their family relationships.
- A lord's successor receives a new person ID and keeps the house connection. Personal
  trust and romance never transfer to an heir.
- Household support does not depend on the spouse occupying a warband slot.
- Court residents do not participate in battle casualty rolls. In the initial release,
  capture of their home causes relocation, not an unseen death. Captivity is a later,
  recoverable branch when the prisoner system exists.

### Progression and limits

- Ordinary absence has no trust decay. No daily visits, gifts, or spouse upkeep checklist.
- Authored scenes and completed promises are the main sources of trust. Each has a unique
  reward key and can pay out only once.
- A gift can prompt dialogue, but repeated gifts cannot satisfy a story milestone.
- House approval cannot override a partner's refusal. Refusal explains whether the issue
  is a missing milestone, an incompatible choice, or an unresolved breach of trust.
- Courtship can be paused or ended through dialogue. A respectful ending preserves the
  friendship and earned political standing; breaking a specific promise has its own cost.
- The player may know all three candidates, but must end one courtship before beginning
  another. Do not include a hidden jealousy simulation in the first release.

## 5. Initial cast and content budget

These are proposed characters, not established setting canon. Bind each to an existing
non-ruling lord's house at campaign initialization and save the binding permanently.

| Candidate | Residence/house anchor | Personal aim | Character conflict | Shared project |
|---|---|---|---|---|
| Edda, 28, Vardish estate steward | House initially holding Ravensford | Restore the household's neglected border villages | Loyalty to relatives versus protecting villagers | Fund a depleted force and negotiate a defensive commitment |
| Farah, 31, Kharzani envoy | House initially holding Qasr Hamra | Keep trade and correspondence open across hostile borders | Diplomatic compromise versus family prestige | Reconcile an allied dispute and arrange relief funding |
| Kaede, 27, Ryumon archivist and household negotiator | House initially holding Kitayama | Preserve an agreement that prevents a local feud | Public duty versus a personally chosen future | Verify competing claims and organize joint defense |

House identity is not reassigned when these castles are conquered. Names, interests,
pronouns, and portrait references belong in authored character data, not culture-wide
stereotypes. All three offer the same basic pact capabilities; their stories and choices
differ, so one culture is not the economically superior romance choice.

All three candidates now have complete five-chapter routes, three final relationship outcomes,
repair branches, equivalent pact access, and six optional personal conversations. Their route
structure is shared for reliable campaign accounting, while scene writing, goals, locations,
portraits, and voice are character-specific.

### Optional personal conversations

The separate [personal conversations plan](romance-personal-conversations-plan.md) proposes
six backstory scenes per candidate, with original dialogue inspired by Three Houses support
writing. It recommends +1 trust for the first three unique personal scenes per character
(+3 maximum), with equal treatment of all responses and no other gameplay rewards. These
are additional optional scenes; the main chapter rewards and required story beats below
keep their existing roles. All 18 optional scenes and capped rewards are implemented as an
extension to the R0–R3 core.

## 6. Main side quest: “A Place Beneath the Banner”

### Entry and pacing

- Court residents are visible immediately at accessible towns/castles. Introduction is
  available from 30 renown or after a qualifying deed for that house, whichever comes first.
- Qualifying deeds are explicit: aiding its lord, successfully defending its bound village,
  or completing a house commission. Bind to campaign event IDs, not generic kill totals.
- No fief, noble title, or mercenary contract is required for courtship.
- Target 5–7 substantial scenes spread over roughly 10–25 campaign days, interleaved
  with normal play; short delivery/audience exchanges are additional. This is a pacing
  target, not a mandatory waiting timer.
- Every invitation identifies the next location or action. Once a contact is established,
  letters allow rescheduling and finding a relocated partner.

### Chapter 1 — An introduction

**Scene:** a short audience at Ravensford. Edda is trying to secure help for the household's
villages while the house head wants a stronger field army.

The player asks about her work, boasts about recent victories, or offers a practical
service. These reveal different aspects of her character; none should instantly end the
route. A clear follow-up offers “I would like to know you better,” “I came to offer help,”
or “Another time.” Mutual interest enables the romantic route; service enables the
friendship route. Both can undertake the same political problem.

**Completion:** record the introduction, a discovered interest, and the chosen intent;
grant +10 trust once. Do not create an engagement or family obligation.

### Chapter 2 — Something of your own

**Scene:** Edda shares a personal ambition beyond managing the estate: preserving local
accounts and songs from villages repeatedly caught in the war.

Choose one authored personal action: visit a named villager to recover an account, bring
news of someone she asked about, or learn a short local verse and discuss its meaning.
The verse route is a brief conversation choice, not a new bard or collectible system.
All routes include a private conversation in which the player can ask a question and
express a view. Picking the most flattering line is not required.

**Completion:** +15 trust, one personal memory, and a clear statement of what she values.
Optional romantic wording is replaced by friendship wording if romance was declined.

### Chapter 3 — An obligation shared

**Problem:** the household needs help protecting its people. Offer a feasible objective
from the actual world state, with a peaceful alternative always available:

1. **Fund a muster:** contribute up to 300 silver toward an understrength household lord
   or its eligible garrison. The money is reserved for recruits, and the quest completes
   when some of it actually recruits men. Section 8 defines the accounting.
2. **Defend the district:** help win an existing village-defense or relief encounter tied
   to that house. Do not spawn an otherwise unjustified war or count unrelated bandit wins.
3. **Broker a contribution:** visit the house head and a second friendly house contact,
   secure an explicitly accepted contribution from available funds, and deliver the
   agreement. This is the low-cash path; contacts cannot promise money they do not have.

At offer time, validate all targets and show only feasible variants. If no military need
or donor exists, offer a correspondence service between two accessible house contacts;
it builds standing without inventing a resource reward. A changed world can rebind an
unfinished objective after the player is informed.

**Completion:** +15 trust and +15 house standing once. State the actual result, such as
“Your contribution paid for eight replacements,” instead of a generic success message.
Only one variant awards chapter credit; switching objectives cannot duplicate rewards.

### Chapter 4 — Between two loyalties

**Conflict:** the house head favors an offensive commitment while Edda wants a promise
to defend the district first. This is a conversation about a real commitment the house
can make, not a requirement to stage an AI siege on demand.

| Choice | Resolution | Initial consequence |
|---|---|---|
| Negotiate a limited defense agreement | Speak to both parties and agree on one named place and a bounded service | +15 trust, +10 house standing; a completed agreement memory |
| Publicly support Edda against the house's plan | Acknowledge that the house may withhold approval | +15 trust, −10 house standing; independent route remains available |
| Promise Edda help, then openly choose the house's demand instead | The broken promise is discussed explicitly | −10 trust, +10 house standing; commitment paused until repaired |
| Decline to intervene | Explain that you cannot keep this obligation | No penalty; chapter stays open and can be resumed |

The repair branch requires acknowledging the breach and fulfilling one concrete replacement
promise. It awards +25 trust once after the −10 result, returning the route to the same
trust total as an honest resolution. It cannot be repeated to farm trust. If the player
refuses repair, friendship or an orderly ending remains possible.

### Chapter 5 — What we choose

A final private conversation gives +10 trust once. On the uncomplicated route the total
is now 65 trust and 25 house standing. Offer the following outcomes only after their
conditions are met; show unmet conditions in ordinary language.

| Outcome | Requirements | Result |
|---|---|---|
| Public engagement and marriage | Mutual romantic intent, trust ≥60, personal and shared chapters complete, house standing ≥25, no unresolved breach | Schedule ceremony; negotiate an optional house pact separately |
| Private vows | The same personal requirements, mutual acceptance of a private ceremony; house approval not required | Marriage can proceed; house standing −10 once if approval is bypassed; no automatic pact |
| Close friendship and sworn cooperation | Shared chapters complete, house standing ≥25; romantic intent not required | Negotiate the same core house pact without marriage |
| Remain close without a commitment | Player or candidate is not ready | Preserve progress; no timer or hidden rejection roll |
| Part respectfully | Explicit player choice | Close courtship, preserve memories and earned standing |

Private vows are not a shortcut to military benefits. A later reconciliation commission
can restore house standing and unlock the ordinary pact terms. A hostile realm still
controls access and military assistance regardless of the couple's personal wishes.

### Ceremony

Choose a mutually accessible friendly/neutral court and schedule a six-hour visit. The
initial ceremony costs 100 silver and 100 rations; both amounts are shown beside the
warband's remaining food and wages. A simple private ceremony costs no resources and
has different writing, not a weaker spouse. The house opposition penalty applies only
when approval is actually being bypassed, not simply because the ceremony is modest.

Private ceremonies may use any accessible friendly/neutral settlement, including a village;
they do not require access to a noble court. The map must simulate those six hours through
its normal time/upkeep flow. A siege,
capture, or loss of access postpones the ceremony and provides a new meeting option.
Reserve costs on confirmation, spend them on completion, and refund on cancellation.
Do not require an AI feast, transfer land, change realms, or alter the player's contract.

## 7. Romance state and failure rules

```text
unknown → acquainted → courting → committed → engaged → married
                    ↘ friendship → shared projects and house pact
```

Friendship is an alternative end state with shared political content. Implement explicit states and edges:
`unknown`, `acquainted`, `courting`, `committed`, `engaged`, `married`, `friendship`, `ended`.
Interest is a mutual flag. `paused` and `strained` are overlays with reason codes, not
states that discard the last completed chapter. Chapter progression is stored separately
from romantic status so the friendship route can complete the entire quest.

| Event | Personal outcome | Political/quest outcome |
|---|---|---|
| Player loses a battle | No automatic trust loss | A specific unfulfilled promise may need rescheduling |
| Partner's settlement falls | Same person and relationship | Relocate, update destination, suspend inaccessible objectives |
| War starts between relevant realms | Personal relationship persists | Hostile military support suspends; meetings use safe locations or wait |
| House head dies or changes allegiance | Partner remains the same person | Pause grants/military help until a successor reaffirms eligible terms; no inherited personal opinion |
| Partner is captured after prisoner support ships | Mark unavailable, preserve progress | Offer recovery/ransom branch; pause personal deadlines |
| Player attacks the pact's protected people | Explicit breach conversation; trust −20 | Suspend pact and apply house standing −25 once per deliberate incident |
| Player misses an optional visit | No loss | Reschedule |
| Player breaks a clearly accepted deadline | One stated consequence | Allow explanation, replacement service, or cancellation |
| Player chooses separation after marriage | Preserve character and history | Close personal union; review linked obligations rather than declare automatic war |

Voluntary separation is supported in the first complete release; widowhood is reserved
for a future design that permits partner deaths. Neither separation nor changing partners
resets a house's reward history or shared assistance cooldowns.

Relocation order: another accessible seat of the same house, its realm's surviving capital,
then a neutral refuge town. If none is available, keep a saved `displaced` state and allow
letters; never delete the character or spawn them inside an enemy battle. Retry destination
selection when ownership/access changes, not every frame.

Loss of every holding does not delete a house. Contacts can remain in exile, with military
aid unavailable until they have a valid force/allegiance again. If the player has no safe
meeting place anywhere, explicitly pause the ceremony until access changes; do not invent
a neutral settlement or force the player through a hostile gate.

## 8. How the side quest strengthens allies

### A house pact is a limited agreement

A pact records the house, the player, any named lord who agreed to serve, protected places,
and current political eligibility. Forming it requires standing ≥25, a completed shared
service, and explicit assent from the current head. The agreement grants +10 house standing
once, whether its origin was marriage or friendship.

At launch, allow up to three house pacts, one per candidate house, with only one military
assistance assignment active for the player at a time. Marriage does not stack a second
copy of the same pact. Pact duties are offered projects, not automatic daily obligations.

### Support actions

| Action | Player/house commitment | Concrete effect | Availability |
|---|---|---|---|
| Sponsor replacements | Player reserves up to 300 silver for a named lord or garrison | Actual recruits paid at existing unit prices and within existing daily limits | First release; eligible political partner and depleted target required |
| Emergency household grant | House's named lord transfers up to 150 silver from its own purse, retaining at least 300 | Helps player pay wages or buy supplies; no money is created | First release; one grant per 14 days globally across player pacts |
| Request district defense | Named willing lord undertakes one defensive assignment for at most 48 hours | An existing party travels to defend a named eligible place | After 4.3 armies and 4.5 allied encounters; shared 14-day military cooldown |
| Mediate a household dispute | Complete a post-commitment conversation/project | Removes a specific dispute blocker so the named lord can consider cooperation again | First release can clear pact blockers; marshal/army effects require 4.3/4.5 |

Keep a small first release: sponsoring replacements and the emergency grant are required.
Military assistance is a separate integration milestone. Men remain under their lord's
command; the player never receives control of an entire realm through marriage.

### Replacement funding: exact accounting

1. Select an understrength target tied to the pact. Show current men/capacity, estimated
   replacements at current unit prices, maximum contribution, and expected recruitment site.
2. Debit the player's silver into a saved project escrow. Its amount is fixed on acceptance;
   no recurring deduction or debt is created.
3. On an eligible recruitment day, consume escrow before ordinary funding for that target.
   Count these recruits inside the existing daily cap. Lords must be at their eligible
   recruitment seat, and garrisons must still be held by the eligible realm/house arrangement.
4. Record recruits and actual expense. XP dilution and unit limits follow the existing
   recruitment path; no free training or permanent combat multiplier is awarded.
5. Refund unused money when the project completes, is cancelled, or reaches seven days.
   If the target becomes hostile, cancel and refund the unspent balance immediately.
6. Bind funding to a stable lord person ID or settlement plus expected owner. Do not let
   an enemy conqueror inherit an unspent player subsidy.

A house is not a new autonomous treasury. Lord purses and realm treasuries remain the
authorities; project escrow is earmarked player money. Extract a shared recruitment-budget
helper if needed, rather than running `_refill()` twice. Ordinary reserve protections stay
in place. Funding may change who pays without increasing recruits when the ally could
already afford them; the preview must distinguish replacement need from funding need.

Only the first qualifying service per chapter grants its trust/standing reward. Later
donations improve real readiness without creating an infinite relationship generator.

### Military help: eligibility and limits

When implemented, a request succeeds only if the named lord is free, politically eligible,
not already in a marshal's army, above its retreat strength threshold, and able to reach
the target. Defense of its own threatened seat takes priority. Display reasons such as
“Rebuilding at Ravensford” or “Already riding with the marshal.”

Accepted help creates a normal saved job/route. It uses actual troops, travel time, wages,
and battle losses. Do not teleport reinforcements or prevent casualties. The cooldown
starts when help is accepted; invalid requests spend nothing. If the order becomes invalid
before departure, cancel without consuming the cooldown. Once deployed, the cooldown stays.

A pact never overrides realm war rules or the player's mercenary contract. Eligibility is
checked on offer, acceptance, departure, and participation in battle. A political change
suspends conflicting military obligations and explains why; it does not erase the marriage.

## 9. After the wedding or friendship pledge

The relationship should continue to produce occasional choices, not become a passive buff
or a maintenance chore. Ship one shared project first; add the others after testing.

### First project — “The Empty Chairs”

Two household contacts disagree over responsibility for a failed defense. The partner asks
whether the player will help bring them to the same table. The player can hear both accounts,
fund replacements for the depleted side, or negotiate a limited division of duties.

The player sees the actual dispute and resources involved. A fair agreement removes that
specific dispute blocker and grants +5 standing with each participating house once. It does
not raise every lord's relationship or force an unwilling lord to join an army. If no dispute
exists, do not manufacture hostility merely to offer this quest; use a joint muster project
instead, with the same capped completion standing reward.

### Later projects

- **“A Table for Allies”:** pay for a small gathering with a known guest list. Each eligible
  attending contact receives one modest standing improvement; absent or hostile contacts
  receive nothing. Costs, attendance rules, and a 30-day reward cooldown need separate tuning.
- **“A Road Home”:** after 4.6, help recover a captured household member. Release/ransom
  events provide the resolution, and the player gets a lasting personal memory.
- **“Two Houses, One Promise”:** optional matchmaking between consenting adult NPCs to
  connect two existing allies. Deferred until the player's own route and house pacts work;
  requires two independent acceptances and offers mediation if either declines.

Offer no more than one relationship project at a time. Use letters or a journal badge;
do not interrupt battles or repeatedly pause normal travel for optional conversations.

## 10. Menus and player communication

### Entry points

- **Settlement → Court:** list current residents and available audiences. Show the person,
  role, house, next useful action, and whether they are elsewhere.
- **Map Menu → People & Letters:** known contacts, the active personal quest, house pacts,
  and unread letters. Keep Settings on its separate existing page.
- **Contact page:** portrait, current location, relationship description, house standing,
  recent memories, next step, and relevant actions. Unknown residents remain silhouettes
  or text entries until introduced; never conceal a required destination behind randomness.
- **Quest detail:** current objective, why it matters, destination, declared costs, any
  accepted deadline, and available alternatives. A “Show on map” action marks the location;
  it does not silently start travel.

Example contact card:

```text
Edda · Steward of the Ravensford household
Courting · Trusting · At Highcliff after Ravensford fell

She remembers that you kept your promise to Thornwall.
Next: discuss a limited defense agreement with her house head.

[Continue the conversation]  [Show on map]
[House pact]                 [Recent memories]
```

Example pact card:

```text
Ravensford household · Cooperation suspended
Reason: your employer is at war with this house's realm.

Your personal relationship with Edda is unchanged.
Letters remain available. Military support resumes when eligible.
```

### Interaction rules

- Use `scripts/ui/menu_page.gd` and existing theme/safe-area helpers. Validate the current
  720×1280 logical canvas at 405×720 window size, plus narrower phone layouts.
- Keep choice buttons at least `Style.TOUCH` high (currently 80 logical pixels), support
  keyboard focus/back, wrap dialogue, and avoid horizontal scrolling.
- Show trust/standing changes with a reason. Do not communicate availability only through
  color or hide essential requirements in hover tooltips.
- Ordinary dialogue pauses the map. Only explicitly accepted timed activities advance it;
  those queue normal travel/wait actions and return to the map so upkeep and interruptions
  work normally. Reading letters consumes no campaign time.
- Marriage, separation, private vows against the house's wishes, and financial commitments
  get a consequence preview and explicit confirmation. Cancel is focused initially.
- Keep resource icons and supply warnings readable while previewing a cost. Estimate food
  and wages remaining after a contribution, without silently preventing a deliberate spend.
- Optional invitations use an unread badge. A critical breach or required choice waits for
  a safe map moment, behind battle results and the existing desertion warning. Save pending
  notices and acknowledge them explicitly so quitting cannot lose the explanation.
- During autoplay, ignore optional invitations; dedicated romance smoke tests exercise
  their screens. Do not let a letter stall the existing campaign autoplay.

### Optional romance setting

Add “Romance invitations” to the existing standalone Settings page. It controls unsolicited
romantic invitations and suggested romantic dialogue, not friendship quests or political
features. Turning it off during courtship preserves the relationship and quest, suppresses
new romantic prompts, and leaves an explicit route to resume or end it. It does not marry,
separate, or erase history on the player's behalf. Essential notices about an existing
commitment remain available in People & Letters.

Store this preference alongside current preferences without overwriting audio or terrain
hints. Existing campaigns default to invitations enabled, with no relationship preselected.

## 11. Technical implementation

### Ownership and boundaries

Use a small pure-logic `SocialSim` owned and serialized by `WorldSim`. It holds people,
houses, relationship/quest state, pacts, project escrows, and durable letters. Keep world
rules independent of screens and the Godot scene tree, following the Phase 4 architecture.

`GameState` remains authoritative for player silver, food, renown, and the warband. It
coordinates a validated social command with the world, applies its costs/effects once,
and saves the whole campaign. `WorldSim` remains authoritative for lords, settlements,
recruitment, war status, and time. Do not duplicate lord purses or realm ownership in
social records. Existing captain bonds remain in their current subsystem.

Create a compact authored quest/state runner for this feature. It needs conditions,
choice IDs, objective bindings, consequences, and once-only rewards. It does not need a
visual dialogue editor or a general-purpose scripting language.

### Proposed state records

| Record | Required fields and invariants |
|---|---|
| Person | Stable `id`, `content_id`, display name, adult age, pronouns, role, culture, `house_id`, optional `lord_id`, residence/status, interests, boundaries; IDs never depend on party IDs |
| House | Stable `id`, display name, head person ID, member IDs, seat; political realm resolved through its current head; standing with player |
| Relationship | Candidate ID, trust, mutual-interest flags, status, paused/strained reasons, current intent, current partner ID, milestone flags, event/memory history |
| Quest instance | Unique ID, content version, chapter/node, bound targets, objective progress, chosen branch, start hour, optional accepted deadline, pause reason, consumed reward keys |
| Pact | House ID, status, origin, consenting signatories, terms/protected sites, eligibility reasons, active assignment, creation hour |
| Support project | Unique ID, beneficiary person/site and expected allegiance/owner, escrow total/remaining/spent/refunded, recruits funded, created/expiry hours, settlement status |
| Letter/notice | Unique ID, sender ID, template key and saved arguments, related quest ID, created hour, read/acknowledged state, current action destination |
| Pending player settlement | Unique command/project ID, validated silver/food credit, source escrow, applied flag; saved until GameState completes the transfer |
| Player social limits | Current courtship/spouse, global last grant hour, global last military-help hour, active military assignment ID, next social event ID |

Keep critical milestone/reward keys permanently. Cap presentation-only recent memories
at 30 per person and archived routine letters at 50, while retaining active objectives,
unread critical letters, commitment history, and reward ledgers. Pruning display history
must never allow replaying rewards.

### Stable initialization and migration

- Assign explicit person IDs to existing lords without replacing their numeric lord IDs.
  Introduce house IDs separately. Initially one lord can head one house; complex family
  trees are unnecessary.
- Preserve existing names. For old saves without a separate house name, use a fallback
  such as “Household of [lord name]”; do not split arbitrary surnames out of display text.
- Candidate bindings use the initial castle holder if still identifiable; otherwise use
  a deterministic non-ruling lord of the matching culture, ordered by stable ID. Store
  the chosen binding once. A missing castle holder must not prevent initialization.
- Generate any social variation using a versioned separate seed/stream. Opening a menu
  or loading an old save must not consume the world's existing RNG stream and change wars
  or battle outcomes. Courtship choices themselves resolve by saved facts, not rerolled
  persuasion chances.
- Increment `SAVE_VERSION` from the version current when implementation lands. It is 5
  now, so 6 is the expected next version only if another feature has not already used it.
- Old saves receive unintroduced candidates, neutral house standing, no pacts or romance,
  and empty escrows. Existing captains, bonds, money, borders, RNG state, and warning/help
  acknowledgments are preserved. Initialize before an invitation can be shown.
- Update lord cleaners/serializers to retain person/house links. Validate references and
  numeric values, preserve missing-content quests as paused with a diagnostic, and never
  silently refund an escrow twice while repairing a save.

### Commands, events, and saving

Suggested public entry points, with names finalized during implementation:

```text
SocialSim.available_actions(person_id, world_view, player_view)
SocialSim.preview_choice(quest_id, choice_id, context)
GameState.choose_social_action(action_id, expected_revision)
SocialSim.on_campaign_event(event)
SocialSim.on_day_changed(day, world_view)
SocialSim.to_dict() / from_dict(data)
```

Every preview returns availability, reason, costs, expected effects, and required context.
Revalidate at confirmation. A screen should never mutate trust, grant money, or advance a
quest by setting dictionary fields directly.

Campaign events need stable IDs and enough context to establish eligibility: actor person,
house/realm, place, battle/objective ID, outcome, and campaign hour. Feed them to social
logic where world/gameplay mutations occur, **before** the map consumes and clears its
transient `world.events`. UI event consumption must not be required for quest progress.

Examples: `lord_aided`, `village_defended`, `recruits_funded`, `ownership_changed`,
`war_declared`, `peace_made`, `contract_changed`, and later `person_captured`,
`person_released`, `person_succeeded`. Attribute each completed objective once, including
when auto-resolve and a later result screen both describe the same fight.

Costs, status transitions, rewards, and consumed event keys are one command result. Apply
them together in memory; then save together. Introduce a temporary-file-and-rename save
path with failure reporting so an interrupted write cannot leave a half-written campaign.
The UI disables duplicate submissions and retains the result until saving succeeds or
the player is told it failed. Reopening a screen is never a reason to apply rewards again.

World-triggered refunds use a durable pending-settlement queue. `GameState` drains it after
world advancement and before showing balances or saving a command result. Until credited,
the money stays in locked remaining escrow and the project cannot spend it; mark it refunded
only in the same operation that credits the player. This keeps headless world logic free
of the `GameState` singleton and preserves the accounting invariant across interruptions.
The same ledger can reserve/refund ceremony resources, with both silver and food accounted
for separately. It is not a second source of player money.

All timers use `world.hour`. Advance social timers during actual world ticks/day changes,
not wall-clock time or only once after a long `GameState.advance()` call. When a multi-day
wait is interrupted by an encounter, process only the time that really elapsed. Process
political changes before recruitment/assistance that would become invalid at that time.

### Files to change or add

New paths below are planned, not already present.

| File | Work |
|---|---|
| `scripts/data/relationships.gd` (new) | Tunables, status labels, pact limits, scoring, and pure eligibility helpers |
| `scripts/data/romance_stories.gd` (new) | Authored candidates, chapters, choices, prerequisites, dialogue keys, and reward IDs |
| `scripts/world/social_sim.gd` (new) | Persistent people/houses, quest progression, memories, letters, pacts, and project accounting |
| `scripts/world/world_sim.gd` | Own social sim; stable lord/person/house links; event delivery; recruitment funding and later assistance jobs; serialization |
| `scripts/game_state.gd` | Command coordination, player costs/refunds, event delivery for player results, migration, safe saving |
| `scripts/data/lords.gd` | House initialization helpers and any shared lord support tunables |
| `scripts/world/settlement_screen.gd` | Court entry, audience availability, return navigation |
| `scripts/menu/people.gd`, `scripts/menu/conversation.gd` (new) | Contact/journal UI, dialogue choices, previews and confirmations |
| `scenes/people.tscn`, `scenes/conversation.tscn` (new) | Thin scene wrappers following existing menu conventions |
| `scripts/world/map_screen.gd` | People & Letters entry, location markers, saved notice delivery, modal time/input protection |
| `scripts/ui/scenes.gd` | Explicit return routing and selected-contact/quest navigation context |
| `scripts/menu/settings.gd`, existing preferences helper | Romance invitation preference, preserving current preference keys |
| `tests/relationship_tests.gd` (new) | State, economy, event attribution, migration, and deterministic simulation checks |
| `tests/menu_tests.gd` | Court/contact/dialogue navigation, pause behavior, confirmation and phone-layout checks |
| `tests/plans.gd` | Scripted romance, friendship, refusal, disrupted-world, and ally-support campaigns |
| `tests/fixtures/` | Real pre-feature save and completed/paused relationship save fixtures |
| `README.md`, `docs/NEXT.md` | As-built behavior and the next bounded implementation task after each completed milestone |

## 12. Implementation order and completion gates

Estimates are rough solo engineering/content days, excluding unfinished Phase 4 dependencies
and final art. Prefer one reviewable commit per completed substep. A full three-character
release is approximately 4–7 weeks after prerequisites; reassess after the first story.

| Step | Work | Dependencies | Exit gate | Estimate |
|---|---|---|---|---|
| R0: people and standing | Stable person/house IDs; shared Phase 4.5 standing; social save/migration; event and command contracts | Coordinate with 4.5 rather than create a competing relation system | Old saves migrate deterministically; party replacement preserves relationships; no RNG drift | 3–4 days |
| R1: conversations and journal | Court entry, contact page, small quest runner, previews, letters, pause/back behavior | R0 | One introduction works through save/reload and both romantic/friendly choices | 3–4 days |
| R2: complete Edda story | All five chapters, repair branch, friendship/private/public endings, ceremony, separation | R1 and usable 4.5 politics | Every route reaches a valid ending; changed ownership/war never traps progression | 4–6 days |
| R3: useful house pact | Replacement escrow, grant, recruitment attribution, eligibility, first joint project | R0–R2; existing lord/garrison economy | Funded recruits and purse transfers reconcile exactly; all limits survive reload | 3–5 days |
| R4: campaign integration | Military assistance, treaty/contract suspension, prisoner/succession hooks when available | R3, 4.3/4.5 for assistance; 4.6 for captivity/succession | Real allied party moves and participates correctly; no hostile cross-realm help | 3–5 days |
| R5: cast and polish | Farah/Kaede variants, portraits, invitations preference, phone QA, pacing/balance passes | First route is fun and stable | **Implemented:** three distinct routes, equivalent core pact access, registered art, and automated presentation coverage | Complete |

**Smallest shippable version:** R0–R3 plus the invitation preference and essential UI/save
validation, with one candidate and one post-commitment project. Clearly expose only
implemented support actions. R5's larger cast is complete; R4's troop call remains future campaign integration.

During R2, use the correspondence or already-supported defense variant to exercise Chapter 3.
Wire funding, brokered transfers, and actual pact benefits in R3. R2 alone is an internal
story prototype; it must not advertise functional financial rewards before R3 exists.

Do not start with three nearly empty storylines. Do not delay the useful alliance result
until after all portraits, wedding variants, and flavor writing are complete.

### First bounded implementation task

After the common standing API is established, add stable person/house references and a
versioned social save containing one unintroduced court resident. Add a Court entry showing
their role and location, plus one introduction with romantic-interest and friendship
choices. Save and reload that choice. This proves identity, navigation, event handling,
and persistence before adding a long quest or monetary reward.

## 13. Validation and acceptance criteria

### State and story tests

- Introduction, chapter reward, repair reward, pact formation, wedding, separation, and
  project completion are each applied exactly once under repeat input and reload.
- The ordinary five-chapter route reaches 65 trust and the public house threshold without
  repeat gifts or grinding. The friendship route reaches the same core pact capabilities.
- Private vows work without approval, apply their stated consequence once, and can later
  reconcile. A modest approved ceremony does not trigger the opposition penalty.
- An unavailable or declined romance remains a valid friendship/contact. Mutual-interest
  flags and story prerequisites cannot be bypassed by a high trust number.
- One active courtship/spouse is enforced; separation preserves house cooldowns, reward
  ledgers, and personal history. No second reward for remarrying the same person.
- Every objective has a feasible initial binding and a recovery path when its target is
  lost, becomes hostile, is already full, lacks money, or disappears.

### Economy and political tests

- For every support project: `contributed = remaining escrow + spent + refunded`, at all
  save points. No negative balances, double refunds, or recruitment above unit/daily caps.
- Grant transfers reduce an actual lord purse by exactly the player gain, respect the
  300-silver reserve, and enforce the global 14-day cooldown across all pacts and spouses.
- A contribution to an already funded ally is presented as paying its costs; the system
  does not claim an extra troop benefit when the baseline would recruit the same men.
- Conquered garrisons and hostile beneficiaries never spend reserved player funds.
- A request for military aid cannot use a captive, retreating, already assigned, hostile,
  or unreachable lord. Accepted help uses normal movement, upkeep, loss accounting, and
  the intended shared cooldown.
- A new war, contract, or allegiance change suspends invalid help without destroying a
  personal relationship. Relations with a house do not override realm hostility.
- Political changes at a recruitment boundary are processed consistently during one long
  wait versus many short waits, including an encounter interrupting either run.

### Persistence and world simulation

- Load a real version-5 pre-feature save, migrate twice, and confirm no duplicate people,
  changed world RNG, resource changes, or lost tutorial/bond/desertion acknowledgments.
- Round-trip saves at every chapter and with active escrow, scheduled ceremony, unread
  letter, suspended pact, relocated partner, and later active military assistance.
- Compare uninterrupted and save/reload campaigns under the same seed/actions, using the
  repository's established numeric tolerance for JSON world state.
- Destroy and recreate a lord's party; retain the person and relationship. Replace a lord
  through the future succession event; retain the house but allocate a new person.
- Run 20 seeded 90-day social/campaign scenarios. No orphaned active objectives, trapped
  funds, unavailable mandatory dialogue, duplicate rewards, or hostile aid deliveries.
- Run a no-romance baseline: no compulsory expenses, unrequested marriages, recurring
  interruptions, or additional world RNG consumption. Simulation overhead should stay
  within 5% of the unchanged build on the same machine; use event/day processing rather
  than per-frame scans and retain existing Phase 4 performance gates.

### UI and playtest gates

- Verify Court → contact → conversation → quest → map and Settings return navigation.
  Opening or cancelling a menu cannot spend money, progress a quest, or advance time.
- Visually inspect 405×720 and a narrower 360×640 window, long names, relocated contacts,
  maximum dialogue length, all consequence previews, and the resource warning overlap.
- Test keyboard/back navigation and touch targets; disabled actions show a readable reason.
- A player can identify the next step and explain why support is unavailable without a
  wiki. The optional verse scene cannot become an essential guessing puzzle.
- Play one romance, one friendship-only run, one private-vow/reconciliation run, and one
  campaign that deliberately ignores the feature. Confirm the story fits between normal
  activities and never forces the player to abandon a viable campaign.
- Run existing focused save/upkeep/lord/garrison checks and menu/autoplay tests. Run the
  broader campaign suite when world jobs or budgets change; leave phase-end battle balance
  sweeps to the established roadmap unless combat behavior changes.

## 14. Decisions to revisit after the prototype

These have proposed defaults so implementation can be scoped, but they are design choices,
not previously approved changes to the entire game:

| Decision | Proposed default | Revisit when |
|---|---|---|
| Can romanceable characters join battles? | Court residents only | Captain survival and long-term character progression are settled |
| Is family approval required for love? | No; it affects house cooperation | Private-vow route is playtested |
| Does marriage grant an alliance automatically? | No; pact has separate terms and eligibility | Kingdom diplomacy exists |
| Is romance required for the strongest political tools? | No; friendship can earn core pact benefits | Compare romance and friendship campaigns |
| How many candidates and commitments? | Three authored candidates; one active romance/spouse | First complete story proves affordable to author and maintain |
| Are all candidates available to every player gender? | Yes, with character-specific mutual choices | A fuller player identity/character creator is designed |
| Can relationships end? | Explicit separation and repair; no passive decay | Long campaigns reveal whether stronger complications add value |
| Do we simulate NPC marriages and children? | No | Houses, succession, and the player's own route are mature |

The first playtest should answer whether the player remembers the partner's personal goal,
cares about a difficult choice, and can point to a concrete allied force or political
relationship their shared effort improved. If those are missing, add better scenes and
consequences before adding more romance meters.
