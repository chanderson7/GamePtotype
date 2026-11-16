## The lists at your tourney, ridden. A grandstand full of the hall's people, the tilt down
## the middle, and two riders charging along it. Your captains' bouts are yours to ride:
## as they close, a needle runs to the strike zone and you tap as the lances meet. Dead on,
## the lance shatters (and may unhorse); close, it's a hit; early or late, a miss. Three
## passes, or until someone is unhorsed. Better captains have a wider zone (the same
## measure the dice use). Every other bout is run past at speed. Then the champion.
##
## The rules are CrownCourt's (lists_field, lists_bout, lists_finish): a bout you ride
## settles who won; a captain unhorsed may still be hurt; the purse, renown and Regard are
## the same as ever. "Let it ride" leaves any bout to the dice.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const CourtUI = preload("res://scripts/ui/court_ui.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const Data = preload("res://scripts/world/world_data.gd")

## Seconds from the start of a charge to the lances meeting.
const CHARGE := 2.0
## The run past at speed for a bout nobody's riding.
const AUTO_CHARGE := 0.9
const PASSES := 3

var _still := false
var _view := Vector2.ZERO
var _arena: Control
var _stands: Control
var _near: Control
var _far: Control
var _stamp: Label
var _hud: VBoxContainer
var _bar: Control
var _strike: Button
var _ride_it: Button
var _overlay: Control

var _field: Array = []
var _mine: Array = []
var _lords: Array = []
var _lines: Array = []
var _round: Array = []          # this round's pairs [a, b] (b {} for a bye)
var _next: Array = []
var _bout := -1
var _round_no := 0

# A bout being ridden.
var _a: Dictionary = {}
var _b: Dictionary = {}
var _yours := false             # one of yours against someone else's
var _you_are_a := true
var _pass := 0
var _score := [0, 0]            # yours, theirs
var _t := -1.0                  # seconds into the charge (-1: not charging)
var _tapped := -1.0
var _charge_len := CHARGE
var _zone := 0.1                # half-width of the strike zone, in seconds
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	_still = Style.motion_reduced()
	_view = get_viewport_rect().size
	_rng.randomize()
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var f: Dictionary = CrownCourt.lists_field(GameState, Scenes.lists_squads) if GameState.world != null else {}
	if not bool(f.get("ok", false)):
		_build_arena()
		_say_card("The lists", "There's nobody to ride today.", [["Back", _leave, true]])
		return
	_field = f["field"]
	_mine = f["mine"]
	_lords = f["lords"]
	_build_arena()
	_build_hud()
	Sound.play("horn")
	Sound.play("cheer", -4.0)
	_start_round()


# ---------------------------------------------------------------- the arena

func _host_realm() -> String:
	var g: Dictionary = CrownCourt.table(GameState) if GameState.world != null else {}
	var realm := String(g.get("realm", Data.CROWN))
	return realm if SettlementScene.TEAM.has(realm) else Data.CROWN


func _colors(e: Dictionary) -> Array:
	var realm := Data.CROWN if GameState.is_crowned() else String(Data.realm_of_culture(GameState.culture))
	if e.has("lord"):
		realm = String(e["lord"].get("realm", "bandits"))
		# A lord sworn to your crown still rides in his own house's colours.
		if realm == Data.CROWN and String(e["lord"].get("sworn_from", "")) != "":
			realm = String(e["lord"]["sworn_from"])
	var t: Array = SettlementScene.TEAM.get(realm, SettlementScene.TEAM["bandits"])
	return [Color(String(t[0])), Color(String(t[1])), Color(String(t[2]))]


