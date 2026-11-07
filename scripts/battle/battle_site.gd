## Battlefield site generator. Pure logic, creates Terrain instances.
##
## Picks and generates battlefield sites (open, hills, woods, river, pass, village)
## based on world map geography, noise, and balance symmetry.
extends RefCounted

const Terrain = preload("res://scripts/battle/terrain.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")
const Data = preload("res://scripts/world/world_data.gd")

const TYPE_OPEN := "open"
const TYPE_HILLS := "hills"
const TYPE_WOODS := "woods"
const TYPE_RIVER := "river"
const TYPE_PASS := "pass"
const TYPE_VILLAGE := "village"

const TYPES := [TYPE_OPEN, TYPE_HILLS, TYPE_WOODS, TYPE_RIVER, TYPE_PASS, TYPE_VILLAGE]
## How often a band met on hills or in woods has picked its ground and holds the better of it.
const UNFAIR_CHANCE := 0.3
## A fight this close to one of the map's rivers (in map units) is fought across it.
const RIVER_NEAR := 28.0
## How far a river winds either side of the middle of the field, on a field not made fair.
const RIVER_BEND := 35.0
## The village you're defending lies behind your line, so raiders who get past you or round
## you reach it first.
const VILLAGE_CENTER := Vector2(420.0, 840.0)


## Pick a battlefield site descriptor based on map position and objective.
## Returns {type, seed, biome, fair}.
## `seed_val` makes the choice repeatable (the encounter dialog and the battle must agree);
## left negative, it's random. On hills and in woods a band that isn't raiding or ambushing
## has chosen its ground UNFAIR_CHANCE of the time, and waits for you on the better side.
static func pick(world = null, position: Vector2 = Vector2.ZERO, objective: String = "rout", seed_val: int = -1) -> Dictionary:
	if seed_val < 0:
		seed_val = randi()
	if objective == "village":
		return {
			"type": TYPE_VILLAGE,
			"seed": seed_val,
			"biome": "vardmark",
			"fair": true,
		}

	var mt = MapTerrain.shared()
	var h: float = mt.height_at(position) if mt != null else 0.5
	var w: float = mt.woods_at(position) if mt != null else 0.5
	var realm: String = mt.realm_at(position) if mt != null else "vardmark"
	var biome: String = realm if realm != "" else "vardmark"

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var site_type := TYPE_OPEN

	# Near one of the map's rivers, the fight is across it.
	var river: Dictionary = Data.nearest_river(position)
	if float(river["distance"]) < RIVER_NEAR:
		site_type = TYPE_RIVER
	elif h > 0.65:
		site_type = TYPE_HILLS if rng.randf() < 0.6 else TYPE_PASS
	elif w > 0.52 and biome != "kharzan":
		site_type = TYPE_WOODS
	elif h > 0.50 and rng.randf() < 0.65:
		site_type = TYPE_HILLS
	elif w > 0.40 and biome != "kharzan" and rng.randf() < 0.4:
		site_type = TYPE_WOODS
	else:
		site_type = TYPE_OPEN

	var fair := true
	if (site_type == TYPE_HILLS or site_type == TYPE_WOODS) and (objective == "rout" or objective == "chief"):
		fair = rng.randf() >= UNFAIR_CHANCE
	var out := {
		"type": site_type,
		"seed": seed_val,
		"biome": biome,
		"fair": fair,
	}
	if site_type == TYPE_RIVER:
		out["river"] = river["name"]
	return out


## Generate a Terrain instance from site descriptor {type, seed, biome, fair}.
static func generate(site: Dictionary) -> Terrain:
	var t := Terrain.new()
	t.reset()

	var site_type: String = site.get("type", TYPE_OPEN)
	var seed_val: int = int(site.get("seed", 1))
	var fair: bool = bool(site.get("fair", true))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	match site_type:
		TYPE_OPEN:
			pass # Flat, empty terrain

		TYPE_HILLS:
			_build_hills(t, rng, fair)

		TYPE_WOODS:
			_build_woods(t, rng, fair)

		TYPE_RIVER:
			_build_river(t, rng, fair)

		TYPE_PASS:
			_build_pass(t, rng, fair)

		TYPE_VILLAGE:
			_build_village(t, rng, fair)

		_:
			pass

	t.bake()
	return t


## A ridge across the field: its brow at `y` (wandering by `wander` along its length), its
## peak and width swelling and falling along it, so it stands as a line of knolls and
## saddles rather than a bank. Height falls off from the brow with a smooth step.
static func _ridge(t: Terrain, rng: RandomNumberGenerator, y: float, peak: float, half_w: float, wander: float) -> void:
	var ph := [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)]
	for cy in Terrain.ROWS:
		for cx in Terrain.COLS:
			var p := t.cell_pos(cx, cy)
			var brow := y + sin(p.x * 0.008 + ph[0]) * wander
			var hw := half_w * (0.80 + 0.20 * sin(p.x * 0.0075 + ph[1]))
			var pk := peak * (0.70 + 0.30 * (0.5 + 0.5 * sin(p.x * 0.0105 + ph[2]))) + 0.06 * sin(p.x * 0.023 + ph[3])
			var dy := absf(p.y - brow)
			if dy < hw:
				var f := 1.0 - dy / hw
				t.height[cy * Terrain.COLS + cx] = maxf(t.height[cy * Terrain.COLS + cx], clampf(pk, 0.0, 1.0) * (f * f * (3.0 - 2.0 * f)))


