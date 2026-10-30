## Captains: the named men and women who lead each squad. Pure data and rules shared by
## the battle (heroics, the death roll, grief, bonds) and the camp (names, memorial).
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")

## Two reusable faces per culture. The captain id chooses between them without
## consuming campaign RNG, so adding portraits never changes names or battle rules.
const APPEARANCES := {
	Cultures.VARDISH: ["vardish_01", "vardish_02"],
	Cultures.KHARZANI: ["kharzani_01", "kharzani_02"],
	Cultures.RYUMON: ["ryumon_01", "ryumon_02"],
}

## How a captain takes the fall of someone they're bonded to.
const VENGEFUL := "Vengeful"   # fights harder and won't break for a while
const STEADFAST := "Steadfast" # steadies the squad
const FRAGILE := "Fragile"     # the squad's nerve goes
const TEMPERAMENTS := [VENGEFUL, STEADFAST, FRAGILE]

## A second trait, or none.
const LUCKY := "Lucky"   # better odds on the death roll
const MENTOR := "Mentor" # bonds grow faster
const BOLD := "Bold"     # the squad holds its nerve better under them
const QUIRKS := [LUCKY, MENTOR, BOLD, "", ""]

const TRAIT_TEXT := {
	VENGEFUL: "turns to fury when a friend falls",
	STEADFAST: "holds firm when a friend falls",
	FRAGILE: "can break when a friend falls",
	LUCKY: "better odds of surviving a fall",
	MENTOR: "bonds grow half again as fast",
	BOLD: "the squad's nerve holds longer",
}

## In battle a captain is one of the squad's men, but a hardier one.
const HP_MULT := 4.0
const DAMAGE_MULT := 1.3
## Morale lost per man killed, scaled by how the squad is led.
const LED := 0.8
const LED_BOLD := 0.7
const LEADERLESS := 1.15
## Morale shock when the squad sees its captain go down.
const FALL_SHOCK := 15.0

## The death roll: a d100, and the captain dies on a roll at or under the death chance.
const DEATH_CHANCE := 45
const RESCUED_BY_SQUAD := 15    # his own squad still has half its men to drag him clear
const RESCUED_BY_FRIENDS := 15  # another friendly squad is close by
const LUCK := 15
const MIN_DEATH := 10
const MAX_DEATH := 90
const RESCUE_RANGE := 160.0
## Battles a wounded captain sits out.
const WOUND_BATTLES := 2

## Bonds: points earned by fighting side by side, about one for every ten seconds.
const BOND_RANGE := 170.0
const BOND_SECONDS_PER_POINT := 10.0
const BOND_POINTS_PER_BATTLE := 6.0
const RANKS := ["", "C", "B", "A"]
const RANK_POINTS := [0.0, 5.0, 12.0, 22.0]
## Per rank, while both captains fight within BOND_RANGE: morale regained per second
## and extra damage.
const RANK_REGEN := [0.0, 1.0, 1.5, 2.0]
const RANK_POWER := [0.0, 0.0, 0.1, 0.2]

## Grief, for a bonded captain's fall.
const FURY_SECONDS := 20.0
const FURY_POWER := 0.3
const FURY_MORALE_FLOOR := 40.0
const STEADY_MORALE := 15.0
const SHAKEN_MORALE := 20.0

## Given names, places of origin and company names come from each captain's culture
## (cultures.gd).

const LAST_WORDS := [
	"Tell them I held.", "Keep the line, lads.", "Not here... not yet.", "Finish it for me.",
	"I can see the hills of home.", "Don't let them break.", "Was it worth it? Say it was.",
	"Burn bright, all of you.", "Look after my blade.", "I'm sorry. I'm so sorry.",
]
const WOUNDED_WORDS := [
	"I'm hit! Get me out!", "Just a scratch... just a...", "Drag me back, I'll live.",
	"Damn it, my leg!", "Hold without me!",
]


## A new captain of `culture`. `id` must be unique across the warband; `taken` lists
## first names already in use, so two captains don't share one.
static func make(rng: RandomNumberGenerator, id: int, type: String, taken: Array = [], culture: String = Cultures.VARDISH) -> Dictionary:
	var names: Array = Cultures.info(culture)["first"]
	var origins: Array = Cultures.info(culture)["origins"]
	var first: String = names[rng.randi_range(0, names.size() - 1)]
	for i in 12:
		if not taken.has(first):
			break
		first = names[rng.randi_range(0, names.size() - 1)]
	return {
		"id": id,
		"appearance_id": appearance_for(culture, id),
		"name": "%s of %s" % [first, origins[rng.randi_range(0, origins.size() - 1)]],
		"first": first,
		"culture": culture,
		"type": type,
		"temperament": TEMPERAMENTS[rng.randi_range(0, TEMPERAMENTS.size() - 1)],
		"quirk": QUIRKS[rng.randi_range(0, QUIRKS.size() - 1)],
		"wounded": 0,
		"battles": 0,
		"kills": 0,
		"bonds": {},
		"history": {"wounds": 0, "fallen_friends": []},
	}


## A stable portrait for new captains and old saves. Old memorial entries did not
## retain an id, so their name supplies a small deterministic fallback key.
static func ensure_appearance(captain: Dictionary) -> String:
	var culture := String(captain.get("culture", Cultures.VARDISH))
	var valid: Array = APPEARANCES.get(culture, [])
	var current := String(captain.get("appearance_id", ""))
	if valid.has(current):
		return current
	var key := int(captain.get("id", 0))
	if key <= 0:
		key = _stable_name_key(String(captain.get("name", captain.get("first", ""))))
	current = appearance_for(culture, key)
	captain["appearance_id"] = current
	return current


static func appearance_for(culture: String, id: int) -> String:
	var choices: Array = APPEARANCES.get(culture, [])
	if choices.is_empty():
		return "fallback"
	return String(choices[posmod(maxi(1, id) - 1, choices.size())])


static func _stable_name_key(value: String) -> int:
	var key := 17
	for character in value.to_utf8_buffer():
		key = posmod(key * 31 + int(character), 2147483629)
	return maxi(1, key)


## "Brann's Pikes", in the captain's own culture's words.
static func company_name(captain: Dictionary, type: String) -> String:
	var culture := String(captain.get("culture", Cultures.VARDISH))
	return "%s's %s" % [captain.get("first", "Nameless"), Cultures.company_noun(culture, type)]


static func traits(captain: Dictionary) -> String:
	var q: String = captain.get("quirk", "")
	return String(captain.get("temperament", "")) + ("" if q == "" else ", " + q)


static func rank_for(points: float) -> int:
	var rank := 0
	for i in RANKS.size():
		if points >= RANK_POINTS[i]:
			rank = i
	return rank


static func rank_letter(points: float) -> String:
	return RANKS[rank_for(points)]


## The chance (in percent) that a captain who falls now dies of it.
static func death_chance(captain: Dictionary, squad_holding: bool, friends_near: bool) -> int:
	var chance := DEATH_CHANCE
	if squad_holding:
		chance -= RESCUED_BY_SQUAD
	if friends_near:
		chance -= RESCUED_BY_FRIENDS
	if captain.get("quirk", "") == LUCKY:
		chance -= LUCK
	return clampi(chance, MIN_DEATH, MAX_DEATH)