func _build_arena() -> void:
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var arena_h := roundf(_view.y * 0.52)
	_arena = Control.new()
	_arena.name = "Arena"
	_arena.clip_contents = true
	_arena.size = Vector2(_view.x, arena_h)
	_arena.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena.gui_input.connect(_on_tap_input)
	add_child(_arena)
	var host: Array = _colors({"lord": {"realm": _host_realm()}})
	_stands = _Stands.new()
	_stands.name = "Stands"
	_stands.size = _arena.size
	_stands.cloth = host[0]
	_stands.trim = host[1]
	_stands.still = _still
	_stands.top = float(insets.get("top", 0.0))
	_arena.add_child(_stands)
	var flag := Widgets.banner(_host_realm(), Vector2(70, 100))
	flag.position = Vector2(20, float(insets.get("top", 0.0)) + 16)
	_arena.add_child(flag)
	var flag2 := Widgets.banner(_host_realm(), Vector2(70, 100))
	flag2.position = Vector2(_view.x - 90, float(insets.get("top", 0.0)) + 16)
	_arena.add_child(flag2)
	_far = _Rider.new()
	_far.name = "FarRider"
	_far.k = maxf(4.0, roundf(_view.x / 150.0))
	_far.facing = -1
	_arena.add_child(_far)
	var tilt := _Tilt.new()
	tilt.size = _arena.size
	tilt.y = arena_h * 0.7
	tilt.cloth = host[0]
	_arena.add_child(tilt)
	_near = _Rider.new()
	_near.name = "NearRider"
	_near.k = _far.k + 1.0
	_near.facing = 1
	_arena.add_child(_near)
	_stamp = Style.label("", 56, Color("f3d891"))
	_stamp.name = "Stamp"
	if Style.display_font() != null:
		_stamp.add_theme_font_override("font", Style.display_font())
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_stamp.add_theme_constant_override("outline_size", 10)
	_stamp.position = Vector2(0, arena_h * 0.3)
	_stamp.size = Vector2(_view.x, 80)
	_stamp.pivot_offset = Vector2(_view.x * 0.5, 40)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_stamp)
	_place_riders(0.0)


## The riders along the tilt, `p` of the way to meeting (0 at the ends, 1 at the meeting,
## on past it).
func _place_riders(p: float) -> void:
	var meet := _view.x * 0.5
	var near_y := _arena.size.y * 0.93
	var far_y := _arena.size.y * 0.66
	_near.position = Vector2(lerpf(-60.0, meet - 30.0 * _near.k, p), near_y)
	_far.position = Vector2(lerpf(_view.x + 60.0, meet + 30.0 * _far.k, p), far_y)


func _build_hud() -> void:
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(20, _arena.size.y + 12)
	scroll.size = Vector2(_view.x - 40, _view.y - _arena.size.y - 12 - float(insets.get("bottom", 0.0)) - 12)
	add_child(scroll)
	_hud = VBoxContainer.new()
	_hud.name = "ListsHud"
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud.add_theme_constant_override("separation", 14)
	scroll.add_child(_hud)


func _clear_hud() -> void:
	for c in _hud.get_children():
		_hud.remove_child(c)
		c.queue_free()
	_bar = null
	_strike = null
	_ride_it = null


# ---------------------------------------------------------------- rounds and bouts

func _start_round() -> void:
	_round_no += 1
	_round = []
	_next = []
	var f := _field.duplicate()
	if f.size() % 2 == 1:
		_next.append(f.pop_back())
	for k in range(0, f.size(), 2):
		_round.append([f[k], f[k + 1]])
	_bout = -1
	_clear_hud()
	var final := _round.size() == 1 and _next.is_empty()
	var head := Style.label("The final" if final else "Round %d" % _round_no, Style.LARGE + 4, Color("f3d891"))
	if Style.display_font() != null:
		head.add_theme_font_override("font", Style.display_font())
	_hud.add_child(head)
	for pair in _round:
		_hud.add_child(_pairing(pair[0], pair[1]))
	for e in _next:
		var bye := Style.label("%s rides on unchallenged." % CrownCourt.entrant_name(e), Style.SMALL, Style.MUTED)
		_hud.add_child(bye)
	var go := Button.new()
	go.name = "ToTheLists"
	go.text = "To the lists"
	go.custom_minimum_size = Vector2(0, Style.TOUCH)
	Style.make_primary(go)
	go.pressed.connect(_next_bout)
	_hud.add_child(go)


