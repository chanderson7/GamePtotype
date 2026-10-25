## The Glass Sea: factions, settlements, roads and coastlines, as plain data. The world
## sim reads this; nothing here changes during a campaign.
##
## Map space is SIZE units, origin at the top left. Vardmark holds the northwest shore,
## Kharzan the south, joined to it by a land bridge in the west; the Ryumon isles lie
## east across a strait. Sea lanes cross the water.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")

const SIZE := Vector2(1000.0, 1600.0)

const TOWN := "town"
const CASTLE := "castle"
const VILLAGE := "village"

const BANDITS := "bandits"

const FACTIONS := {
	"vardmark": {"name": "Kingdom of Vardmark", "culture": Cultures.VARDISH, "ruler": "King Aldwin", "capital": "highcliff"},
	"kharzan": {"name": "Sultanate of Kharzan", "culture": Cultures.KHARZANI, "ruler": "Sultan Rustam", "capital": "khalun"},
	"ryumon": {"name": "Ryumon Shogunate", "culture": Cultures.RYUMON, "ruler": "Shogun Hidemasa", "capital": "kurogane"},
	BANDITS: {"name": "Bandits", "culture": "", "ruler": "", "capital": ""},
}

## Pairs of factions at war. Everyone is also at war with bandits.
const WARS := [["vardmark", "kharzan"]]

const SETTLEMENTS := {
	"highcliff": {"name": "Highcliff", "type": TOWN, "faction": "vardmark", "pos": Vector2(300, 250)},
	"ravensford": {"name": "Ravensford", "type": CASTLE, "faction": "vardmark", "pos": Vector2(180, 560)},
	"kettlebrook": {"name": "Kettlebrook", "type": VILLAGE, "faction": "vardmark", "pos": Vector2(470, 160)},
	"thornwall": {"name": "Thornwall", "type": VILLAGE, "faction": "vardmark", "pos": Vector2(420, 470)},
	"khalun": {"name": "Khalun", "type": TOWN, "faction": "kharzan", "pos": Vector2(520, 1300)},
	"zeyra": {"name": "Qal'at Zeyra", "type": CASTLE, "faction": "kharzan", "pos": Vector2(230, 1080)},
	"bir_sahra": {"name": "Bir Sahra", "type": VILLAGE, "faction": "kharzan", "pos": Vector2(760, 1420)},
	"nahrabad": {"name": "Nahrabad", "type": VILLAGE, "faction": "kharzan", "pos": Vector2(330, 1460)},
	"kurogane": {"name": "Kurogane", "type": TOWN, "faction": "ryumon", "pos": Vector2(860, 380)},
	"takamine": {"name": "Takamine", "type": CASTLE, "faction": "ryumon", "pos": Vector2(900, 700)},
	"hamazaki": {"name": "Hamazaki", "type": VILLAGE, "faction": "ryumon", "pos": Vector2(780, 160)},
	"shiraumi": {"name": "Shiraumi", "type": VILLAGE, "faction": "ryumon", "pos": Vector2(760, 560)},
}

## [a, b, sea]. Sea lanes are slower and bandits never take them.
const ROADS := [
	["highcliff", "kettlebrook", false],
	["highcliff", "thornwall", false],
	["highcliff", "ravensford", false],
	["thornwall", "ravensford", false],
	["ravensford", "zeyra", false],
	["zeyra", "nahrabad", false],
	["zeyra", "khalun", false],
	["khalun", "nahrabad", false],
	["khalun", "bir_sahra", false],
	["kurogane", "hamazaki", false],
	["kurogane", "shiraumi", false],
	["shiraumi", "takamine", false],
	["kettlebrook", "hamazaki", true],
	["thornwall", "shiraumi", true],
	["bir_sahra", "takamine", true],
]

## Coastlines: the mainland (Vardmark, the land bridge and Kharzan) and the Ryumon isle.
const LAND := [
	[
		Vector2(0, 0), Vector2(600, 0), Vector2(620, 120), Vector2(580, 300), Vector2(540, 520),
		Vector2(460, 620), Vector2(330, 680), Vector2(300, 820), Vector2(330, 960), Vector2(480, 1000),
		Vector2(700, 1040), Vector2(900, 1100), Vector2(1000, 1150), Vector2(1000, 1600), Vector2(0, 1600),
	],
	[
		Vector2(720, 90), Vector2(900, 60), Vector2(990, 200), Vector2(980, 520), Vector2(960, 780),
		Vector2(860, 820), Vector2(740, 700), Vector2(700, 420), Vector2(710, 200),
	],
]

## Where each realm's land is tinted on the map (drawn over the coastlines).
const REALM_TINT := {
	"vardmark": [
		Vector2(0, 0), Vector2(600, 0), Vector2(620, 120), Vector2(580, 300), Vector2(540, 520),
		Vector2(460, 620), Vector2(330, 680), Vector2(300, 820), Vector2(0, 860),
	],
}

## A bandit band roams each realm.
const BANDIT_BANDS := {
	"vardmark": "Ash Hill brigands",
	"kharzan": "Red Waste reavers",
	"ryumon": "Ronin band",
}


static func settlement(id: String) -> Dictionary:
	return SETTLEMENTS[id]


static func pos(id: String) -> Vector2:
	return SETTLEMENTS[id]["pos"]


static func culture_of(faction: String) -> String:
	return String(FACTIONS[faction]["culture"])


## "Capital of the Kingdom of Vardmark, seat of King Aldwin · Vardish": what a place is,
## whose it is, and who lives there.
static func describe(id: String) -> String:
	var s := settlement(id)
	var faction: Dictionary = FACTIONS[s["faction"]]
	var line := "%s of the %s" % [String(s["type"]).capitalize(), faction["name"]]
	if s["type"] == TOWN and faction["capital"] == id:
		line = "Capital of the %s, seat of %s" % [faction["name"], faction["ruler"]]
	return "%s · %s" % [line, Cultures.info(culture_of(s["faction"]))["people"]]


static func capital_of_culture(culture: String) -> String:
	for f in FACTIONS:
		if FACTIONS[f]["culture"] == culture:
			return String(FACTIONS[f]["capital"])
	return "highcliff"


static func at_war(a: String, b: String) -> bool:
	if a == b:
		return false
	if a == BANDITS or b == BANDITS:
		return true
	for w in WARS:
		if w.has(a) and w.has(b):
			return true
	return false


## The index of the coastline a point lies on, or -1 if it's at sea.
static func land_at(p: Vector2) -> int:
	for i in LAND.size():
		if Geometry2D.is_point_in_polygon(p, PackedVector2Array(LAND[i])):
			return i
	return -1


static func villages_of(faction: String) -> Array:
	var out := []
	for id in SETTLEMENTS:
		if SETTLEMENTS[id]["faction"] == faction and SETTLEMENTS[id]["type"] == VILLAGE:
			out.append(id)
	return out
