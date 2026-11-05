extends SceneTree
## The opening: the boot splash comes to life over Home once a launch and hands its title
## over; a tap hurries it; reduced motion goes straight to Home.
const Cultures = preload("res://scripts/data/cultures.gd")
const Opening = preload("res://scripts/menu/opening.gd")

var failures := 0

func check(ok: bool, text: String) -> void:
	print(("ok " if ok else "FAIL ") + text)
	if not ok:
		failures += 1


func _init() -> void:
	_run.call_deferred()


func _home_title(scene) -> Label:
	var layer: Node = scene.get_node_or_null("Opening")
	for n in scene.find_children("*", "Label", true, false):
		var l := n as Label
		if l.text == "Bannerfall" and (layer == null or not layer.is_ancestor_of(l)):
			return l
	return null


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.persist = false
	# The splash is set in the project, in the opening's night, and is the opening's frame.
	var splash := String(ProjectSettings.get_setting("application/boot_splash/image", ""))
	check(splash == "res://assets/splash.png" and FileAccess.file_exists(splash), "the boot splash is the game's own image")
	var img := Image.load_from_file(splash)
	check(img != null and img.get_size() == Vector2i(1080, 2342), "rendered at phone resolution for the opening's frame")
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	check(bg.is_equal_approx(Opening.NIGHT) and clear.is_equal_approx(Color(0.055, 0.075, 0.133)), "splash, window and opening share the same night")
	check(int(ProjectSettings.get_setting("application/boot_splash/stretch_mode", -1)) == 1, "the splash is fitted keeping its shape, as the opening fits its box")
	var corner := img.get_pixel(4, 4)
	check(corner.is_equal_approx(Opening.NIGHT) or corner.to_html(false) == Opening.NIGHT.to_html(false), "the splash's edges are the night, so fitting it leaves no seam")

	gs.new_campaign(Cultures.VARDISH)
	Opening.played = false
	check(Opening.wanted(), "the first Home of a launch wants the opening")
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	var home = current_scene
	check(home.has_node("Opening"), "Home opens under the opening")
	var op = home.get_node("Opening").get_child(0)
	var title := _home_title(home)
	check(title != null and title.modulate.a == 0.0 and op.title.visible, "Home's title waits while the opening's own title is shown")
	check(op.mouse_filter == Control.MOUSE_FILTER_STOP, "taps go to the opening while it covers Home")
	op.set_process(false)
	op.t = 0.0
	op.apply()
	var start_y: float = op.title.position.y
	op.t = 1.0
	op.apply()
	check(op._banners[0].modulate.r > 0.5 and op.title.position.y == start_y, "dawn lights the banners before the title moves")
	op.t = 2.0
	op.apply()
	check(op.title.position.y < start_y and op.title.position.y > title.global_position.y - 1.0, "then the title rises toward Home's")
	op.t = 0.2
	op.rate = 1.0
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	op._gui_input(e)
	check(op.t >= Opening.LAND_GOES.x and op.rate == Opening.HURRY, "a tap hurries it on to the title rising")
	op.set_process(true)
	var frames := 0
	while home.has_node("Opening") and frames < 600:
		await process_frame
		frames += 1
	check(not home.has_node("Opening") and title.modulate.a == 1.0, "it ends by handing over to Home's title")
	check(not is_instance_valid(op) or op.is_queued_for_deletion() or not op.is_inside_tree(), "and goes")

	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	check(not current_scene.has_node("Opening") and _home_title(current_scene).modulate.a == 1.0, "only once a launch: Home again opens straight")

	var sound = root.get_node("Sound")
	var was: bool = sound.reduced_motion
	sound.reduced_motion = true
	Opening.played = false
	check(not Opening.wanted(), "reduced motion goes straight to Home")
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	check(not current_scene.has_node("Opening"), "and Home builds without it")
	sound.reduced_motion = was

	# A first visit (no campaign) gets it too, over the three peoples.
	gs.world = null
	Opening.played = false
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	check(current_scene.has_node("Opening") and _home_title(current_scene) != null, "a first visit opens the same way")

	print("Opening failures: %d" % failures)
	quit(failures)
