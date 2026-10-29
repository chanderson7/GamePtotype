## Small shared art catalog. Missing or disabled art never blocks a conversation.
extends RefCounted
const Style = preload("res://scripts/ui/style.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const EXPRESSIONS := ["neutral", "amused", "thoughtful", "concerned", "warm"]
static var _textures: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not Style.illustrations_on() or path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path]
	var result: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		result = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			result = ImageTexture.create_from_image(img)
	if result != null:
		_textures[path] = result
	return result

static func portrait(expression: String = "neutral", height: float = 176.0) -> TextureRect:
	var node := TextureRect.new()
	node.name = "EddaPortrait"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(height * 0.75, height)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var safe := expression if EXPRESSIONS.has(expression) else "neutral"
	node.texture = texture("res://assets/portraits/edda_%s.png" % safe)
	if node.texture == null and safe != "neutral":
		node.texture = texture("res://assets/portraits/edda_neutral.png")
	node.visible = node.texture != null
	return node

static func location(id: String, height: float = 230.0) -> TextureRect:
	var node := TextureRect.new()
	node.name = "LocationIllustration"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size.y = height
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if id in ["ravensford", "common_room"]:
		node.texture = texture("res://assets/locations/%s.png" % id)
	node.visible = node.texture != null
	return node

static func identity(expression: String = "neutral") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(portrait(expression))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	words.add_child(Page.note("Edda", Style.LARGE, Style.BRASS))
	words.add_child(Page.note("Steward · a place for ordinary stories", Style.SMALL))
	return row

static func stage(expression: String, setting: String = "common_room") -> Control:
	var root := Control.new()
	root.name = "StoryStage"
	root.custom_minimum_size.y = 240
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = Style.illustrations_on()
	var bg := ColorRect.new()
	bg.color = Style.PANEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var room := location(setting, 0)
	root.add_child(room)
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var face := portrait(expression, 0)
	root.add_child(face)
	face.anchor_left = 0.55
	face.anchor_right = 1.0
	face.anchor_bottom = 1.0
	return root