## A pairing: two faces and their names.
func _pairing(a: Dictionary, b: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_face(a, 60.0))
	var na := Style.label(CrownCourt.entrant_name(a), Style.SMALL, Style.BRASS if a.has("captain") else Style.TEXT)
	na.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	na.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	na.custom_minimum_size = Vector2(10, 0)
	row.add_child(na)
	row.add_child(Style.label("vs", Style.SMALL, Style.MUTED))
	var nb := Style.label(CrownCourt.entrant_name(b), Style.SMALL, Style.BRASS if b.has("captain") else Style.TEXT)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb.custom_minimum_size = Vector2(10, 0)
	row.add_child(nb)
	row.add_child(_face(b, 60.0))
	return row


func _face(e: Dictionary, w: float) -> Control:
	var tex: Texture2D = CaptainArt.texture(e["captain"], "", true) if e.has("captain") else CaptainArt.texture(LordVoice.portrait_record(e["lord"]), "", true)
	return CourtUI.portrait(tex, w)


func _next_bout() -> void:
	_bout += 1
	if _bout >= _round.size():
		_field = _next
		if _field.size() <= 1:
			_champion()
		else:
			_start_round()
		return
	_a = _round[_bout][0]
	_b = _round[_bout][1]
	_yours = _a.has("captain") != _b.has("captain")
	_you_are_a = _a.has("captain")
	_pass = 0
	_score = [0, 0]
	var mine_e := _a if _you_are_a else _b
	var theirs := _b if _you_are_a else _a
	# The near rider is yours (or the first named, when it's not your bout).
	var near_e := mine_e if _yours else _a
	var far_e := theirs if _yours else _b
	var nc := _colors(near_e)
	var fc := _colors(far_e)
	_near.set_colors(nc[0], nc[1])
	_far.set_colors(fc[0], fc[1])
	_near.reset()
	_far.reset()
	_place_riders(0.0)
	_clear_hud()
	_hud.add_child(_pairing(near_e, far_e))
	if _yours:
		_zone = 0.06 + 0.08 * CrownCourt.lists_chance(mine_e, theirs)
		_ride_pass()
	else:
		_hud.add_child(_note("%s against %s: the crowd watches, you wait your turn." % [CrownCourt.entrant_name(_a), CrownCourt.entrant_name(_b)]))
		_charge(AUTO_CHARGE)


func _note(text: String, tone: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, tone)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A pass you ride: the needle, the strike, the score so far.
func _ride_pass() -> void:
	while _hud.get_child_count() > 1:
		var c := _hud.get_child(_hud.get_child_count() - 1)
		_hud.remove_child(c)
		c.queue_free()
	var pips := HBoxContainer.new()
	pips.name = "Passes"
	pips.add_theme_constant_override("separation", 10)
	var pl := Style.label("Pass %d of %d" % [_pass + 1, PASSES], Style.BODY, Style.TEXT)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.add_child(pl)
	pips.add_child(Widgets.chip("you %d" % _score[0], Style.BRASS, "", "fight", true))
	pips.add_child(Widgets.chip("them %d" % _score[1], Style.TEXT, "", "fight"))
	_hud.add_child(pips)
	_bar = _Bar.new()
	_bar.name = "StrikeBar"
	_bar.custom_minimum_size = Vector2(0, 64)
	_bar.zone = _zone / (CHARGE * 1.3)
	_bar.at = 1.0 / 1.3
	_hud.add_child(_bar)
	_strike = Button.new()
	_strike.name = "Strike"
	_strike.text = "Strike!"
	_strike.custom_minimum_size = Vector2(0, 120)
	_strike.add_theme_font_size_override("font_size", Style.text_size(36))
	Style.make_primary(_strike)
	_strike.button_down.connect(_on_strike)
	_hud.add_child(_strike)
	_hud.add_child(_note("Tap as the lances meet: dead on, the lance shatters."))
	_ride_it = Button.new()
	_ride_it.name = "LetItRide"
	_ride_it.text = "Let it ride (the dice decide)"
	_ride_it.flat = true
	_ride_it.custom_minimum_size = Vector2(0, Style.TOUCH)
	_ride_it.pressed.connect(_let_it_ride)
	_hud.add_child(_ride_it)
	_charge(CHARGE)