static func _build_hills(t: Terrain, rng: RandomNumberGenerator, fair: bool) -> void:
	var hills := []
	if fair:
		# Either a central ridge along the midline or two mirrored hills (one enemy side,
		# one player side)
		if rng.randf() < 0.5:
			var ridge_peak := rng.randf_range(0.65, 0.85)
			var ridge_half_w := rng.randf_range(160.0, 220.0)
			hills.append({
				"type": "ridge",
				"y": 630.0,
				"half_w": ridge_half_w,
				"peak": ridge_peak,
			})
			# The brow stays on the midline, so each side faces the same slope.
			_ridge(t, rng, 630.0, ridge_peak, ridge_half_w, 0.0)
		else:
			# Two mirrored hills, each a little lumpy in the same way
			var h1_pos := Vector2(rng.randf_range(180.0, 660.0), rng.randf_range(280.0, 460.0))
			var h1_rad := rng.randf_range(180.0, 250.0)
			var h1_peak := rng.randf_range(0.70, 0.85)
			var lump := rng.randf_range(0.0, TAU)

			var h2_pos := Vector2(h1_pos.x, Terrain.ARENA.y - h1_pos.y)
			var h2_rad := h1_rad
			var h2_peak := h1_peak

			hills.append({"type": "hill", "center": h1_pos, "radius": h1_rad, "peak": h1_peak})
			hills.append({"type": "hill", "center": h2_pos, "radius": h2_rad, "peak": h2_peak})

			for cy in Terrain.ROWS:
				for cx in Terrain.COLS:
					var p := t.cell_pos(cx, cy)
					var max_h := 0.0
					for h in [h1_pos, h2_pos]:
						var d := p.distance_to(h)
						# The same lumps on both, measured from each hill's own side of the field.
						var ang := atan2(absf(p.y - h.y) * (1.0 if h.y < 630.0 else 1.0), p.x - h.x)
						var rad := h1_rad * (1.0 + 0.14 * sin(3.0 * ang + lump))
						if d < rad:
							var f := 1.0 - (d / rad)
							max_h = maxf(max_h, h1_peak * (f * f * (3.0 - 2.0 * f)))
					t.height[cy * Terrain.COLS + cx] = max_h
	else:
		# Unfair: the enemy holds the high ground, a ridge across the whole of his half, wide
		# enough for his line to stand along its brow, and free to wander.
		var ridge_y := rng.randf_range(360.0, 400.0)
		var ridge_peak := rng.randf_range(0.8, 0.9)
		var ridge_half_w := rng.randf_range(200.0, 230.0)
		hills.append({"type": "ridge", "y": ridge_y, "half_w": ridge_half_w, "peak": ridge_peak})
		_ridge(t, rng, ridge_y, ridge_peak, ridge_half_w, 35.0)

	t.features = hills


static func _build_woods(t: Terrain, rng: RandomNumberGenerator, fair: bool) -> void:
	var stands := []
	var count := rng.randi_range(2, 4)

	# Stands placed on the flanks
	var slots := [
		Vector2(rng.randf_range(100.0, 240.0), rng.randf_range(300.0, 480.0)), # Left upper
		Vector2(rng.randf_range(600.0, 740.0), rng.randf_range(780.0, 960.0)), # Right lower
		Vector2(rng.randf_range(100.0, 240.0), rng.randf_range(780.0, 960.0)), # Left lower
		Vector2(rng.randf_range(600.0, 740.0), rng.randf_range(300.0, 480.0)), # Right upper
	]

	var placed := []
	if fair:
		# In pairs, each stand matched by its mirror image across the middle of the field, so
		# each side has the same woods in the same places. (Mirrored, not turned half round:
		# both sides line up from the same end of the field.)
		for i in (2 if count > 2 else 1):
			var c: Vector2 = slots[i * 3] # upper left, then upper right: the enemy's half
			var r := rng.randf_range(90.0, 135.0)
			placed.append([c, r])
			placed.append([Vector2(c.x, Terrain.ARENA.y - c.y), r])
	else:
		# The enemy chose his ground: woods along the front of his line, his men in them.
		for x in [rng.randf_range(220.0, 300.0), rng.randf_range(540.0, 620.0)]:
			placed.append([Vector2(x, rng.randf_range(430.0, 480.0)), rng.randf_range(110.0, 135.0)])
	for stand in placed:
		var c: Vector2 = stand[0]
		var r: float = stand[1]
		stands.append({"type": "woods", "center": c, "radius": r})

		for cy in Terrain.ROWS:
			for cx in Terrain.COLS:
				var p := t.cell_pos(cx, cy)
				if p.distance_to(c) <= r:
					t.woods[cy * Terrain.COLS + cx] = Terrain.WOODS_TREES

	t.features = stands


