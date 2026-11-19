## Sandbox, from Home: a battle of your own making, outside any campaign. Choose the
## ground, the land, the hour and (at a wall) whether you storm it or hold it; drag the
## enemy's companies onto their side of the field and confirm; drag your own; start. Every
## troop in the game is in the tray. Nothing here touches a campaign: no pay, no losses
## kept, no renown. The last setup is remembered (user://sandbox.json).
##
## The field shown while placing is the real one (the same site and seed the battle will
## use), and the zones are the battle's own deployment zones, read from a sim built for
## the purpose. The battle screen then puts each company where it was dropped
## (battle_screen.gd, `_sandbox`).
extends Control

const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Sim = preload("res://scripts/battle/battle_sim.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")
const FieldArt = preload("res://scripts/battle/field_art.gd")
const SiegeTown = preload("res://scripts/battle/siege_town.gd")
const SiegeWorks = preload("res://scripts/battle/siege_works.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Art = preload("res://scripts/art/unit_art.gd")

const SAVE := "user://sandbox.json"
const SCENE := "res://scenes/sandbox.tscn"
## Companies a side can put on the field, as in a campaign battle.
const CAP := 8
## [id, words]: the fields first, then the walls.
const SITES := [["open", "Open field"], ["hills", "Hills"], ["woods", "Woods"], ["river", "River"], ["pass", "Pass"],
	["town", "Town siege"], ["castle", "Castle siege"]]
const TIMES := [["Day", 12.0], ["Dusk", 18.5], ["Night", 23.0]]
## How fast the fight runs at 1x, for trying out the pace: a second on screen is this much of
## a second of battle (a campaign battle runs at BattleScreen.BATTLE_PACE, the one marked).
const PACES := [0.35, 0.5, 0.75, 1.0, 1.25]
const PACE_DEFAULT := 0.75
## The enemy's commander: "" lets the battle pick one.
const TEMPERS := [["", "Any"], [Commander.PATIENT, "Patient"], [Commander.HAMMER, "Hammer"], [Commander.RECKLESS, "Reckless"]]
const ATTACK_ENGINES := [[SiegeWorks.RAM, "Ram"], [SiegeWorks.LADDERS, "Ladders"], [SiegeWorks.MORE_LADDERS, "More ladders"],
	[SiegeWorks.MANTLETS, "Mantlets"], [SiegeWorks.TOWER, "Siege tower"], [SiegeWorks.THROWER, "Stone throwers"]]
const DEFEND_ENGINES := [[SiegeWorks.BOLT, "Bolt throwers"], [SiegeWorks.OIL, "Boiling oil"], [SiegeWorks.YARD, "Courtyard thrower"],
	[SiegeWorks.POSTERN, "Postern gate"]]
## A company's mark on the field while placing, in field units.
const TOKEN := Vector2(170.0, 58.0)

## The setup being made, kept between visits in one session; read from disk the first time.
static var setup := {}
## Which step to open on: the result screen's *Edit setup* comes back to the enemy's.
static var open_step := 0

var step := 0
var land_tab := ""
## What is in hand: {"unit": id} from the tray, or {"index": i} for one picked up off the field.
var carry := {}
## A tray unit tapped and not dragged: the next tap on the field places it.
var armed := ""
var pointer := Vector2.ZERO
var field: Control = null
var _plate: Texture2D = null
var _town := {}
var _woods: Array = []
var _zones := [Rect2(), Rect2()]
var _wall_y := -1.0
var _ladders: Array = []


# ---------------------------------------------------------------- the setup, as data

static func default_setup() -> Dictionary:
	return {"site": "open", "land": Cultures.VARDISH, "defend": false, "time": 0, "temper": "", "pace": PACE_DEFAULT,
		"attack": [SiegeWorks.RAM, SiegeWorks.LADDERS], "defense": [], "enemy": [], "mine": [], "seed": 1}


## The remembered setup, or a fresh one. Anything unreadable or out of date is dropped.
static func load_setup() -> Dictionary:
	var out := default_setup()
	if not FileAccess.file_exists(SAVE):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not (parsed is Dictionary):
		return out
	for key in ["site", "land", "temper"]:
		if parsed.get(key) is String:
			out[key] = parsed[key]
	if SITES.all(func(s): return s[0] != out["site"]):
		out["site"] = "open"
	if not Cultures.ORDER.has(out["land"]):
		out["land"] = Cultures.VARDISH
	if TEMPERS.all(func(t): return t[0] != out["temper"]):
		out["temper"] = ""
	out["defend"] = bool(parsed.get("defend", false))
	out["time"] = clampi(int(parsed.get("time", 0)), 0, TIMES.size() - 1)
	var pace := float(parsed.get("pace", PACE_DEFAULT))
	out["pace"] = pace if PACES.has(pace) else PACE_DEFAULT
	out["seed"] = maxi(1, int(parsed.get("seed", 1)))
	for key in ["attack", "defense"]:
		if parsed.get(key) is Array:
			var known: Array = (ATTACK_ENGINES if key == "attack" else DEFEND_ENGINES).map(func(e): return e[0])
			out[key] = (parsed[key] as Array).filter(func(e): return known.has(e))
	for key in ["enemy", "mine"]:
		if parsed.get(key) is Array:
			for c in parsed[key]:
				if c is Dictionary and Units.has(String(c.get("unit", ""))) and (out[key] as Array).size() < CAP:
					out[key].append({"unit": String(c["unit"]), "x": float(c.get("x", 420.0)), "y": float(c.get("y", 300.0))})
	return out


static func save_setup(s: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(s))


static func is_siege(s: Dictionary) -> bool:
	return String(s["site"]) in ["town", "castle"]


## The battlefield this setup is fought on.
static func site_of(s: Dictionary) -> Dictionary:
	return {"type": "open" if is_siege(s) else String(s["site"]), "seed": int(s["seed"]), "biome": String(s["land"]), "fair": true}


static func _roster(list: Array, base: int) -> Array:
	var out := []
	for i in list.size():
		var id := String(list[i]["unit"])
		out.append({"id": base + i, "type": Units.role(id), "unit": id, "men": Units.full_size(id),
			"culture": Units.culture(id), "xp": 0, "level": 1})
	return out


## The battle this setup describes, as the battle screen reads it (GameState.pending_battle).
static func pending(s: Dictionary) -> Dictionary:
	var mine := _roster(s["mine"], 9000)
	var theirs := _roster(s["enemy"], 9100)
	var places := {}
	for i in mine.size():
		places[9000 + i] = Vector2(float(s["mine"][i]["x"]), float(s["mine"][i]["y"]))
	for i in theirs.size():
		places[9100 + i] = Vector2(float(s["enemy"][i]["x"]), float(s["enemy"][i]["y"]))
	var land := String(s["land"])
	var out := {"sandbox": true, "army": mine, "enemy": theirs, "land": land,
		"culture": String(theirs[0]["culture"]) if not theirs.is_empty() else land,
		"objective": Sim.OBJECTIVE_SIEGE if is_siege(s) else Sim.OBJECTIVE_ROUT, "site": site_of(s),
		"temperament": String(s["temper"]), "hour": float(TIMES[int(s["time"])][1]), "seed": int(s["seed"]),
		"pace": float(s.get("pace", PACE_DEFAULT)),
		"places": places, "can_withdraw": true}
	if is_siege(s):
		var stormers: Array = theirs if bool(s["defend"]) else mine
		out["siege_kind"] = String(s["site"])
		out["siege_defend"] = bool(s["defend"])
		out["siege_engines"] = {"attacker": (s["attack"] as Array).duplicate(), "defender": (s["defense"] as Array).duplicate(),
			"attacker_land": String(stormers[0]["culture"]) if not stormers.is_empty() else land, "defender_land": land}
	return out


## A sim set up on this setup's field with nobody on it, for its ground and its zones.
static func field_sim(s: Dictionary) -> Sim:
	var sim := Sim.new()
	if is_siege(s):
		sim.siege_kind = String(s["site"])
		sim.siege_defender = Sim.PLAYER if bool(s["defend"]) else Sim.ENEMY
	var one := [{"id": 1, "type": Troops.INFANTRY, "men": 20}]
	var two := [{"id": 2, "type": Troops.INFANTRY, "men": 20}]
	sim.setup(one, two, int(s["seed"]), site_of(s), Sim.OBJECTIVE_SIEGE if is_siege(s) else Sim.OBJECTIVE_ROUT)
	return sim


## Every unit of a land, by role in the usual order, each role's recruit first.
static func units_of(land: String) -> Array:
	var out := []
	for role in Troops.ORDER:
		var first := Units.recruit(land, role)
		out.append(first)
		for id in Units.UNITS:
			if id != first and Units.culture(id) == land and Units.role(id) == role:
				out.append(id)
	return out


## Start the battle `s` describes.
static func fight(s: Dictionary) -> void:
	save_setup(s)
	GameState.pending_battle = pending(s)
	Scenes.go("res://scenes/battle.tscn")


# ---------------------------------------------------------------- the screen

func _ready() -> void:
	if setup.is_empty():
		setup = load_setup()
	land_tab = String(setup["land"])
	step = open_step
	open_step = 0
	_build()


func _list() -> Array:
	return setup["enemy"] if step == 1 else setup["mine"]


func _team() -> int:
	return Sim.ENEMY if step == 1 else Sim.PLAYER


func _build() -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)
	field = null
	carry = {}
	armed = ""
	if step == 0:
		_build_options()
	else:
		_read_field()
		_build_placing()


