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
	# The year turns: winter is its last quarter, and she dresses for it.
	check(StoryArt.season(0.0) == "spring" and StoryArt.season(24.0 * 30) == "summer" and StoryArt.season(24.0 * 50) == "autumn"
		and StoryArt.season(24.0 * 80) == "winter" and StoryArt.season(24.0 * (StoryArt.YEAR_DAYS + 3)) == "spring",
		"a year is four seasons, beginning with spring")
	var was_hour: float = w.hour
	w.hour = 24.0 * 80 + 10.0
	check(StoryArt.outfit_for("edda") == "winter", "in winter she's in winter clothes")
	edda["residence"] = "highcliff"
	check(StoryArt.outfit_for("edda") == "travel", "driven from her seat, travelling clothes even in winter")
	edda["residence"] = "ravensford"
	# One of your captains falls: someone who knows you well wears mourning for three days.
	var rel: Dictionary = w.social.get_relationship("edda")
	var was_status := String(rel.get("status", ""))
	var lost := [{"first": "Rowan", "hour": w.hour - 10.0}]
	check(StoryArt.outfit_for("edda", w, lost) == "winter", "a stranger doesn't mourn your captain")
	rel["status"] = "courting"
	check(StoryArt.outfit_for("edda", w, lost) == "mourning", "someone you court wears mourning when a captain of yours falls")
	check(StoryArt.outfit_for("edda", w, [{"first": "Rowan", "hour": w.hour - StoryArt.MOURNING_HOURS - 1.0}]) == "winter",
		"for three days, no longer")
	check(StoryArt.outfit_for("edda", w, [{"first": "Rowan", "battle": 2}]) == "winter", "a memorial from an older save, with no hour, isn't mourned again")
	rel["status"] = was_status
	w.hour = was_hour
	# She speaks: every face has a twin with its mouth open, the same everywhere but her mouth.
	var spoken := 0
	var only_mouth := true
	for who in ["edda", "farid", "kaede"]:
		for face in [StoryArt.outfit_portrait(who, "neutral"), StoryArt.face_frame(StoryArt.outfit_portrait(who, "warm", "court"), "shut")]:
			var said: Texture2D = StoryArt.talking(face)
			if said == null or said == face or said.get_size() != face.get_size():
				continue
			spoken += 1
			var a := (face as Texture2D).get_image().duplicate() as Image
			var b := said.get_image().duplicate() as Image
			a.clear_mipmaps()
			b.clear_mipmaps()
			var rect := StoryArt._scaled(StoryArt.MOUTH, a.get_size())
			if a.get_region(rect).get_data() == b.get_region(rect).get_data():
				only_mouth = false
			b.blit_rect(a.get_region(rect), Rect2i(Vector2i.ZERO, rect.size), rect.position)
			if a.get_data() != b.get_data():
				only_mouth = false
	check(spoken == 6, "a portrait, and its blinking face, each have a twin with the mouth open (%d of 6)" % spoken)
	check(only_mouth, "which is the same picture everywhere but her mouth")
	check(StoryArt.talking(StoryArt.outfit_portrait("edda", "neutral")) == StoryArt.talking(StoryArt.outfit_portrait("edda", "neutral")),
		"made once and kept")
	check(StoryArt.talking(ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))) == null, "a picture with no mouth strip has none")
	var PortraitLife = load("res://scripts/ui/portrait_life.gd")
	var life := {}
	check(PortraitLife.attach(life, StoryArt.outfit_portrait("kaede", "neutral")), "a portrait comes alive")
	var quiet: Dictionary = PortraitLife.step(life, 0.01)
	var speaking: Dictionary = PortraitLife.step(life, 0.01, true)
	check(speaking["texture"] != quiet["texture"] and PortraitLife.wears(life, speaking["texture"]),
		"on a word it wears the open-mouthed twin of whatever face it had, and knows it for its own")
	for f in ["edda_neutral.png", "face/edda_neutral.png", "small/edda_neutral.png", "small/face/edda_neutral.png"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/" + f))
	print("Portrait scale failures: %d" % failures)
	quit(1 if failures > 0 else 0)
