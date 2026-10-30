## Shared captain portrait catalog. Portraits are decorative: when illustrations are
## disabled, callers keep their normal text and troop-icon fallbacks.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")
const Captains = preload("res://scripts/data/captains.gd")

static var _textures: Dictionary = {}


static func texture(captain: Dictionary) -> Texture2D:
	if not Style.illustrations_on():
		return null
	Captains.ensure_appearance(captain)
	var appearance := String(captain.get("appearance_id", "fallback"))
	var path := "res://assets/portraits/captain_%s.png" % appearance
	var result := _load(path)
	if result == null and appearance != "fallback":
		result = _load("res://assets/portraits/captain_fallback.png")
	return result


static func portrait(captain: Dictionary, size: Vector2 = Vector2(60, 80)) -> TextureRect:
	var node := TextureRect.new()
	node.name = "CaptainPortrait"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.texture = texture(captain)
	node.visible = node.texture != null
	return node


static func _load(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var result: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		result = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			result = ImageTexture.create_from_image(image)
	if result != null:
		_textures[path] = result
	return result
