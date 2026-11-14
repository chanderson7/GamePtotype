## Small shared art catalog. Missing or disabled art never blocks a conversation.
extends RefCounted
const Style = preload("res://scripts/ui/style.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const EXPRESSIONS := ["neutral", "amused", "thoughtful", "concerned", "warm"]
static var _textures: Dictionary = {}
## The strip of a painted portrait its eyes and brows are in. tools/portrait_faces.py saves
## that strip once per face it makes from each painting, stacked in FRAMES order, and must
## say the same. In portrait space: a painting PICTURE in size, or a whole multiple of it
## (a 768x1024 painting has twice the detail, and its strip is twice the size: face_rect).
const FACE := Rect2i(106, 104, 104, 72)
## A painted portrait's size in portrait space, which the life shader and HEADS work in.
const PICTURE := Vector2i(384, 512)
const FRAMES := ["shut", "half", "soft", "away", "brow1", "brow2"]
## How long a blink keeps the eyes shut.
const BLINK_TIME := 0.13
## Where each painted character's head sits, for assets/shaders/portrait_life.gdshader:
## the neck (chin, collar), what the head turns about, and the front of the face.
const HEADS := {
	"edda": {"chin": 226.0, "collar": 260.0, "pivot": Vector2(186, 252), "front": Vector2(150, 172)},
	"farid": {"chin": 232.0, "collar": 256.0, "pivot": Vector2(190, 250), "front": Vector2(148, 170)},
	"kaede": {"chin": 230.0, "collar": 252.0, "pivot": Vector2(186, 248), "front": Vector2(148, 168)},
}
const LIFE_SHADER := "res://assets/shaders/portrait_life.gdshader"
## Path of each texture handed out, by instance id; and the faces made for a path.
static var _paths: Dictionary = {}
static var _frames: Dictionary = {}

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


## `tex` (a painted portrait from texture()) with its eyes shut, or null if it has none.
static func eyes_shut(tex: Texture2D) -> Texture2D:
	return face_frame(tex, "shut")


## Another face of `tex` (a painted portrait from texture()): one of FRAMES, made from the
## painting by tools/portrait_faces.py. Null if the painting has no such face. The strip
## (assets/portraits/face/) is laid over the painting the first time it's asked for, so it
## sits exactly on it.
static func face_frame(tex: Texture2D, name: String) -> Texture2D:
	if tex == null or not FRAMES.has(name):
		return null
	var path := String(_paths.get(tex.get_instance_id(), ""))
	if path.is_empty():
		return null
	if not _frames.has(path):
		_frames[path] = _make_frames(path)
	return (_frames[path] as Dictionary).get(name)


static func _make_frames(path: String) -> Dictionary:
	var made := {}
	var whole := _image(path)
	var atlas := _image("%s/face/%s" % [path.get_base_dir(), path.get_file()])
	if whole == null or atlas == null:
		return made
	var rect := face_rect(whole.get_size())
	if rect.size == Vector2i.ZERO or atlas.get_width() != rect.size.x \
			or atlas.get_height() != rect.size.y * FRAMES.size():
		return made
	for i in FRAMES.size():
		var strip := atlas.get_region(Rect2i(0, rect.size.y * i, rect.size.x, rect.size.y))
		if strip.is_invisible():
			continue                                  # a face that couldn't be made
		var face := whole.duplicate() as Image
		face.blit_rect(strip, Rect2i(Vector2i.ZERO, rect.size), rect.position)
		made[FRAMES[i]] = ImageTexture.create_from_image(face)
	return made


## Where FACE lies on a painting `size` pixels big: FACE times however many times bigger
## than PICTURE the painting is. Nothing (a zero rect) for a painting that isn't a whole
## multiple of PICTURE.
static func face_rect(size: Vector2i) -> Rect2i:
	if size.x % PICTURE.x != 0 or size.y % PICTURE.y != 0 or size.x / PICTURE.x != size.y / PICTURE.y or size.x == 0:
		return Rect2i()
	var k := size.x / PICTURE.x
	return Rect2i(FACE.position * k, FACE.size * k)


## Whose painting `tex` is ("edda", "farid", "kaede"), or "".
static func painted_who(tex: Texture2D) -> String:
	var path := String(_paths.get(tex.get_instance_id(), "")) if tex != null else ""
	var who := path.get_file().get_slice("_", 0)
	return who if HEADS.has(who) else ""


## What `tex` is dressed in: "wedding" for a painting dressed for the wedding
## (tools/portrait_wedding.py), "" for every day.
static func painted_dress(tex: Texture2D) -> String:
	var path := String(_paths.get(tex.get_instance_id(), "")) if tex != null else ""
	return "wedding" if path.get_file().contains("_wedding_") else ""


## A material that lets the head and loose hair of `who`'s painting move
## (assets/shaders/portrait_life.gdshader), or null. Each face needs its own. Dressed, the
## hair that may swing is the dress's own (Edda's unbound locks; none under a veil or hood).
static func life_material(who: String, dress: String = "") -> ShaderMaterial:
	if not HEADS.has(who) or not ResourceLoader.exists(LIFE_SHADER):
		return null
	var m := ShaderMaterial.new()
	m.shader = load(LIFE_SHADER)
	var head: Dictionary = HEADS[who]
	for key in head:
		m.set_shader_parameter(key, head[key])
	var hair := texture("res://assets/portraits/face/%s_hair.png" % (who if dress.is_empty() else "%s_%s" % [who, dress]))
	if hair != null:
		m.set_shader_parameter("hair", hair)
	return m


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


## A painted portrait blinks wherever it's shown: `node` closes its eyes for a moment, now
## and then (half, shut, half), for as long as it wears the picture it has now. Nothing if
## the picture has no shut eyes, or under Reduced motion.
static func blink(node: TextureRect) -> void:
	if node == null or Style.motion_reduced():
		return
	var rest := node.texture
	var shut := eyes_shut(rest)
	if shut == null:
		return
	var half := face_frame(rest, "half")
	if half == null:
		half = shut
	var swap := func(from: Array, to: Texture2D) -> void:
		if from.has(node.texture):
			node.texture = to
	var start := func() -> void:
		var t := node.create_tween().set_loops()
		t.tween_interval(randf_range(2.4, 5.6))
		t.tween_callback(swap.bind([rest], half))
		t.tween_interval(0.03)
		t.tween_callback(swap.bind([half], shut))
		t.tween_interval(0.1)
		t.tween_callback(swap.bind([shut], half))
		t.tween_interval(0.04)
		t.tween_callback(swap.bind([half, shut], rest))
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
