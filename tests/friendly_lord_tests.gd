## Friendly lords on the road stop you only with something to say: the first time you meet,
## when there's war news since you last heard, or when they lead an army you could ride
## with. Otherwise they ride past with a wave, and at most one stops you in a half day. Their
## greeting carries the news, and you can still tap one nearby to talk.
extends SceneTree

const Data = preload("res://scripts/world/world_data.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _meet(w, lp) -> String:
	# Put the lord on the player, out of everyone else's way, and see what the road does.
	for p in w.parties:
		if p != w.player():
			p.grace_until = w.hour + 1000.0
	lp.grace_until = 0.0
	lp.node = w.player().node
	lp.next = ""
	lp.along = 0.0
	w.events.clear()
	w.encounter = -1
	w._check_encounter()
	for e in w.events:
		if e["type"] == "friendly_encounter" and int(e["party"]) == lp.id:
			return "stop:" + String(e.get("reason", ""))
		if e["type"] == "friendly_pass" and int(e["party"]) == lp.id:
			return "pass"
	return "none"


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign("vardish")
	var w = gs.world
	var home: String = Data.realm_of_culture("vardish")
	var mine := []
	for l in w.lords:
		if l["realm"] == home and l["state"] == "field" and int(l.get("party", -1)) >= 0:
			mine.append(w.party(int(l["party"])))
	check(mine.size() >= 2, "two lords of your own realm are on the road")
	var a = mine[0]
	var b = mine[1]
	var me = w.player()
	me.next = String(w.path(me.node, "ravensford" if me.node != "ravensford" else "highcliff")[0])
	me.along = 0.0
	w.news_heard_at = w.hour

	check(_meet(w, a) == "stop:first", "a lord you've never met stops to greet you")
	check(int(w.lord_of(a).get("greeted", 0)) == 1, "and remembers he has")
	check(_meet(w, b) == "pass", "another, an hour later, rides past with a wave")

	w.friendly_quiet_until = 0.0
	check(_meet(w, a) == "pass", "a lord you know, with no news, rides past")

	w.news_heard_at = w.hour - 1.0
	w.activity_log.push_front({"hour": w.hour, "type": "war", "category": "war", "text": "Kharzan declared war on the Ryumon.", "place": ""})
	check(_meet(w, a) == "stop:news", "with news since you last heard, he stops")

	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	var map = current_scene
	map.paused = true
	# The map opens the waiting encounter as it loads.
	check(map.sheet_body.text.contains("Kharzan declared war on the Ryumon."), "and tells you the news himself")
	check(map.sheet_row.get_node_or_null("Dock_Morenews") != null, "with More news for the rest")
	check(w.fresh_news().is_empty(), "after which it's heard")
	map._open_wars()
	map._close_or_back()
	check(map.sheet_body.text.contains("Kharzan declared war on the Ryumon."), "and back from the war news, he still says it")
	map._on_part_ways_friendly()

	w.friendly_quiet_until = 0.0
	check(_meet(w, a) == "pass", "so next time he rides past")
	map._open_lord(a)
	check(map.sheet_row.get_node_or_null("Dock_Talk") != null, "but tap him while he's near and you can talk")
	map._on_talk_to_lord(a.id)
	check(w.encounter == a.id and map._sheet == "encounter", "and he stops for you")
	map._on_part_ways_friendly()

	var saved: Dictionary = w.to_dict()
	var w2 := WorldSim.new()
	w2.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(is_equal_approx(w2.news_heard_at, w.news_heard_at) and int(w2.lord_of(w2.party(a.id)).get("greeted", 0)) == 1
		and int(w2.lord_of(w2.party(b.id)).get("greeted", 0)) == 0,
		"what you've heard and whom you've met is saved")
	saved.erase("news_heard_at")
	var w3 := WorldSim.new()
	w3.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(int(w3.lord_of(w3.party(b.id)).get("greeted", 0)) == 1 and w3.fresh_news().is_empty(),
		"a campaign saved before this counts every lord as met and all news as heard")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
