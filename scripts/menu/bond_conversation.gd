## Optional, replayable camp dialogue assembled only from saved captain and battle facts.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")

func _ready() -> void:
	Sound.set_loop("camp")
	var conversation := GameState.bond_conversation(Scenes.active_bond_a_id, Scenes.active_bond_b_id)
	if conversation.is_empty():
		var missing := Page.column(self, "The fire has gone quiet", "BOND CONVERSATION")
		missing.add_child(Page.note("These captains can no longer share this conversation."))
		missing.add_child(Page.button("Back", _back, true))
		return
	var a: Dictionary = conversation["a"]
	var b: Dictionary = conversation["b"]
	var col := Page.column(self, "%s & %s" % [a["first"], b["first"]], "CAMP · BOND %s" % conversation["rank"])
	var faces := HBoxContainer.new()
	faces.name = "BondConversationPortraits"
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	faces.add_theme_constant_override("separation", 24)
	faces.add_child(CaptainArt.portrait(a, Vector2(108, 144)))
	faces.add_child(CaptainArt.portrait(b, Vector2(108, 144)))
	col.add_child(faces)
	for passage in conversation["passages"]:
		var panel := PanelContainer.new()
		panel.add_child(Page.note(String(passage), Style.BODY, Style.TEXT))
		col.add_child(panel)
	col.add_child(Page.note("A quiet conversation. It changes no battle values or campaign resources.", Style.SMALL, Style.MUTED))
	col.add_child(Page.button("Back to Warband" if Scenes.bond_conversation_return.ends_with("main_menu.tscn") else "Continue", _back, true))
	GameState.acknowledge_bond_conversation(int(a["id"]), int(b["id"]))

func _exit_tree() -> void:
	Sound.set_loop("")

func _back() -> void:
	Scenes.go(Scenes.bond_conversation_return)
