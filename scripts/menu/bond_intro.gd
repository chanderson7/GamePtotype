## Saved bond-rank and remembrance moments, acknowledged only by an explicit action.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Captains = preload("res://scripts/data/captains.gd")

var _event := {}

func _ready() -> void:
	_event = GameState.bond_intro_event()
	var kind := String(_event.get("kind", "rank"))
	Sound.play("bell" if kind == "memorial" else "bond_rank")
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
			var gone: bool = kind == "memorial" and i == captains.size() - 1
			# The one who remains grieves; at a new rank, both are glad of each other.
			var mood := "" if gone else ("grief" if kind == "memorial" else "warm")
			var face := CaptainArt.portrait(captains[i], Vector2(108, 144), mood)
			if gone:
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
		col.add_child(_rank_row(rank))
		col.add_child(Page.note("The effect applies only while both captains are active and their squads remain close together. Shared fighting continues to build the next rank."))
	var go := Page.button("Continue to the map", _finish.bind("res://scenes/world_map.tscn"), true)
	col.add_child(go)
	if kind == "rank" and captains.size() == 2:
		col.add_child(Page.button("Spend time at camp", _talk))
	col.add_child(Page.button("View my warband", _finish.bind("res://scenes/main_menu.tscn")))
	go.grab_focus()

## The rank as its badge, and what it does in battle as chips: morale back each second
## nearby, and the damage it adds from rank B.
func _rank_row(rank: String) -> Control:
	var i := maxi(0, Captains.RANKS.find(rank))
	var row := HBoxContainer.new()
	row.name = "RankEffect"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(Widgets.rank_badge(rank, 56.0))
	var regen := Widgets.stat("morale", "+%.1f/s" % Captains.RANK_REGEN[i])
	regen.tooltip_text = "morale each second nearby"
	row.add_child(regen)
	var damage := roundi(Captains.RANK_POWER[i] * 100.0)
	if damage > 0:
		var hit := Widgets.stat("fight", "+%d%%" % damage)
		hit.tooltip_text = "damage"
		row.add_child(hit)
	return row


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
