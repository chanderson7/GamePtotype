## Turns the pixel grids in sprite_data.gd into textures, once, and hands them out.
## Built in code rather than imported from PNGs, so the art works the same in the
## editor, in headless tests and in an exported build with no import step.
extends RefCounted

const Data = preload("res://scripts/art/sprite_data.gd")
const Units = preload("res://scripts/data/units.gd")

## Arena units per sprite pixel. Men are drawn a size larger than the room they take up
## in the sim, so they read on a phone and formations read as solid blocks.
const FOOT_PIXEL := 2.4
const HORSE_PIXEL := 2.05
## Bushes and stones keep their own size, so a man stands a little taller than a shrub.
const PROP_PIXEL := 2.1
## Grass is drawn chunkier than the men, so it stays in the background.
const GRASS_PIXEL := 3.0
## Card and roster icons: frame 0 cropped to a square around the body, scaled up.
const ICON_SIZE := 20
const ICON_SCALE := 2

static var _cache := {}

## The unit atlas: every frame a battle draws, each in a CELL-sized cell (the sprite at (1, 1)
## inside it, a clear pixel all round), so a whole army is one draw. Cells are filled as
## frames are first asked for. The largest sprite is 22 by 28.
const CELL := Vector2i(24, 30)
const ATLAS := 1024
## A disk for shadows: centre DISK_C, radius DISK_R, in its own pixels (22 by 22).
const DISK_C := Vector2(11.0, 11.0)
const DISK_R := 11.0
const DISK_SIZE := 22
static var _atlas_img: Image
static var _atlas_tex: ImageTexture
static var _atlas_cells := {}
static var _atlas_dirty := false


## Frame `index` (0 and 1 walk, 2 strike, 3 the passing step between the walks) of a troop type as `culture` dresses it, in
## a team's colors. Bodies and arrows look the same for everyone.
static func frame(type: String, team: int, index: int, culture: String = "vardish") -> Texture2D:
	var name := sprite_name(type, culture)
	var key := "%s/%d/%d" % [name, team, index]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_image(name, team, index))
	return _cache[key]


## The sprite drawn for a troop type of a culture: "ryumon/archers", or "corpse". A unit
## id names its own sprite when its branch has one ("vardish_knights"), else its recruit's.
static func sprite_name(type: String, culture: String) -> String:
	if Data.SPRITES.has(type):
		return type
	var role := type
	var cult := culture
	if Units.has(type):
		role = Units.role(type)
		cult = Units.culture(type)
	var name := "%s/%s" % [cult, role]
	if Data.SPRITES.has(name):
		return name
	if Data.SPRITES.has(role):
		return role
	if Data.SPRITES.has("vardish/" + role):
		return "vardish/" + role
	# An id nothing knows (an old save, a renamed unit) still draws, as a footman of its
	# people, rather than stopping the page.
	return "%s/infantry" % cult if Data.SPRITES.has("%s/infantry" % cult) else "vardish/infantry"


## A white silhouette of the same frame, drawn over a man for a moment when he's hit.
static func flash(type: String, index: int, culture: String = "vardish") -> Texture2D:
	var name := sprite_name(type, culture)
	var key := "%s/flash/%d" % [name, index]
	if not _cache.has(key):
		var img := _image(name, 0, index)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color.WHITE)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Where frame `index` of a troop type, in a team's colours, sits in the atlas: its
## top-left and size, in UV (the size times ATLAS is its size in pixels).
static func atlas_cell(type: String, team: int, index: int, culture: String = "vardish") -> Rect2:
	var name := sprite_name(type, culture)
	var key := "%s/%d/%d" % [name, team, index]
	if _atlas_cells.has(key):
		return _atlas_cells[key]
	return _atlas_add(key, _image(name, team, index))


## The shadow disk's place in the atlas.
static func atlas_disk() -> Rect2:
	if _atlas_cells.has("disk"):
		return _atlas_cells["disk"]
	var img := Image.create_empty(DISK_SIZE, DISK_SIZE, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5, y + 0.5).distance_to(DISK_C) <= DISK_R:
				img.set_pixel(x, y, Color.WHITE)
	return _atlas_add("disk", img)


static func _atlas_add(key: String, img: Image) -> Rect2:
	if _atlas_img == null:
		_atlas_img = Image.create_empty(ATLAS, ATLAS, false, Image.FORMAT_RGBA8)
	var cols := ATLAS / CELL.x
	var n := _atlas_cells.size()
	if n >= cols * (ATLAS / CELL.y):
		push_warning("unit atlas full")
		n = 0
	var at := Vector2i((n % cols) * CELL.x, (n / cols) * CELL.y)
	_atlas_img.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at + Vector2i.ONE)
	_atlas_dirty = true
	var uv := Rect2(Vector2(at + Vector2i.ONE) / float(ATLAS), Vector2(img.get_size()) / float(ATLAS))
	_atlas_cells[key] = uv
	return uv