func _go(to: int) -> void:
	step = to
	save_setup(setup)
	_build()


# ---- step 0: the fight

func _build_options() -> void:
	var insets := Style.safe_insets(get_viewport())
	var col := Page.frame(self, 124.0 + float(insets["bottom"]))
	col.add_child(Style.label("Sandbox", 52, Style.BRASS))
	col.add_child(Page.note("A battle of your own making. Nothing here touches a campaign."))
	col.add_child(Widgets.section("Where"))
	col.add_child(_choices(SITES.map(func(s): return s[1]), SITES.map(func(s): return s[0]).find(setup["site"]), func(i: int):
		setup["site"] = SITES[i][0]
		_build(), "Site"))
	col.add_child(Widgets.section("Whose land"))
	col.add_child(Widgets.segmented(Cultures.ORDER.map(func(c): return String(Cultures.info(c)["people"])), Cultures.ORDER.find(setup["land"]), func(i: int):
		setup["land"] = Cultures.ORDER[i]
		_build(), "Land"))
	if is_siege(setup):
		col.add_child(Widgets.section("Your side of the wall"))
		col.add_child(Widgets.segmented(["Attack it", "Defend it"], 1 if setup["defend"] else 0, func(i: int):
			setup["defend"] = i == 1
			_build(), "Side"))
		col.add_child(Widgets.section("The attackers bring"))
		col.add_child(_checks(ATTACK_ENGINES, setup["attack"], "Attack"))
		col.add_child(Widgets.section("The walls have"))
		col.add_child(_checks(DEFEND_ENGINES, setup["defense"], "Defense"))
	col.add_child(Widgets.section("Hour"))
	col.add_child(Widgets.segmented(TIMES.map(func(t): return t[0]), int(setup["time"]), func(i: int):
		setup["time"] = i, "Hour"))
	col.add_child(Widgets.section("Battle speed"))
	col.add_child(Widgets.segmented(PACES.map(func(p): return ("%s×" % str(p)) + (" ·" if is_equal_approx(p, PACE_DEFAULT) else "")),
		maxi(0, PACES.find(float(setup.get("pace", PACE_DEFAULT)))), func(i: int):
		setup["pace"] = PACES[i], "Pace"))
	col.add_child(Page.note("How much of a second of battle passes in a second at 1×. The campaign runs at %s× (marked ·)." % str(PACE_DEFAULT), Style.SMALL))
	col.add_child(Widgets.section("Their commander"))
	col.add_child(Widgets.segmented(TEMPERS.map(func(t): return t[1]), TEMPERS.map(func(t): return t[0]).find(setup["temper"]), func(i: int):
		setup["temper"] = TEMPERS[i][0], "Temper"))
	col.add_child(Widgets.section("Ground"))
	var again := Page.button("Another field like this", func():
		setup["seed"] = randi_range(1, 99999)
		_build())
	again.name = "Reroll"
	col.add_child(again)
	col.add_child(Page.note("Field %d. Woods, hills and rivers fall differently on each." % int(setup["seed"]), Style.SMALL))
	var next := Page.button("Place the enemy", func(): _go(1), true)
	next.name = "Next"
	var bar := Widgets.bottom_bar([Widgets.back_button(func():
		save_setup(setup)
		Scenes.go("res://scenes/title.tscn"), "Home"), next], insets)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)


