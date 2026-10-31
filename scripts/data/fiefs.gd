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

const IMPROVEMENTS := {
	IMPROVEMENT_GRANARY: {
		"name": "Granary & Stores",
		"cost": 300,
		"food_bonus": 15,
		"description": "Expanded granaries increase food reserves to 250 rations and yield +15 rations daily.",
	},
	IMPROVEMENT_FORTIFICATIONS: {
		"name": "Palisade & Watchtower",
		"cost": 450,
		"defense_mult": 1.35,
		"militia_bonus": 15,
		"description": "Timber palisades and a sturdy watchtower muster 15 militia, grant +35% defense strength, and spot raiders early.",
	},
	IMPROVEMENT_MILL: {
		"name": "Water Mill & Market Stalls",
		"cost": 400,
		"silver_bonus": 30,
		"description": "A bustling mill and covered market stalls stimulate local trade, yielding +30 silver in daily taxes.",
	},
}

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