func _charge(length: float) -> void:
	_charge_len = length
	_t = 0.0
	_tapped = -1.0
	_near.galloping = true
	_far.galloping = true
	Sound.play("charge", -6.0, 0.05)
	if _strike != null:
		_strike.disabled = false


func _on_tap_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
		_on_strike()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_strike()
		get_viewport().set_input_as_handled()


func _on_strike() -> void:
	if not _yours or _t < 0.0 or _tapped >= 0.0 or _charge_len != CHARGE:
		return
	_tapped = _t
	if _strike != null:
		_strike.disabled = true
	if _bar != null:
		_bar.tap = _t / (CHARGE * 1.3)
		_bar.queue_redraw()


## For tests: strike at `seconds` from the start of this pass (or not at all, -1).
func strike_at(seconds: float) -> void:
	_tapped = seconds


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		_arena.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake if not _still else Vector2.ZERO
	if _t < 0.0:
		return
	_t += delta
	var p := _t / _charge_len
	_place_riders(pow(minf(p, 1.6), 1.15) if p < 1.0 else 1.0 + (p - 1.0) * 1.3)
	if _bar != null:
		_bar.needle = _t / (_charge_len * 1.3)
		_bar.queue_redraw()
	if p >= 1.0 and not _busy:
		_busy = true
		_impact()
	if p >= 1.55:
		_t = -1.0
		_busy = false
		_near.galloping = false
		_far.galloping = false
		_after_pass()


## The lances meet: how your strike landed, how theirs did, and the crowd.
var _pass_result := {}


func _impact() -> void:
	Sound.play("cav_impact", -2.0, 0.04)
	Sound.haptic(true)
	_shake = 1.0
	if not _yours:
		var a_wins := _rng.randf() < CrownCourt.lists_chance(_a, _b)
		_pass_result = {"auto": true, "a_wins": a_wins}
		var loser: Control = _far if a_wins else _near
		loser.unhorse()
		_near.break_lance()
		_far.break_lance()
		Sound.play("clash1", 0.0, 0.05)
		_show_stamp("%s!" % CrownCourt.entrant_name(_a if a_wins else _b), Color("f3d891"), 40)
		return
	var d := absf((_tapped if _tapped >= 0.0 else 99.0) - _charge_len)
	var q := 0
	if d <= _zone * 0.4:
		q = 2
	elif d <= _zone:
		q = 1
	var mine_e := _a if _you_are_a else _b
	var theirs := _b if _you_are_a else _a
	var edge := CrownCourt.lists_chance(mine_e, theirs)
	var roll := _rng.randf()
	var t := 0
	if roll < 0.3 + 0.35 * (1.0 - edge):
		t = 2 if _rng.randf() < 0.35 else 1
	var you_unhorse := q == 2 and _rng.randf() < 0.3 + 0.3 * edge
	var they_unhorse := t == 2 and _rng.randf() < 0.25 + 0.3 * (1.0 - edge)
	if you_unhorse and they_unhorse:
		you_unhorse = false
		they_unhorse = false
	_score[0] += q
	_score[1] += t
	_pass_result = {"q": q, "t": t, "you_unhorse": you_unhorse, "they_unhorse": they_unhorse}
	if q > 0:
		_near.break_lance()
		Sound.play("clash%d" % (1 + _rng.randi() % 3), 2.0, 0.05)
	if t > 0:
		_far.break_lance()
	if you_unhorse:
		_far.unhorse()
		Sound.play("cheer", 0.0, 0.03)
		_show_stamp("Unhorsed!", Color("8fe07a"))
	elif they_unhorse:
		_near.unhorse()
		Sound.play("gasp", 0.0, 0.03)
		_show_stamp("Struck down!", Color("ff9b8f"))
	elif q == 2:
		Sound.play("cheer", -3.0, 0.03)
		_show_stamp("Shattered!", Color("f3d891"))
	elif q == 1:
		_show_stamp("A hit", Style.TEXT)
	else:
		Sound.play("gasp", -6.0, 0.03)
		_show_stamp("Missed" if _tapped >= 0.0 else "Too slow", Style.MUTED)
	if t > 0 and not they_unhorse and not you_unhorse:
		_stamp.text += "  ·  struck" if q > 0 else ""
	_stands.cheer(1.0 if q == 2 or you_unhorse else 0.5)


