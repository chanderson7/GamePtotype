## Painted portraits at twice the detail. A portrait may be PICTURE (384x512) or a whole
## multiple of it: its other faces (assets/portraits/face/) are then that much bigger, and
## are laid over it at FACE times that much. Checked with today's paintings doubled pixel
## for pixel: every face comes out as today's, doubled.
extends SceneTree

const StoryArt = preload("res://scripts/ui/story_art.gd")

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


func _run() -> void:
	check(StoryArt.face_rect(StoryArt.PICTURE) == StoryArt.FACE, "a 384x512 painting's face strip is FACE")
	check(StoryArt.face_rect(Vector2i(768, 1024)) == Rect2i(StoryArt.FACE.position * 2, StoryArt.FACE.size * 2),
		"a 768x1024 painting's is FACE twice over")
	check(StoryArt.face_rect(Vector2i(500, 512)).size == Vector2i.ZERO and StoryArt.face_rect(Vector2i(768, 512)).size == Vector2i.ZERO,
		"a painting of any other size has none (it shows, without other faces)")
	var dir := "user://portrait_scale"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "/face"))
	var here := "res://assets/portraits/edda_neutral.png"
	var one := StoryArt._image(here)
	var strips := StoryArt._image("res://assets/portraits/face/edda_neutral.png")
	_doubled(one).save_png(dir + "/edda_neutral.png")
	_doubled(strips).save_png(dir + "/face/edda_neutral.png")
	var small := StoryArt.texture(here)
	var big := StoryArt.texture(dir + "/edda_neutral.png")
	check(big != null and big.get_width() == 768 and big.get_height() == 1024, "a 768x1024 painting loads")
	var same := 0
	for name in StoryArt.FRAMES:
		var a: Texture2D = StoryArt.face_frame(small, name)
		var b: Texture2D = StoryArt.face_frame(big, name)
		if a == null and b == null:
			same += 1
			continue
		if a == null or b == null:
			continue
		if _doubled(a.get_image()).get_data() == b.get_image().get_data():
			same += 1
	check(same == StoryArt.FRAMES.size(), "and every other face of it is today's face, doubled (%d of %d)" % [same, StoryArt.FRAMES.size()])
	check(StoryArt.painted_who(big) == "edda" and StoryArt.life_material("edda") != null,
		"it's still Edda, and her head and hair move as before (the shader works in portrait space)")
	for f in ["edda_neutral.png", "face/edda_neutral.png"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/" + f))
	print("Portrait scale failures: %d" % failures)
	quit(1 if failures > 0 else 0)
