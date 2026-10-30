## Saved bond-rank and remembrance moments, acknowledged only by an explicit action.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")

var _event := {}

func _ready() -> void:
	_event = GameState.bond_intro_event()
	var kind := String(_event.get("kind", "rank"))
	var rank := String(_event.get("rank", "C"))
	var title: String = "A place left empty" if kind == "memorial" else String({"C": "A bond is forged", "B": "Trust under fire", "A": "Bound by battle"}.get(rank, "A bond deepens"))
	var subtitle := "REMEMBRANCE · BOND %s" % rank if kind == "memorial" else "CAPTAINS · RANK %s" % rank
	var col := Page.column(self, title, subtitle)
	var captains := GameState.bond_intro_captains()
	if not captains.is_empty():
		var faces := HBoxContainer.new()
		faces.name = "BondPortraits"
		faces.alignment = BoxContainer.ALIGNMENT_CENTER
		faces.add_theme_constant_override("separation", 24)
		for i in captains.size():
			var face := CaptainArt.portrait(captains[i], Vector2(108, 144))
			if kind == "memorial" and i == captains.size() - 1:
				face.modulate = Color(0.55, 0.55, 0.62)
			faces.add_child(face)
		col.add_child(faces)
	col.add_child(Page.note(String(_event.get("pair", GameState.bond_intro_pair)), 36, Style.BRASS))
	var shared := int(_event.get("shared_battles", 0))
	if kind == "memorial":
		col.add_child(Page.note("They fought together in %d %s. One place by the fire will remain empty tonight." % [shared, "battle" if shared == 1 else "battles"], Style.BODY, Style.TEXT))
		col.add_child(Page.note("The surviving captain keeps the memory in their personal record. Their battlefield reaction still follows their temperament."))
	else:
		col.add_child(Page.note(_rank_story(rank, shared), Style.BODY, Style.TEXT))
		var points := float(_event.get("points", 0.0))
		col.add_child(Page.note("Rank %s effect: %s" % [rank, GameState.bond_effect_text(points)], Style.BODY, Style.BRASS))
		col.add_child(Page.note("The effect applies only while both captains are active and their squads remain close together. Shared fighting continues to build the next rank."))
	var go := Page.button("Continue to the map", _finish.bind("res://scenes/world_map.tscn"), true)
	col.add_child(go)
	if kind == "rank" and captains.size() == 2:
		col.add_child(Page.button("Spend time at camp", _talk))
	col.add_child(Page.button("View my warband", _finish.bind("res://scenes/main_menu.tscn")))
	go.grab_focus()

func _rank_story(rank: String, shared: int) -> String:
	match rank:
		"B":
			return "After %d shared battles, trust has become habit. Each captain knows where the other will stand before the order is given." % shared
		"A":
			return "After %d shared battles, this is one of the company’s defining bonds. They have learned how to steady and strengthen one another under pressure." % shared
		_:
			return "Fighting side by side has brought these captains together. Their squads can now recover morale when they support one another nearby."

func _talk() -> void:
	Scenes.active_bond_a_id = int(_event.get("a_id", 0))
	Scenes.active_bond_b_id = int(_event.get("b_id", 0))
	Scenes.bond_conversation_return = "res://scenes/world_map.tscn"
	GameState.acknowledge_bond_intro()
	Scenes.go("res://scenes/bond_conversation.tscn")

func _finish(path: String) -> void:
	GameState.acknowledge_bond_intro()
	Scenes.go(path)
