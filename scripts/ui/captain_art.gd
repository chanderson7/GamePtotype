## Shared captain portrait catalog: every captain's own face, drawn by CaptainFace from
## who they are and what has happened to them. Portraits are decorative: when
## illustrations are disabled, callers keep their normal text and troop-icon fallbacks.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")
const Captains = preload("res://scripts/data/captains.gd")
const CaptainFace = preload("res://scripts/art/captain_face.gd")

static var _textures: Dictionary = {}
static var _faces: Dictionary = {}


static func texture(captain: Dictionary) -> Texture2D:
	if not Style.illustrations_on():
		return null
	# Old saves still carry a painted appearance id; it no longer chooses the face, but
	# keep it filled in so nothing that reads it breaks.
	Captains.ensure_appearance(captain)
	var key := _face_key(captain)
	if _faces.has(key):
		return _faces[key]
	var tex: Texture2D = CaptainFace.texture(captain)
	if _faces.size() > 400:
		_faces.clear()
	_faces[key] = tex
	return tex


## Everything that changes how a captain looks: who they are, and how their career has
## marked them.
static func _face_key(captain: Dictionary) -> String:
	var history: Dictionary = captain.get("history", {}) if typeof(captain.get("history", {})) == TYPE_DICTIONARY else {}
	return "%d|%s|%s|%s|%s|%s|%s|%d|%d|%d" % [int(captain.get("id", 0)), String(captain.get("culture", "")),
		String(captain.get("first", captain.get("name", ""))), String(captain.get("type", "")),
		String(captain.get("temperament", "")), String(captain.get("quirk", "")),
		"bandaged" if int(captain.get("wounded", 0)) > 0 else "",
		CaptainFace.rank(captain), mini(3, int(history.get("wounds", 0))), 1 if int(captain.get("battles", 0)) >= 20 else 0]


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
