## Turns the pixel grids in map_sprite_data.gd into textures, once, and hands them out:
## settlements, terrain and parties for the world map.
extends RefCounted

const Data = preload("res://scripts/art/map_sprite_data.gd")

static var _cache := {}


static func has(name: String) -> bool:
	return Data.SPRITES.has(name)


## Frame `index` of a map sprite, with its owner's colors (T/t/L) in `color`.
static func texture(name: String, index: int = 0, color: Color = Color(0.29, 0.45, 0.82)) -> Texture2D:
	var key := "%s/%d/%s" % [name, index, color.to_html(false)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_image(name, index, color))
	return _cache[key]


## Where the sprite stands on the ground, in sprite pixels: the middle of its bottom row.
static func pivot(name: String) -> Vector2:
	return Data.SPRITES[name]["pivot"]


static func size(name: String) -> Vector2:
	var rows: Array = Data.SPRITES[name]["frames"][0]
	return Vector2(String(rows[0]).length(), rows.size())


static func _image(name: String, index: int, color: Color) -> Image:
	var frames: Array = Data.SPRITES[name]["frames"]
	var rows: Array = frames[mini(index, frames.size() - 1)]
	var colors: Dictionary = Data.PALETTE.duplicate()
	colors["T"] = color
	colors["t"] = color.darkened(0.45)
	colors["L"] = color.lightened(0.45)
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
