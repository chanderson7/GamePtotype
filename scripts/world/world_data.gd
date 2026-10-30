## The Glass Sea: factions, settlements, roads and coastlines, as plain data. The world
## sim reads this; nothing here changes during a campaign. Who holds each settlement and
## who is at war are only where a campaign starts: the world sim keeps them after that.
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

## The wars a campaign starts with. The world sim keeps the wars after that.
const WARS := [["vardmark", "kharzan"]]

const SETTLEMENTS := {
	"highcliff": {"name": "Highcliff", "type": TOWN, "faction": "vardmark", "pos": Vector2(300, 250)},
	"ravensford": {"name": "Ravensford", "type": CASTLE, "faction": "vardmark", "pos": Vector2(180, 560)},
	"marchgate": {"name": "Marchgate", "type": CASTLE, "faction": "vardmark", "pos": Vector2(200, 800)},
	"kettlebrook": {"name": "Kettlebrook", "type": VILLAGE, "faction": "vardmark", "pos": Vector2(470, 160), "bound_to": "highcliff"},
	"ashby": {"name": "Ashby", "type": VILLAGE, "faction": "vardmark", "pos": Vector2(130, 340), "bound_to": "highcliff"},
	"thornwall": {"name": "Thornwall", "type": VILLAGE, "faction": "vardmark", "pos": Vector2(420, 470), "bound_to": "ravensford"},
	"bramblemoor": {"name": "Bramblemoor", "type": VILLAGE, "faction": "vardmark", "pos": Vector2(90, 690), "bound_to": "marchgate"},
	"khalun": {"name": "Khalun", "type": TOWN, "faction": "kharzan", "pos": Vector2(520, 1300)},
	"zeyra": {"name": "Qal'at Zeyra", "type": CASTLE, "faction": "kharzan", "pos": Vector2(230, 1080)},
	"qasr_hamra": {"name": "Qasr Hamra", "type": CASTLE, "faction": "kharzan", "pos": Vector2(860, 1215)},
	"nahrabad": {"name": "Nahrabad", "type": VILLAGE, "faction": "kharzan", "pos": Vector2(330, 1460), "bound_to": "khalun"},
	"dar_nakhla": {"name": "Dar Nakhla", "type": VILLAGE, "faction": "kharzan", "pos": Vector2(110, 1270), "bound_to": "zeyra"},
	"bir_sahra": {"name": "Bir Sahra", "type": VILLAGE, "faction": "kharzan", "pos": Vector2(760, 1420), "bound_to": "qasr_hamra"},
	"ain_tamar": {"name": "Ain Tamar", "type": VILLAGE, "faction": "kharzan", "pos": Vector2(930, 1370), "bound_to": "qasr_hamra"},
	"kurogane": {"name": "Kurogane", "type": TOWN, "faction": "ryumon", "pos": Vector2(860, 380)},
	"takamine": {"name": "Takamine", "type": CASTLE, "faction": "ryumon", "pos": Vector2(900, 700)},
	"kitayama": {"name": "Kitayama", "type": CASTLE, "faction": "ryumon", "pos": Vector2(915, 215)},
	"kawabe": {"name": "Kawabe", "type": VILLAGE, "faction": "ryumon", "pos": Vector2(745, 260), "bound_to": "kurogane"},
	"hamazaki": {"name": "Hamazaki", "type": VILLAGE, "faction": "ryumon", "pos": Vector2(780, 160), "bound_to": "kitayama"},
	"shiraumi": {"name": "Shiraumi", "type": VILLAGE, "faction": "ryumon", "pos": Vector2(760, 560), "bound_to": "takamine"},
	"minato": {"name": "Minato", "type": VILLAGE, "faction": "ryumon", "pos": Vector2(930, 560), "bound_to": "takamine"},
}

