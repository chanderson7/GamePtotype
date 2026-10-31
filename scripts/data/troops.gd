## Troop types and the counter loop. Pure data shared by battles and, later, the war map.
##
## Counter loop: spearmen beat cavalry, cavalry beat archers, archers beat infantry,
## infantry beat spearmen. Bonus multipliers below are what make that true in the sim.
extends RefCounted

const INFANTRY := "infantry"
const SPEARMEN := "spearmen"
const ARCHERS := "archers"
const CAVALRY := "cavalry"

## Display and recruit order.
const ORDER := [INFANTRY, SPEARMEN, ARCHERS, CAVALRY]

## Which type answers a given threat (used by the enemy commander to pick targets).
const COUNTERED_BY := {
	CAVALRY: SPEARMEN,
	SPEARMEN: INFANTRY,
	INFANTRY: ARCHERS,
	ARCHERS: CAVALRY,
}

## Per-soldier stats. Distances are in arena units (the field is 840 x 1260), speeds in
## units a second, cooldown in seconds between blows or shots.
## size: soldiers in a full squad.
## reach: melee distance (gap between bodies). range: bow range for ranged troops.
## Hit points are high next to damage on purpose: a melee between two even squads takes
## the best part of a minute, which leaves time to see it coming and send help.
const TYPES := {
	INFANTRY: {
		"name": "Infantry", "size": 20,
		"hp": 600.0, "damage": 13.0, "cooldown": 1.0, "reach": 14.0, "range": 0.0,
		"speed": 40.0, "radius": 7.0, "ranged": false,
		"bonus": {SPEARMEN: 1.45},
		"blurb": "Swords and shields. Cuts through spear lines.",
	},
	SPEARMEN: {
		"name": "Spearmen", "size": 20,
		"hp": 540.0, "damage": 11.0, "cooldown": 1.1, "reach": 24.0, "range": 0.0,
		"speed": 38.0, "radius": 7.0, "ranged": false,
		"bonus": {CAVALRY: 2.3},
		"blurb": "Long reach. Braced spears stop a charge cold.",
	},
	ARCHERS: {
		"name": "Archers", "size": 20,
		"hp": 360.0, "damage": 40.0, "cooldown": 1.5, "reach": 0.0, "range": 250.0,
		"speed": 40.0, "radius": 6.0, "ranged": true, "arrows": 8,
		"bonus": {INFANTRY: 1.6, CAVALRY: 0.75},
		"blurb": "Shred slow infantry from range, until the arrows run out. Helpless when caught.",
	},
	CAVALRY: {
		"name": "Cavalry", "size": 16,
		"hp": 780.0, "damage": 15.0, "cooldown": 1.0, "reach": 14.0, "range": 0.0,
		"speed": 100.0, "radius": 9.0, "ranged": false,
		"bonus": {ARCHERS: 1.8},
		"blurb": "Fast and heavy. Charges hit hard, except into spears.",
	},
}

## Extra damage on a cavalry strike after a run-up (not against braced spearmen).
const CHARGE_MULTIPLIER := 6.0
const CHARGE_RUNUP := 60.0
## Archers caught in melee shoot rushed, at this fraction of their damage.
const POINT_BLANK := 0.2
## Archers out of arrows draw short blades: this damage, reach and pace, no bonuses.
const SIDEARM := {"damage": 7.0, "reach": 12.0, "cooldown": 1.2}
## Arrows aimed at a man locked in melee with your own troops miss this often: archers
## shoot wide rather than hit their own side. Volleys into troops still on the move
## land in full.
const MELEE_MISS := 0.65

## Each troop type has one ability, used from the squad's ability button. `seconds` is
## how long it lasts (0 for an instant one); `cooldown` is the wait before it can be used
## again, counted from when it was used.
const ABILITIES := {
	INFANTRY: {"name": "Shield wall", "seconds": 15.0, "cooldown": 30.0,
		"blurb": "Shields locked. Arrows and blows from the front barely land, but they move at half pace."},
	SPEARMEN: {"name": "Schiltron", "seconds": 15.0, "cooldown": 35.0,
		"blurb": "A ring of spears with no flank or rear to hit, and no charge lands. They stand fast."},
	ARCHERS: {"name": "Volley", "seconds": 0.0, "cooldown": 20.0,
		"blurb": "Every bow looses at once into one squad, harder, and shakes its nerve."},
	CAVALRY: {"name": "Wheel", "seconds": 0.0, "cooldown": 15.0,
		"blurb": "Break off, ride clear, and charge the same enemy again."},
}
## Shield wall: what's left of arrow and melee damage from the front, and the pace.
const SHIELD_WALL_ARROWS := 0.35
const SHIELD_WALL_MELEE := 0.75
const SHIELD_WALL_SPEED := 0.5
## Volley: extra damage per arrow, and morale the target loses in all if every man is hit.
const VOLLEY_POWER := 1.3
const VOLLEY_SHOCK := 8.0
## Wheel: how far the horse rides clear before turning to charge again.
const WHEEL_DISTANCE := 160.0

## Veterancy: experience is kills carried over between battles.
const XP_PER_LEVEL := 20
const MAX_LEVEL := 3


static func stats(type: String) -> Dictionary:
	return TYPES[type]


static func full_size(type: String) -> int:
	return int(TYPES[type]["size"])


static func display_name(type: String) -> String:
	return String(TYPES[type]["name"])


static func ability(type: String) -> Dictionary:
	return ABILITIES[type]


static func level_for(xp: int) -> int:
	return clampi(1 + int(float(xp) / XP_PER_LEVEL), 1, MAX_LEVEL)


## Each level above 1 adds 10% damage and health.
static func power_for(level: int) -> float:
	return 1.0 + 0.1 * float(level - 1)