## A wrapping row of buttons where one is picked.
func _choices(words: Array, current: int, on_pick: Callable, row_name: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = row_name
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for i in words.size():
		var b := Button.new()
		b.text = String(words[i])
		b.custom_minimum_size = Vector2(0, Style.TOUCH)
		if i == current:
			Style.make_primary(b)
		b.pressed.connect(on_pick.bind(i))
		flow.add_child(b)
	return flow


## A wrapping row of buttons, each on or off: `chosen` is edited in place.
func _checks(options: Array, chosen: Array, row_name: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = row_name
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for o in options:
		var b := Button.new()
		b.text = String(o[1])
		b.custom_minimum_size = Vector2(0, Style.TOUCH)
		if chosen.has(o[0]):
			Style.make_primary(b)
		b.pressed.connect(func():
			if chosen.has(o[0]):
				chosen.erase(o[0])
			else:
				chosen.append(o[0])
			_build())
		flow.add_child(b)
	return flow


# ---- steps 1 and 2: placing

## The field's picture, its zones and its wall, from a sim built on this setup.
func _read_field() -> void:
	var sim := field_sim(setup)
	var t: Terrain = sim.terrain
	var land := String(setup["land"])
	_woods = []
	for cy in Terrain.ROWS:
		for cx in Terrain.COLS:
			if t.woods[cy * Terrain.COLS + cx] == Terrain.WOODS_TREES:
				_woods.append(t.cell_pos(cx, cy))
	_plate = FieldArt.overlay(FieldArt.hillshade_image(t, land), FieldArt.plate_image(t, land, [], 999))
	_zones = [sim.deploy_zone(Sim.PLAYER), sim.deploy_zone(Sim.ENEMY)]
	_town = {}
	_wall_y = -1.0
	_ladders = []
	if is_siege(setup):
		_wall_y = sim.wall_y
		_ladders = sim.ladder_points()
		# The battle screen's own styles for the walls (loaded here, not at the top: it is
		# a large script and only a siege needs it).
		var styles: Dictionary = load("res://scripts/battle/battle_screen.gd").CASTLE_STYLES
		var cols: Array = load("res://scripts/battle/battle_screen.gd").TOWER_COLS
		_town = SiegeTown.bake(styles[land], land, Sim.CASTLE_BUILDINGS, Sim.WALL_ROW, cols, Sim.GATE_COLS, sim.siege_defender == Sim.PLAYER)
	sim.dispose()
	# Anything remembered from another field is pulled back inside its zone.
	for key in ["enemy", "mine"]:
		var zone: Rect2 = _zones[Sim.ENEMY if key == "enemy" else Sim.PLAYER]
		for c in setup[key]:
			var at := _into(zone, Vector2(float(c["x"]), float(c["y"])))
			c["x"] = at.x
			c["y"] = at.y


static func _into(zone: Rect2, at: Vector2) -> Vector2:
	var room := zone.grow_individual(-TOKEN.x * 0.5, -TOKEN.y * 0.5, -TOKEN.x * 0.5, -TOKEN.y * 0.5)
	return Vector2(clampf(at.x, room.position.x, room.end.x), clampf(at.y, room.position.y, room.end.y))


func _build_placing() -> void:
	theme = Style.make_theme()
	var insets := Style.safe_insets(get_viewport())
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = float(insets["top"]) + 10.0
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_child(head)
	v.add_child(pad)
	var title := Style.label("Place the enemy" if step == 1 else "Place your own", 34, Style.ENEMY_LIGHT if step == 1 else Style.BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var count := Style.label("", Style.BODY, Style.MUTED)
	count.name = "Count"
	head.add_child(count)
	var hint := Page.note("Drag a company onto the lit ground. Drag one off it to take it away.", Style.SMALL)
	var hint_pad := MarginContainer.new()
	hint_pad.add_theme_constant_override("margin_left", 20)
	hint_pad.add_theme_constant_override("margin_right", 20)
	hint_pad.add_child(hint)
	v.add_child(hint_pad)
	field = Control.new()
	field.name = "Field"
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.clip_contents = true
	field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	v.add_child(field)
	# The tray: a land's twelve at a time.
	var tray := VBoxContainer.new()
	tray.add_theme_constant_override("separation", 6)
	var tray_pad := MarginContainer.new()
	tray_pad.add_theme_constant_override("margin_left", 12)
	tray_pad.add_theme_constant_override("margin_right", 12)
	tray_pad.add_child(tray)
	v.add_child(tray_pad)
	tray.add_child(Widgets.segmented(Cultures.ORDER.map(func(c): return String(Cultures.info(c)["people"])), Cultures.ORDER.find(land_tab), func(i: int):
		land_tab = Cultures.ORDER[i]
		_build(), "TrayLand"))
	var grid := GridContainer.new()
	grid.name = "Tray"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	tray.add_child(grid)
	var ordered := units_of(land_tab)
	# Rows read across by rank (recruits, then each branch), columns by role.
	var by_role := {}
	for id in ordered:
		by_role[Units.role(id)] = (by_role.get(Units.role(id), []) as Array) + [id]
	for rank in 3:
		for role in Troops.ORDER:
			var of_role: Array = by_role.get(role, [])
			if rank < of_role.size():
				grid.add_child(_tray_button(String(of_role[rank])))
			else:
				grid.add_child(Control.new())
	var back := Widgets.back_button(func(): _go(step - 1), "Back")
	var reset := Button.new()
	reset.name = "Reset"
	reset.text = "Reset"
	reset.pressed.connect(func():
		_list().clear()
		_changed())
	var next := Button.new()
	next.name = "Next"
	next.text = "Confirm" if step == 1 else "Start battle"
	Style.make_primary(next)
	next.pressed.connect(func():
		if step == 1:
			_go(2)
		else:
			fight(setup))
	v.add_child(Widgets.bottom_bar([back, reset, next], insets))
	# What is in hand rides over everything.
	var ghost := Control.new()
	ghost.name = "Ghost"
	ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.draw.connect(_draw_ghost.bind(ghost))
	add_child(ghost)
	_changed()


func _tray_button(id: String) -> Button:
	var b := Button.new()
	b.name = "Unit_%s" % id
	b.text = Units.display_name(id)
	b.icon = Art.icon(Units.role(id), _team(), Units.culture(id))
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 30)
	b.add_theme_constant_override("h_separation", 4)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL) - 3)
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = String(Units.get_unit(id).get("blurb", ""))
	b.button_down.connect(func():
		carry = {"unit": id}
		armed = id
		pointer = get_viewport().get_mouse_position()
		_redraw())
	return b