func _show_stamp(text: String, tone: Color, size: int = 56) -> void:
	_stamp.text = text
	_stamp.add_theme_color_override("font_color", tone)
	_stamp.add_theme_font_size_override("font_size", Style.text_size(size))
	_stamp.modulate.a = 1.0
	if _still:
		return
	_stamp.scale = Vector2(1.4, 1.4)
	var t := _stamp.create_tween()
	t.tween_property(_stamp, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(_stamp, "modulate:a", 0.0, 0.3)


func _after_pass() -> void:
	if bool(_pass_result.get("auto", false)):
		_settle(1 if bool(_pass_result["a_wins"]) else 0, 0)
		return
	_pass += 1
	var you_win := -1
	if bool(_pass_result.get("you_unhorse", false)):
		you_win = 1
	elif bool(_pass_result.get("they_unhorse", false)):
		you_win = 0
	elif _pass >= PASSES:
		if _score[0] != _score[1]:
			you_win = 1 if _score[0] > _score[1] else 0
		else:
			var mine_e := _a if _you_are_a else _b
			var theirs := _b if _you_are_a else _a
			you_win = 1 if _rng.randf() < CrownCourt.lists_chance(mine_e, theirs) else 0
	if you_win < 0:
		_near.reset()
		_far.reset()
		_place_riders(0.0)
		var t := get_tree().create_timer(0.3 if _still else 0.5)
		t.timeout.connect(_ride_pass)
		return
	var a_wins := you_win if _you_are_a else 1 - you_win
	_settle(a_wins, mini(_pass - 1, 2))


## Leave the rest of this bout to the dice.
func _let_it_ride() -> void:
	if not _yours:
		return
	_t = -1.0
	_busy = false
	_settle(-1, -1)


## The bout is decided (`a_wins` 1/0, or -1 to the dice): the rules say who's through and
## whether the fallen rider is hurt.
func _settle(a_wins: int, at_pass: int) -> void:
	var r: Dictionary = CrownCourt.lists_bout(GameState, _a, _b, a_wins, at_pass)
	_lines.append(String(r["line"]))
	_next.append(r["won"])
	var yours_won: bool = r["won"].has("captain")
	_clear_hud()
	var won_l := Style.label("%s rides on" % CrownCourt.entrant_name(r["won"]), Style.LARGE, Color("f3d891") if yours_won else Style.TEXT)
	won_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Style.display_font() != null:
		won_l.add_theme_font_override("font", Style.display_font())
	_hud.add_child(won_l)
	_hud.add_child(_note(String(r["line"]), Style.TEXT))
	if bool(r.get("hurt", false)):
		_hud.add_child(_note("Carried from the lists, hurt: out of the next battles.", Style.ENEMY_LIGHT))
	if _yours:
		Sound.play("cheer" if (yours_won) else "gasp", -2.0, 0.03)
	var go := Button.new()
	go.name = "NextBout"
	go.text = "Next bout" if _bout < _round.size() - 1 or _next.size() + (_round.size() - _bout - 1) > 1 else "The champion"
	go.custom_minimum_size = Vector2(0, Style.TOUCH)
	Style.make_primary(go)
	go.pressed.connect(_next_bout)
	_hud.add_child(go)
	if not _yours:
		# Others' bouts carry on by themselves after a breath.
		var at_bout := _bout
		var at_round := _round_no
		var t := get_tree().create_timer(0.2 if _still else 0.9)
		t.timeout.connect(func():
			if is_inside_tree() and _bout == at_bout and _round_no == at_round and _t < 0.0 and _overlay == null:
				_next_bout())


## For tests: every bout left, to the dice, at once.
func ride_all_to_dice() -> void:
	while true:
		_bout += 1
		if _bout >= _round.size():
			_field = _next
			if _field.size() <= 1:
				break
			_start_round()
			continue
		var r: Dictionary = CrownCourt.lists_bout(GameState, _round[_bout][0], _round[_bout][1])
		_lines.append(String(r["line"]))
		_next.append(r["won"])
	_champion()


# ---------------------------------------------------------------- the champion

func _champion() -> void:
	_t = -1.0
	var winner: Dictionary = _field[0] if not _field.is_empty() else (_next[0] if not _next.is_empty() else {})
	if winner.is_empty():
		_leave()
		return
	var done: Dictionary = CrownCourt.lists_finish(GameState, winner, _lines, _mine, _lords)
	Sound.play("horn")
	Sound.play("cheer", 0.0, 0.03)
	Sound.haptic(true)
	_stands.cheer(1.0)
	_near.reset()
	_far.reset()
	_place_riders(0.0)
	var ours: bool = winner.has("captain")
	var o := Control.new()
	o.name = "Champion"
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(o)
	_overlay = o
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.07, 0.8)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(veil)
	var rays = load("res://scripts/ui/event_cards.gd")._Rays.new()
	rays.size = Vector2(_view.x, _view.y * 0.55)
	rays.still = _still
	o.add_child(rays)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_right = -28
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	o.add_child(col)
	var face := _face(winner, 200.0)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(face)
	var k := Style.label("CHAMPION OF THE %s" % String(CrownCourt.table(GameState).get("name", "lists")).to_upper(), Style.SMALL, Style.BRASS)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(k)
	var title := Style.label(CrownCourt.entrant_name(winner), Style.TITLE_SIZE, Color("f3d891"))
	title.name = "ChampionName"
	if Style.display_font() != null:
		title.add_theme_font_override("font", Style.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var said := Style.label(String(done.get("result", "")), Style.BODY, Style.TEXT)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(said)
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 10)
	if ours:
		tiles.add_child(Widgets.effect("silver", Gatherings.TOURNEY_PURSE))
		tiles.add_child(Widgets.effect("renown", Gatherings.TOURNEY_RENOWN))
	tiles.add_child(Widgets.effect("bond", Gatherings.TOURNEY_ENTRY_REGARD, " every lord"))
	col.add_child(tiles)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back to the hall"
	back.custom_minimum_size = Vector2(0, Style.TOUCH)
	Style.make_primary(back)
	back.pressed.connect(_leave)
	col.add_child(back)
	if not _still:
		face.pivot_offset = Vector2(100, 125)
		face.scale = Vector2(0.6, 0.6)
		face.modulate.a = 0.0
		var t := face.create_tween().set_parallel()
		t.tween_property(face, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(face, "modulate:a", 1.0, 0.3)


## A card in the middle, for nobody-to-ride.
func _say_card(title: String, text: String, buttons: Array) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_right = -28
	col.offset_top = _view.y * 0.55
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	var t := Style.label(title, Style.LARGE, Color("f3d891"))
	col.add_child(t)
	col.add_child(_note(text, Style.TEXT))
	for b in buttons:
		var btn := Button.new()
		btn.name = String(b[0])
		btn.text = String(b[0])
		btn.custom_minimum_size = Vector2(0, Style.TOUCH)
		if bool(b[2]):
			Style.make_primary(btn)
		btn.pressed.connect(b[1])
		col.add_child(btn)


func _leave() -> void:
	GameState.save_game()
	Scenes.lists_squads = []
	Scenes.go(Scenes.lists_return)


# ---------------------------------------------------------------- painted pieces

## The grandstand: a striped canopy, tiers of wood and the crowd on them, bobbing, and
## jumping when the lances break.
class _Stands extends Control:
	var cloth := Color.BLUE
	var trim := Color.DARK_BLUE
	var still := false
	var top := 0.0
	var _t := 0.0
	var _excite := 0.0
	var _crowd: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var tones := [Color("c8443c"), Color("4a74d1"), Color("d9962b"), Color("ece5d3"), Color("6fcf5a"), Color("8a5a9a"), Color("e8c547")]
		var skins := [Color("f1c8a0"), Color("d9a77a"), Color("a8714a"), Color("6e4a30")]
		var y0 := top + 150.0
		for row in 4:
			var y := y0 + row * 34.0
			var x := 8.0 + (row % 2) * 10.0
			while x < size.x - 8.0:
				_crowd.append({"x": x, "y": y, "c": tones[rng.randi() % tones.size()], "s": skins[rng.randi() % skins.size()], "ph": rng.randf() * TAU})
				x += 20.0 + rng.randf() * 6.0
		set_process(not still)

	func cheer(amount: float) -> void:
		_excite = maxf(_excite, amount)

	func _process(delta: float) -> void:
		_t += delta
		_excite = maxf(0.0, _excite - delta * 0.6)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		# Sky, then the stand, then the field.
		draw_rect(Rect2(0, 0, size.x, top + 140.0), Color("7fb0d8"))
		draw_rect(Rect2(0, top + 90.0, size.x, 60.0), Color("9cc4e4"))
		# Canopy, striped in the host's colours, with a scalloped edge.
		var cy := top + 118.0
		var sx := 0.0
		var i := 0
		while sx < size.x:
			draw_rect(Rect2(sx, top + 96.0, 36.0, 22.0), cloth if i % 2 == 0 else Color("ece5d3"))
			draw_circle(Vector2(sx + 18.0, cy), 18.0, cloth if i % 2 == 0 else Color("ece5d3"))
			sx += 36.0
			i += 1
		# The tiers.
		var ty := top + 140.0
		for row in 5:
			draw_rect(Rect2(0, ty + row * 34.0, size.x, 34.0), Color("6b4426") if row % 2 == 0 else Color("5a3820"))
			draw_rect(Rect2(0, ty + row * 34.0, size.x, 4.0), Color("8a5c34"))
		# The crowd: heads and shoulders, bobbing, jumping when roused.
		for p in _crowd:
			var bob := 0.0 if still else sin(_t * (2.0 + _excite * 9.0) + float(p["ph"])) * (1.5 + _excite * 7.0)
			var x: float = p["x"]
			var y: float = float(p["y"]) + bob
			draw_rect(Rect2(x, y + 8.0, 14.0, 14.0), p["c"])
			draw_rect(Rect2(x + 3.0, y, 8.0, 8.0), p["s"])
			if _excite > 0.4 and int(x) % 3 == 0:
				draw_rect(Rect2(x + 12.0, y - 6.0 + bob, 3.0, 10.0), p["s"])
		# A rail in the host's colours, then the field.
		var fy := ty + 5 * 34.0
		draw_rect(Rect2(0, fy - 8.0, size.x, 8.0), trim)
		draw_rect(Rect2(0, fy, size.x, h - fy), Color("c9a96a"))
		for k in 30:
			var gx := fmod(k * 97.0, size.x)
			var gy := fy + fmod(k * 53.0, maxf(1.0, h - fy))
			draw_rect(Rect2(gx, gy, 24.0, 3.0), Color("b8955a"))


## The tilt: the long barrier down the middle of the lists, posts and rail.
class _Tilt extends Control:
	var y := 0.0
	var cloth := Color.BLUE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, y - 26.0, size.x, 10.0), Color("8a5c34"))
		draw_rect(Rect2(0, y - 16.0, size.x, 4.0), Color("4a2e18"))
		var x := 10.0
		var i := 0
		while x < size.x:
			draw_rect(Rect2(x, y - 30.0, 8.0, 34.0), Color("6b4426"))
			draw_rect(Rect2(x, y - 34.0, 8.0, 6.0), cloth if i % 2 == 0 else Color("ece5d3"))
			x += 60.0
			i += 1