## [a, b, sea]. Sea lanes are slower and bandits never take them.
const ROADS := [
	["highcliff", "kettlebrook", false],
	["highcliff", "thornwall", false],
	["highcliff", "ravensford", false],
	["highcliff", "ashby", false],
	["ashby", "ravensford", false],
	["thornwall", "ravensford", false],
	["ravensford", "marchgate", false],
	["marchgate", "bramblemoor", false],
	["marchgate", "zeyra", false],
	["zeyra", "nahrabad", false],
	["zeyra", "khalun", false],
	["zeyra", "dar_nakhla", false],
	["dar_nakhla", "nahrabad", false],
	["khalun", "nahrabad", false],
	["khalun", "bir_sahra", false],
	["khalun", "qasr_hamra", false],
	["qasr_hamra", "bir_sahra", false],
	["qasr_hamra", "ain_tamar", false],
	["kurogane", "hamazaki", false],
	["kurogane", "shiraumi", false],
	["kurogane", "kawabe", false],
	["kurogane", "kitayama", false],
	["kurogane", "minato", false],
	["kawabe", "hamazaki", false],
	["kitayama", "hamazaki", false],
	["shiraumi", "takamine", false],
	["minato", "takamine", false],
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

## Rivers, each from its source to its mouth on the sea. Where a road crosses one there's
## a ford, and a fight there is fought across it.
const RIVERS := [
	{"name": "the Raven", "points": [Vector2(10, 400), Vector2(90, 470), Vector2(150, 535), Vector2(215, 575),
		Vector2(290, 610), Vector2(360, 640), Vector2(394, 659)]},
	{"name": "the Qamar", "points": [Vector2(700, 1600), Vector2(660, 1500), Vector2(615, 1400), Vector2(630, 1290),
		Vector2(660, 1170), Vector2(690, 1025)]},
	{"name": "the Kumo", "points": [Vector2(950, 260), Vector2(900, 300), Vector2(840, 310), Vector2(780, 330),
		Vector2(695, 342)]},
]

## Where each realm's land is tinted on the map (drawn over the coastlines).
const REALM_TINT := {
	"vardmark": [
		Vector2(0, 0), Vector2(600, 0), Vector2(620, 120), Vector2(580, 300), Vector2(540, 520),
		Vector2(460, 620), Vector2(330, 680), Vector2(300, 820), Vector2(0, 860),
	],
}

## The bandit bands that roam each realm, one name for each band at large there.
const BANDIT_BANDS := {
	"vardmark": ["Ash Hill brigands", "Fenland cutthroats"],
	"kharzan": ["Red Waste reavers", "Sand Viper raiders"],
	"ryumon": ["Ronin band", "Wako pirates"],
}


static func settlement(id: String) -> Dictionary:
	return SETTLEMENTS[id]


static func pos(id: String) -> Vector2:
	return SETTLEMENTS[id]["pos"]


static func culture_of(faction: String) -> String:
	return String(FACTIONS[faction]["culture"])


static func capital_of_culture(culture: String) -> String:
	for f in FACTIONS:
		if FACTIONS[f]["culture"] == culture:
			return String(FACTIONS[f]["capital"])
	return "highcliff"


static func realm_of_culture(culture: String) -> String:
	for faction in FACTIONS:
		if FACTIONS[faction]["culture"] == culture:
			return String(faction)
	return "vardmark"


## Stable, plain-language map intelligence. Dynamic ownership, danger and available
## recruits are added by the world screen so this never promises a service that is absent.
static func services(id: String) -> Array:
	match String(settlement(id)["type"]):
		TOWN:
			return ["provisions", "recruits", "reinforcement", "training", "court"]
		CASTLE:
			return ["provisions", "recruits", "court"]
		_:
			return ["cheap provisions", "recruits"]


static func importance(id: String) -> String:
	var s := settlement(id)
	if String(FACTIONS[String(s["faction"])]["capital"]) == id:
		return "A founding capital and the political heart of its people."
	match String(s["type"]):
		TOWN:
			return "A regional market where companies can reinforce and train."
		CASTLE:
			var villages := 0
			for other in SETTLEMENTS.values():
				if String(other.get("bound_to", "")) == id:
					villages += 1
			return "A fortified road stronghold%s." % (" protecting %d nearby villages" % villages if villages > 0 else "")
		_:
			var bound := String(s.get("bound_to", ""))
			if bound != "":
				return "A farming community supplying %s and selling the cheapest provisions." % settlement(bound)["name"]
			return "A farming community selling the cheapest provisions."


## The index of the coastline a point lies on, or -1 if it's at sea.
static func land_at(p: Vector2) -> int:
	for i in LAND.size():
		if Geometry2D.is_point_in_polygon(p, coast(i)):
			return i
	return -1


## Coastline `i` as it really runs: LAND's corners joined by a ragged shore instead of
## straight lines. Worked out once, the same every time.
static func coast(i: int) -> PackedVector2Array:
	if _coasts.is_empty():
		for points in LAND:
			_coasts.append(_ragged(points))
	return _coasts[i]


## A realm's land, for tinting the map: its outline, with the stretches it shares with a
## coastline as ragged as the coast.
static func realm_shape(faction: String) -> PackedVector2Array:
	if not _realms.has(faction):
		_realms[faction] = _ragged(REALM_TINT.get(faction, []))
	return _realms[faction]


static var _coasts: Array = []
static var _realms := {}
## How far the shore wanders from a straight line, in map units, and how finely.
const SHORE_WANDER := 14.0
const SHORE_STEP := 9.0


## A closed outline with every edge broken into short steps that wander side to side.
## The wander depends only on where a step lies, so two outlines sharing an edge share
## its shore. Corners stay put, and so do edges along the map's border.
static func _ragged(points: Array) -> PackedVector2Array:
	var noise := FastNoiseLite.new()
	noise.seed = 1166
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.022
	noise.fractal_octaves = 3
	var out := PackedVector2Array()
	for k in points.size():
		var a: Vector2 = points[k]
		var b: Vector2 = points[(k + 1) % points.size()]
		out.append(a)
		if on_border(a, b):
			continue
		var steps := int(a.distance_to(b) / SHORE_STEP)
		var side := (b - a).normalized().orthogonal()
		for j in range(1, steps):
			var t := float(j) / steps
			var p := a.lerp(b, t)
			out.append(p + side * noise.get_noise_2dv(p) * SHORE_WANDER * sin(PI * t))
	return out


## True for an edge that runs along the map's border, where the land goes on past it.
static func on_border(a: Vector2, b: Vector2) -> bool:
	return (a.x == 0.0 and b.x == 0.0) or (a.y == 0.0 and b.y == 0.0) \
		or (a.x == SIZE.x and b.x == SIZE.x) or (a.y == SIZE.y and b.y == SIZE.y)


## The river nearest `p`: {name, distance} in map units.
static func nearest_river(p: Vector2) -> Dictionary:
	var best := {"name": "", "distance": INF}
	for r in RIVERS:
		var pts: Array = r["points"]
		for k in pts.size() - 1:
			var d := Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]).distance_to(p)
			if d < float(best["distance"]):
				best = {"name": r["name"], "distance": d}
	return best


## Where the roads cross the rivers: [{pos, river}].
static func fords() -> Array:
	var out := []
	for road in ROADS:
		if road[2]:
			continue
		var a := pos(road[0])
		var b := pos(road[1])
		for r in RIVERS:
			var pts: Array = r["points"]
			for k in pts.size() - 1:
				var hit = Geometry2D.segment_intersects_segment(a, b, pts[k], pts[k + 1])
				if hit != null:
					out.append({"pos": hit, "river": r["name"]})
	return out


static func is_village(id: String) -> bool:
	return SETTLEMENTS.has(id) and SETTLEMENTS[id]["type"] == VILLAGE
