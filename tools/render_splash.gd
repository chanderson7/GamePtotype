extends SceneTree
## Renders assets/splash.png, the boot splash: frame 0 of the opening (scripts/menu/opening.gd)
## alone on the night, at 1080x2342 so the opening's box fills it exactly. Re-run after
## changing the opening's first frame:
##   xvfb-run -a -s "-screen 0 1200x2400x24" godot --path . --resolution 1080x2342 -s tools/render_splash.gd
const Style = preload("res://scripts/ui/style.gd")
const Opening = preload("res://scripts/menu/opening.gd")


func _init() -> void:
	await process_frame
	Opening.played = true
	var bg := ColorRect.new()
	bg.color = Opening.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# Home's title as the opening finds it: the display face, brass, with its outline.
	var stand_in := Style.label("Bannerfall", Opening.SPLASH_TITLE, Style.BRASS)
	stand_in.add_theme_constant_override("outline_size", 10)
	stand_in.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	stand_in.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stand_in.position = Vector2(32, 60)
	stand_in.size = Vector2(656, 120)
	bg.add_child(stand_in)
	var opening := Opening.new()
	bg.add_child(opening)
	# Held at its first frame: entering the tree turns processing on, so it is stopped here.
	opening.set_process(false)
	opening.setup(stand_in)
	for i in 6:
		opening.t = 0.0
		opening.apply()
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img.get_size() != Vector2i(1080, 2342):
		push_error("Run at --resolution 1080x2342; got %s" % img.get_size())
		quit(1)
		return
	img.save_png("res://assets/splash.png")
	print("Wrote assets/splash.png")
	quit()
