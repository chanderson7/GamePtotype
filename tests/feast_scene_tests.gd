## The feast as a place (scenes/feast.tscn): the way in from the town's Feast tab, the
## herald at the door (once), the guests seated in the hall, the deeds done there with the
## same results as the rules give, the hall's moments, the night's tally, sleeping to the
## next night, the last night, the uninvited door, saves, and the hall's life holding still
## under Reduced motion.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const HallMoments = preload("res://scripts/data/hall_moments.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Style = preload("res://scripts/ui/style.gd")

var failures := 0
var gs
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _arrive(path: String) -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready() and not scenes._busy:
			for j in 3:
				await process_frame
			return


func _find(n: Node, name: String) -> Node:
	return n.find_child(name, true, false)


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []


func _seat_guests(g: Dictionary) -> void:
	var w = gs.world
	for l in w.gathering_guests(g):
		var p = w.party(int(l["party"]))
		p.node = String(g["place"])
		p.next = ""
		p.path = []
		w._lord_arrives(l, p)


func _clock_to(hour: float) -> void:
	gs.world.hour = hour
	gs.world._step_gatherings()


func _regards(g: Dictionary) -> Dictionary:
	var out := {}
	for l in gs.gathering_lords(g):
		out[int(l["id"])] = LordTalk.regard(gs, l)
	return out


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	var sound = root.get_node("Sound")
	sound.settings_path = "user://feast_scene_tests_settings.cfg"
	sound.set_music_on(false)
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	gs.persist = false
	var w = gs.world
	w.friendly_quiet_until = 1.0e9
	gs.silver = 1000
	gs.food = 600
	gs.renown = 300

	# ---- a peace feast at Highcliff, and you serve Vardmark
	w.make_peace("vardmark", "kharzan")
	w._gatherings_day()
	var g: Dictionary = w.gathering_of_realm("vardmark")
	check(not g.is_empty(), "a peace feast is called at Highcliff")
	var starts := float(g["starts_hour"])
	gs.contract = {"realm": "vardmark", "daily_pay": 10, "days_left": 30, "bonus_per_lord": 100}
	_go(String(g["place"]))
	_seat_guests(g)
	_clock_to(starts + 1.0)
	check(w.gathering_on(g) and w.gathering_night(g) == 1, "the first night is on")
	var host: Dictionary = w.lord_by_id(int(g["host_lord"]))
	# A Cruel host doesn't care for toasts, which would muddy the sums below.
	host["bearing"] = Lords.HONORABLE

	# ---- the town's Feast tab is the way in
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	var page = current_scene
	page._on_tab("court")
	await process_frame
	check(_find(page, "EnterHall") != null, "the Feast tab offers Enter the hall")
	check(_find(page, "HallPeek") != null and _find(page, "HallLife") != null, "with a look at the hall, alive")
	check(_find(page, "Feast_Toast") == null and _find(page, "Hall") != null, "the toast is done in the hall now; who's there is still listed")
	(_find(page, "EnterHall") as Button).pressed.emit()
	await _arrive("feast.tscn")
	var hall = current_scene
	check(hall != null and hall.scene_file_path.ends_with("feast.tscn"), "Enter the hall opens the feast")

	# ---- the herald, once
	check(_find(hall, "Herald") != null, "the herald meets you at the door")
	var line: Label = _find(hall, "HeraldLine")
	check(line != null and line.text.contains("Vardish warband") and line.text.contains("in the pay of Vardmark"),
		"and calls out who you are (%s)" % (line.text if line != null else ""))
	(_find(hall, "GoIn") as Button).pressed.emit()
	await process_frame
	await process_frame
	check(_find(hall, "Herald") == null and not gs.feast_needs_herald(g), "you go in, and the herald is done for this feast")

	# ---- the guests at the tables
	var lords: Array = gs.gathering_lords(g)
	var seated: Array = hall.guest_ids()
	check(seated.size() == mini(lords.size(), 1 + hall.FAR_SEATS + hall.NEAR_SEATS), "every guest has a seat (%d of %d)" % [seated.size(), lords.size()])
	check(seated.has(int(g["host_lord"])), "the host among them")
	var view: Vector2 = hall.get_viewport_rect().size
	var on_screen := true
	var tall_enough := true
	for lid in seated:
		var b: Control = hall._guests[lid]["node"]
		on_screen = on_screen and b.position.x >= -1.0 and b.position.x + b.size.x <= view.x + 1.0
		tall_enough = tall_enough and b.size.y >= Style.TOUCH
	check(on_screen, "every guest is within the screen")
	check(tall_enough, "and big enough to tap")
	var host_scale: float = hall._guests[int(g["host_lord"])]["scale"]
	var far_larger := true
	for lid in seated:
		if (hall._guests[lid]["node"] as Control).get_parent() == hall._far and int(lid) != int(g["host_lord"]):
			far_larger = far_larger and host_scale > float(hall._guests[lid]["scale"])
	check(far_larger, "the host sits larger than the high table's other guests")
	check(_find(hall, "Mark_%d" % int(g["host_lord"])) != null, "the host is marked")
	check(_find(hall, "Whisper") != null, "a whisper shows there's gossip to be had")
	check(_find(hall, "HallLife") != null, "the hall is alive")

	# ---- the deeds: the same as the rules
	gs.gathering_record(g)["moment_nights"] = [1]          # no moment tonight while we count
	var before := _regards(g)
	check(hall.act("Toast"), "Toast")
	var toasted := true
	for l in gs.gathering_lords(g):
		toasted = toasted and LordTalk.regard(gs, l) == int(before[int(l["id"])]) + Gatherings.TOAST_REGARD
	check(toasted and bool(gs.gathering_record(g)["toast"]), "a toast warms every lord in the hall by %d" % Gatherings.TOAST_REGARD)
	await process_frame
	check((_find(hall, "Feast_Toast") as Button).disabled, "and is done for this feast")
	var silver := int(gs.silver)
	var host_before: int = gs.relation_with_lord(int(host["id"]))
	check(hall.act("Gift"), "Gift")
	check(int(gs.silver) == silver - Gatherings.GIFT_SILVER and gs.relation_with_lord(int(host["id"])) == host_before + Gatherings.GIFT_REGARD,
		"a gift is %d silver and +%d with the host" % [Gatherings.GIFT_SILVER, Gatherings.GIFT_REGARD])
	var hour: float = w.hour
	check(hall.act("Listen"), "Listen")
	check(w.hour >= hour + Gatherings.GOSSIP_HOURS - 0.01 and not bool(gs.gossip_check(g)["ok"]), "listening takes the hour, once a night")
	await process_frame
	check(_find(hall, "Whisper") == null, "and the whisper is gone")
	check((_find(hall, "Feast_Dance") as Button).disabled, "no dancing on the first night")

	# ---- the night's tally
	var s: Dictionary = gs.feast_night_summary(g)
	var right := true
	for e in s["lords"]:
		var l: Dictionary = w.lord_by_id(int(e["id"]))
		right = right and int(e["change"]) == LordTalk.regard(gs, l) - int(gs.feast_tally(g)["regard"][str(int(e["id"]))])
	check(not (s["lords"] as Array).is_empty() and right, "the night's tally holds each change in Regard (%d lords)" % (s["lords"] as Array).size())
	check(int(s["silver"]) == int(gs.silver) - int(gs.feast_tally(g)["silver"]) , "and what it cost (%d silver)" % int(s["silver"]))

	# ---- moments
	var rec: Dictionary = gs.gathering_record(g)
	rec["moment_nights"] = []
	rec["moments"] = []
	check(gs.hall_moment(g, 0.99).is_empty(), "most deeds bring no moment on a high roll")
	check(gs.hall_moment(g, 0.0).is_empty(), "and one roll a night: none again tonight")
	rec["moment_nights"] = []
	var m: Dictionary = gs.hall_moment(g, 0.0, "round")
	check(String(m.get("id", "")) == "round" and (m["choices"] as Array).size() == 2, "a moment: another round, with two choices")
	before = _regards(g)
	silver = int(gs.silver)
	var r: Dictionary = gs.hall_moment_choose(g, m, "stand")
	var warmed := true
	for l in gs.gathering_lords(g):
		warmed = warmed and LordTalk.regard(gs, l) == int(before[int(l["id"])]) + Gatherings.MOMENT_REGARD
	check(bool(r["ok"]) and int(gs.silver) == silver - Gatherings.ROUND_SILVER and warmed, "standing the hall a round: −%d silver, +%d with every lord" % [Gatherings.ROUND_SILVER, Gatherings.MOMENT_REGARD])
	rec["moment_nights"] = []
	check(gs.hall_moment(g, 0.0, "round").is_empty(), "never the same moment twice at one feast")
	var cm: Dictionary = HallMoments.make(gs, g, "challenge")
	var foe: Dictionary = w.lord_by_id(int(cm["lord_id"]))
	var foe_before := LordTalk.regard(gs, foe)
	var renown := int(gs.renown)
	var won: Dictionary = HallMoments.choose(gs, g, cm, "accept", 0.0)
	check(bool(won["won"]) and LordTalk.regard(gs, foe) == foe_before + Gatherings.CHALLENGE_WIN_REGARD and int(gs.renown) == renown + Gatherings.CHALLENGE_RENOWN,
		"winning the arm-wrestle: +%d Regard, +%d renown" % [Gatherings.CHALLENGE_WIN_REGARD, Gatherings.CHALLENGE_RENOWN])
	var lost: Dictionary = HallMoments.choose(gs, g, cm, "accept", 0.99)
	check(not bool(lost["won"]) and LordTalk.regard(gs, foe) == foe_before + Gatherings.CHALLENGE_WIN_REGARD + Gatherings.MOMENT_REGARD, "losing it: still +%d" % Gatherings.MOMENT_REGARD)
	for l in gs.gathering_lords(g):
		if LordTalk.regard(gs, l) < 0:
			LordTalk.change_regard(gs, l, -LordTalk.regard(gs, l))
	check(not HallMoments.fits(gs, g, "insult"), "no insult when nobody in the hall thinks ill of you")
	var aside: Dictionary = HallMoments.make(gs, g, "aside")
	check(int(HallMoments.choose(gs, g, aside, "go")["talk"]) == int(aside["lord_id"]), "a quiet word takes you to sit with that lord")
	# The moment card in the hall, answered from it.
	rec["moment_nights"] = []
	rec["moments"] = []
	hall._moment = gs.hall_moment(g, 0.0, "bard")
	hall._show_moment(hall._moment)
	await process_frame
	check(_find(hall, "Moment") != null and _find(hall, "Choice_stand") != null, "a moment shows over the hall with its choices")
	renown = int(gs.renown)
	(_find(hall, "Choice_stand") as Button).pressed.emit()
	await process_frame
	await process_frame
	check(_find(hall, "Moment") == null and int(gs.renown) == renown + Gatherings.BARD_RENOWN, "and is answered there (+%d renown)" % Gatherings.BARD_RENOWN)

	# ---- saves keep what the hall knows
	var json: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	gs.from_dict(json)
	w = gs.world
	w.friendly_quiet_until = 1.0e9
	g = w.gathering_by_id(int(g["id"]))
	check(not gs.feast_needs_herald(g) and (gs.gathering_record(g)["moments"] as Array).has("bard"), "a save keeps the herald done and the moments had")
	check(not (gs.feast_night_summary(g)["lords"] as Array).is_empty(), "and tonight's tally")

	# ---- sleeping to the next night
	var rest: Dictionary = gs.feast_rest_check(g)
	check(bool(rest["ok"]) and not bool(rest["last"]) and is_equal_approx(w.hour + float(rest["hours"]), starts + 24.0), "sleep runs to tomorrow's dusk")
	var slept: Dictionary = gs.feast_rest(g)
	check(bool(slept["ok"]), "you sleep")
	# Brigands on the road can wake you (the hall then sends you to the map); here, send
	# them packing and sleep on.
	for attempt in 4:
		if not bool(slept.get("stopped", false)):
			break
		w.parties.erase(w.party(w.encounter))
		w.encounter = -1
		slept = gs.feast_rest(g)
	check(bool(slept["ok"]) and not bool(slept["broken"]) and int(slept["night"]) == 2 and absf(w.hour - (starts + 24.0)) < 0.2, "and you wake to the second night (%s, hour %.2f of %.2f)" % [str(slept), w.hour, starts + 24.0])
	check((gs.feast_night_summary(g)["lords"] as Array).is_empty(), "with a fresh tally")
	change_scene_to_file("res://scenes/feast.tscn")
	await _arrive("feast.tscn")
	hall = current_scene
	check(_find(hall, "Herald") == null, "the herald doesn't call you twice")
	check((_find(hall, "Rest") as Button).visible, "on the second night you can sleep again")
	_clock_to(starts + 49.0)
	gs.feast_tally(g)
	hall._refresh()
	await process_frame
	check(bool(gs.feast_rest_check(g)["last"]) and not (_find(hall, "Rest") as Button).visible, "the last night: no sleeping through it")
	check(not (_find(hall, "Feast_Dance") as Button).disabled, "and the dancing has begun")
	(_find(hall, "Feast_Dance") as Button).pressed.emit()
	await _arrive("dance.tscn")
	current_scene.close()
	await _arrive("feast.tscn")
	check(current_scene.scene_file_path.ends_with("feast.tscn"), "the dance returns to the hall")

	# ---- leaving: a quiet night goes straight out
	hall = current_scene
	gs.feast_tally_start(g)
	scenes.feast_return = "res://scenes/settlement.tscn"
	(_find(hall, "Leave") as Button).pressed.emit()
	await _arrive("settlement.tscn")
	check(current_scene.scene_file_path.ends_with("settlement.tscn"), "leaving after a quiet night goes straight back to the town")

	# ---- the uninvited door
	gs.contract = {}
	gs.gathering_log.erase(str(int(g["id"])))
	for l in [host]:
		LordTalk.change_regard(gs, l, -LordTalk.regard(gs, l))
	check(not bool(gs.gathering_invite(g)["invited"]), "without the contract you're not invited")
	change_scene_to_file("res://scenes/feast.tscn")
	await _arrive("feast.tscn")
	hall = current_scene
	line = _find(hall, "HeraldLine")
	check(line != null and line.text.contains("not on it"), "the herald can't find your name")
	check(_find(hall, "WalkIn") != null and _find(hall, "TurnBack") != null, "you may walk in anyway, or turn back")
	(_find(hall, "TurnBack") as Button).pressed.emit()
	await _arrive("settlement.tscn")
	check(gs.feast_needs_herald(g), "turning back leaves you outside")

	# ---- the hall's life holds still under Reduced motion
	sound.set_reduced_motion(true)
	var art := Control.new()
	art.size = Vector2(480, 300)
	root.add_child(art)
	var life = load("res://scripts/ui/hall_life.gd").over(art, "kharzani")
	await process_frame
	check(not life.is_processing(), "under Reduced motion the hall's fires and lanterns hold still")
	sound.set_reduced_motion(false)
	var art2 := Control.new()
	art2.size = Vector2(480, 300)
	root.add_child(art2)
	var life2 = load("res://scripts/ui/hall_life.gd").over(art2, "ryumon")
	await process_frame
	check(life2.is_processing(), "otherwise they move")

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
