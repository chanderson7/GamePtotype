## Shared portrait catalog: every captain's and lord's own face, put together from the
## pixel portrait kit (LordPortrait) from who they are and what has happened to them, in
## any mood. Portraits are decorative: when illustrations are disabled, callers keep their
## normal text and troop-icon fallbacks.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")
const Captains = preload("res://scripts/data/captains.gd")
const CaptainFace = preload("res://scripts/art/captain_face.gd")
const LordPortrait = preload("res://scripts/art/lord_portrait.gd")

static var _textures: Dictionary = {}
static var _faces: Dictionary = {}


## `expression` is the moment the face is drawn for: "" for the captain's resting face, or
## one of the moods (LordPortrait.MOODS: warm, grim, laugh, sad, shy...), with what the face
## is doing after a slash ("warm/talk", "/shut"). `small` gives the picture for a little
## slot: head and shoulders, at 60 x 80.
static func texture(captain: Dictionary, expression: String = "", small: bool = false) -> Texture2D:
	if not Style.illustrations_on():
		return null
	# Old saves still carry a painted appearance id; it no longer chooses the face, but
	# keep it filled in so nothing that reads it breaks.
	Captains.ensure_appearance(captain)
	if expression == "blink":
		expression = "/shut"                    # the same face as a resting blink
	var key := _face_key(captain) + "|" + expression + ("|small" if small else "")
	if _faces.has(key):
		return _faces[key]
	# Everyone is drawn from the pixel portrait kit; the faces CaptainFace draws are kept
	# for when it can't be read.
	var tex: Texture2D = null
	if LordPortrait.available():
		var img := LordPortrait.image(captain, true, expression)
		if img != null and small:
			img = LordPortrait.bust(img)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = CaptainFace.texture(captain, true, _old_expression(expression))
	if _faces.size() > 400:
		_faces.clear()
	_faces[key] = tex
	return tex


## The nearest of the faces CaptainFace draws to `expression`.
static func _old_expression(expression: String) -> String:
	var mood := expression.get_slice("/", 0)
	var doing := expression.get_slice("/", 1) if expression.contains("/") else ""
	mood = String({"laugh": "warm", "amused": "warm", "tease": "warm", "shy": "warm", "surprised": "fear",
		"angry": "grim", "determined": "grim", "sad": "grief", "worried": "grief", "thoughtful": ""}.get(mood, mood))
	var eyes := ""
	for d in doing.split(",", false):
		if d in CaptainFace.EYES_DOING:
			eyes = d
	return mood if eyes == "" else mood + "/" + eyes


## Everything that changes how a captain looks: who they are, and how their career has
## marked them, down to the token of a veteran role.
static func _face_key(captain: Dictionary) -> String:
	var history: Dictionary = captain.get("history", {}) if typeof(captain.get("history", {})) == TYPE_DICTIONARY else {}
	return "%d|%s|%s|%s|%s|%s|%s|%d|%d|%d" % [int(captain.get("id", 0)), String(captain.get("culture", "")),
		String(captain.get("first", captain.get("name", ""))), String(captain.get("type", "")),
		String(captain.get("temperament", "")), String(captain.get("quirk", "")),
		("bandaged" if int(captain.get("wounded", 0)) > 0 else "") + String(captain.get("noble", "")) + String(captain.get("house", "")),
		CaptainFace.rank(captain), mini(3, int(history.get("wounds", 0))), 1 if int(captain.get("battles", 0)) >= 20 else 0] \
		+ "|" + String(captain.get("specialization", ""))


## Slots shorter than this show the small picture (head and shoulders).
const SMALL_BELOW := 110.0


static func portrait(captain: Dictionary, size: Vector2 = Vector2(60, 80), expression: String = "") -> TextureRect:
	var node := TextureRect.new()
	node.name = "CaptainPortrait"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.texture = texture(captain, expression, size.y < SMALL_BELOW)
	node.visible = node.texture != null
	return node


## A captain's face blinks now and then, wherever it is shown: `apply` is given the
## picture to show (their resting face, or the same with their eyes shut), and `host` is
## the control that shows it (the blinking stops when it goes). Only a resting face
## blinks (half shut, shut, half shut, open), and nothing does under Reduced motion.
static func blink_loop(host: Node, apply: Callable, captain: Dictionary, small: bool = false) -> void:
	if host == null or Style.motion_reduced():
		return
	var rest := texture(captain, "", small)
	var shut := texture(captain, "/shut", small)
	var half := texture(captain, "/half", small)
	if rest == null or shut == null:
		return
	var start := func() -> void:
		var t := host.create_tween().set_loops()
		t.tween_interval(randf_range(2.4, 5.6))
		t.tween_callback(apply.bind(half))
		t.tween_interval(0.03)
		t.tween_callback(apply.bind(shut))
		t.tween_interval(0.07)
		t.tween_callback(apply.bind(half))
		t.tween_interval(0.03)
		t.tween_callback(apply.bind(rest))
	if host.is_inside_tree():
		start.call()
	else:
		host.ready.connect(start, CONNECT_ONE_SHOT)


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