## The atlas, with any cells added since the last call.
static func atlas() -> Texture2D:
	if _atlas_img == null:
		atlas_disk()
	if _atlas_tex == null:
		_atlas_tex = ImageTexture.create_from_image(_atlas_img)
	elif _atlas_dirty:
		_atlas_tex.update(_atlas_img)
	_atlas_dirty = false
	return _atlas_tex


## Where the man stands in his sprite, in sprite pixels.
static func pivot(type: String, culture: String = "vardish") -> Vector2:
	return Data.SPRITES[sprite_name(type, culture)]["pivot"]


static func pixel_size(type: String) -> float:
	var role := Units.role(type) if Units.has(type) else type
	return HORSE_PIXEL if role == "cavalry" or role == "corpse_horse" else FOOT_PIXEL


## A square portrait of the troop type, as `culture` dresses it, for cards and rosters.
static func icon(type: String, team: int = 0, culture: String = "vardish") -> Texture2D:
	var name := sprite_name(type, culture)
	var key := "%s/icon/%d" % [name, team]
	if not _cache.has(key):
		var src := _image(name, team, 0)
		var p := pivot(type, culture)
		var img := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
		var ox := int(p.x) - ICON_SIZE / 2
		var oy := int(p.y) - ICON_SIZE / 2 - (2 if pixel_size(type) == HORSE_PIXEL else 0)
		img.blit_rect(src, Rect2i(ox, oy, ICON_SIZE, ICON_SIZE), Vector2i.ZERO)
		img.resize(ICON_SIZE * ICON_SCALE, ICON_SIZE * ICON_SCALE, Image.INTERPOLATE_NEAREST)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## The ground of a battlefield, by the land the fight is in: {base, tuft, light, speck,
## specks}. Meadow in Vardmark with a few yellow flowers, dry steppe in Kharzan with
## pebbles, deep moss on the Ryumon isles with fallen petals.
const GROUND := {
	"vardish": {"base": Color(0.322, 0.502, 0.235), "tuft": Color(0.278, 0.447, 0.204),
		"light": Color(0.373, 0.565, 0.267), "speck": Color(0.93, 0.86, 0.47), "specks": 3},
	"kharzani": {"base": Color(0.612, 0.522, 0.329), "tuft": Color(0.525, 0.459, 0.255),
		"light": Color(0.69, 0.608, 0.408), "speck": Color(0.47, 0.45, 0.42), "specks": 7},
	"ryumon": {"base": Color(0.247, 0.42, 0.263), "tuft": Color(0.196, 0.353, 0.212),
		"light": Color(0.306, 0.49, 0.302), "speck": Color(0.94, 0.70, 0.78), "specks": 4},
}


## A tile of pixel-art ground for a culture's land: a quiet base with broad, soft patches
## of lighter and darker growth (seamless noise, so the tile repeats without a seam), a
## fine grain over it, darker tufts and a few specks. 192 pixels, so the patches are big
## enough to read as ground and not as a pattern.
static func ground(biome: String = "vardish") -> Texture2D:
	var key := "ground/" + biome
	if not _cache.has(key):
		var look: Dictionary = GROUND.get(biome, GROUND["vardish"])
		var size := 192
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var base: Color = look["base"]
		var tuft: Color = look["tuft"]
		var light: Color = look["light"]
		var patches := FastNoiseLite.new()
		patches.seed = 11
		patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		patches.frequency = 0.028
		patches.fractal_octaves = 2
		var patch_img := patches.get_seamless_image(size, size)
		var grain := FastNoiseLite.new()
		grain.seed = 12
		grain.noise_type = FastNoiseLite.TYPE_VALUE
		grain.fractal_type = FastNoiseLite.FRACTAL_NONE
		grain.frequency = 0.35
		var grain_img := grain.get_seamless_image(size, size)
		for y in size:
			for x in size:
				var pv := patch_img.get_pixel(x, y).r - 0.5
				var c := base.lerp(light if pv > 0.0 else tuft, absf(pv) * 0.55)
				var g := (grain_img.get_pixel(x, y).r - 0.5) * 0.05
				img.set_pixel(x, y, Color(c.r + g, c.g + g * 1.3, c.b + g * 0.6))
		for i in 230:
			var x := rng.randi_range(0, size - 1)
			var y := rng.randi_range(0, size - 1)
			img.set_pixel(x, y, tuft)
			img.set_pixel((x + 1) % size, y, tuft)
			img.set_pixel(x, (y + size - 1) % size, light)
		for i in int(look["specks"]) * 16:
			img.set_pixel(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), look["speck"])
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func _image(type: String, team: int, index: int) -> Image:
	var spr: Dictionary = Data.SPRITES[type]
	var frames: Array = spr["frames"]
	var rows: Array = frames[mini(index, frames.size() - 1)]
	var colors: Dictionary = Data.PALETTE.duplicate()
	colors.merge(Data.TEAMS[clampi(team, 0, 1)], true)
	var h := rows.size()
	var w := String(rows[0]).length()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row := String(rows[y])
		for x in w:
			var ch := row[x]
			if ch != ".":
				img.set_pixel(x, y, colors[ch])
	return img
