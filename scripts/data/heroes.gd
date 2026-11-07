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
		"unit": "vardish_knights",
		"temperament": Captains.STEADFAST,
		"quirk": Captains.BOLD,
		"specialization": Captains.DRILLMASTER,
		"cost": 250,
		"origin_settlement": "highcliff",
		"appearance_id": "vardish_02",
		"dialogue": "I was cast out from House Dunmere for holding the gate against orders. Give me men who will not flinch, and I will train them into steel.",
		"bio": "Exiled knight of the Pale. Fought in the defense of Ravensford before taking to the wanderer's road.",
		"byname": "Sir Katherine",
		# At the fire after a battle (%s is her name; for "mourn", hers and then the fallen's).
		"camp": {
			"victory": "%s walks the line after the victory and makes every recruit name the soldier beside them. \"That's who you held for. Remember it.\"",
			"defeat": "%s drills the survivors at first light, defeat or no. \"We held the gate at Ravensford with fewer. Again.\"",
			"wounded": "%s sits by the fire with her arm bound, correcting the recruits' grips from where she sits.",
			"mourn": "%s stands a watch at %s's empty place, as a knight would, and lets no one take it from her.",
		},
		# Her talks at the fire with a bonded captain, by rank; she speaks first.
		"bond": {
			"C": ["You hold a line well. Who taught you?", "Nobody. I just didn't move.", "That's most of it. The rest is drill.", "Then drill me."],
			"B": ["I was cast out for holding a gate. I'd do it again, for you.", "That's not a compliment, is it?", "It's the only kind I have.", "Then I'll take it."],
			"A": ["If they cast me out of this company too, I'll hold whatever gate you're behind.", "They won't.", "No. But I wanted you to know where I'd stand.", "I know where you stand. Next to me."],
		},
	},
	TARIQ: {
		"id": TARIQ,
		"name": "Tariq Windrunner",
		"first": "Tariq",
		"culture": Cultures.KHARZANI,
		"type": Troops.ARCHERS,
		"unit": "kharzani_horse_archers",
		"temperament": Captains.VENGEFUL,
		"quirk": Captains.LUCKY,
		"specialization": Captains.SCOUT,
		"cost": 220,
		"origin_settlement": "khalun",
		"appearance_id": "kharzani_01",
		"dialogue": "The sands have no master, and neither do I. If you seek eyes on the road and arrows that find their mark in the dusk, my blade is yours.",
		"bio": "Former outrider of Qasr Hamra. Knows every dune and dry wadi between Khalun and the sea.",
		"byname": "Windrunner",
		"camp": {
			"victory": "%s counts the arrows recovered from the field, then the ones that weren't, and grins at the difference.",
			"defeat": "%s rides out alone before dawn and comes back with the name of every rider who followed you off the field.",
			"wounded": "%s lies by the fire, bandaged, swearing the arrow that found him was the luckiest shot in Kharzan.",
			"mourn": "%s fletches a single arrow in %s's colours and puts it in his quiver, unused.",
		},
		"bond": {
			"C": ["You were slow off the mark today.", "I was waiting for your arrows.", "My arrows wait for no one.", "That's why I wait for them."],
			"B": ["I rode ahead last night and counted their fires. I counted ours too.", "Ours? Why?", "To know how many I'd have to avenge.", "Count fewer. I'm staying alive."],
			"A": ["The sands have no master. Neither do I. But I'd ride behind you.", "Behind me?", "Behind, ahead, beside. Wherever the shot is.", "Then the sands have lost one."],
		},
	},
	MORI: {
		"id": MORI,
		"name": "Mori the Unbroken",
		"first": "Mori",
		"culture": Cultures.RYUMON,
		"type": Troops.INFANTRY,
		"unit": "ryumon_hatamoto",
		"temperament": Captains.VENGEFUL,
		"quirk": Captains.BOLD,
		"specialization": Captains.CHAMPION,
		"cost": 260,
		"origin_settlement": "kurogane",
		"appearance_id": "ryumon_02",
		"dialogue": "My lord fell at sea and left no heir to serve. I have no master now but the red road. Lead me to worthy foes, and my naginata will speak.",
		"bio": "A masterless hatamoto who survived the destruction of the island fleet. Known for unyielding fury in the press of shields.",
		"byname": "the Unbroken",
		"camp": {
			"victory": "%s cleans the naginata in silence, then bows once toward the sea.",
			"defeat": "%s kneels facing the field until the fire burns down. \"Not again,\" is all Mori says.",
			"wounded": "%s refuses to lie down, and sits upright by the fire, bandaged, the naginata across both knees.",
			"mourn": "%s sits at %s's empty place and recites the names of the island fleet's dead, and then one more.",
		},
		"bond": {
			"C": ["You fight without anger. I find it strange.", "You fight with enough for both of us.", "Perhaps that is why we stand well together.", "Perhaps."],
			"B": ["My lord left no heir. I have served no one since.", "You don't serve me.", "No. I stand beside you. It is a different oath.", "One I'll keep too."],
			"A": ["If you fall, I will not seek a new lord. I will seek the one who felled you.", "Then I'd better not fall.", "Yes. Do not.", "I won't. Eat something."],
		},
	},
}

## Every hero's given name: set aside, so no captain, lord or heir is given one of them.
const NAMES := ["Katherine", "Tariq", "Mori"]


## A hero's line at the fire for `kind` (victory, defeat, wounded, mourn), or "".
static func camp_line(hero_id: String, kind: String) -> String:
	return String(HEROES.get(hero_id, {}).get("camp", {}).get(kind, ""))


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
