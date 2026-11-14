## Fiefdom and vassalage rules for player-held estates.
extends RefCounted

const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

const MIN_RENOWN := 50
const MIN_RELATION := 20

const BASE_TAX := {
	WorldData.VILLAGE: 50,
	WorldData.CASTLE: 90,
	WorldData.TOWN: 150,
}

const BASE_FOOD := {
	WorldData.VILLAGE: 12,
	WorldData.CASTLE: 6,
	WorldData.TOWN: 4,
}

const MAX_STORAGE_SILVER := 1500
const BASE_MAX_STORAGE_FOOD := 100
const GRANARY_MAX_STORAGE_FOOD := 250

const IMPROVEMENT_GRANARY := "granary"
const IMPROVEMENT_FORTIFICATIONS := "fortifications"
const IMPROVEMENT_MILL := "mill"
## A castle's or town's: siege works (oil over the gate, a stone thrower in the
## courtyard) and a third bolt thrower on the towers.
const IMPROVEMENT_SIEGE_WORKS := "siege_works"
const IMPROVEMENT_TOWER_BOLTS := "tower_bolts"

const IMPROVEMENTS := {
	IMPROVEMENT_GRANARY: {
		"name": "Granary & Stores",
		"cost": 300,
		"food_bonus": 15,
		"effects": ["+15 rations a day", "Stores 250 rations"],
		"description": "Expanded granaries increase food reserves to 250 rations and yield +15 rations daily.",
	},
	IMPROVEMENT_FORTIFICATIONS: {
		"name": "Palisade & Watchtower",
		"cost": 450,
		"defense_mult": 1.35,
		"militia_bonus": 15,
		"effects": ["15 militia join the defence", "+35% strength holding the village"],
		"description": "Timber palisades and a sturdy watchtower muster 15 militia and grant +35% defense strength against raiders.",
	},
	IMPROVEMENT_MILL: {
		"name": "Water Mill & Market Stalls",
		"cost": 400,
		"silver_bonus": 30,
		"effects": ["+30 silver a day in taxes"],
		"description": "A bustling mill and covered market stalls stimulate local trade, yielding +30 silver in daily taxes.",
	},
	IMPROVEMENT_SIEGE_WORKS: {
		"name": "Siege Works",
		"cost": 500,
		"walled": true,
		"effects": ["Oil over the gate", "A stone thrower in the courtyard"],
		"description": "Cauldrons over the gate and a stone thrower on a platform in the courtyard that outranges any besieger's.",
	},
	IMPROVEMENT_TOWER_BOLTS: {
		"name": "Tower Bolts",
		"cost": 300,
		"walled": true,
		"effects": ["A third bolt thrower", "Bolts loosed faster"],
		"description": "A third bolt thrower over the gate, and crews drilled to load all three faster.",
	},
}

## The order the Manor card lists them in.
const IMPROVEMENT_ORDER := [IMPROVEMENT_GRANARY, IMPROVEMENT_FORTIFICATIONS, IMPROVEMENT_MILL, IMPROVEMENT_SIEGE_WORKS, IMPROVEMENT_TOWER_BOLTS]


## The improvements a holding of `kind` can have: a palisade for a village, siege works
## and tower bolts for walls.
static func improvements_for(kind: String) -> Array:
	var walled := kind == WorldData.CASTLE or kind == WorldData.TOWN
	return IMPROVEMENT_ORDER.filter(func(k): return (k != IMPROVEMENT_FORTIFICATIONS or not walled) and (not bool(IMPROVEMENTS[k].get("walled", false)) or walled))

const REPAIR_COST := 200

const TITLES := {
	Cultures.VARDISH: "Lord",
	Cultures.KHARZANI: "Emir",
	Cultures.RYUMON: "Jito",
}


static func title_for(culture: String) -> String:
	return TITLES.get(culture, "Lord")


static func daily_tax(fief: Dictionary, is_burned: bool = false) -> int:
	if fief.is_empty():
		return 0
	var kind: String = String(WorldData.settlement(fief.get("settlement_id", "")).get("type", WorldData.VILLAGE))
	var tax: int = BASE_TAX.get(kind, 50)
	var imps: Dictionary = fief.get("improvements", {})
	if bool(imps.get(IMPROVEMENT_MILL, false)):
		tax += int(IMPROVEMENTS[IMPROVEMENT_MILL]["silver_bonus"])
	if is_burned:
		tax = int(tax * 0.25)
	return tax


static func daily_food(fief: Dictionary, is_burned: bool = false) -> int:
	if fief.is_empty() or is_burned:
		return 0
	var kind: String = String(WorldData.settlement(fief.get("settlement_id", "")).get("type", WorldData.VILLAGE))
	var food: int = BASE_FOOD.get(kind, 12)
	var imps: Dictionary = fief.get("improvements", {})
	if bool(imps.get(IMPROVEMENT_GRANARY, false)):
		food += int(IMPROVEMENTS[IMPROVEMENT_GRANARY]["food_bonus"])
	return food


static func max_food_capacity(fief: Dictionary) -> int:
	var imps: Dictionary = fief.get("improvements", {})
	return GRANARY_MAX_STORAGE_FOOD if bool(imps.get(IMPROVEMENT_GRANARY, false)) else BASE_MAX_STORAGE_FOOD
