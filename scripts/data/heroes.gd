## Unique wandering heroes (companions) available to recruit in taverns across the Glass Sea.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Units = preload("res://scripts/data/units.gd")

const KATHERINE := "katherine"
const TARIQ := "tariq"
const MORI := "mori"

const HEROES := {
	KATHERINE: {
		"id": KATHERINE,
		"name": "Sir Katherine of the Pale",
		"first": "Katherine",
		"culture": Cultures.VARDISH,
		"type": Troops.CAVALRY,
		"unit": "v_knight",
		"temperament": Captains.STEADFAST,
		"quirk": Captains.BOLD,
		"specialization": Captains.DRILLMASTER,
		"cost": 250,
		"origin_settlement": "highcliff",
		"appearance_id": "vardish_02",
		"dialogue": "I was cast out from House Dunmere for holding the gate against orders. Give me men who will not flinch, and I will train them into steel.",
		"bio": "Exiled knight of the Pale. Fought in the defense of Ravensford before taking to the wanderer's road.",
	},
	TARIQ: {
		"id": TARIQ,
		"name": "Tariq Windrunner",
		"first": "Tariq",
		"culture": Cultures.KHARZANI,
		"type": Troops.ARCHERS,
		"unit": "k_horse_archer",
		"temperament": Captains.VENGEFUL,
		"quirk": Captains.LUCKY,
		"specialization": Captains.SCOUT,
		"cost": 220,
		"origin_settlement": "khalun",
		"appearance_id": "kharzani_01",
		"dialogue": "The sands have no master, and neither do I. If you seek eyes on the road and arrows that find their mark in the dusk, my blade is yours.",
		"bio": "Former outrider of Qasr Hamra. Knows every dune and dry wadi between Khalun and the sea.",
	},
	MORI: {
		"id": MORI,
		"name": "Mori the Unbroken",
		"first": "Mori",
		"culture": Cultures.RYUMON,
		"type": Troops.INFANTRY,
		"unit": "r_hatamoto",
		"temperament": Captains.VENGEFUL,
		"quirk": Captains.BOLD,
		"specialization": Captains.CHAMPION,
		"cost": 260,
		"origin_settlement": "kurogane",
		"appearance_id": "ryumon_02",
		"dialogue": "My lord fell at sea and left no heir to serve. I have no master now but the red road. Lead me to worthy foes, and my naginata will speak.",
		"bio": "A masterless hatamoto who survived the destruction of the island fleet. Known for unyielding fury in the press of shields.",
	},
}


static func hero(id: String) -> Dictionary:
	return HEROES.get(id, {}).duplicate(true)


static func hero_for_settlement(settlement_id: String) -> Dictionary:
	for hid in HEROES:
		if HEROES[hid].get("origin_settlement", "") == settlement_id:
			return HEROES[hid].duplicate(true)
	return {}


static func make_hero_captain(hero_data: Dictionary, captain_id: int) -> Dictionary:
	return {
		"id": captain_id,
		"appearance_id": hero_data.get("appearance_id", "fallback"),
		"name": hero_data.get("name", "Hero"),
		"first": hero_data.get("first", "Hero"),
		"culture": hero_data.get("culture", Cultures.VARDISH),
		"type": hero_data.get("type", Troops.INFANTRY),
		"temperament": hero_data.get("temperament", Captains.STEADFAST),
		"quirk": hero_data.get("quirk", Captains.BOLD),
		"specialization": hero_data.get("specialization", ""),
		"wounded": 0,
		"battles": 3,
		"kills": 8,
		"is_hero": true,
		"hero_id": hero_data.get("id", ""),
		"bonds": {},
		"history": {"wounds": 0, "fallen_friends": [], "scars": []},
	}