## Something was added, moved or taken away.
func _changed() -> void:
	var n := _list().size()
	var count := find_child("Count", true, false) as Label
	if count != null:
		count.text = "%d of %d" % [n, CAP]
	var next := find_child("Next", true, false) as Button
	if next != null:
		next.disabled = n == 0
	var reset := find_child("Reset", true, false) as Button
	if reset != null:
		reset.disabled = n == 0
	_redraw()


func _redraw() -> void:
	if field != null:
		field.queue_redraw()
	var ghost := get_node_or_null("Ghost") as Control
	if ghost != null:
		ghost.queue_redraw()


## The field fitted into its control: [scale, where the arena's corner sits].
func _fit() -> Array:
	var s := minf(field.size.x / Sim.ARENA.x, field.size.y / Sim.ARENA.y)
	return [s, (field.size - Sim.ARENA * s) * 0.5]


func _to_field(local: Vector2) -> Vector2:
	var f := _fit()
	return (local - Vector2(f[1])) / float(f[0])


## The company of the side being placed that lies under `at` (field units), or -1.
func _token_at(at: Vector2) -> int:
	var list := _list()
	for i in range(list.size() - 1, -1, -1):
		if Rect2(Vector2(float(list[i]["x"]), float(list[i]["y"])) - TOKEN * 0.5, TOKEN).has_point(at):
			return i
	return -1


