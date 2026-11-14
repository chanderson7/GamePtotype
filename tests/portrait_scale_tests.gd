## The romance portraits' sizes and outfits. A portrait may be PICTURE (384x512) or a whole
## multiple of it: its other faces (assets/portraits/face/) are then that much bigger, and
## are laid over it at FACE times that much. Checked with one portrait at 384x512 and
## doubled pixel for pixel: every face comes out the same, doubled. Then the game's own:
## every outfit's portraits, and what she wears where.
extends SceneTree

const StoryArt = preload("res://scripts/ui/story_art.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	_run.call_deferred()


func _doubled(img: Image) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return out


func _halved(img: Image) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
	return out


func _run() -> void:
	check(StoryArt.face_rect(StoryArt.PICTURE) == StoryArt.FACE, "a 384x512 portrait's face strip is FACE")
	check(StoryArt.face_rect(Vector2i(768, 1024)) == Rect2i(StoryArt.FACE.position * 2, StoryArt.FACE.size * 2),
		"a 768x1024 portrait's is FACE twice over")
	check(StoryArt.face_rect(Vector2i(500, 512)).size == Vector2i.ZERO and StoryArt.face_rect(Vector2i(768, 512)).size == Vector2i.ZERO,
		"a picture of any other size has none (it shows, without other faces)")
	var dir := "user://portrait_scale"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "/face"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "/small/face"))
	# One of the game's portraits (tools/portrait_kit draws them on a 192x256 grid, four
	# times the size) at 384x512 with its faces, and the same at twice that.
	var here := dir + "/small/edda_neutral.png"
	var one := _halved(StoryArt._image("res://assets/portraits/edda_neutral.png"))
	var strips := _halved(StoryArt._image("res://assets/portraits/face/edda_neutral.png"))
	one.save_png(here)
	strips.save_png(dir + "/small/face/edda_neutral.png")
	_doubled(one).save_png(dir + "/edda_neutral.png")
	_doubled(strips).save_png(dir + "/face/edda_neutral.png")
	var small := StoryArt.texture(here)
	var big := StoryArt.texture(dir + "/edda_neutral.png")
	check(big != null and big.get_width() == 768 and big.get_height() == 1024, "a 768x1024 portrait loads")
	var same := 0
	for name in StoryArt.FRAMES:
		var a: Texture2D = StoryArt.face_frame(small, name)
		var b: Texture2D = StoryArt.face_frame(big, name)
		if a == null and b == null:
			same += 1
			continue
		if a == null or b == null:
			continue
		var b_image := b.get_image().duplicate() as Image
		b_image.clear_mipmaps()   # a portrait twice the size carries mipmaps; compare the picture
		if _doubled(a.get_image()).get_data() == b_image.get_data():
			same += 1
	check(same == StoryArt.FRAMES.size(), "and every other face of it is today's face, doubled (%d of %d)" % [same, StoryArt.FRAMES.size()])
	check(StoryArt.painted_who(big) == "edda" and StoryArt.life_material("edda") != null,
		"it's still Edda, and her head and hair move as before (the shader works in portrait space)")
	# The game's own: painted by the rig at twice the size, with faces to match.
	var game: Texture2D = StoryArt.texture("res://assets/portraits/edda_neutral.png")
	var ready := 0
	for who in ["edda", "farid", "kaede"]:
		for expression in StoryArt.EXPRESSIONS + ["wedding_neutral", "wedding_warm", "wedding_amused"]:
			var t: Texture2D = StoryArt.texture("res://assets/portraits/%s_%s.png" % [who, expression])
			if t != null and t.get_size() == Vector2(768, 1024) and StoryArt.face_frame(t, "shut") != null:
				ready += 1
	check(game != null and ready == 24, "every romance portrait in the game is 768x1024, and blinks (%d of 24)" % ready)
	# Her other outfits (tools/portrait_wardrobe.py): court and travel, every expression.
	var dressed := 0
	var named := 0
	var swinging := 0
	for who in ["edda", "farid", "kaede"]:
		for outfit in StoryArt.OUTFITS:
			for expression in StoryArt.EXPRESSIONS:
				var t: Texture2D = StoryArt.outfit_portrait(who, expression, outfit)
				if t != null and t.get_size() == Vector2(768, 1024) and StoryArt.face_frame(t, "shut") != null:
					dressed += 1
				if StoryArt.painted_dress(t) == outfit and StoryArt.painted_who(t) == who:
					named += 1
			var m: ShaderMaterial = StoryArt.life_material(who, outfit)
			if m != null and m.get_shader_parameter("hair") != null:
				swinging += 1
	var outfits := StoryArt.OUTFITS.size() * StoryArt.EXPRESSIONS.size() * 3
	check(dressed == outfits, "every court and travel portrait is 768x1024, and blinks (%d of %d)" % [dressed, outfits])
	check(named == outfits, "each knows what it's dressed in, and whose it is (%d of %d)" % [named, outfits])
	check(swinging == StoryArt.OUTFITS.size() * 3, "each outfit has its own loose-hair map (%d)" % swinging)
	var everyday: Texture2D = StoryArt.outfit_portrait("edda", "warm")
	check(everyday == StoryArt.texture("res://assets/portraits/edda_warm.png") and StoryArt.painted_dress(everyday) == "",
		"no outfit is what she wears every day")
	check(StoryArt.outfit_portrait("kaede", "warm", "ballgown") == StoryArt.texture("res://assets/portraits/kaede_warm.png"),
		"an outfit she hasn't got falls back to every day")
	check(StoryArt.outfit_portrait("farid", "sulking", "court") == StoryArt.texture("res://assets/portraits/farid_court_neutral.png"),
		"and a face she hasn't got, to her neutral one in that outfit")
	check(StoryArt.painted_dress(StoryArt.texture("res://assets/portraits/edda_wedding_warm.png")) == "wedding",
		"the wedding is still the wedding")
	# What she wears: court dress in a feast's hall, travelling clothes driven from home.
	var gs: Node = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	w.gatherings = []
	var p = w.player()
	p.node = "ravensford"
	p.next = ""
	p.path = []
	var edda: Dictionary = w.social.get_candidate_person("edda")
	check(String(edda.get("residence", "")) == "ravensford", "Edda lives at Ravensford")
	check(StoryArt.outfit_for("edda") == "" and StoryArt.outfit_for("kaede") == "",
		"at home (and the talks are in her own room), each is in her everyday clothes")
	w.gatherings.append({"id": 999, "place": "ravensford", "realm": "vardmark", "state": "on",
		"starts_hour": w.hour - 1.0, "ends_hour": w.hour + 24.0, "name": "feast"})
	check(StoryArt.outfit_for("edda") == "court", "at a feast in her own hall, Edda's in court dress")
	check(StoryArt.outfit_for("kaede") == "", "Kaede, not among its guests, isn't")
	w.gatherings[0]["starts_hour"] = w.hour + 12.0
	check(StoryArt.outfit_for("edda") == "", "and not before it starts")
	w.gatherings[0]["starts_hour"] = w.hour - 1.0
	p.node = "highcliff"
	check(StoryArt.outfit_for("edda") == "", "nor when you're at another town")
	w.gatherings = []
	edda["residence"] = "highcliff"
	check(StoryArt.outfit_for("edda") == "travel", "driven from her seat, she's in travelling clothes")
	check(StoryArt.outfit_for("edda", null) == StoryArt.outfit_for("edda", w), "the world can be handed in")
	edda["residence"] = "ravensford"
	for f in ["edda_neutral.png", "face/edda_neutral.png", "small/edda_neutral.png", "small/face/edda_neutral.png"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/" + f))
	print("Portrait scale failures: %d" % failures)
	quit(1 if failures > 0 else 0)
