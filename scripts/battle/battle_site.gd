## Battlefield site generator. Pure logic, creates Terrain instances.
##
## Picks and generates battlefield sites (open, hills, woods, river, pass, village)
## based on world map geography, noise, and balance symmetry.
extends RefCounted

const Terrain = preload("res://scripts/battle/terrain.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")

const TYPE_OPEN := "open"
const TYPE_HILLS := "hills"
const TYPE_WOODS := "woods"
const TYPE_RIVER := "river"
const TYPE_PASS := "pass"
const TYPE_VILLAGE := "village"

const TYPES := [TYPE_OPEN, TYPE_HILLS, TYPE_WOODS, TYPE_RIVER, TYPE_PASS, TYPE_VILLAGE]


## Pick a battlefield site descriptor based on map position and objective.
## Returns {type, seed, biome, fair}.
static func pick(world = null, position: Vector2 = Vector2.ZERO, objective: String = "rout") -> Dictionary:
	var seed_val := randi()
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

	var roll := rng.randf()
	var site_type := TYPE_OPEN

	# River: 15% at random
	if roll < 0.15:
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

	return {
		"type": site_type,
		"seed": seed_val,
		"biome": biome,
		"fair": true,
	}


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


static func _build_hills(t: Terrain, rng: RandomNumberGenerator, fair: bool) -> void:
	var hills := []
	if fair:
		# Either a central ridge or two mirrored hills (one enemy side, one player side)
		if rng.randf() < 0.5:
			# Central ridge along the midline
			var ridge_peak := rng.randf_range(0.65, 0.85)
			var ridge_half_w := rng.randf_range(160.0, 220.0)
			hills.append({
				"type": "ridge",
				"y": 630.0,
				"half_w": ridge_half_w,
				"peak": ridge_peak,
			})
			for cy in Terrain.ROWS:
				for cx in Terrain.COLS:
					var p := t.cell_pos(cx, cy)
					var dy := absf(p.y - 630.0)
					if dy < ridge_half_w:
						var f := 1.0 - (dy / ridge_half_w)
						var h := ridge_peak * (f * f * (3.0 - 2.0 * f))
						t.height[cy * Terrain.COLS + cx] = h
		else:
			# Two mirrored hills
			var h1_pos := Vector2(rng.randf_range(180.0, 660.0), rng.randf_range(280.0, 460.0))
			var h1_rad := rng.randf_range(180.0, 250.0)
			var h1_peak := rng.randf_range(0.70, 0.85)

			var h2_pos := Vector2(Terrain.ARENA.x - h1_pos.x, Terrain.ARENA.y - h1_pos.y)
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
						if d < h1_rad:
							var f := 1.0 - (d / h1_rad)
							max_h = maxf(max_h, h1_peak * (f * f * (3.0 - 2.0 * f)))
					t.height[cy * Terrain.COLS + cx] = max_h
	else:
		# Unfair: enemy holds the high ground (upper half)
		var enemy_hill_pos := Vector2(420.0, 320.0)
		var enemy_hill_rad := 340.0
		var enemy_hill_peak := 0.85
		hills.append({"type": "hill", "center": enemy_hill_pos, "radius": enemy_hill_rad, "peak": enemy_hill_peak})

		for cy in Terrain.ROWS:
			for cx in Terrain.COLS:
				var p := t.cell_pos(cx, cy)
				var d := p.distance_to(enemy_hill_pos)
				if d < enemy_hill_rad:
					var f := 1.0 - (d / enemy_hill_rad)
					t.height[cy * Terrain.COLS + cx] = enemy_hill_peak * (f * f * (3.0 - 2.0 * f))

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
		# In pairs, each stand matched by one where the field turned half round puts it, so
		# each side has the same woods in the same places.
		for i in (2 if count > 2 else 1):
			var c: Vector2 = slots[i * 3] # upper left, then upper right: the enemy's half
			var r := rng.randf_range(90.0, 135.0)
			placed.append([c, r])
			placed.append([Terrain.ARENA - c, r])
	else:
		for i in count:
			placed.append([slots[i], rng.randf_range(90.0, 135.0)])
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
	if fair:
		# Bends that turn the field into itself when it's spun half round, so each side
		# faces the same river: crossing the middle of the field at its middle.
		phase = -0.007 * Terrain.ARENA.x * 0.5 + (PI if rng.randf() < 0.5 else 0.0)

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
			var ry := 630.0 + sin(p.x * 0.007 + phase) * 35.0
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
		"fords": fords,
		"ford_width": ford_half_w * 2.0,
	})
	t.features = river_features


static func _build_pass(t: Terrain, rng: RandomNumberGenerator, _fair: bool) -> void:
	var pass_features := []
	var left_w := rng.randf_range(220.0, 280.0)
	var right_w := rng.randf_range(220.0, 280.0)
	var pass_y_min := 520.0
	var pass_y_max := 740.0

	var left_rect := Rect2(0.0, pass_y_min, left_w, pass_y_max - pass_y_min)
	var right_rect := Rect2(Terrain.ARENA.x - right_w, pass_y_min, right_w, pass_y_max - pass_y_min)

	for cy in Terrain.ROWS:
		for cx in Terrain.COLS:
			var p := t.cell_pos(cx, cy)
			if left_rect.has_point(p) or right_rect.has_point(p):
				t.rock[cy * Terrain.COLS + cx] = Terrain.ROCK_BLOCKED

	pass_features.append({"type": "rock", "rect": left_rect})
	pass_features.append({"type": "rock", "rect": right_rect})
	t.features = pass_features


static func _build_village(t: Terrain, rng: RandomNumberGenerator, _fair: bool) -> void:
	var village_features := []
	var center := Vector2(420.0, 630.0)

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
