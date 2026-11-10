extends SceneTree
## Renders assets/splash.png, the boot splash: frame 0 of the opening (scripts/menu/opening.gd)
## alone, at 1440x3122: twice the opening's box, so the box fills it exactly, and larger
## than any phone's screen, so the engine only ever scales it down to cover. Beside it,
## assets/splash.json records what the frame was drawn from (the wordmark's MD5) and where
## the name and each banner sit in the box, so tests/opening_tests.gd can tell, headless,
## when the splash no longer matches the opening.
## Re-run after changing the opening's first frame or the wordmark:
##   xvfb-run -a -s "-screen 0 1500x3200x24" godot --path . --resolution 1440x3122 -s tools/render_splash.gd
## Add `-- --check` to render and compare with the committed splash instead (exits 1 if
## they differ by more than MAX_ERROR).
const Opening = preload("res://scripts/menu/opening.gd")
const Wordmark = preload("res://scripts/ui/wordmark.gd")

const PNG := "res://assets/splash.png"
const JSON_PATH := "res://assets/splash.json"
const SIZE := Vector2i(1440, 3122)
## The mean difference allowed per channel, out of 255: room for a driver's rounding.
const MAX_ERROR := 1.5


func _init() -> void:
	await process_frame
	var check := OS.get_cmdline_user_args().has("--check")
	Opening.played = true
	var bg := ColorRect.new()
	bg.color = Opening.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# Home's title, which the opening copies (and hides until the hand-over).
	var home := Wordmark.title(80)
	home.position = Vector2(32, 60)
	bg.add_child(home)
	var opening := Opening.new()
	bg.add_child(opening)
	# Held at its first frame: entering the tree turns processing on, so it is stopped here.
	opening.set_process(false)
	opening.setup(home, "full")
	for i in 6:
		opening.t = 0.0
		opening.apply()
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img.get_size() != SIZE:
		push_error("Run at --resolution %dx%d; got %s" % [SIZE.x, SIZE.y, img.get_size()])
		quit(1)
		return
	img.convert(Image.FORMAT_RGB8)
	if check:
		var was := Image.load_from_file(PNG)
		was.convert(Image.FORMAT_RGB8)
		var error := _mean_error(img, was)
		print("Splash differs from the opening's first frame by %.2f per channel (allowed %.2f)" % [error, MAX_ERROR])
		quit(0 if error <= MAX_ERROR else 1)
		return
	img.save_png(PNG)
	var frame := {}
	var rects: Dictionary = opening.frame_rects()
	for key in rects:
		var r: Rect2 = rects[key]
		frame[key] = [snappedf(r.position.x, 0.01), snappedf(r.position.y, 0.01), snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01)]
	var f := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"wordmark_md5": FileAccess.get_md5(Wordmark.PATH), "frame": frame}, "  ", true) + "\n")
	f.close()
	print("Wrote %s and %s" % [PNG, JSON_PATH])
	quit()


func _mean_error(a: Image, b: Image) -> float:
	if b == null or b.get_size() != a.get_size():
		return 255.0
	var da := a.get_data()
	var db := b.get_data()
	var total := 0
	# Every 7th byte: enough to see any change in the picture, quick at this size.
	for i in range(0, da.size(), 7):
		total += absi(int(da[i]) - int(db[i]))
	return float(total) / float(ceili(da.size() / 7.0))
