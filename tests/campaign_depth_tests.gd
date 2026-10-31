## Deeper campaign: lords sworn to your crown, friendly lords joining your assaults, and
## lords who remember fighting you.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Lords = preload("res://scripts/data/lords.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []


func _crowned() -> void:
	gs.new_campaign(Cultures.VARDISH)
	var seat := "ravensford"
	gs.player_fief = {"settlement_id": seat, "realm": gs.world.owner_of(seat), "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	gs.renown = 250
	_go(seat)
	gs.declare_crown()


func _captive(bearing: String) -> Dictionary:
	for l in gs.world.lords:
		if not l["ruler"] and l["realm"] != WorldData.CROWN and l["state"] != "prisoner":
			l["bearing"] = bearing
			gs.world.capture_lord(int(l["id"]), "player")
			return l
	return {}


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false

	# Lords sworn to the crown.
	_crowned()
	var w = gs.world
	var honest := _captive(Lords.HONORABLE)
	check(not gs.swear_check(int(honest["id"]))["ok"] and String(gs.swear_check(int(honest["id"]))["reason"]).contains("faith"),
		"an honorable captive keeps faith with their realm")
	var bold := _captive(Lords.DARING)
	check(gs.swear_lord_to_crown(int(bold["id"])), "a daring captive swears to your crown")
	check(bold["realm"] == WorldData.CROWN and bold["state"] == "regroup" and gs.crown_lords().has(bold),
		"and now serves it, regrouping at its seat")
	w.hour = float(bold["back_at"]) + 0.5
	w._step_lords(0.0)
	var bp = w.party(int(bold["party"]))
	check(bold["state"] == "field" and bp != null and bp.faction == WorldData.CROWN and w.relation_to_player(bp.faction) == "friendly",
		"they ride out under the crown's banner, a friend")
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(gs2.crown_lords().size() == 1, "a sworn lord survives a save and load")
	gs2.free()

	# Friendly lords at the walls join the assault.
	var target := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and w.at_war(WorldData.CROWN, w.owner_of(id)):
			target = id
			break
	_go(target)
	bp.node = target
	bp.next = ""
	bp.path = []
	var allies: Array = gs.siege_allies(target)
	check(not allies.is_empty() and allies.all(func(a): return a["is_ally"] and int(a["lord_id"]) == int(bold["id"])),
		"a friendly lord at the walls will storm them beside you")
	gs.start_siege_battle(target)
	check(gs.pending_battle["allies"].size() == allies.size(), "and joins the battle as an ally")
	gs.pending_battle = {}
	var before: int = w.men_of(bp.army)
	w.garrisons[target] = w.garrisons[target].slice(0, 2)
	gs.auto_resolve_siege(target)
	check(w.men_of(bp.army) <= before, "their losses go home to them")

	# Lords remember fighting you.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	var foe: Dictionary = {}
	for l in w.lords:
		if l["realm"] == "kharzan" and l["state"] == "field" and not l["ruler"]:
			foe = l
			break
	var fp = w.party(int(foe["party"]))
	check(int(foe.get("met_player", 0)) == 0, "a lord you've never fought doesn't know you")
	w.encounter = fp.id
	gs.auto_resolve_encounter()
	check(int(foe.get("met_player", 0)) == 1, "after a battle, the lord remembers your company")
	gs.map_notice = ""
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	var map = current_scene
	map._close_sheet()
	if int(foe["party"]) >= 0 and foe["state"] == "field":
		w.encounter = int(foe["party"])
		map._open_encounter()
		check(map.sheet_body.text.contains(LordVoice.line("again", foe)), "and greets you as someone they've met before")
		w.encounter = -1

	print("\nCampaign depth tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
