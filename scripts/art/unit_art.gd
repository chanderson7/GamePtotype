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


## Frame `index` (0 and 1 walk, 2 strike) of a troop type as `culture` dresses it, in
## a team's colors. Bodies and arrows look the same for everyone.
static func frame(type: String, team: int, index: int, culture: String = "vardish") -> Texture2D:
	var name := sprite_name(type, culture)
	var key := "%s/%d/%d" % [name, team, index]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_image(name, team, index))
	return _cache[key]


## The sprite drawn for a troop type of a culture: "ryumon/archers", or "corpse".
static func sprite_name(type: String, culture: String) -> String:
	var name := "%s/%s" % [culture, type]
	if Data.SPRITES.has(name):
		return name
	if Data.SPRITES.has(type):
		return type
	return "vardish/" + type


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


## Where the man stands in his sprite, in sprite pixels.
static func pivot(type: String, culture: String = "vardish") -> Vector2:
	return Data.SPRITES[sprite_name(type, culture)]["pivot"]


static func pixel_size(type: String) -> float:
	return HORSE_PIXEL if type == "cavalry" or type == "corpse_horse" else FOOT_PIXEL


## A square portrait of the troop type, as `culture` dresses it, for cards and rosters.
static func icon(type: String, team: int = 0, culture: String = "vardish") -> Texture2D:
	var name := sprite_name(type, culture)
	var key := "%s/icon/%d" % [name, team]
	if not _cache.has(key):
		var src := _image(name, team, 0)
		var p := pivot(type, culture)
		var img := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
		var ox := int(p.x) - ICON_SIZE / 2
		var oy := int(p.y) - ICON_SIZE / 2 - (2 if type == "cavalry" else 0)
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


## A tile of pixel-art ground for a culture's land: a quiet base with darker tufts.
static func ground(biome: String = "vardish") -> Texture2D:
	var key := "ground/" + biome
	if not _cache.has(key):
		var look: Dictionary = GROUND.get(biome, GROUND["vardish"])
		var size := 48
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var base: Color = look["base"]
		for y in size:
			for x in size:
				var v := rng.randf_range(-0.018, 0.018)
				img.set_pixel(x, y, Color(base.r + v, base.g + v * 1.4, base.b + v * 0.6))
		for i in 14:
			var x := rng.randi_range(0, size - 1)
			var y := rng.randi_range(0, size - 1)
			img.set_pixel(x, y, look["tuft"])
			img.set_pixel((x + 1) % size, y, look["tuft"])
			img.set_pixel(x, (y + size - 1) % size, look["light"])
		for i in int(look["specks"]):
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
