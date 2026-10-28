## A saved, once-per-campaign introduction, acknowledged only by an explicit action.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")

func _ready() -> void:
	var col := Page.column(self, "A bond is forged", "CAPTAINS · RANK C")
	col.add_child(Page.note(GameState.bond_intro_pair, 36, Style.BRASS))
	col.add_child(Page.note("Fighting side by side has brought these captains together. Their bond now helps their squads recover morale when they fight near each other.", Style.BODY, Style.TEXT))
	col.add_child(Page.note("Deploy their squads close together and keep them supporting one another. More shared battles build rank B, then A, adding stronger morale recovery and bonus damage."))
	col.add_child(Page.note("If a bonded captain falls, their partner reacts according to their temperament. You can review your pairs in Warband → Bonds."))
	var go := Page.button("Continue to the map", _finish.bind("res://scenes/world_map.tscn"), true)
	col.add_child(go)
	col.add_child(Page.button("View my warband", _finish.bind("res://scenes/main_menu.tscn")))
	go.grab_focus()

func _finish(path: String) -> void:
	GameState.acknowledge_bond_intro()
	Scenes.go(path)
