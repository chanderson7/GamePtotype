## Small shared art catalog. Missing or disabled art never blocks a conversation.
extends RefCounted
const Style = preload("res://scripts/ui/style.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const EXPRESSIONS := ["neutral", "amused", "thoughtful", "concerned", "warm"]
## Her outfits besides what she wears every day (assets/portraits/<who>_<outfit>_<expression>.png,
## drawn by tools/portrait_kit).
const OUTFITS := ["court", "travel", "winter", "mourning"]
static var _textures: Dictionary = {}
## The strip of a romance portrait its eyes and brows are in. tools/portrait_kit/build.py
## saves that strip once per face it draws for each portrait (FRAMES, stacked in that
## order), and must say the same (FACE_STRIP there, on its own grid). In portrait space: a
## picture PICTURE in size, or a whole multiple of it (the portraits are 768x1024, so their
## strips are twice this: face_rect).
const FACE := Rect2i(116, 116, 136, 76)
## The strip her mouth is in: saved once more with her mouth open on a word
## (assets/portraits/mouth/, MOUTH_STRIP in the kit), for when she speaks (talking).
const MOUTH := Rect2i(144, 200, 80, 56)
## A portrait's size in portrait space, which the life shader and HEADS work in.
const PICTURE := Vector2i(384, 512)
const FRAMES := ["shut", "half", "soft", "away", "brow1", "brow2"]
## How long a blink keeps the eyes shut.
const BLINK_TIME := 0.13
## Where each character's head sits, for assets/shaders/portrait_life.gdshader: the neck
## (chin, collar), what the head turns about, and the front of the face. Each holds her
## head at her own height (POSES in tools/portrait_kit/build.py).
const HEADS := {
	"edda": {"chin": 258.0, "collar": 288.0, "pivot": Vector2(194, 284), "front": Vector2(172, 188)},
	"farid": {"chin": 254.0, "collar": 286.0, "pivot": Vector2(194, 282), "front": Vector2(178, 184)},
	"kaede": {"chin": 266.0, "collar": 292.0, "pivot": Vector2(194, 288), "front": Vector2(175, 192)},
}
const LIFE_SHADER := "res://assets/shaders/portrait_life.gdshader"
## Path of each texture handed out, by instance id; and the faces made for a path.
static var _paths: Dictionary = {}
static var _frames: Dictionary = {}
## The portrait each made face came from, and each face's twin with its mouth open.
static var _sources: Dictionary = {}
static var _talking: Dictionary = {}

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
		result = _with_mipmaps(result)
		_textures[path] = result
		_paths[result.get_instance_id()] = path
	return result


## A painting bigger than PICTURE (the romance portraits, painted at twice the size) is
## drawn smaller than its pixels, so it needs mipmaps, whatever its import settings say
## (they aren't kept in the repository): made here, once, when it's first loaded.
static func _with_mipmaps(tex: Texture2D) -> Texture2D:
	var size := Vector2i(tex.get_size())
	if face_rect(size).size == Vector2i.ZERO or size == PICTURE:
		return tex
	var img := tex.get_image()
	if img == null or img.is_empty() or img.has_mipmaps():
		return tex
	img = img.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		return tex
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## `tex` (a painted portrait from texture()) with its eyes shut, or null if it has none.
static func eyes_shut(tex: Texture2D) -> Texture2D:
	return face_frame(tex, "shut")


## Another face of `tex` (a painted portrait from texture()): one of FRAMES, made from the
## portrait by tools/portrait_kit/build.py. Null if the painting has no such face. The strip
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
	# A painting bigger than PICTURE is drawn smaller than its pixels: its other faces
	# carry mipmaps as it does, so a blink doesn't sharpen it for a moment.
	var mipmapped := rect.size != FACE.size
	if whole.has_mipmaps():
		whole.clear_mipmaps()
	for i in FRAMES.size():
		var strip := atlas.get_region(Rect2i(0, rect.size.y * i, rect.size.x, rect.size.y))
		if strip.is_invisible():
			continue                                  # a face that couldn't be made
		var face := whole.duplicate() as Image
		face.blit_rect(strip, Rect2i(Vector2i.ZERO, rect.size), rect.position)
		if mipmapped:
			face.generate_mipmaps()
		made[FRAMES[i]] = ImageTexture.create_from_image(face)
		_sources[(made[FRAMES[i]] as Texture2D).get_instance_id()] = path
	return made


## `tex` (a romance portrait from texture(), or one of its faces from face_frame()) with
## her mouth open on a word, or null if it has none. Made the first time it's asked for:
## the portrait's mouth strip (assets/portraits/mouth/) laid over that face.
static func talking(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var id := tex.get_instance_id()
	if _talking.has(id):
		return _talking[id]
	var made: Texture2D = null
	var path := String(_paths.get(id, _sources.get(id, "")))
	var img := tex.get_image() if not path.is_empty() else null
	if img != null and not img.is_empty():
		var strip := _image("%s/mouth/%s" % [path.get_base_dir(), path.get_file()])
		var rect := _scaled(MOUTH, img.get_size())
		if strip != null and rect.size != Vector2i.ZERO and strip.get_size() == rect.size:
			img = img.duplicate() as Image
			var mipmapped := img.has_mipmaps()
			if mipmapped:
				img.clear_mipmaps()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.blit_rect(strip, Rect2i(Vector2i.ZERO, rect.size), rect.position)
			if mipmapped:
				img.generate_mipmaps()
			made = ImageTexture.create_from_image(img)
	_talking[id] = made
	return made


## Where FACE lies on a painting `size` pixels big: FACE times however many times bigger
## than PICTURE the painting is. Nothing (a zero rect) for a painting that isn't a whole
## multiple of PICTURE.
static func face_rect(size: Vector2i) -> Rect2i:
	return _scaled(FACE, size)


## `rect` (in portrait space) on a picture `size` pixels big; a zero rect for a picture that
## isn't a whole multiple of PICTURE.
static func _scaled(rect: Rect2i, size: Vector2i) -> Rect2i:
	if size.x % PICTURE.x != 0 or size.y % PICTURE.y != 0 or size.x / PICTURE.x != size.y / PICTURE.y or size.x == 0:
		return Rect2i()
	var k := size.x / PICTURE.x
	return Rect2i(rect.position * k, rect.size * k)


## Whose painting `tex` is ("edda", "farid", "kaede"), or "".
static func painted_who(tex: Texture2D) -> String:
	var path := String(_paths.get(tex.get_instance_id(), "")) if tex != null else ""
	var who := path.get_file().get_slice("_", 0)
	return who if HEADS.has(who) else ""


## What `tex` is dressed in: "wedding" for a portrait dressed for the wedding, an outfit's
## name ("court", "travel") for one of her other outfits (all drawn by tools/portrait_kit),
## "" for every day.
static func painted_dress(tex: Texture2D) -> String:
	var path := String(_paths.get(tex.get_instance_id(), "")) if tex != null else ""
	var parts := path.get_file().get_basename().split("_")
	if parts.has("wedding"):
		return "wedding"
	return parts[1] if parts.size() == 3 and OUTFITS.has(parts[1]) else ""


## Her portrait in `outfit` ("" for every day, or one of OUTFITS), at `expression`: falls
## back to every day, then to her neutral face.
static func outfit_portrait(candidate_id: String, expression: String, outfit: String = "") -> Texture2D:
	var safe := expression if EXPRESSIONS.has(expression) else "neutral"
	var paths: Array = []
	if OUTFITS.has(outfit):
		paths.append("res://assets/portraits/%s_%s_%s.png" % [candidate_id, outfit, safe])
	paths.append("res://assets/portraits/%s_%s.png" % [candidate_id, safe])
	paths.append("res://assets/portraits/%s_neutral.png" % candidate_id)
	for path in paths:
		var tex := texture(path)
		if tex != null:
			return tex
	return null


## The year, for what she wears: YEAR_DAYS long, four seasons of equal length beginning
## with spring on the campaign's first day.
const YEAR_DAYS := 96
const SEASONS := ["spring", "summer", "autumn", "winter"]
## How long she wears mourning after one of your captains falls (hours), and who does:
## someone who has come to know you.
const MOURNING_HOURS := 72.0
const MOURNERS := ["courting", "committed", "engaged", "married", "friendship"]


## The season at `hour` of the campaign.
static func season(hour: float) -> String:
	var day := int(floor(maxf(hour, 0.0) / 24.0)) % YEAR_DAYS
	return SEASONS[day * SEASONS.size() / YEAR_DAYS]


## What she's wearing, the first of these that holds:
## - court dress in the hall of a feast that's on where you are (she's among its guests);
## - mourning for MOURNING_HOURS after one of your captains falls, once she knows you well;
## - travelling clothes once she's been driven from her own seat;
## - winter clothes in winter;
## - otherwise her everyday clothes ("").
## The talks are in her own room, so where you are matters only at a feast. `w` is the
## world and `fallen` your memorials (the game's own if left out).
static func outfit_for(candidate_id: String, w = null, fallen = null) -> String:
	if w == null or fallen == null:
		var tree := Engine.get_main_loop() as SceneTree
		var gs: Node = tree.root.get_node_or_null("GameState") if tree != null else null
		if w == null:
			w = gs.get("world") if gs != null else null
		if fallen == null:
			fallen = gs.get("fallen") if gs != null else []
	if w == null or w.social == null:
		return ""
	var person: Dictionary = w.social.get_candidate_person(candidate_id)
	if person.is_empty():
		return ""
	var here := String(w.here())
	var g: Dictionary = w.gathering_at(here) if here != "" else {}
	if not g.is_empty() and w.gathering_on(g) \
			and w.social.attending(here, w.lords_at(here), String(g.get("realm", w.owner_of(here)))).has(person):
		return "court"
	if MOURNERS.has(String(w.social.get_relationship(candidate_id).get("status", ""))):
		for m in (fallen if fallen is Array else []):
			var at := float((m as Dictionary).get("hour", -1.0)) if m is Dictionary else -1.0
			if at >= 0.0 and float(w.hour) - at >= 0.0 and float(w.hour) - at < MOURNING_HOURS:
				return "mourning"
	var seat := String(RomanceStories.CANDIDATES.get(candidate_id, {}).get("initial_seat", ""))
	var home := String(person.get("residence", ""))
	if seat != "" and home != "" and home != seat:
		return "travel"
	return "winter" if season(float(w.hour)) == "winter" else ""


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
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	node.texture = outfit_portrait(candidate_id, expression, outfit_for(candidate_id))
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
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if id in ["ravensford", "common_room", "company_camp", "qasr_hamra", "envoy_room", "kitayama", "archive_room"]:
		node.texture = texture("res://assets/locations/%s.png" % id)
	node.visible = node.texture != null
	if id == "company_camp" and node.texture != null:
		load("res://scripts/ui/camp_life.gd").over(node)
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
