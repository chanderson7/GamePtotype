## Your own kingdom: raising a crown, its lands, alliances and peace.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _grant(seat: String) -> void:
	gs.player_fief = {"settlement_id": seat, "realm": gs.world.owner_of(seat), "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}


func _step(path: Array, id: String) -> Dictionary:
	for s in path:
		if String(s["id"]) == id:
			return s
	return {}


func _met(path: Array, id: String) -> bool:
	return bool(_step(path, id).get("done", false))


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.KHARZANI)
	var w = gs.world
	var seat := "ravensford"
	var liege: String = w.owner_of(seat)
	check(not gs.crown_check()["ok"] and String(gs.crown_check()["reason"]).contains("fief"), "no crown without a fief")
	var path: Array = gs.crown_path()
	check(path.size() == 5 and not _met(path, "fief") and String(_step(path, "fief")["detail"]).contains("fealty"),
		"the road to a crown starts with fealty for a fief, and says what that takes")
	_grant(seat)
	_go(seat)
	gs.renown = 50
	check(String(gs.crown_check()["reason"]).contains("renown"), "nor without renown")
	path = gs.crown_path()
	check(_met(path, "fief") and _met(path, "walls") and _met(path, "seat") and not _met(path, "renown")
		and String(_step(path, "renown")["detail"]).contains("50"), "the checklist ticks the seat and its walls, and counts the renown still to win")
	gs.renown = 250
	gs.contract = {"realm": liege, "daily_pay": 10, "days_left": 5, "bonus_per_lord": 100}
	check(String(gs.crown_check()["reason"]).contains("contract"), "nor while under contract")
	check(not _met(gs.crown_path(), "contract"), "and the checklist says so")
	gs.contract = {}
	_go("highcliff")
	check(String(gs.crown_check()["reason"]).contains("seat"), "and only at your own seat")
	check(not _met(gs.crown_path(), "seat") and String(_step(gs.crown_path(), "seat")["place"]) == seat,
		"the checklist points you back to your seat")
	_go(seat)
	check(gs.crown_check()["ok"], "a famous landed company at its seat can raise a crown")
	check(gs.crown_path().all(func(s): return bool(s["done"])), "and exactly then every step is ticked")

	check(gs.declare_crown(), "the crown is raised")
	check(gs.crown_path().is_empty(), "and the road to it is no longer shown")
	check(gs.is_crowned() and w.owner_of(seat) == WorldData.CROWN and not bool(gs.player_fief.get("lost", true)),
		"the fief becomes the crown's seat, and is not lost")
	check(w.at_war(liege, WorldData.CROWN) and gs.is_at_war_with(liege), "the old liege goes to war with the crown")
	check(w.relation_to_player(liege) == "hostile" and w.relation_to_player(WorldData.CROWN) == "friendly",
		"its lords are now your enemies")
	check(WorldData.culture_of(WorldData.CROWN) == Cultures.KHARZANI, "the crown takes the company's people")

	# Storming walls now takes them for the crown.
	var target := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and w.owner_of(id) == liege:
			target = id
			break
	_go(target)
	w.garrisons[target] = []
	check(gs.siege_check(target)["ok"], "a crowned company can storm its enemy's walls")
	var men_before: int = gs.total_men()
	gs.auto_resolve_siege(target)
	check(w.owner_of(target) == WorldData.CROWN and gs.crown_holdings().has(target), "and what it storms joins the crown")
	var held: int = w.men_of(w.garrison_at(target))
	check(held > 0 and gs.total_men() == men_before - held and gs.stationed_at(target).is_empty(),
		"with some of the stormers left on its walls as its garrison, not an empty keep (%d men)" % held)

	# Crown dues.
	var purse: int = gs.silver
	var treasury: int = int(w.realms[WorldData.CROWN]["treasury"])
	gs._crown_day()
	check(gs.silver > purse and int(w.realms[WorldData.CROWN]["treasury"]) > treasury, "crown lands pay the purse and the treasury")

	# Alliances: only with a realm sharing an enemy.
	var other := ""
	for r in w.realms:
		if r != liege and r != WorldData.CROWN:
			other = r
	if not w.at_war(other, liege):
		check(not w.can_ally_crown(other), "no alliance with a realm that shares no enemy")
		w.declare_war(other, liege, true)
	check(w.can_ally_crown(other) and gs.propose_alliance(other), "a realm at war with your enemy will ally with you")
	check(gs.is_allied_with(other) and w.relation_to_player(other) == "friendly", "and its lords are friendly")
	w.make_peace(other, liege, 0)
	w._prune_alliances()
	check(not w.allied_with_crown(other), "the alliance ends when the shared enemy is gone")

	# Peace: only after time at war, with a weary enemy.
	check(not gs.crown_peace_check(liege)["ok"], "too soon to sue for peace")
	w.wars[w.war_key(WorldData.CROWN, liege)]["since"] = w.hour - 8 * 24.0
	w.realms[liege]["weariness"] = 10.0
	check(String(gs.crown_peace_check(liege)["reason"]).contains("weary"), "nor before they tire of the war")
	w.realms[liege]["weariness"] = 50.0
	check(gs.sue_for_peace(liege) and not w.at_war(liege, WorldData.CROWN) and w.has_truce(liege, WorldData.CROWN),
		"a weary enemy accepts peace, with a truce")

	# Saved and loaded.
	w.declare_war(liege, WorldData.CROWN, true)
	w.declare_war(other, liege, true)
	gs.propose_alliance(other)
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(gs2.is_crowned() and gs2.world.owner_of(target) == WorldData.CROWN and gs2.world.allied_with_crown(other),
		"the crown, its lands and its alliances survive a save and load")
	gs2.free()

	# The world carries on with a crown in it.
	var ok := true
	var start: float = gs.world.hour
	var guard := 0
	while gs.world.hour - start < 24.0 * 30.0 and guard < 400:
		guard += 1
		if gs.world.encounter != -1:
			# Ride on, as a withdrawal would: whoever stopped us leaves us be for a while.
			var foe = gs.world.party(gs.world.encounter)
			if foe != null:
				foe.grace_until = gs.world.hour + 48.0
			gs.world.encounter = -1
		if not gs.world.pending_assault.is_empty():
			gs.answer_assault(false)
		if not gs.world.busy():
			gs.world.wait(24.0)
		gs.world.step(24.0)
		gs.settle()
	print("  hours passed %.0f, encounter %d, pending %s, moving %s" % [gs.world.hour - start, gs.world.encounter, str(gs.world.pending_assault), gs.world.player().moving()])
	check(ok and gs.world.hour - start >= 24.0 * 29.0, "a month passes with the crown in the world")

	# The map shows the crown's sheet.
	gs.map_notice = ""
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	current_scene._close_sheet()
	current_scene._open_crown()
	check(current_scene._kingdom != null and current_scene._kingdom.find_child("CrownTitle", true, false) != null, "the campaign menu opens your crown")

	print("\nKingdom tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
