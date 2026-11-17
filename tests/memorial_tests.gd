## The fallen remembered: where and when each fell, who killed them and what became of him,
## the gathering that lays them to rest (the rite, the words, the epitaph, a candle, shared
## grief between those who loved them), the vow of vengeance in the journal, candles, saves;
## and the memorial at camp with its stones, the roll, each captain's page, and the ways in
## (the Warband's Camp tab, the camp moment, the map's card, a fallen captain's profile).
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const MemorialLines = preload("res://scripts/data/memorial_lines.gd")

var failures := 0
var gs
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _arrive(path: String) -> void:
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready() and not scenes._busy:
			for j in 3:
				await process_frame
			return


func _find(n: Node, name: String) -> Node:
	return n.find_child(name, true, false)


## A captain falls: the record as apply_result keeps it, killed by `lord` when given.
func _fall(i: int, lord: Dictionary = {}) -> Dictionary:
	var sq: Dictionary = gs.army[i]
	var c: Dictionary = sq["captain"]
	var m: Dictionary = gs._memorial(sq, c, "Hold the line.", int(lord.get("id", -1)), String(lord.get("name", "")))
	gs.fallen.append(m)
	# The dead leave the company: their squad is without them.
	sq.erase("captain")
	return m


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	var sound = root.get_node("Sound")
	sound.settings_path = "user://memorial_tests_settings.cfg"
	sound.set_music_on(false)
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	gs.persist = false
	var w = gs.world
	w.friendly_quiet_until = 1.0e9
	w.hour = 24.0 * 9 + 20.0
	var p = w.player()
	p.node = "ravensford"
	p.next = ""
	p.path = []

	# ---- the memorial at camp, before anyone falls
	scenes.memorial_return = "res://scenes/main_menu.tscn"
	change_scene_to_file("res://scenes/memorial.tscn")
	await _arrive("memorial.tscn")
	var mem = current_scene
	var place_name: Label = _find(mem, "PlaceName")
	check(place_name != null and place_name.text == "The Cairn Field", "a Vardish company's memorial is the Cairn Field")
	check(mem.stone_ids().is_empty() and _find(mem, "HillArt") != null and _find(mem, "MemorialLife") != null, "with no stones yet, the rise is bare, and alive")

	# ---- a captain falls: where, and when
	var lord: Dictionary = {}
	for l in w.lords:
		if String(l["realm"]) == "kharzan" and not bool(l["ruler"]):
			lord = l
			break
	var a: Dictionary = gs.army[0]["captain"]
	var b: Dictionary = gs.army[3]["captain"]
	var c2: Dictionary = gs.army[4]["captain"]
	# Two survivors both bonded to the one who falls.
	for s in [b, c2]:
		a["bonds"][str(int(s["id"]))] = 120.0
		s["bonds"][str(int(a["id"]))] = 120.0
	var bc_before := float(b["bonds"].get(str(int(c2["id"])), 0.0))
	var m := _fall(0, lord)
	check(String(m["place"]) == "ravensford" and gs.memorial_where(m) == "Ravensford", "the record keeps where they fell (Ravensford)")
	check(gs.memorial_day(m) == 10, "and the day (%d)" % gs.memorial_day(m))
	var old := {"name": "Old Bran", "first": "Bran", "battle": 2}
	check(gs.memorial_where(old) == "somewhere on the road" and gs.memorial_day(old) == 0, "an old record reads 'somewhere on the road'")
	check(gs.unmourned().size() == 1 and int(gs.unmourned()[0]["id"]) == int(m["id"]), "they wait to be laid to rest")

	# ---- who killed them, and what became of him
	var sl: Dictionary = gs.memorial_slayer(m)
	check(String(sl["state"]) == "rides" and String(sl["realm"]) == "kharzan" and String(sl["place"]) != "", "their killer still rides, and the map can find him")
	lord["captive_of"] = "player"
	check(String(gs.memorial_slayer(m)["state"]) == "captive", "taken: your captive")
	lord["captive_of"] = ""
	var real_name := String(lord["name"])
	lord["name"] = "Lord Heir Test"
	check(String(gs.memorial_slayer(m)["state"]) == "slain", "an heir in his seat: the one who did it is dead")
	lord["name"] = real_name
	check(gs.memorial_slayer({"name": "Wat", "killed_by_lord_id": -1, "killed_by_lord_name": ""}).is_empty(), "a captain lost to bandits has no lord to name")

	# ---- mourners, and the epitaph before a gathering
	var mourners: Array = gs.memorial_mourners(m)
	check(mourners.size() == 2 and mourners.all(func(e): return String(e["rank"]) != ""), "the bonded survivors mourn them (%d)" % mourners.size())
	check(gs.memorial_epitaph(m) != "", "an epitaph even before they're mourned")

	# ---- the gathering
	var r: Dictionary = gs.memorial_gather(int(m["id"]), "vengeance")
	check(bool(r["ok"]) and bool(m["mourned"]) and String(m["words_said"]) == "vengeance", "laid to rest, with a vow")
	check(String(m["epitaph"]).contains(String(lord["name"])) or String(m["epitaph"]).contains("Not forgotten"), "the vow is cut in the stone (%s)" % m["epitaph"])
	check(String(m["rite"]) == "Raise the cairn", "with the company's own rite")
	check(gs.candle_lit(m), "a candle is lit")
	check(is_equal_approx(float(b["bonds"][str(int(c2["id"]))]), bc_before + MemorialLines.SHARED_GRIEF) and (r["shared"] as Array).size() == 1,
		"the two who loved them grow closer (+%.1f)" % MemorialLines.SHARED_GRIEF)
	check(gs.unmourned().is_empty() and gs.camp_seen.has("fallen_%d" % int(m["id"])), "no longer waiting; the camp's empty place is seen")
	check(not bool(gs.memorial_gather(int(m["id"]), "grief")["ok"]), "laid to rest once")
	var vow: Array = gs.commitments().filter(func(e): return String(e["id"]) == "avenge_%d" % int(m["id"]))
	check(vow.size() == 1 and String(vow[0]["objective"]).contains(String(lord["name"])), "the vow is in the journal")
	m["avenged"] = true
	check(not gs.commitments().any(func(e): return String(e["id"]) == "avenge_%d" % int(m["id"])), "and leaves it when they're avenged")
	m["avenged"] = false
	var m2 := _fall(1)
	r = gs.memorial_gather(int(m2["id"]), "vengeance")
	check(bool(r["ok"]) and String(m2["words_said"]) == "honour", "no vengeance without a lord to answer: honour")

	# ---- candles
	check(not gs.light_candle(int(m["id"])), "one candle a day")
	w.hour += 24.0
	check(gs.light_candle(int(m["id"])), "the next day, another")
	w.hour += 24.0 * MemorialLines.CANDLE_DAYS
	check(not gs.candle_lit(m), "a candle burns out after %d days" % MemorialLines.CANDLE_DAYS)

	# ---- saves
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	gs.from_dict(saved)
	w = gs.world
	var lm: Dictionary = gs.memorial_of(int(m["id"]))
	check(String(lm["epitaph"]) == String(m["epitaph"]) and String(lm["words_said"]) == "vengeance" and String(lm["place"]) == "ravensford"
		and int(lm["candle_day"]) == int(m["candle_day"]), "a save keeps the epitaph, the words, where they fell and the candle")
	m = lm

	# ---- the memorial: stones, the roll, a page
	var m3 := _fall(2, lord)
	change_scene_to_file("res://scenes/memorial.tscn")
	await _arrive("memorial.tscn")
	mem = current_scene
	check(mem.stone_ids().size() == 3 and _find(mem, "Stone_%d" % int(m3["id"])) != null, "a stone for each of the fallen")
	check(_find(mem, "Name_%d" % int(m["id"])) != null and _find(mem, "Waiting_%d" % int(m3["id"])) != null, "the roll, and the newest waiting to be laid to rest")
	var stone: Button = _find(mem, "Stone_%d" % int(m["id"]))
	stone.pressed.emit()
	check((_find(mem, "StonePlate") as Label).visible and (_find(mem, "StonePlate") as Label).text == String(m["name"]), "a stone tapped shows whose it is")
	stone.pressed.emit()
	await process_frame
	check(mem.page_open() == int(m["id"]), "tapped again, their page")
	check(_find(mem, "Epitaph") != null and (_find(mem, "Epitaph") as Label).text.contains(String(m["epitaph"])), "with their epitaph")
	check(_find(mem, "WhereTheyFell") != null and (_find(mem, "WhereTheyFell") as Label).text.contains("Ravensford"), "where they fell")
	check(_find(mem, "Slayer") != null and _find(mem, "ShowOnMap") != null, "who killed them, and a way to find him")
	check(_find(mem, "Mourners") != null and _find(mem, "Mourner_%d" % int(b["id"])) != null, "and who mourns them")
	var candle: Button = _find(mem, "LightCandle")
	check(candle != null and not candle.disabled, "a candle to light")
	candle.pressed.emit()
	await process_frame
	check(gs.candle_lit(gs.memorial_of(int(m["id"]))) and (_find(mem, "LightCandle") as Button).disabled, "lit, and burning")
	(_find(mem, "PageBack") as Button).pressed.emit()
	await process_frame
	check(mem.page_open() == -1, "back to the roll")

	# ---- a gathering, on screen
	(_find(mem, "Gather_%d" % int(m3["id"])) as Button).pressed.emit()
	await process_frame
	check(mem.gathering_open() and _find(mem, "FriendSpeaks") != null and _find(mem, "TheCompany") != null, "the company gathers; a friend speaks")
	var rite: Button = _find(mem, "Rite_go")
	check(rite != null and rite.text == "Raise the cairn", "the rite, in the company's way")
	rite.pressed.emit()
	# The rite takes its seconds: wait by the clock, not by frames.
	var rite_by := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < rite_by:
		await process_frame
		if _find(mem, "Words_honour") != null:
			break
	check(_find(mem, "RiteDone") != null and _find(mem, "Words_honour") != null and _find(mem, "Words_grief") != null and _find(mem, "Words_vengeance") != null,
		"the cairn raised, then the words: honour, grief, and vengeance on the lord")
	(_find(mem, "Words_grief") as Button).pressed.emit()
	await process_frame
	await process_frame
	check(bool(gs.memorial_of(int(m3["id"]))["mourned"]) and mem.page_open() == int(m3["id"]) and _find(mem, "GatheringDone") != null,
		"laid to rest: their page, with what it did")

	# ---- the ways in
	# The Warband's Camp tab.
	scenes.warband_tab = "camp"
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	var page = current_scene
	check(_find(page, "FallenCard") != null and _find(page, "MemorialStrip") != null and _find(page, "VisitMemorial") != null,
		"the Camp tab shows the memorial, small, with the way to it")
	(_find(page, "VisitMemorial") as Button).pressed.emit()
	await _arrive("memorial.tscn")
	check(current_scene.scene_file_path.ends_with("memorial.tscn"), "Visit the memorial")
	(_find(current_scene, "Back") as Button).pressed.emit()
	await _arrive("main_menu.tscn")
	check(current_scene.scene_file_path.ends_with("main_menu.tscn"), "and back to camp")
	# The camp moment's Remember opens their gathering.
	var m4 := _fall(3)
	page = current_scene
	page._on_moment({"key": "fallen_%d" % int(m4["id"]), "action": "memorial", "captain_id": int(m4["id"])})
	await _arrive("memorial.tscn")
	check(current_scene.gathering_open(), "the camp moment's Remember opens their gathering")
	# A fallen captain's profile.
	scenes.active_captain_id = int(m["id"])
	scenes.captain_profile_return = "res://scenes/main_menu.tscn"
	change_scene_to_file("res://scenes/captain_profile.tscn")
	await _arrive("captain_profile.tscn")
	var stone_btn: Button = _find(current_scene, "TheirStone")
	check(stone_btn != null, "a fallen captain's profile has their stone")
	stone_btn.pressed.emit()
	await _arrive("memorial.tscn")
	check(current_scene.page_open() == int(m["id"]), "which opens their page")
	# The map's card for a captain fallen: Remember, and the rest of the news waits.
	gs.clear_notice()
	var cards: Array = gs.describe_result_cards({"squads": {int(gs.army[4]["id"]): {"men": 10, "kills": 3, "captain": {"fate": "killed", "roll": 6, "needed": 16, "kills": 1}}}})
	gs._note(String(cards[0]["text"]), cards[0]["card"])
	gs._note("Khalun falls!", {"kind": "taken", "place": "khalun", "title": "Khalun is taken", "big": true})
	gs._note("Collected 5 silver.", {"kind": "ledger", "row": "silver"})
	var fallen_id := int(cards[0]["card"]["id"])
	gs.fallen.append(gs._memorial(gs.army[4], gs.army[4]["captain"], ""))
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	var map = current_scene
	for i in 4:
		if map._deck == null or String(map._deck.current().get("kind", "")) == "captain_fallen":
			break
		map._deck.next_card()
		await process_frame
	var rem: Button = _find(map, "RememberThem") if map._deck != null else null
	check(rem != null, "a fallen captain's card offers Remember")
	if rem != null:
		rem.pressed.emit()
		await _arrive("memorial.tscn")
		check(current_scene.scene_file_path.ends_with("memorial.tscn") and (current_scene.gathering_open() or current_scene.page_open() == fallen_id),
			"which opens their stone at camp")
		check(gs.map_cards.any(func(c): return String(c.get("kind", "")) == "ledger"), "and the rest of the news waits on the map")

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
