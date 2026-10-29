## A settlement you've stopped at: buy food, hire the recruits looking for work, and in a
## town reinforce and train your squads. The clock stands still while you're here. All
## rules live in game_state.gd; this screen shows them and passes the taps on.
extends Control

const StoryArt = preload("res://scripts/ui/story_art.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/data/economy.gd")
const Units = preload("res://scripts/data/units.gd")
const Relationships = preload("res://scripts/data/relationships.gd")

## The food you can buy in one go, in days for the whole warband.
const FOOD_DAYS := [3, 7]

var place := ""
var autoplay := false
var _scroll: ScrollContainer


func _ready() -> void:
	theme = Style.make_theme()
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	var w = GameState.world
	if w == null or w.here() == "":
		get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn" if w != null else "res://scenes/title.tscn")
		return
	place = w.here()
	Sound.play_music(WorldData.culture_of(WorldData.settlement(place)["faction"]))
	_build()
	if autoplay:
		_autoplay.call_deferred()


func _build() -> void:
	var keep := _scroll.scroll_vertical if _scroll != null else 0
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	var insets := Style.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_top", 56 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 40 + int(insets["bottom"]))
	_scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	if place == "ravensford":
		col.add_child(StoryArt.location("ravensford"))
	col.add_child(Style.label(String(WorldData.settlement(place)["name"]), 64, Style.BRASS))
	col.add_child(_note(GameState.world.describe(place)))
	var days := GameState.food_days()
	var purse := Style.label("%d silver · food for %s · wages %d a day" % [GameState.silver,
		"1 day" if days == 1 else "%d days" % days, GameState.daily_wages()], Style.BODY, Style.TEXT)
	purse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(purse)

	_add_provisions(col)
	_add_recruits(col)
	_add_squads(col)
	_add_court(col)

	var back := Button.new()
	back.text = "Back to the map"
	back.custom_minimum_size = Vector2(0, 92)
	back.add_theme_font_size_override("font_size", Style.LARGE)
	Style.make_primary(back)
	back.pressed.connect(_on_leave)
	col.add_child(back)
	_restore_scroll(keep)


## Rebuilding after a tap shouldn't throw the player back to the top.
func _restore_scroll(value: int) -> void:
	if value <= 0:
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value


