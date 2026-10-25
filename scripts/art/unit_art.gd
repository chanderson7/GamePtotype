## Turns the pixel grids in sprite_data.gd into textures, once, and hands them out.
## Built in code rather than imported from PNGs, so the art works the same in the
## editor, in headless tests and in an exported build with no import step.
extends RefCounted

const Data = preload("res://scripts/art/sprite_data.gd")

## Arena units per sprite pixel. Foot soldiers come out a little wider than the room
## they take up in the sim, so formations read as solid blocks.
const FOOT_PIXEL := 2.1
const HORSE_PIXEL := 1.8
## Grass is drawn chunkier than the men, so it stays in the background.
const GRASS_PIXEL := 3.0
## Card and roster icons: frame 0 cropped to a square around the body, scaled up.
const ICON_SIZE := 20
const ICON_SCALE := 2

static var _cache := {}


## Frame `index` (0 and 1 walk, 2 strike) of a troop type in a team's colors.
static func frame(type: String, team: int, index: int) -> Texture2D:
	var key := "%s/%d/%d" % [type, team, index]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_image(type, team, index))
	return _cache[key]


## A white silhouette of the same frame, drawn over a man for a moment when he's hit.
static func flash(type: String, index: int) -> Texture2D:
	var key := "%s/flash/%d" % [type, index]
	if not _cache.has(key):
		var img := _image(type, 0, index)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color.WHITE)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Where the man stands in his sprite, in sprite pixels.
static func pivot(type: String) -> Vector2:
	return Data.SPRITES[type]["pivot"]


static func pixel_size(type: String) -> float:
	return HORSE_PIXEL if type == "cavalry" or type == "corpse_horse" else FOOT_PIXEL


## A square portrait of the troop type for cards and the camp roster.
static func icon(type: String, team: int = 0) -> Texture2D:
	var key := "%s/icon/%d" % [type, team]
	if not _cache.has(key):
		var src := _image(type, team, 0)
		var p := pivot(type)
		var img := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
		var ox := int(p.x) - ICON_SIZE / 2
		var oy := int(p.y) - ICON_SIZE / 2 - (2 if type == "cavalry" else 0)
		img.blit_rect(src, Rect2i(ox, oy, ICON_SIZE, ICON_SIZE), Vector2i.ZERO)
		img.resize(ICON_SIZE * ICON_SCALE, ICON_SIZE * ICON_SCALE, Image.INTERPOLATE_NEAREST)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## A tile of pixel-art grass: a quiet green with darker tufts.
static func grass() -> Texture2D:
	if not _cache.has("grass"):
		var size := 48
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var base := Color(0.322, 0.502, 0.235)
		for y in size:
			for x in size:
				var v := rng.randf_range(-0.018, 0.018)
				img.set_pixel(x, y, Color(base.r + v, base.g + v * 1.4, base.b + v * 0.6))
		for i in 14:
			var x := rng.randi_range(0, size - 1)
			var y := rng.randi_range(0, size - 1)
			var tuft := Color(0.278, 0.447, 0.204)
			img.set_pixel(x, y, tuft)
			img.set_pixel((x + 1) % size, y, tuft)
			img.set_pixel(x, (y + size - 1) % size, Color(0.373, 0.565, 0.267))
		_cache["grass"] = ImageTexture.create_from_image(img)
	return _cache["grass"]


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