## A knight on a horse, couched lance forward, drawn in big square pixels: the horse in
## its caparison of the rider's colours, legs galloping, the lance breaking on a hit and
## the rider pitching off when unhorsed.
class _Rider extends Control:
	var k := 4.0
	var facing := 1
	var galloping := false
	var cloth := Color("4a74d1")
	var dark := Color("284282")
	var _t := 0.0
	var _broken := false
	var _fall := 0.0
	var _falling := false
	var _chips: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_colors(c: Color, d: Color) -> void:
		cloth = c
		dark = d
		queue_redraw()

	func reset() -> void:
		_broken = false
		_falling = false
		_fall = 0.0
		_chips.clear()
		galloping = false
		queue_redraw()

	func break_lance() -> void:
		if _broken:
			return
		_broken = true
		for i in 14:
			_chips.append({"p": Vector2(44, -33), "v": Vector2(randf_range(-30, 50), randf_range(-60, 10)), "life": randf_range(0.5, 1.0)})

	func unhorse() -> void:
		_falling = true

	func _process(delta: float) -> void:
		_t += delta
		if _falling:
			_fall = minf(1.0, _fall + delta * 2.2)
		for c in _chips:
			c["v"] = Vector2(c["v"].x, c["v"].y + 160.0 * delta)
			c["p"] = c["p"] + c["v"] * delta
			c["life"] = float(c["life"]) - delta
		_chips = _chips.filter(func(c): return float(c["life"]) > 0.0)
		queue_redraw()

	func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
		# In the rider's own pixels, facing right; mirrored when facing left.
		var rx := x if facing > 0 else -x - w
		draw_rect(Rect2(rx * k, y * k, w * k, h * k), c)

	func _draw() -> void:
		var step := int(_t * 10.0) % 2 if galloping else 0
		var horse := Color("6b4426")
		var horse_d := Color("4a2e18")
		# Legs, galloping.
		var lift := 2.0 if step == 1 else 0.0
		_px(-12, -12, 2, 12 - lift, horse_d)
		_px(-8, -12, 2, 12 - (2.0 - lift), horse_d)
		_px(6, -12, 2, 12 - (2.0 - lift), horse_d)
		_px(10, -12, 2, 12 - lift, horse_d)
		# Body, neck, head, tail.
		_px(-14, -22, 26, 10, horse)
		_px(10, -28, 4, 10, horse)
		_px(12, -31, 7, 5, horse)
		_px(17, -29, 2, 2, horse_d)
		_px(-17, -22, 3, 8, horse_d)
		# The caparison in the rider's colours.
		_px(-14, -19, 26, 9, cloth)
		_px(-14, -11, 26, 1, dark)
		_px(-6, -17, 4, 4, dark)
		# The rider, pitching back and off when unhorsed.
		var off := _fall * 14.0
		var up := _fall * 10.0
		_px(-4 - off, -36 - up + _fall * 18.0, 7, 14, cloth)
		_px(-3 - off, -42 - up + _fall * 18.0, 5, 6, Color("a8b0c0"))
		_px(-1 - off, -40 - up + _fall * 18.0, 3, 1, Color("1d2030"))
		_px(-2 - off, -44 - up + _fall * 18.0, 3, 2, dark)
		_px(1 - off, -34 - up + _fall * 18.0, 5, 8, dark)
		_px(2 - off, -32 - up + _fall * 18.0, 3, 3, Color("ece5d3"))
		# The lance, couched: whole, or a stump after a hit.
		if _fall < 0.2:
			var length := 14.0 if _broken else 42.0
			_px(2, -31, length, 2, Color("c8b080"))
			if not _broken:
				_px(34, -34, 6, 3, cloth)
		for c in _chips:
			var p: Vector2 = c["p"]
			_px(p.x, p.y, 2, 1, Color("e8dcb8"))


## The strike bar: the needle running to the meeting, and the zone to strike in.
class _Bar extends Control:
	var zone := 0.05
	var at := 0.77
	var needle := 0.0
	var tap := -1.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, h * 0.25, w, h * 0.5), Color("1f2846"))
		draw_rect(Rect2((at - zone) * w, h * 0.2, zone * 2.0 * w, h * 0.6), Color("8a6a2a"))
		draw_rect(Rect2((at - zone * 0.4) * w, h * 0.15, zone * 0.8 * w, h * 0.7), Color("f3d891"))
		if tap >= 0.0:
			draw_rect(Rect2(tap * w - 2.0, 0, 4.0, h), Color("8fe07a"))
		draw_rect(Rect2(clampf(needle, 0.0, 1.0) * w - 3.0, 0, 6.0, h), Color("ece5d3"))