## Put `id` down at `at` if that is in the zone and there is room for another.
func add_company(id: String, at: Vector2) -> bool:
	var zone: Rect2 = _zones[_team()]
	if _list().size() >= CAP or not zone.grow(20.0).has_point(at):
		return false
	var spot := _into(zone, at)
	_list().append({"unit": id, "x": spot.x, "y": spot.y})
	_changed()
	return true


func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var at := _to_field(event.position)
		var i := _token_at(at)
		if i >= 0:
			armed = ""
			carry = {"index": i}
			pointer = get_viewport().get_mouse_position()
			_redraw()
		elif armed != "":
			add_company(armed, at)


func _input(event: InputEvent) -> void:
	if field == null or carry.is_empty():
		return
	if event is InputEventMouseMotion:
		pointer = event.position
		if carry.has("index"):
			var c: Dictionary = _list()[int(carry["index"])]
			var at := _to_field(pointer - field.global_position)
			c["x"] = at.x
			c["y"] = at.y
		_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var at := _to_field(event.position - field.global_position)
		var on_field := Rect2(Vector2.ZERO, field.size).has_point(event.position - field.global_position)
		var zone: Rect2 = _zones[_team()]
		if carry.has("unit"):
			# Let go over the field: it lands there. Let go on the tray: it stays armed for a tap.
			if on_field and add_company(String(carry["unit"]), at):
				armed = ""
		else:
			var i := int(carry["index"])
			if on_field and zone.grow(20.0).has_point(at):
				var spot := _into(zone, at)
				_list()[i]["x"] = spot.x
				_list()[i]["y"] = spot.y
			else:
				_list().remove_at(i)
		carry = {}
		_changed()


