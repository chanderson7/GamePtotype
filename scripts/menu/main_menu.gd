## Camp: shows the warband that carries between battles and starts the next one.
## The war map will take over as the game's hub; for now this is the space between fights.
extends Control

const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")

var _reset_armed := 0.0


func _ready() -> void:
	theme = Style.make_theme()
	_build()
	# Headless smoke test: `-- --autoplay` keeps fighting a couple of battles on its own.
	if OS.get_cmdline_user_args().has("--autoplay") and GameState.battles < 2:
		get_tree().create_timer(0.5).timeout.connect(_on_battle)


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	col.add_child(Style.label("Bannerfall", 72, Style.BRASS))
	col.add_child(Style.label("Prototype · field battles", 22, Style.MUTED))

	var last: Dictionary = GameState.last_result
	if not last.is_empty():
		var won: bool = last["won"]
		var line := "Last battle: %s. Lost %d men, cut down %d." % ["Victory" if won else "Defeat", last["lost"], last["killed"]]
		var last_label := Style.label(line, 22, Style.BRASS if won else Style.ENEMY_LIGHT)
		last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(last_label)

	col.add_child(_section("Your warband"))
	col.add_child(Style.label("%d men in %d squads · %d battles, %d won" % [
		GameState.total_men(), GameState.army.size(), GameState.battles, GameState.wins], 20, Style.MUTED))
	var roster := VBoxContainer.new()
	roster.add_theme_constant_override("separation", 8)
	col.add_child(roster)
	for s in GameState.army:
		roster.add_child(_squad_row(s))
	if GameState.army.is_empty():
		roster.add_child(Style.label("Your warband is gone. Raise a new one.", 22, Style.ENEMY_LIGHT))

	var fight := Button.new()
	fight.text = "To battle"
	fight.custom_minimum_size = Vector2(0, 84)
	fight.add_theme_font_size_override("font_size", 28)
	Style.make_primary(fight)
	fight.disabled = GameState.army.is_empty()
	fight.pressed.connect(_on_battle)
	col.add_child(fight)

	var rest := Button.new()
	rest.text = "Rest and reinforce"
	rest.custom_minimum_size = Vector2(0, 64)
	rest.disabled = not GameState.is_wounded()
	rest.pressed.connect(_on_reinforce)
	col.add_child(rest)

	var fresh := Button.new()
	fresh.text = "Raise a new warband"
	fresh.custom_minimum_size = Vector2(0, 64)
	fresh.pressed.connect(_on_new.bind(fresh))
	col.add_child(fresh)

	col.add_child(_section("How to fight"))
	var how := Style.label(
		"Before the fight, place your whole army in the blue zone: tap a card, then the field, " +
		"or tap Auto-place. Press Fight when you're ready.\n\n" +
		"Your squads hold their ground until ordered. Advance sends them at the enemy; Hold stops " +
		"them where they stand. Tap a squad to order it alone, then tap an enemy squad to attack it " +
		"or open ground to march there.\n\n" +
		"Spearmen stop cavalry. Cavalry ride down archers. Archers shred infantry, until their " +
		"arrows run out. Infantry cut through spear lines. Break their army to win.", 20, Style.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(how)


func _section(text: String) -> Label:
	return Style.label(text.to_upper(), 18, Style.MUTED)


func _squad_row(s: Dictionary) -> Control:
	var type: String = s["type"]
	var full := Troops.full_size(type)
	var men: int = s["men"]
	var level := Troops.level_for(int(s["xp"]))
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var chip := ColorRect.new()
	chip.color = Style.PLAYER
	chip.custom_minimum_size = Vector2(10, 40)
	row.add_child(chip)
	var name_label := Style.label(Troops.display_name(type), 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if level > 1:
		row.add_child(Style.label("Lv%d" % level, 20, Style.BRASS))
	row.add_child(Style.label("%d / %d men" % [men, full], 22, Style.TEXT if men >= full else Style.ENEMY_LIGHT))
	return panel


func _on_battle() -> void:
	if GameState.army.is_empty():
		return
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _on_reinforce() -> void:
	GameState.reinforce()
	_build()


func _on_new(button: Button) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _reset_armed or GameState.army.is_empty():
		GameState.new_warband()
		_build()
		return
	_reset_armed = now + 3.0
	button.text = "Tap again to start over"
