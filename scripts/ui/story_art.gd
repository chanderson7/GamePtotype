## Small shared art catalog. Missing or disabled art never blocks a conversation.
extends RefCounted
const Style = preload("res://scripts/ui/style.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const EXPRESSIONS := ["neutral", "amused", "thoughtful", "concerned", "warm"]
static var _textures: Dictionary = {}
## The strip of a painted portrait its eyes are in. tools/portrait_blink.py saves that
## strip with the eyes shut, for every painting, and must say the same.
const EYES := Rect2i(112, 136, 96, 40)
## How long a blink keeps the eyes shut.
const BLINK_TIME := 0.13
## Path of each texture handed out, by instance id; and the shut-eyed twin made for a path.
static var _paths: Dictionary = {}
static var _shut: Dictionary = {}

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
		_paths[result.get_instance_id()] = path
	return result


## `tex` (a painted portrait from texture()) with its eyes shut, or null if it has no
## such picture. The shut eyes are a small strip (assets/portraits/blink/) laid over the
## painting the first time it's asked for, so they sit exactly on the open ones.
static func eyes_shut(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var path := String(_paths.get(tex.get_instance_id(), ""))
	if path.is_empty():
		return null
	if _shut.has(path):
		return _shut[path]
	var result: Texture2D = null
	var whole := _image(path)
	var strip := _image("%s/blink/%s" % [path.get_base_dir(), path.get_file()])
	if whole != null and strip != null and strip.get_size() == EYES.size \
			and Rect2i(Vector2i.ZERO, whole.get_size()).encloses(EYES):
		whole.blit_rect(strip, Rect2i(Vector2i.ZERO, EYES.size), EYES.position)
		result = ImageTexture.create_from_image(whole)
	_shut[path] = result
	return result


## The pixels of the picture at `path`, as RGBA, or null.
static func _image(path: String) -> Image:
	var img: Image = null
	if ResourceLoader.exists(path, "Texture2D"):
		var tex := load(path) as Texture2D
		if tex != null:
			img = tex.get_image()
	if (img == null or img.is_empty()) and FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	# Our own copy: without a screen the texture hands out the image it keeps.
	img = img.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## A painted portrait blinks wherever it's shown: `node` swaps to its shut-eyed twin for
## a moment, now and then, for as long as it wears the picture it has now. Nothing if
## the picture has no twin, or under Reduced motion.
static func blink(node: TextureRect) -> void:
	if node == null or Style.motion_reduced():
		return
	var rest := node.texture
	var shut := eyes_shut(rest)
	if shut == null:
		return
	var close := func() -> void:
		if node.texture == rest:
			node.texture = shut
	var open := func() -> void:
		if node.texture == shut:
			node.texture = rest
	var start := func() -> void:
		var t := node.create_tween().set_loops()
		t.tween_interval(randf_range(2.4, 5.6))
		t.tween_callback(close)
		t.tween_interval(BLINK_TIME)
		t.tween_callback(open)
	if node.is_inside_tree():
		start.call()
	else:
		node.ready.connect(start, CONNECT_ONE_SHOT)


static func portrait(expression: String = "neutral", height: float = 176.0) -> TextureRect:
	return candidate_portrait("edda", expression, height)


static func candidate_portrait(candidate_id: String, expression: String = "neutral", height: float = 176.0) -> TextureRect:
	var node := TextureRect.new()
	node.name = "%sPortrait" % candidate_id.capitalize()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(height * 0.75, height)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var safe := expression if EXPRESSIONS.has(expression) else "neutral"
	node.texture = texture("res://assets/portraits/%s_%s.png" % [candidate_id, safe])
	if node.texture == null and safe != "neutral":
		node.texture = texture("res://assets/portraits/%s_neutral.png" % candidate_id)
	node.visible = node.texture != null
	blink(node)
	return node

static func location(id: String, height: float = 230.0) -> TextureRect:
	var node := TextureRect.new()
	node.name = "LocationIllustration"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size.y = height
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if id in ["ravensford", "common_room", "company_camp", "qasr_hamra", "envoy_room", "kitayama", "archive_room"]:
		node.texture = texture("res://assets/locations/%s.png" % id)
	node.visible = node.texture != null
	return node

static func identity(candidate_id: String = "edda", expression: String = "neutral") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(candidate_portrait(candidate_id, expression))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var labels := {
		"edda": ["Edda", "Steward · a place for ordinary stories"],
		"farid": ["Farah", "Envoy · words with no audience to persuade"],
		"kaede": ["Kaede", "Archivist · the details she chooses to keep"],
	}
	var copy: Array = labels.get(candidate_id, [candidate_id.capitalize(), "Personal conversations"])
	words.add_child(Page.note(copy[0], Style.LARGE, Style.BRASS))
	words.add_child(Page.note(copy[1], Style.SMALL))
	return row

static func stage(expression: String, setting: String = "common_room") -> Control:
	return candidate_stage("edda", expression, setting)


static func candidate_stage(candidate_id: String, expression: String, setting: String) -> Control:
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
	var face := candidate_portrait(candidate_id, expression, 0)
	root.add_child(face)
	face.anchor_left = 0.55
	face.anchor_right = 1.0
	face.anchor_bottom = 1.0
	return root
