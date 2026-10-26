## Culture troop trees and unit definitions. Pure data.
##
## Defines tier 1 recruits and branching tier 2 upgrade paths for all three
## cultures (Vardmark, Kharzan, Ryumon) across four roles: infantry, spearmen,
## archers, and cavalry.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

## All units in the game.
## Key: unit_id (String)
## Fields:
##   role: Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS, Troops.CAVALRY
##   culture: Cultures.VARDISH, Cultures.KHARZANI, Cultures.RYUMON
##   tier: 1 or 2
##   branch_of: id of the tier 1 unit it upgrades from (or "" for tier 1)
##   name: Display name
##   blurb: Short description
##   stats: Dictionary of stat overrides against Troops.TYPES[role]
##   mechanics: Dictionary of mechanical traits (armor, piercing, javelins, etc.)
##   cost_mult: Multiplier on recruit / training costs
##   wage_mult: Multiplier on daily wages
const UNITS := {
	# =========================================================================
	# VARDISH (Heavy, disciplined, armor & long pikes)
	# =========================================================================

	# --- Tier 1 ---
	"vardish_infantry": {
		"role": Troops.INFANTRY, "culture": Cultures.VARDISH, "tier": 1, "branch_of": "",
		"name": "Vardish Footmen", "blurb": "Sturdy levy footmen with arming swords and kites.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"vardish_spearmen": {
		"role": Troops.SPEARMEN, "culture": Cultures.VARDISH, "tier": 1, "branch_of": "",
		"name": "Vardish Spearmen", "blurb": "Common levies bearing spears and shields.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"vardish_archers": {
		"role": Troops.ARCHERS, "culture": Cultures.VARDISH, "tier": 1, "branch_of": "",
		"name": "Vardish Bowmen", "blurb": "Hunters and yeomen armed with self bows.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"vardish_cavalry": {
		"role": Troops.CAVALRY, "culture": Cultures.VARDISH, "tier": 1, "branch_of": "",
		"name": "Vardish Horsemen", "blurb": "Mounted retainers in chain shirts with lances.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},

	# --- Tier 2 ---
	# Infantry A: Men-at-arms (armor 0.3, shield wall stronger, speed x0.9)
	"vardish_men_at_arms": {
		"role": Troops.INFANTRY, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_infantry",
		"name": "Men-at-arms", "blurb": "Heavy infantry in plate and mail; formidable shield wall.",
		"stats": {"speed": 36.0},
		"mechanics": {"armor": 0.3, "shield_wall_boost": 0.2},
		"cost_mult": 1.25, "wage_mult": 1.25,
	},
	# Infantry B: Sergeants (damage +15%, speed +10%, wage -15%)
	"vardish_sergeants": {
		"role": Troops.INFANTRY, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_infantry",
		"name": "Sergeants", "blurb": "Veteran foot leaders who strike hard and march fast at modest pay.",
		"stats": {"damage": 15.0, "speed": 44.0},
		"mechanics": {},
		"cost_mult": 1.0, "wage_mult": 0.85,
	},
	# Spearmen A: Pikemen (reach 32, longer schiltron, speed x0.9)
	"vardish_pikemen": {
		"role": Troops.SPEARMEN, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_spearmen",
		"name": "Pikemen", "blurb": "Long 18-foot pikes creating an impenetrable hedgehog formation.",
		"stats": {"reach": 32.0, "speed": 34.2},
		"mechanics": {"longer_schiltron": true},
		"cost_mult": 1.2, "wage_mult": 1.2,
	},
	# Spearmen B: Halberdiers (sweep, bonus vs infantry x1.2, vs horse x1.8)
	"vardish_halberdiers": {
		"role": Troops.SPEARMEN, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_spearmen",
		"name": "Halberdiers", "blurb": "Heavy poleaxes that cleave multiple footmen and drag down cavalry.",
		"stats": {"bonus": {Troops.INFANTRY: 1.2, Troops.CAVALRY: 1.8}},
		"mechanics": {"sweep": true},
		"cost_mult": 1.2, "wage_mult": 1.15,
	},
	# Archers A: Crossbowmen (piercing 0.7, damage +30%, reload +40%, range 210)
	"vardish_crossbowmen": {
		"role": Troops.ARCHERS, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_archers",
		"name": "Crossbowmen", "blurb": "Heavy steel crossbows that punch through shields and armor.",
		"stats": {"damage": 52.0, "cooldown": 2.1, "range": 210.0},
		"mechanics": {"piercing": 0.7},
		"cost_mult": 1.25, "wage_mult": 1.2,
	},
	# Archers B: Longbowmen (range 290, reload -10%)
	"vardish_longbowmen": {
		"role": Troops.ARCHERS, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_archers",
		"name": "Longbowmen", "blurb": "Yew warbows raining rapid heavy shafts across immense distances.",
		"stats": {"range": 290.0, "cooldown": 1.35},
		"mechanics": {},
		"cost_mult": 1.2, "wage_mult": 1.2,
	},
	# Cavalry A: Knights (armor 0.35, charge x7.5, speed x0.9)
	"vardish_knights": {
		"role": Troops.CAVALRY, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_cavalry",
		"name": "Knights", "blurb": "Fully barded noble lancers whose crushing charge shatters battle lines.",
		"stats": {"speed": 90.0},
		"mechanics": {"armor": 0.35, "charge_mult": 7.5},
		"cost_mult": 1.4, "wage_mult": 1.4,
	},
	# Cavalry B: Mounted sergeants (speed +15%, wheel cooldown -40%, wage -15%)
	"vardish_mounted_sergeants": {
		"role": Troops.CAVALRY, "culture": Cultures.VARDISH, "tier": 2, "branch_of": "vardish_cavalry",
		"name": "Mounted sergeants", "blurb": "Fast, nimble outriders who wheel away quickly to charge again.",
		"stats": {"speed": 115.0},
		"mechanics": {"wheel_cooldown_mult": 0.6},
		"cost_mult": 1.0, "wage_mult": 0.85,
	},

	# =========================================================================
	# KHARZANI (Fast, shooting, javelins & horse archers)
	# =========================================================================

	# --- Tier 1 ---
	"kharzani_infantry": {
		"role": Troops.INFANTRY, "culture": Cultures.KHARZANI, "tier": 1, "branch_of": "",
		"name": "Askari", "blurb": "Light infantry armed with scimitars and light bucklers.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"kharzani_spearmen": {
		"role": Troops.SPEARMEN, "culture": Cultures.KHARZANI, "tier": 1, "branch_of": "",
		"name": "Kharzani Spearmen", "blurb": "Desert footmen bearing cane spears.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"kharzani_archers": {
		"role": Troops.ARCHERS, "culture": Cultures.KHARZANI, "tier": 1, "branch_of": "",
		"name": "Desert Bowmen", "blurb": "Skilled oasis bowmen armed with short recurves.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"kharzani_cavalry": {
		"role": Troops.CAVALRY, "culture": Cultures.KHARZANI, "tier": 1, "branch_of": "",
		"name": "Faris Riders", "blurb": "Swift desert horsemen riding purebred steeds.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},

	# --- Tier 2 ---
	# Infantry A: Javelin askari (2 javelins each, speed +10%)
	"kharzani_javelin_askari": {
		"role": Troops.INFANTRY, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_infantry",
		"name": "Javelin askari", "blurb": "Agile skirmishers hurling twin javelins before closing in melee.",
		"stats": {"speed": 44.0},
		"mechanics": {"javelins": 2},
		"cost_mult": 1.15, "wage_mult": 1.1,
	},
	# Infantry B: Guard askari (armor 0.2, steady)
	"kharzani_guard_askari": {
		"role": Troops.INFANTRY, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_infantry",
		"name": "Guard askari", "blurb": "Disciplined city guard wearing gilded lamellar armor with iron nerve.",
		"stats": {},
		"mechanics": {"armor": 0.2, "steady": true},
		"cost_mult": 1.2, "wage_mult": 1.2,
	},
	# Spearmen A: Spear guard (armor 0.2, steady)
	"kharzani_spear_guard": {
		"role": Troops.SPEARMEN, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_spearmen",
		"name": "Spear guard", "blurb": "Veteran palace spearmen in chain coats who hold steady under fire.",
		"stats": {},
		"mechanics": {"armor": 0.2, "steady": true},
		"cost_mult": 1.2, "wage_mult": 1.2,
	},
	# Spearmen B: Levy spears (24 men, wage -20%, health -10%)
	"kharzani_levy_spears": {
		"role": Troops.SPEARMEN, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_spearmen",
		"name": "Levy spears", "blurb": "Massive 24-man spear levy providing dense numbers for low pay.",
		"stats": {"size": 24, "hp": 486.0},
		"mechanics": {},
		"cost_mult": 1.0, "wage_mult": 0.8,
	},
	# Archers A: Composite bowmen (range +15%, reload -15%)
	"kharzani_composite_bowmen": {
		"role": Troops.ARCHERS, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_archers",
		"name": "Composite bowmen", "blurb": "Horn-and-sinew composite bows shooting further and faster.",
		"stats": {"range": 287.5, "cooldown": 1.275},
		"mechanics": {},
		"cost_mult": 1.2, "wage_mult": 1.2,
	},
	# Archers B: Desert archers (speed +20%, step back from foot)
	"kharzani_desert_archers": {
		"role": Troops.ARCHERS, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_archers",
		"name": "Desert archers", "blurb": "Fleet-footed archers who step back and maintain distance as foot close.",
		"stats": {"speed": 48.0},
		"mechanics": {"kite": true},
		"cost_mult": 1.15, "wage_mult": 1.1,
	},
	# Cavalry A: Horse archers (signature: 8 arrows, weak melee, skirmish)
	"kharzani_horse_archers": {
		"role": Troops.CAVALRY, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_cavalry",
		"name": "Horse archers", "blurb": "Master horsemen who kite enemy foot and rain arrows from the saddle.",
		"stats": {"damage": 32.0, "cooldown": 1.5, "range": 220.0, "ranged": true, "arrows": 8, "size": 16},
		"mechanics": {"horse_archer": true, "weak_melee": true},
		"cost_mult": 1.35, "wage_mult": 1.35,
	},
	# Cavalry B: Faris lancers (charge x7, speed +10%)
	"kharzani_faris_lancers": {
		"role": Troops.CAVALRY, "culture": Cultures.KHARZANI, "tier": 2, "branch_of": "kharzani_cavalry",
		"name": "Faris lancers", "blurb": "Swift desert cavalry striking with explosive lance charges.",
		"stats": {"speed": 110.0},
		"mechanics": {"charge_mult": 7.0},
		"cost_mult": 1.25, "wage_mult": 1.25,
	},

	# =========================================================================
	# RYUMON (Elite warriors, 16/24 sizes, naginata & samurai)
	# =========================================================================

	# --- Tier 1 ---
	"ryumon_infantry": {
		"role": Troops.INFANTRY, "culture": Cultures.RYUMON, "tier": 1, "branch_of": "",
		"name": "Samurai", "blurb": "Honor-bound warriors bearing keen katana.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"ryumon_spearmen": {
		"role": Troops.SPEARMEN, "culture": Cultures.RYUMON, "tier": 1, "branch_of": "",
		"name": "Ashigaru", "blurb": "Disciplined conscript spearmen bearing yari.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"ryumon_archers": {
		"role": Troops.ARCHERS, "culture": Cultures.RYUMON, "tier": 1, "branch_of": "",
		"name": "Yumi archers", "blurb": "Skilled archers bearing asymmetrical wooden yumi.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},
	"ryumon_cavalry": {
		"role": Troops.CAVALRY, "culture": Cultures.RYUMON, "tier": 1, "branch_of": "",
		"name": "Ryumon Riders", "blurb": "Armored samurai mounted on sturdy warhorses.",
		"stats": {}, "mechanics": {}, "cost_mult": 1.0, "wage_mult": 1.0,
	},

	# --- Tier 2 ---
	# Infantry A: Hatamoto (16 elite, damage +20%, health +20%, steady)
	"ryumon_hatamoto": {
		"role": Troops.INFANTRY, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_infantry",
		"name": "Hatamoto", "blurb": "16 elite bannermen with unmatched blade skills and deep composure.",
		"stats": {"size": 16, "damage": 15.6, "hp": 720.0},
		"mechanics": {"steady": true},
		"cost_mult": 1.3, "wage_mult": 1.3,
	},
	# Infantry B: Ronin (damage +25%, always Vengeful when captain falls)
	"ryumon_ronin": {
		"role": Troops.INFANTRY, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_infantry",
		"name": "Ronin", "blurb": "Fierce masterless warriors who fly into red fury if their captain falls.",
		"stats": {"damage": 16.25},
		"mechanics": {"ronin": true},
		"cost_mult": 1.15, "wage_mult": 1.0,
	},
	# Spearmen A: Yari ashigaru (reach 30, 24 men)
	"ryumon_yari_ashigaru": {
		"role": Troops.SPEARMEN, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_spearmen",
		"name": "Yari ashigaru", "blurb": "24 ashigaru with 16-foot yari presenting an unyielding wall of points.",
		"stats": {"size": 24, "reach": 30.0},
		"mechanics": {},
		"cost_mult": 1.2, "wage_mult": 1.1,
	},
	# Spearmen B: Naginata (sweep, vs horse x2.0, vs infantry x1.15)
	"ryumon_naginata": {
		"role": Troops.SPEARMEN, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_spearmen",
		"name": "Naginata", "blurb": "Graceful curved polearms that sweep through both foot and horse.",
		"stats": {"bonus": {Troops.CAVALRY: 2.0, Troops.INFANTRY: 1.15}},
		"mechanics": {"sweep": true},
		"cost_mult": 1.25, "wage_mult": 1.25,
	},
	# Archers A: Yumi samurai (range +10%, fight like infantry when caught)
	"ryumon_yumi_samurai": {
		"role": Troops.ARCHERS, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_archers",
		"name": "Yumi samurai", "blurb": "Armored samurai archers who draw razor-sharp swords in close melee.",
		"stats": {"range": 275.0, "hp": 480.0, "reach": 12.0},
		"mechanics": {"samurai_sidearm": true},
		"cost_mult": 1.3, "wage_mult": 1.3,
	},
	# Archers B: Ashigaru archers (24 men, volley cooldown -30%)
	"ryumon_ashigaru_archers": {
		"role": Troops.ARCHERS, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_archers",
		"name": "Ashigaru archers", "blurb": "24 massed bowmen loosing frequent, coordinated volleys.",
		"stats": {"size": 24},
		"mechanics": {"volley_cooldown_mult": 0.7},
		"cost_mult": 1.15, "wage_mult": 1.1,
	},
	# Cavalry A: Mounted samurai (lance, steady)
	"ryumon_mounted_samurai": {
		"role": Troops.CAVALRY, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_cavalry",
		"name": "Mounted samurai", "blurb": "Armored cavalry charging with heavy yari and steadfast resolve.",
		"stats": {},
		"mechanics": {"lance": true, "steady": true},
		"cost_mult": 1.35, "wage_mult": 1.35,
	},
	# Cavalry B: Mounted archers (5 arrows, good melee)
	"ryumon_mounted_archers": {
		"role": Troops.CAVALRY, "culture": Cultures.RYUMON, "tier": 2, "branch_of": "ryumon_cavalry",
		"name": "Mounted archers", "blurb": "Mobile samurai who loose arrows on approach before charging home.",
		"stats": {"damage": 36.0, "cooldown": 1.5, "range": 200.0, "ranged": true, "arrows": 5, "size": 16},
		"mechanics": {"horse_archer": true, "good_melee": true},
		"cost_mult": 1.35, "wage_mult": 1.35,
	},
}


## Does the unit id exist?
static func has(unit_id: String) -> bool:
	return UNITS.has(unit_id)


## Full descriptor dictionary for unit_id.
static func get_unit(unit_id: String) -> Dictionary:
	return UNITS.get(unit_id, {})


## Role type string (Troops.INFANTRY, etc.)
static func role(unit_id: String) -> String:
	return String(UNITS.get(unit_id, {}).get("role", Troops.INFANTRY))


## Culture string (Cultures.VARDISH, etc.)
static func culture(unit_id: String) -> String:
	return String(UNITS.get(unit_id, {}).get("culture", Cultures.VARDISH))


## Tier (1 or 2)
static func tier(unit_id: String) -> int:
	return int(UNITS.get(unit_id, {}).get("tier", 1))


## Human-readable unit name.
static func display_name(unit_id: String) -> String:
	var u: Dictionary = UNITS.get(unit_id, {})
	if u.is_empty():
		return unit_id.capitalize()
	return String(u.get("name", unit_id.capitalize()))


## Returns the default recruit unit_id for culture and role.
static func recruit(cult: String, r: String) -> String:
	var prefix := cult.to_lower()
	var cand := "%s_%s" % [prefix, r]
	if UNITS.has(cand):
		return cand
	return "vardish_%s" % r


## Returns array of unit_ids that branch off from this unit at tier 2.
static func branches(unit_id: String) -> Array:
	var out := []
	for id in UNITS:
		var u: Dictionary = UNITS[id]
		if u.get("branch_of") == unit_id:
			out.append(id)
	return out


## Squad size when at full strength.
static func full_size(unit_id: String) -> int:
	var u: Dictionary = UNITS.get(unit_id, {})
	if u.is_empty():
		return 20
	var r: String = u.get("role", Troops.INFANTRY)
	var base_size: int = Troops.full_size(r)
	var overrides: Dictionary = u.get("stats", {})
	return int(overrides.get("size", base_size))


## Cost multiplier on recruit and training.
static func cost_mult(unit_id: String) -> float:
	return float(UNITS.get(unit_id, {}).get("cost_mult", 1.0))


## Wage multiplier on daily pay.
static func wage_mult(unit_id: String) -> float:
	return float(UNITS.get(unit_id, {}).get("wage_mult", 1.0))


## Combined mechanics dictionary (armor, piercing, javelins, etc.).
## Level 3 enhances specific branch mechanics slightly.
static func mechanics(unit_id: String, level: int = 1) -> Dictionary:
	var u: Dictionary = UNITS.get(unit_id, {})
	var base_m: Dictionary = u.get("mechanics", {}).duplicate()
	if level >= 3:
		if base_m.has("armor"):
			base_m["armor"] = minf(0.5, float(base_m["armor"]) + 0.05)
		if base_m.has("piercing"):
			base_m["piercing"] = minf(1.0, float(base_m["piercing"]) + 0.1)
		if base_m.has("javelins"):
			base_m["javelins"] = int(base_m["javelins"]) + 1
		if base_m.has("charge_mult"):
			base_m["charge_mult"] = float(base_m["charge_mult"]) + 0.5
	return base_m


## Combined per-soldier stats with base role defaults, unit overrides, and level scaling.
static func stats(unit_id: String, level: int = 1) -> Dictionary:
	var u: Dictionary = UNITS.get(unit_id, {})
	var r: String = u.get("role", Troops.INFANTRY) if not u.is_empty() else Troops.INFANTRY
	var s: Dictionary = Troops.TYPES[r].duplicate(true)

	if not u.is_empty():
		var overrides: Dictionary = u.get("stats", {})
		for k in overrides:
			if k == "bonus":
				var b: Dictionary = s["bonus"].duplicate()
				for foe_type in overrides["bonus"]:
					b[foe_type] = overrides["bonus"][foe_type]
				s["bonus"] = b
			else:
				s[k] = overrides[k]

	# Level 3 branch strengthening: +10% damage and health (beyond today's power_for)
	if level >= 3:
		s["hp"] = float(s["hp"]) * 1.05
		s["damage"] = float(s["damage"]) * 1.05
		if s.get("ranged", false) and float(s.get("range", 0.0)) > 0.0:
			s["range"] = float(s["range"]) * 1.05

	return s