static func _build_river(t: Terrain, rng: RandomNumberGenerator, fair: bool) -> void:
	var river_features := []
	var half_w := 38.0
	var phase := rng.randf_range(0.0, TAU)
	# On a fair field the river runs straight across the middle, so each side faces the same
	# river: a bend toward one side is a bend away from the other.
	var bend := 0.0 if fair else RIVER_BEND

	# 2 or 3 fords, placed alike from each side's point of view on a fair field.
	var ford_count := rng.randi_range(2, 3)
	var fords := []
	if ford_count == 2:
		fords.append(rng.randf_range(180.0, 300.0))
		fords.append(Terrain.ARENA.x - fords[0] if fair else rng.randf_range(540.0, 660.0))
	else:
		fords.append(rng.randf_range(140.0, 240.0))
		fords.append(Terrain.ARENA.x * 0.5 if fair else rng.randf_range(370.0, 470.0))
		fords.append(Terrain.ARENA.x - fords[0] if fair else rng.randf_range(600.0, 700.0))

	var ford_half_w := 45.0 # 90 units wide ford

	for cy in Terrain.ROWS:
		for cx in Terrain.COLS:
			var p := t.cell_pos(cx, cy)
			var ry := 630.0 + sin(p.x * 0.007 + phase) * bend
			if absf(p.y - ry) <= half_w:
				var in_ford := false
				for fx in fords:
					if absf(p.x - fx) <= ford_half_w:
						in_ford = true
						break
				var idx := cy * Terrain.COLS + cx
				if in_ford:
					t.water[idx] = Terrain.WATER_SHALLOW
				else:
					t.water[idx] = Terrain.WATER_DEEP

	river_features.append({
		"type": "river",
		"half_width": half_w,
		"phase": phase,
		"bend": bend,
		"fords": fords,
		"ford_width": ford_half_w * 2.0,
	})
	t.features = river_features


## How far a pass's rock mass reaches into the field at `y`, in field units, or a
## negative number where there is none. The mass swells from nothing at either end to its
## full reach astride the middle, its edge wandering a little, the same above and below
## the middle so both sides face the same gap.
static func rock_reach(feat: Dictionary, y: float) -> float:
	var dy := absf(y - 630.0) / float(feat.get("half_h", 220.0))
	if dy >= 1.0:
		return -999.0
	var bell := pow(1.0 - dy * dy, 0.7)
	var ay := absf(y - 630.0)
	var phase := float(feat.get("phase", 0.0))
	var wobble := sin(ay * 0.021 + phase) + 0.5 * sin(ay * 0.047 + phase * 1.7)
	return float(feat.get("reach", 240.0)) * bell + float(feat.get("amp", 18.0)) * wobble * sqrt(bell) - 6.0


## A pass: a mass of rock comes in from each side of the field, broadest astride the
## middle and dying away toward either end, so the way through winds between two rounded
## masses rather than two blocks. Each mass is mirrored across the middle of the field.
static func _build_pass(t: Terrain, rng: RandomNumberGenerator, _fair: bool) -> void:
	var pass_features := []
	for side in [-1.0, 1.0]:
		var sd := float(side)
		var edge_x := 0.0 if sd < 0.0 else Terrain.ARENA.x
		var inward := -sd
		var half_h := rng.randf_range(200.0, 250.0)
		var feat := {"type": "rock", "side": sd, "reach": rng.randf_range(220.0, 290.0), "half_h": half_h,
			"phase": rng.randf_range(0.0, TAU), "amp": rng.randf_range(14.0, 26.0)}
		var far := 0.0
		for cy in Terrain.ROWS:
			for cx in Terrain.COLS:
				var p := t.cell_pos(cx, cy)
				var r := rock_reach(feat, p.y)
				far = maxf(far, r)
				if (p.x - edge_x) * inward <= r:
					t.rock[cy * Terrain.COLS + cx] = Terrain.ROCK_BLOCKED
		var x0 := 0.0 if sd < 0.0 else Terrain.ARENA.x - far
		feat["rect"] = Rect2(x0, 630.0 - half_h, far, half_h * 2.0)
		pass_features.append(feat)
	t.features = pass_features


static func _build_village(t: Terrain, rng: RandomNumberGenerator, _fair: bool) -> void:
	var village_features := []
	var center := VILLAGE_CENTER

	# 4-6 house obstacles around the village center
	var house_count := rng.randi_range(4, 6)
	var angles := [0.2, 1.3, 2.5, 3.4, 4.6, 5.8]

	for i in house_count:
		var ang: float = angles[i] + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(70.0, 130.0)
		var hp := center + Vector2(cos(ang), sin(ang)) * dist
		var hw := rng.randf_range(35.0, 50.0)
		var hh := rng.randf_range(35.0, 50.0)
		var rect := Rect2(hp.x - hw * 0.5, hp.y - hh * 0.5, hw, hh)

		for cy in Terrain.ROWS:
			for cx in Terrain.COLS:
				var p := t.cell_pos(cx, cy)
				if rect.has_point(p):
					t.rock[cy * Terrain.COLS + cx] = Terrain.ROCK_BLOCKED

		village_features.append({"type": "building", "rect": rect})

	t.features = village_features
