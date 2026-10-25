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

## Which type answers a given threat (used by the enemy commander).
const COUNTERED_BY := {
	CAVALRY: SPEARMEN,
	SPEARMEN: INFANTRY,
	INFANTRY: ARCHERS,
	ARCHERS: CAVALRY,
}

## Per-soldier stats. Distances are in arena units (the field is 720 x 1100).
## size: soldiers in a full squad. cost: command points to deploy.
## reach: melee distance (gap between bodies). range: bow range for ranged troops.
const TYPES := {
	INFANTRY: {
		"name": "Infantry", "short": "INF", "cost": 3, "size": 10,
		"hp": 100.0, "damage": 13.0, "cooldown": 1.0, "reach": 14.0, "range": 0.0,
		"speed": 50.0, "radius": 7.0, "ranged": false,
		"bonus": {SPEARMEN: 1.45},
		"blurb": "Swords and shields. Cuts through spear lines.",
	},
	SPEARMEN: {
		"name": "Spearmen", "short": "SPR", "cost": 3, "size": 10,
		"hp": 90.0, "damage": 11.0, "cooldown": 1.1, "reach": 24.0, "range": 0.0,
		"speed": 48.0, "radius": 7.0, "ranged": false,
		"bonus": {CAVALRY: 2.3},
		"blurb": "Long reach. Braced spears stop a charge cold.",
	},
	ARCHERS: {
		"name": "Archers", "short": "ARC", "cost": 3, "size": 10,
		"hp": 65.0, "damage": 11.0, "cooldown": 1.4, "reach": 0.0, "range": 230.0,
		"speed": 50.0, "radius": 6.0, "ranged": true,
		"bonus": {INFANTRY: 1.6, CAVALRY: 0.75},
		"blurb": "Shred slow infantry from range. Helpless when caught.",
	},
	CAVALRY: {
		"name": "Cavalry", "short": "CAV", "cost": 4, "size": 8,
		"hp": 130.0, "damage": 15.0, "cooldown": 1.0, "reach": 14.0, "range": 0.0,
		"speed": 120.0, "radius": 9.0, "ranged": false,
		"bonus": {ARCHERS: 1.8},
		"blurb": "Fast and heavy. Charges hit hard, except into spears.",
	},
}

## Extra damage on a cavalry strike after a run-up (not against braced spearmen).
const CHARGE_MULTIPLIER := 2.5
const CHARGE_RUNUP := 60.0

## Veterancy: experience is kills carried over between battles.
const XP_PER_LEVEL := 8
const MAX_LEVEL := 3


static func stats(type: String) -> Dictionary:
	return TYPES[type]


static func cost(type: String) -> int:
	return int(TYPES[type]["cost"])


static func full_size(type: String) -> int:
	return int(TYPES[type]["size"])


static func display_name(type: String) -> String:
	return String(TYPES[type]["name"])


static func level_for(xp: int) -> int:
	return clampi(1 + int(float(xp) / XP_PER_LEVEL), 1, MAX_LEVEL)


## Each level above 1 adds 10% damage and health.
static func power_for(level: int) -> float:
	return 1.0 + 0.1 * float(level - 1)
