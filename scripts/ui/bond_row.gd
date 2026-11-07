## One bond between captains, drawn the same on the Warband's Bonds tab and in a captain's
## profile: their faces, the rank badge, what the bond does in battle as chips, and a meter
## to the next rank with the points as its aside.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Captains = preload("res://scripts/data/captains.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")


## `faces` are the captains drawn on the left (one or two) and `title` the line beside
## them. `shared` is the battles fought side by side (shown when there are any). `talk`
## opens the talk at the fire, with a dot when `is_new`; `open` makes the whole row one
## touch target instead (`button_name` names whichever button there is).
static func make(faces: Array, title: String, points: float, shared: int = 0, talk: Callable = Callable(),
		is_new: bool = false, open: Callable = Callable(), button_name: String = "") -> PanelContainer:
	var rank := Captains.rank_for(points)
	var panel := PanelContainer.new()
	panel.name = "BondRow"
	var sb := Style.box(Style.RAISED, Style.BRASS.darkened(0.25) if is_new else Style.RULE, 2, 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	for c in faces:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var pic := CaptainArt.portrait(c, Vector2(48, 60))
		if pic.texture == null:
			continue
		var f := Widgets.framed(pic, Vector2(48, 60))
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(f)

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 6)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(head)
	if rank > 0:
		head.add_child(Widgets.rank_badge(String(Captains.RANKS[rank]), 40.0))
	var t := Style.label(title, Style.BODY, Style.TEXT)
	t.name = "BondTitle"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size.x = 10
	head.add_child(t)

	# What it does when they fight near each other, and how often they have.
	var chips: Array = []
	if rank > 0:
		var morale := Widgets.stat("morale", "+%s/s" % _short(Captains.RANK_REGEN[rank]), Style.MORALE_HIGH)
		morale.name = "BondMorale"
		morale.tooltip_text = "Morale regained each second while near each other"
		chips.append(morale)
		var power := roundi(float(Captains.RANK_POWER[rank]) * 100.0)
		if power > 0:
			var fight := Widgets.stat("fight", "+%d%%" % power, Style.MORALE_HIGH)
			fight.name = "BondFight"
			chips.append(fight)
	if shared > 0:
		var together := Widgets.stat("battle", str(shared))
		together.name = "SharedBattles"
		chips.append(together)
	if not chips.is_empty():
		words.add_child(Widgets.chip_row(chips))

	# The meter fills within the current rank, toward the next.
	var meter_row := HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 10)
	meter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(meter_row)
	var frac := 1.0
	var aside := "Rank A"
	if rank + 1 < Captains.RANK_POINTS.size():
		var lo: float = Captains.RANK_POINTS[rank]
		var hi: float = Captains.RANK_POINTS[rank + 1]
		frac = clampf((points - lo) / maxf(0.01, hi - lo), 0.0, 1.0)
		aside = "%.0f/%.0f → %s" % [points, hi, Captains.RANKS[rank + 1]]
	var m := Widgets.meter(frac, Style.PLAYER_LIGHT if rank > 0 else Style.MUTED, 12.0)
	m.name = "BondMeter"
	meter_row.add_child(m)
	var a := Style.label(aside, Style.SMALL, Style.MUTED)
	a.name = "BondNext"
	meter_row.add_child(a)

	if talk.is_valid():
		var b := Widgets.icon_button("talk", talk, "Spend time at camp", button_name)
		b.accessibility_name = "Spend time at camp" + (", new" if is_new else "")
		var dot := Panel.new()
		dot.name = "NewDot"
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", Style.box(Style.BRASS, Style.NIGHT, 2, 10))
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -24.0
		dot.offset_right = -6.0
		dot.offset_top = 6.0
		dot.offset_bottom = 24.0
		dot.visible = is_new
		b.add_child(dot)
		row.add_child(b)
	elif open.is_valid():
		var tap := Button.new()
		tap.name = button_name if button_name != "" else "OpenBond"
		tap.flat = true
		tap.focus_mode = Control.FOCUS_ALL
		tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tap.accessibility_name = "View %s" % title
		tap.pressed.connect(open)
		panel.add_child(tap)
	return panel


## 1.0 as "1", 1.5 as "1.5".
static func _short(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
