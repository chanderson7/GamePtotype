extends SceneTree
## The opening: the boot splash is its first frame and says so (splash.json); the mark's
## banners stand as the ridge's do; the full opening on a first visit, the short one with a
## campaign, a still fade with reduced motion; the dawn never falls back and nothing crosses
## the name; the banners fly into the mark and the title lands on Home's; Home arrives in
## turn; a tap hurries it on without a jump.
## Run: godot --headless --path . --script res://tests/opening_tests.gd
const Cultures = preload("res://scripts/data/cultures.gd")
const Opening = preload("res://scripts/menu/opening.gd")
const Wordmark = preload("res://scripts/ui/wordmark.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")

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


func _open_home() -> Node:
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	await process_frame
	return current_scene


func _close(a: Rect2, b: Rect2, within: float) -> bool:
	return a.position.distance_to(b.position) <= within and a.size.distance_to(b.size) <= within


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.persist = false
	_splash()
	_mark()

	# ---- A first visit: the full opening.
	gs.world = null
	gs.load_problem = ""
	Opening.played = false
	check(Opening.wanted(), "the first Home of a launch wants the opening")
	var home = await _open_home()
	check(home.has_node("Opening"), "Home opens under the opening")
	var op = home.get_node("Opening").get_child(0)
	check(op.kind == "full" and is_equal_approx(float(op.timeline["length"]), 2.7), "a first visit gets the full opening, 2.7 s")
	await _plays(home, op, "full")

	check(not (await _open_home()).has_node("Opening") and _home_title(current_scene).modulate.a == 1.0,
		"only once a launch: Home again opens straight")

	# ---- A campaign under way: the short one.
	gs.new_campaign(Cultures.VARDISH)
	Opening.played = false
	home = await _open_home()
	op = home.get_node("Opening").get_child(0)
	check(op.kind == "short" and is_equal_approx(float(op.timeline["length"]), 1.5), "with a campaign, the short opening, 1.5 s")
	await _plays(home, op, "short")

	# ---- Saves that couldn't load: no campaign, so the full one, over the stranded card.
	gs.world = null
	gs.load_problem = "unreadable"
	Opening.played = false
	home = await _open_home()
	check(home.has_node("Opening") and home.get_node("Opening").get_child(0).kind == "full", "a launch whose autosave couldn't load gets the full opening")
	gs.load_problem = ""

	# ---- Reduced motion: the first frame, still, fading off Home.
	var sound = root.get_node("Sound")
	var was: bool = sound.reduced_motion
	sound.reduced_motion = true
	gs.new_campaign(Cultures.VARDISH)
	Opening.played = false
	home = await _open_home()
	check(home.has_node("Opening"), "with reduced motion Home still opens under the first frame")
	op = home.get_node("Opening").get_child(0)
	op.set_process(false)
	check(op.kind == "still", "as a still")
	op.t = 0.0
	op.apply()
	var at0: Dictionary = op.frame_rects()
	op.t = 0.4
	op.apply()
	var title := _home_title(home)
	var same := true
	var later: Dictionary = op.frame_rects()
	for key in at0:
		same = same and _close(at0[key], later[key], 0.01)
	check(same and op._sky.position.y == 0.0, "nothing moves")
	check(op.modulate.a > 0.0 and op.modulate.a < 1.0 and title.modulate.a == 1.0, "it fades, over Home's own title")
	check(op.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and taps reach Home under it")
	op.set_process(true)
	var frames := 0
	while home.has_node("Opening") and frames < 200:
		await process_frame
		frames += 1
	check(not home.has_node("Opening"), "and it goes")
	sound.reduced_motion = was

	print("Opening failures: %d" % failures)
	quit(failures)


## The splash is set in the project, in the opening's night, and is the opening's first
## frame as the code draws it now.
func _splash() -> void:
	var splash := String(ProjectSettings.get_setting("application/boot_splash/image", ""))
	check(splash == "res://assets/splash.png" and FileAccess.file_exists(splash), "the boot splash is the game's own image")
	var img := Image.load_from_file(splash)
	check(img != null and img.get_size() == Vector2i(1440, 3122), "rendered larger than any phone screen, in the opening's frame")
	check(absf(float(img.get_width()) / float(img.get_height()) - Opening.BOX.x / Opening.BOX.y) < 0.001, "in exactly the shape of the opening's box")
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	check(bg.is_equal_approx(Opening.NIGHT) and clear.is_equal_approx(Color(0.055, 0.075, 0.133)), "splash, window and opening share the same night")
	check(int(ProjectSettings.get_setting("application/boot_splash/stretch_mode", -1)) == 4, "the splash covers the screen, as the opening covers it with its box")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(presets.contains("storyboard/image_scale_mode=3"), "and the iOS launch screen fills it too (aspect fill), not the image's own size")
	var corner := img.get_pixel(4, 4)
	check(corner.is_equal_approx(Opening.NIGHT) or corner.to_html(false) == Opening.NIGHT.to_html(false), "the splash's edges are the night, so fitting it leaves no seam")
	var record = JSON.parse_string(FileAccess.get_file_as_string("res://assets/splash.json"))
	check(record is Dictionary and String(record.get("wordmark_md5", "")) == FileAccess.get_md5(Wordmark.PATH),
		"the splash was rendered from this wordmark (else re-run tools/render_splash.gd)")
	# Build the opening's first frame as the render tool does and compare where things are.
	var holder := Control.new()
	root.add_child(holder)
	var stand_in := Wordmark.title(92)
	holder.add_child(stand_in)
	var op := Opening.new()
	holder.add_child(op)
	op.set_process(false)
	op.setup(stand_in, "full")
	var rects: Dictionary = op.frame_rects()
	var frame: Dictionary = record.get("frame", {}) if record is Dictionary else {}
	var same := frame.size() == rects.size()
	for key in rects:
		var v: Array = frame.get(key, [0, 0, 0, 0])
		same = same and _close(rects[key], Rect2(v[0], v[1], v[2], v[3]), 0.5)
	check(same, "the splash shows the name and banners where the opening's first frame has them (else re-run tools/render_splash.gd)")
	var name: Rect2 = rects["name"]
	check(absf(name.get_center().x - Opening.BOX.x * 0.5) < 0.5 and name.position.y > Opening.BOX.y * Opening.RIDGE_AT,
		"the first frame has the name centred under the ridge")
	var ink: Rect2 = op.name_ink()
	var six := false
	for b in op._banners:
		six = six or Rect2(b.position, b.size * b.scale.x).intersects(ink)
	check(not six and op._mark != null and float(op._mark.get("banners")) == 0.0, "and only the ridge's three banners: the mark's own wait")
	holder.queue_free()


## The mark's banners stand as the ridge's: the same order, the same layout, scaled.
func _mark() -> void:
	var order: Array = []
	for spec in Wordmark.BANNERS:
		order.append(spec[0])
	check(order == ["kharzan", "vardmark", "ryumon"], "Kharzan, Vardmark and Ryumon along the ridge, Vardmark in the middle")
	var tallest := true
	for spec in Wordmark.BANNERS:
		tallest = tallest and (spec[0] == "vardmark" or (spec[1] as Rect2).position.y > (Wordmark.BANNERS[1][1] as Rect2).position.y)
	check(tallest, "on the tallest pole")
	var img := Image.load_from_file(Wordmark.PATH)
	check(img != null, "the wordmark is there")
	if img == null:
		return
	# Each cloth's colour, found in a window around where the layout says the cloth is.
	var is_cloth := {
		"vardmark": func(c: Color) -> bool: return c.a > 0.5 and c.b8 > 150 and c.r8 < 110,
		"ryumon": func(c: Color) -> bool: return c.a > 0.5 and ((c.r8 > 150 and c.g8 < 80 and c.b8 < 70) or (c.r8 > 225 and c.g8 > 220 and c.b8 > 205)),
		"kharzan": func(c: Color) -> bool: return c.a > 0.5 and c.r8 > 180 and c.g8 > 100 and c.b8 < 60,
	}
	for spec in Wordmark.BANNERS:
		var realm: String = spec[0]
		var cloth := Heraldry.realm_cloth(realm, spec[1])
		var want := Rect2(Wordmark.MARK_OFFSET + cloth.position * Wordmark.MARK_SCALE, cloth.size * Wordmark.MARK_SCALE)
		# Clear of the pole: it stands at a gonfalon's middle, beside the others' cloth.
		var look := want.grow(8.0) if realm == "vardmark" else want.grow_individual(-3.0, 8.0, 8.0, 8.0)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for y in range(maxi(0, int(look.position.y)), mini(img.get_height(), int(look.end.y))):
			for x in range(maxi(0, int(look.position.x)), mini(img.get_width(), int(look.end.x))):
				if is_cloth[realm].call(img.get_pixel(x, y)):
					lo = lo.min(Vector2(x, y))
					hi = hi.max(Vector2(x + 1, y + 1))
		var found := Rect2(lo, hi - lo)
		# Each edge within a few pixels: the painted cloth's outline sits on its edge.
		var edges := maxf(maxf(absf(found.position.x - want.position.x), absf(found.position.y - want.position.y)),
			maxf(absf(found.end.x - want.end.x), absf(found.end.y - want.end.y)))
		check(edges <= 4.0, "the mark's %s cloth is where the ridge's layout puts it (%s, want %s)" % [realm, found, want])


## Plays one opening through, checking it frame by frame on the way.
func _plays(home, op, which: String) -> void:
	op.set_process(false)
	var tl: Dictionary = op.timeline
	var title := _home_title(home)
	var card: Array = op._card
	var row: Array = op._row
	check(not card.is_empty() and not row.is_empty(), "%s: Home hands it its card and its bottom row" % which)
	op.t = 0.0
	op.apply()
	check(title.modulate.a == 0.0 and op.title.visible, "%s: Home's title waits while the opening's own is shown" % which)
	check(op.mouse_filter == Control.MOUSE_FILTER_STOP, "%s: taps go to the opening while it covers Home" % which)
	check(op._banners[1].modulate.r < 0.3, "%s: the banners are dark before the dawn" % which)
	var start_name: Rect2 = op.name_rect()
	var start_banner: Vector2 = op._banners[0].position
	op.t = minf((tl["light"] as Vector2).y, (tl["fly"] as Vector2).x)
	op.apply()
	var brightest := 0.0
	for b in op._banners:
		brightest = maxf(brightest, b.modulate.r)
	check(brightest > 0.6 and _close(op.name_rect(), start_name, 0.01) and op._banners[0].position == start_banner,
		"%s: dawn lights the banners before anything moves" % which)

	# Frame by frame: the dawn, once up, never falls back; the dawn's bands and the flying
	# banners never cross the name; the title and banners only ever rise.
	var dawn_ok := true
	var clear_ok := true
	var crossed := ""
	var last_dawn := 0.0
	var last_y := INF
	var rises := true
	var t := 0.0
	while t <= float(tl["length"]) + 0.001:
		op.t = t
		op.apply()
		var dawn: float = op._phase(tl["dawn"])
		if dawn < last_dawn - 0.0001 or (t > float(tl["hold"]) + 0.05 and dawn <= 0.0):
			dawn_ok = false
		last_dawn = dawn
		var ink: Rect2 = op.name_ink()
		if op.dawn_line() > ink.position.y + 0.5:
			clear_ok = false
			crossed = "the dawn at %.2f s" % t
		for b in op._banners:
			if b.modulate.a > 0.05 and Rect2(b.position, b.size * b.scale.x).grow(-2.0).intersects(ink):
				clear_ok = false
				crossed = "%s at %.2f s" % [b.realm, t]
		if ink.position.y > last_y + 0.01:
			rises = false
		last_y = ink.position.y
		t += 0.02
	check(dawn_ok, "%s: no dark frame after the hold: the dawn comes up and never falls back" % which)
	check(clear_ok, "%s: nothing crosses the name%s" % [which, "" if crossed == "" else " (" + crossed + ")"])
	check(rises, "%s: the title only rises" % which)

	# The banners have flown into Home's mark; the title is on Home's; the painted banners
	# take over; then the night has gone and Home's own title shows.
	var rise: Vector2 = tl["rise"]
	op.t = rise.y
	op.apply()
	check(op.title.position.distance_to(title.global_position) < 0.5 and is_equal_approx(op.title.scale.x, 1.0), "%s: the title lands on Home's" % which)
	var home_mark: Control = title.get_node("Wordmark")
	var xf := home_mark.get_global_transform()
	var landed := true
	for i in op._banners.size():
		var r: Rect2 = home_mark.from_image(Wordmark.box_in_image(Wordmark.BANNERS[i][1]))
		var want := Rect2(xf * r.position, r.size * xf.get_scale().x)
		var b = op._banners[i]
		landed = landed and _close(Rect2(b.position, b.size * b.scale.x), want, 0.5)
	check(landed, "%s: the three banners land where the mark's painted banners are" % which)
	op.t = rise.y + 0.11
	op.apply()
	check(float(op._mark.get("banners")) == 1.0 and op._banners[0].modulate.a == 0.0, "%s: and the painted ones take over" % which)
	op.t = (tl["lift"] as Vector2).y
	op.apply()
	check(op.dawn_line() < 0.0 and title.modulate.a == 1.0 and not op.title.visible, "%s: the night has lifted off the top, and Home's title is its own" % which)

	# Home arrives in turn: the card, then the row.
	var c: Vector2 = tl["card"]
	op.t = c.x
	op.apply()
	var base: Vector2 = card[0].get_meta("opening_base")
	check(card[0].modulate.a == 0.0 and card[0].position.y > base.y and row[0].modulate.a == 0.0, "%s: Home's card waits below its place" % which)
	op.t = (c.x + c.y) * 0.5
	op.apply()
	check(card[0].modulate.a > 0.0 and card[0].modulate.a < 1.0 and row[0].modulate.a == 0.0, "%s: then rises into it, before the bottom row" % which)
	op.t = c.y
	op.apply()
	check(card[0].modulate.a == 1.0 and card[0].position == base, "%s: and is in its place" % which)
	check(op.mouse_filter == (Control.MOUSE_FILTER_IGNORE if c.y >= float(tl["taps"]) else Control.MOUSE_FILTER_STOP), "%s: taps reach Home once its card is up" % which)

	# A tap: nothing jumps, the rest just goes quickly.
	op.t = 0.2
	op.rate = 1.0
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	op._gui_input(e)
	check(is_equal_approx(op.t, 0.2) and (float(tl["length"]) - op.t) / op.rate <= Opening.HURRY_SECONDS + 0.001, "%s: a tap hurries it on from where it is, done in %.1f s" % [which, Opening.HURRY_SECONDS])
	var fired: Dictionary = op._fired
	op.set_process(true)
	var frames := 0
	while home.has_node("Opening") and frames < 600:
		await process_frame
		frames += 1
	check(not home.has_node("Opening") and title.modulate.a == 1.0, "%s: it ends by handing over to Home" % which)
	check(card[0].modulate.a == 1.0 and row[0].modulate.a == 1.0 and not card[0].has_meta("opening_set"), "%s: with Home whole" % which)
	if which == "full":
		check(fired.has("birds") and fired.has("glint") and fired.has("landed"), "full: the birds, the glint's shimmer, and a touch as the title lands")
	else:
		check(not fired.has("birds") and not fired.has("glint") and fired.has("landed"), "short: no birds or glint, just the touch as the title lands")
