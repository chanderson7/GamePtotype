## Battlefield terrain grid and lookups. Pure logic, no scene nodes.
##
## A grid over the 840 x 1260 arena with CELL = 30.0 units (28 x 42 cells = 1176 total).
## Stores packed arrays for elevation (0.0 to 1.0), tree cover, water depth, and rocks.
## Provides instant lookups queried every step by soldiers and pathing.
extends RefCounted

const TerrainRules = preload("res://scripts/data/terrain_rules.gd")

const ARENA := Vector2(840.0, 1260.0)
const CELL := 30.0
const COLS := 28 # int(ARENA.x / CELL)
const ROWS := 42 # int(ARENA.y / CELL)
const TOTAL_CELLS := COLS * ROWS # 1176

const WATER_NONE := 0
const WATER_SHALLOW := 1 # Shallow ford (walkable at 50% speed, vulnerable)
const WATER_DEEP := 2 # Deep water (impassable)

const ROCK_NONE := 0
const ROCK_BLOCKED := 1 # Impassable rock outcrops or buildings

const WOODS_NONE := 0
const WOODS_TREES := 1 # Tree cover

## Elevation from 0.0 (lowland) to 1.0 (hill peak).
var height: PackedFloat32Array
## Tree cover: 1 if inside woods, 0 otherwise.
var woods: PackedByteArray
## Water: 0 none, 1 shallow ford, 2 deep water.
var water: PackedByteArray
## Rock: 1 if impassable terrain/rock/building, 0 otherwise.
var rock: PackedByteArray
## High-level descriptors for screen rendering and replay [{type, ...}].
var features: Array = []


func _init() -> void:
	reset()


## Clear all grid cells to an open flat field.
func reset() -> void:
	height.resize(TOTAL_CELLS)
	height.fill(0.0)
	woods.resize(TOTAL_CELLS)
	woods.fill(WOODS_NONE)
	water.resize(TOTAL_CELLS)
	water.fill(WATER_NONE)
	rock.resize(TOTAL_CELLS)
	rock.fill(ROCK_NONE)
	features.clear()


## Grid coordinates (cx, cy) containing point `p`. Clamped to valid cells.
func cell_coords(p: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(p.x / CELL), 0, COLS - 1),
		clampi(int(p.y / CELL), 0, ROWS - 1)
	)


## Packed array index for point `p`.
func cell_index(p: Vector2) -> int:
	var c := cell_coords(p)
	return c.y * COLS + c.x


## Center position in arena coordinates of cell (cx, cy).
func cell_pos(cx: int, cy: int) -> Vector2:
	return Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)


## Smooth elevation at point `p` from 0.0 to 1.0 using bilinear interpolation.
func height_at(p: Vector2) -> float:
	if height.is_empty():
		return 0.0
	var fx := (p.x / CELL) - 0.5
	var fy := (p.y / CELL) - 0.5
	var x0 := clampi(int(floor(fx)), 0, COLS - 1)
	var y0 := clampi(int(floor(fy)), 0, ROWS - 1)
	var x1 := mini(x0 + 1, COLS - 1)
	var y1 := mini(y0 + 1, ROWS - 1)
	var tx := clampf(fx - float(x0), 0.0, 1.0)
	var ty := clampf(fy - float(y0), 0.0, 1.0)
	var h00 := height[y0 * COLS + x0]
	var h10 := height[y0 * COLS + x1]
	var h01 := height[y1 * COLS + x0]
	var h11 := height[y1 * COLS + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)


## True if point `p` stands under tree canopy.
func in_woods(p: Vector2) -> bool:
	if woods.is_empty():
		return false
	return woods[cell_index(p)] == WOODS_TREES


## Water status at point `p`: 0 none, 1 shallow ford, 2 deep impassable.
func water_at(p: Vector2) -> int:
	if water.is_empty():
		return WATER_NONE
	return int(water[cell_index(p)])


## Rock status at point `p`: 0 none, 1 impassable.
func rock_at(p: Vector2) -> int:
	if rock.is_empty():
		return ROCK_NONE
	return int(rock[cell_index(p)])


## True if point `p` is inside the arena and not blocked by deep water or rock.
func passable(p: Vector2) -> bool:
	if p.x < 0.0 or p.x > ARENA.x or p.y < 0.0 or p.y > ARENA.y:
		return false
	var idx := cell_index(p)
	if idx < 0 or idx >= TOTAL_CELLS:
		return false
	return water[idx] != WATER_DEEP and rock[idx] == ROCK_NONE


## True if grid cell (cx, cy) is within bounds and passable.
func passable_cell(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return false
	var idx := cy * COLS + cx
	return water[idx] != WATER_DEEP and rock[idx] == ROCK_NONE


## Normalized slope along direction `dir` at point `p`:
## Positive indicates uphill travel; negative indicates downhill.
func slope_at(p: Vector2, dir: Vector2) -> float:
	if dir.is_zero_approx():
		return 0.0
	var sample_p: Vector2 = p + dir.normalized() * TerrainRules.SLOPE_SAMPLE_DIST
	sample_p.x = clampf(sample_p.x, 0.0, ARENA.x)
	sample_p.y = clampf(sample_p.y, 0.0, ARENA.y)
	var dh := height_at(sample_p) - height_at(p)
	return clampf(dh / TerrainRules.SLOPE_MAX_RISE, -1.0, 1.0)


## Overall speed factor at `p` accounting for woods, shallow water, and directional slope.
## Returns 0.0 if impassable.
func speed_factor(p: Vector2, mounted: bool = false, dir: Vector2 = Vector2.ZERO) -> float:
	if not passable(p):
		return 0.0
	var factor := 1.0
	if water_at(p) == WATER_SHALLOW:
		factor *= TerrainRules.FORD_SPEED
	if in_woods(p):
		factor *= (TerrainRules.WOODS_SPEED_HORSE if mounted else TerrainRules.WOODS_SPEED_FOOT)
	if not dir.is_zero_approx():
		var s := slope_at(p, dir)
		factor *= TerrainRules.slope_speed_mult(s)
	return factor


## Serialize terrain state for replay or save compatibility.
func to_dict() -> Dictionary:
	return {
		"height": Array(height),
		"woods": Array(woods),
		"water": Array(water),
		"rock": Array(rock),
		"features": features.duplicate(true),
	}


## Restore terrain state from dictionary.
static func from_dict(d: Dictionary) -> RefCounted:
	var t = new()
	if d.has("height"):
		t.height = PackedFloat32Array(d["height"])
	if d.has("woods"):
		t.woods = PackedByteArray(d["woods"])
	if d.has("water"):
		t.water = PackedByteArray(d["water"])
	if d.has("rock"):
		t.rock = PackedByteArray(d["rock"])
	if d.has("features"):
		t.features = d["features"].duplicate(true)
	return t