# ---- drawing

func _draw_field() -> void:
	var f := _fit()
	var s: float = f[0]
	field.draw_set_transform(f[1], 0.0, Vector2(s, s))
	var px := Art.GRASS_PIXEL
	field.draw_set_transform(f[1], 0.0, Vector2(s * px, s * px))
	field.draw_texture_rect(Art.ground(String(setup["land"])), Rect2(Vector2.ZERO, Sim.ARENA / px), true)
	field.draw_set_transform(f[1], 0.0, Vector2(s, s))
	if _plate != null:
		field.draw_texture_rect(_plate, Rect2(Vector2.ZERO, Sim.ARENA), false)
	for p in _woods:
		field.draw_rect(Rect2(Vector2(p) - Vector2(13, 13), Vector2(26, 26)), Color(0.14, 0.3, 0.16, 0.8))
		field.draw_rect(Rect2(Vector2(p) - Vector2(9, 11), Vector2(12, 10)), Color(0.24, 0.44, 0.24, 0.8))
	if not _town.is_empty():
		field.draw_texture_rect(_town["texture"], _town["rect"], false)
		for lp in _ladders:
			field.draw_rect(Rect2(lp.x - 8.0, _wall_y - 30.0, 16.0, 60.0), Color("b88a52"))
	# The side being placed has its ground lit; the other side's is only outlined.
	var mine := _team()
	field.draw_rect(_zones[1 - mine], Color(1, 1, 1, 0.12), false, 2.0)
	field.draw_rect(_zones[mine], Color(Style.ENEMY if mine == Sim.ENEMY else Style.PLAYER, 0.2))
	field.draw_rect(_zones[mine], Color(Style.ENEMY_LIGHT if mine == Sim.ENEMY else Style.PLAYER_LIGHT, 0.9), false, 3.0)
	# The enemy stays in sight while you place your own.
	if step == 2:
		for c in setup["enemy"]:
			_draw_token(field, c, Sim.ENEMY, 0.75)
	var list := _list()
	for i in list.size():
		_draw_token(field, list[i], mine, 0.55 if carry.get("index", -1) == i else 1.0)
	field.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_token(on: Control, c: Dictionary, team: int, alpha: float) -> void:
	var id := String(c["unit"])
	var at := Vector2(float(c["x"]), float(c["y"]))
	var r := Rect2(at - TOKEN * 0.5, TOKEN)
	on.draw_rect(r.grow(3.0), Color(0.09, 0.07, 0.05, alpha))
	on.draw_rect(r, Color(Style.ENEMY if team == Sim.ENEMY else Style.PLAYER, alpha))
	on.draw_rect(Rect2(r.position, Vector2(r.size.x, 6.0)), Color(Style.ENEMY_LIGHT if team == Sim.ENEMY else Style.PLAYER_LIGHT, alpha))
	var icon := Art.icon(Units.role(id), team, Units.culture(id))
	on.draw_texture_rect(icon, Rect2(Vector2(r.position.x + 4.0, at.y - 24.0), Vector2(48, 48)), false, Color(1, 1, 1, alpha))
	var font := ThemeDB.fallback_font
	on.draw_string(font, Vector2(r.position.x + 54.0, at.y + 7.0), Units.display_name(id), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 58.0, 22, Color(1, 1, 1, alpha))


## The company in hand from the tray, under the finger.
func _draw_ghost(ghost: Control) -> void:
	if not carry.has("unit") or field == null:
		return
	var s: float = _fit()[0]
	ghost.draw_set_transform(pointer, 0.0, Vector2(s, s))
	_draw_token(ghost, {"unit": carry["unit"], "x": 0.0, "y": 0.0}, _team(), 0.8)
	ghost.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