func _add_court(col: VBoxContainer) -> void:
	var w = GameState.world
	if w == null or w.social == null:
		return
	var residents: Array = w.social.residents_at(place)
	if residents.is_empty():
		return
	col.add_child(_section("Court & Nobles"))
	for person in residents:
		var name_str := String(person.get("name", "Noble"))
		var role_str := String(person.get("role", "Resident"))
		var cid := String(person.get("content_id", ""))
		var rel: Dictionary = w.social.get_relationship(cid)
		var status_str := Relationships.status_label(String(rel.get("status", Relationships.UNKNOWN)))
		var btn := _button("Speak with %s (%s · %s)" % [name_str, role_str, status_str], func():
			Scenes.active_candidate_id = cid
			Scenes.active_person_id = String(person.get("id", ""))
			Scenes.conversation_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/conversation.tscn"))
		col.add_child(btn)


func _add_provisions(col: VBoxContainer) -> void:
	col.add_child(_section("Provisions"))
	var men := GameState.total_men()
	var kind := String(WorldData.settlement(place)["type"])
	var price := float(Economy.FOOD_PRICE.get(kind, 0.3))
	var cheap := " Villages sell it cheapest." if kind != WorldData.VILLAGE else ""
	col.add_child(_note("Every man eats a ration a day. Rations cost %.1f silver here.%s" % [price, cheap]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for d in FOOD_DAYS:
		var rations: int = d * men
		var cost := GameState.food_cost(rations)
		var b := _button("%d days · %d silver" % [d, cost], _on_buy_food.bind(rations))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = men == 0 or cost > GameState.silver
		row.add_child(b)


func _add_recruits(col: VBoxContainer) -> void:
	col.add_child(_section("Recruits"))
	var cap := GameState.squad_cap()
	var full := GameState.army.size() >= cap
	var line := "You lead %d squads, and your renown lets you lead %d." % [GameState.army.size(), cap]
	if full:
		line += " Win renown to lead more."
	col.add_child(_note(line, Style.ENEMY_LIGHT if full else Style.MUTED))
	var offers: Array = GameState.world.offers_at(place)
	for i in offers.size():
		col.add_child(_offer_row(offers[i], i, full))
	if offers.is_empty():
		var back: float = float(GameState.world.offers_back.get(place, GameState.world.hour)) - GameState.world.hour
		col.add_child(_note("Nobody else here is looking for work. More will come in about %d hours." % maxi(1, int(ceil(back)))))


func _offer_row(offer: Dictionary, index: int, full: bool) -> Control:
	var type := String(offer["type"])
	var culture := String(offer["culture"])
	var men := Troops.full_size(type)
	var cost := Economy.recruit_cost(type, men)
	var wage := Economy.daily_wage({"type": type, "men": men, "level": 1})
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(_portrait(type, culture))
	var text := _text_column(row)
	text.add_child(Style.label(Cultures.troop_name(culture, type), Style.BODY))
	var people := String(Cultures.info(culture)["people"])
	text.add_child(_small("%d %s recruits · wages %d a day" % [men, people, int(ceil(wage))]))
	var b := _button("Hire · %d" % cost, _on_hire.bind(index))
	b.disabled = full or cost > GameState.silver
	row.add_child(b)
	return panel


func _add_squads(col: VBoxContainer) -> void:
	col.add_child(_section("Your squads"))
	if not GameState.in_town():
		col.add_child(_note("Ride to a town to reinforce and train your squads."))
		return
	col.add_child(_note("Fresh men fill the gaps but water down a squad's experience. Training a squad "
		+ "that has earned it makes its men tougher and deadlier, and raises their wages."))
	var total := 0
	var cheapest := 0
	for s in GameState.army:
		var cost := GameState.reinforce_cost(s)
		total += cost
		if cost > 0 and (cheapest == 0 or cost < cheapest):
			cheapest = cost
		col.add_child(_squad_row(s))
	if total > 0:
		var all := _button("Reinforce all · %d silver" % total, _on_reinforce_all)
		all.disabled = cheapest > GameState.silver
		col.add_child(all)


func _squad_row(s: Dictionary) -> Control:
	var type := String(s["type"])
	var unit_id := String(s.get("unit", ""))
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(type)
	var men := int(s["men"])
	var level := int(s.get("level", 1))
	var xp := int(s["xp"])
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_portrait(unit_id if unit_id != "" else type, String(s.get("culture", GameState.culture))))
	var text := _text_column(row)
	var title := String(s.get("name", ""))
	var name_label := Style.label(title if title != "" else Units.troop_name(s, GameState.culture), Style.BODY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(10, 0)
	text.add_child(name_label)
	var drill := "fully trained"
	if GameState.can_train(s):
		drill = "ready to train"
	elif level < Troops.MAX_LEVEL:
		drill = "%d/%d xp" % [xp, level * Troops.XP_PER_LEVEL]
	text.add_child(_small("%s · %d/%d men · level %d · %s" % [Units.troop_name(s, GameState.culture), men, full, level, drill],
		Style.TEXT if men >= full else Style.ENEMY_LIGHT))
	var refill := GameState.reinforce_cost(s)
	if refill > 0:
		var b := _button("Refill · %d" % refill, _on_reinforce.bind(int(s["id"])))
		b.disabled = refill > GameState.silver
		row.add_child(b)
	if GameState.can_train(s):
		# Training a recruit squad makes it one of two branches, each with its own price.
		var branches := Units.branches(unit_id)
		var choosing: bool = (level == 1 or bool(s.get("pending_branch", false))) and not branches.is_empty()
		var price: int = 0 if bool(s.get("pending_branch", false)) else Economy.train_cost(s)
		if choosing and not s.get("pending_branch", false):
			price = Economy.train_cost(s, branches[0])
			for b in branches:
				price = mini(price, Economy.train_cost(s, b))
		var label: String = "Train · free" if price == 0 else ("Train · from %d" if choosing else "Train · %d") % price
		var t := _button(label, _on_train.bind(int(s["id"])))
		t.disabled = price > GameState.silver
		row.add_child(t)
	return panel


# ---------------------------------------------------------------- pieces

func _section(text: String) -> Label:
	return Style.label(text.to_upper(), Style.SMALL, Style.MUTED)


func _note(text: String, color: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _small(text: String, color: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(10, 0)
	return l


func _text_column(row: HBoxContainer) -> VBoxContainer:
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	return text


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, Style.TOUCH)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	b.pressed.connect(callback)
	return b


## A unit portrait, scaled up with hard pixel edges, dressed as `culture` dresses it.
func _portrait(type: String, culture: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = Art.icon(type, 0, culture)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(64, 64)
	return portrait


# ---------------------------------------------------------------- actions

func _on_buy_food(rations: int) -> void:
	_paid(GameState.buy_food(rations))


func _on_hire(index: int) -> void:
	_paid(GameState.hire(place, index))


func _on_reinforce(id: int) -> void:
	_paid(GameState.reinforce_squad(id))


func _on_reinforce_all() -> void:
	_paid(GameState.reinforce() > 0)


var _modal: Control = null


func _on_train(id: int) -> void:
	var s := GameState.squad_by_id(id)
	if s.is_empty():
		return
	var branches := Units.branches(s.get("unit", ""))
	if (int(s.get("level", 1)) == 1 or s.get("pending_branch", false)) and not branches.is_empty():
		_show_branch_choice(id, branches)
	else:
		_paid(GameState.train_squad(id))


func _show_branch_choice(id: int, branches: Array) -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null

	var squad := GameState.squad_by_id(id)
	if squad.is_empty():
		return

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_modal = overlay

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var heading := Style.label("Choose Upgrade Path", Style.LARGE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var sub := Style.label("Select a veteran specialization for this squad:", Style.BODY, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	box.add_child(cards_row)

	for b_id in branches:
		var u_info := Units.get_unit(b_id)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_box := VBoxContainer.new()
		c_box.add_theme_constant_override("separation", 8)
		card.add_child(c_box)

		var b_portrait := _portrait(b_id, Units.culture(b_id))
		b_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c_box.add_child(b_portrait)

		var b_title := Style.label(Units.display_name(b_id), Style.BODY)
		b_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_box.add_child(b_title)

		var b_blurb := Style.label(String(u_info.get("blurb", "")), Style.SMALL)
		b_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_box.add_child(b_blurb)

		var stats_desc := _format_unit_diff(b_id)
		if stats_desc != "":
			var diff_label := Style.label(stats_desc, Style.SMALL, Style.TEXT)
			diff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c_box.add_child(diff_label)

		var is_free: bool = squad.get("pending_branch", false)
		var price := 0 if is_free else Economy.train_cost(squad, b_id)
		var btn_text := "Select (Free)" if is_free else "Select · %d silver" % price
		var btn := _button(btn_text, func():
			overlay.queue_free()
			_modal = null
			_paid(GameState.train_squad(id, b_id))
		)
		btn.disabled = price > GameState.silver
		c_box.add_child(btn)

		cards_row.add_child(card)

	var cancel_btn := _button("Cancel", func():
		overlay.queue_free()
		_modal = null
	)
	box.add_child(cancel_btn)


func _format_unit_diff(unit_id: String) -> String:
	var u := Units.get_unit(unit_id)
	var lines := []
	var mech: Dictionary = u.get("mechanics", {})
	if mech.has("armor"):
		lines.append("• Armor: %.0f%%" % [float(mech["armor"]) * 100.0])
	if mech.has("piercing"):
		lines.append("• Piercing: %.0f%%" % [float(mech["piercing"]) * 100.0])
	if mech.has("javelins"):
		lines.append("• Javelins: %d per man" % int(mech["javelins"]))
	if mech.get("sweep", false):
		lines.append("• Sweep: hits 2nd foe for 50%")
	if mech.get("steady", false):
		lines.append("• Steady: -20% morale loss")
	if mech.get("horse_archer", false):
		lines.append("• Horse Archer: shoots from saddle & kites")
	if mech.get("ronin", false):
		lines.append("• Ronin: enters fury if captain falls")
	var st: Dictionary = u.get("stats", {})
	if st.has("damage"):
		lines.append("• Damage: %.0f" % float(st["damage"]))
	if st.has("range"):
		lines.append("• Range: %.0f" % float(st["range"]))
	if st.has("speed"):
		lines.append("• Speed: %.0f" % float(st["speed"]))
	if st.has("size"):
		lines.append("• Squad size: %d men" % int(st["size"]))
	return "\n".join(lines)


## Silver changed hands, or didn't: the coins chink, and the screen shows the new state.
func _paid(done: bool) -> void:
	if done:
		Sound.play("coins", 0.0, 0.08)
	_build()


func _on_leave() -> void:
	GameState.save_game()
	Scenes.go("res://scenes/world_map.tscn")


## The smoke test: buy food, hire whoever's here, fill the ranks, then stop.
func _autoplay() -> void:
	var before := GameState.silver
	_on_buy_food(GameState.total_men() * FOOD_DAYS[0])
	if not GameState.world.offers_at(place).is_empty():
		_on_hire(0)
	_on_reinforce_all()
	print("autoplay: at %s spent %d silver; %d men in %d squads, food for %d days" % [
		place, before - GameState.silver, GameState.total_men(), GameState.army.size(), GameState.food_days()])
	get_tree().quit()
