extends Control
## The map's news, dealt one card at a time, each drawn with the game's own art instead of
## a line in a box (GameState.map_cards says what each card is):
##
## - a place, painted as SettlementVista paints it: taken (its old banner comes down and
##   yours goes up), held, fallen, burning or under siege;
## - a lord in their own hall (HallScene), a lord's face over a place (a castle granted, a
##   fealty sworn to a king);
## - a fallen captain's memorial at the camp fire, a wounded one's face;
## - the realms' banners: two clashing for war, side by side for peace and alliance, one
##   alone for a contract or a crown at risk;
## - a deed, the company's banner in a burst of light.
##
## Big cards (a place taken or lost, a captain fallen, an oath, a war, a deed) take most of
## the screen, stamp in and hit with a sound and a buzz; the rest are smaller. Numbers count
## up. A tap on the picture finishes its animation; Next deals the next card, Skip all puts
## the deck away. Under Reduced motion it all holds still. Plain bookkeeping (taxes, a
## squad stationed) isn't dealt here: the map lists it on its own sheet afterwards.

signal finished
## Remember them: a fallen captain's card asks to open their stone at camp (by id).
signal remember(captain_id: int)

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const CampLife = preload("res://scripts/ui/camp_life.gd")
const HallScene = preload("res://scripts/ui/hall_scene.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const LordPortrait = preload("res://scripts/art/lord_portrait.gd")
const Data = preload("res://scripts/world/world_data.gd")

## What each kind of card is called over its title, its mark, and what it sounds like.
const KINDS := {
	"taken": ["Taken", "keep", "horn"],
	"walls_held": ["The walls held", "walls", "horn"],
	"place_lost": ["Fallen", "keep", "bell"],
	"assault_failed": ["The assault", "ladder", "bell"],
	"siege": ["The siege", "ram", "page"],
	"raid": ["The raid", "fire", "coins"],
	"crown_raised": ["A new crown", "crown", "horn"],
	"crown_fallen": ["The crown falls", "crown", "bell"],
	"crown_risk": ["Your crown", "crown", "alarm"],
	"deserted": ["Your court", "crown", "bell"],
	"alliance": ["An alliance", "bond", "bond_rank"],
	"peace": ["Peace", "peace", "bell"],
	"war": ["War", "fight", "horn"],
	"grant": ["Your court", "keep", "page"],
	"muster": ["The banners", "crown", "horn"],
	"deed": ["A deed to remember", "renown", "promotion"],
	"fealty": ["Sworn", "crown", "horn"],
	"renounce": ["Oath broken", "cancel", "bell"],
	"fief_lost": ["Your fief", "keep", "bell"],
	"fief_freed": ["Your fief", "keep", "horn"],
	"fief_burned": ["Your fief", "fire", "alarm"],
	"contract": ["Contract", "journal", "page"],
	"captain_wounded": ["The company", "wounded", "page"],
	"captain_fallen": ["Fallen", "skull", "captain_down"],
	"peace_broken": ["The peace is broken", "fight", "alarm"],
	"chief": ["The bounty", "skull", "coins"],
	"village_saved": ["Saved", "keep", "cheer"],
	"beaten": ["Defeat", "retreat", "bell"],
	"ransom": ["Prisoners", "lock", "coins"],
	"lord_said": ["After the battle", "talk", "page"],
}
const TONES := {"good": Color("8fe07a"), "bad": Color("ff9b8f"), "gold": Color("f3d891"), "": Color("f3d891")}

var deck: Array = []
var _i := -1
var _still := false
var _view := Vector2.ZERO
var _page: Control
var _art_box: Control
var _seq: Array = []
var _counter: Label
var _next: Button


## Which of `cards` are dealt as cards (the rest are bookkeeping, for the map's list), with
## a night's siege news for one place gathered onto one card, and what a battle's result
## card already said left out. Returns [deck, ledger].
static func split(cards: Array) -> Array:
	var out := []
	var ledger := []
	for c in cards:
		if bool(c.get("told", false)):
			continue
		var kind := String(c.get("kind", "note"))
		if kind in ["note", "ledger"] or not KINDS.has(kind):
			ledger.append(c)
			continue
		if kind == "siege":
			var same: Array = out.filter(func(o): return String(o.get("kind", "")) == "siege" and String(o.get("place", "")) == String(c.get("place", "")))
			if not same.is_empty():
				(same[0]["rows"] as Array).append([String(c.get("row", "ram")), String(c["text"]), String(c.get("tone", ""))])
				continue
			var first: Dictionary = c.duplicate(true)
			first["rows"] = [[String(c.get("row", "ram")), String(c["text"]), String(c.get("tone", ""))]]
			first["body"] = ""
			out.append(first)
			continue
		out.append(c)
	# The big news first, in the order it happened; then the rest.
	var big: Array = out.filter(func(c): return bool(c.get("big", false)))
	var small: Array = out.filter(func(c): return not bool(c.get("big", false)))
	return [big + small, ledger]


## Deal `cards` (from split) over `parent`, filling it.
static func open(parent: Control, cards: Array) -> Control:
	var e = load("res://scripts/ui/event_cards.gd").new()
	e.name = "EventCards"
	e.deck = cards
	parent.add_child(e)
	return e


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.make_theme()
	_still = Style.motion_reduced()
	_view = get_viewport_rect().size
	var veil := ColorRect.new()
	veil.name = "Veil"
	# Solid: the card is the whole screen while it's read.
	veil.color = Color(0.02, 0.03, 0.07, 1.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	# Escape (a phone's back gesture) deals the next card.
	veil.set_meta("close", next_card)
	add_child(veil)
	next_card()


## The card on show, for tests: its {kind, title, ...}.
func current() -> Dictionary:
	return deck[_i] if _i >= 0 and _i < deck.size() else {}


func next_card() -> void:
	_finish_seq()
	_i += 1
	if _page != null:
		var old := _page
		_page = null
		if _still:
			old.queue_free()
		else:
			var t := old.create_tween()
			t.tween_property(old, "modulate:a", 0.0, 0.15)
			t.tween_callback(old.queue_free)
	if _i >= deck.size():
		finished.emit()
		queue_free()
		return
	_show(deck[_i])


## The cards not yet dealt (after the one on show).
func remaining() -> Array:
	return deck.slice(_i + 1)


func skip_all() -> void:
	_i = deck.size() - 1
	next_card()


# ---------------------------------------------------------------- one card

func _show(c: Dictionary) -> void:
	var kind := String(c.get("kind", ""))
	var spec: Array = KINDS.get(kind, ["News", "journal", "page"])
	var big := bool(c.get("big", false))
	var insets: Dictionary = Style.safe_insets(get_viewport())
	_page = Control.new()
	_page.name = "Card_%d" % _i
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	# The picture: most of the screen for big news, a third for the rest.
	var art_h := roundf(_view.y * (0.5 if big else 0.34))
	_art_box = Control.new()
	_art_box.name = "Art"
	_art_box.clip_contents = true
	_art_box.position = Vector2.ZERO
	_art_box.size = Vector2(_view.x, art_h)
	_art_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_art_box.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_finish_seq())
	_page.add_child(_art_box)
	_build_art(c, _art_box)
	# Its foot fades into the card under it.
	var fade := _fade_strip(Vector2(_view.x, 140), art_h - 140)
	_page.add_child(fade)
	# What happened: a kicker, the headline, a line or two, the numbers.
	var col := VBoxContainer.new()
	col.name = "Words"
	col.position = Vector2(28, art_h - 34)
	col.size = Vector2(_view.x - 56, 0)
	# Wrapped words measure tall until they know their width: settle the column's height
	# (never its width) whenever what it holds is measured again.
	var w := _view.x - 56
	var settle := func():
		if is_instance_valid(col):
			col.size = Vector2(w, 0)
	col.minimum_size_changed.connect(settle.call_deferred)
	settle.call_deferred()
	col.add_theme_constant_override("separation", 14)
	_page.add_child(col)
	var tone: Color = TONES.get(String(c.get("tone", "")), TONES[""])
	var kick := HBoxContainer.new()
	kick.add_theme_constant_override("separation", 10)
	var mark := Widgets.icon_rect(String(spec[1]), 30)
	mark.modulate = Style.BRASS
	kick.add_child(mark)
	var kl := Style.label(String(spec[0]).to_upper(), Style.SMALL, Style.BRASS)
	kl.name = "Kicker"
	kick.add_child(kl)
	var rule := ColorRect.new()
	rule.color = Color(Style.BRASS, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kick.add_child(rule)
	col.add_child(kick)
	var title := Style.label(String(c.get("title", "")), Style.TITLE_SIZE if big else Style.LARGE + 4, tone)
	title.name = "CardTitle"
	if Style.display_font() != null:
		title.add_theme_font_override("font", Style.display_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 6)
	col.add_child(title)
	var body_text := String(c.get("body", c.get("text", "")))
	if body_text != "":
		var body := Style.label(body_text, Style.BODY, Style.TEXT)
		body.name = "CardBody"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(body)
	for r in c.get("rows", []):
		col.add_child(_row(String(r[0]), String(r[1]), String(r[2]) if r.size() > 2 else ""))
	if String(c.get("aside", "")) != "":
		var aside := Style.label(String(c["aside"]), Style.SMALL, Style.MUTED)
		aside.name = "CardAside"
		aside.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(aside)
	var tiles: Array = c.get("tiles", [])
	if not tiles.is_empty():
		var tr := HFlowContainer.new()
		tr.name = "CardTiles"
		tr.add_theme_constant_override("h_separation", 10)
		tr.add_theme_constant_override("v_separation", 10)
		for t in tiles:
			var chip := Widgets.effect(String(t[0]), int(t[1]), String(t[2]) if t.size() > 2 else "")
			tr.add_child(chip)
			_count_chip(chip, int(t[1]))
		col.add_child(tr)
	var reactions: Array = c.get("reactions", [])
	if not reactions.is_empty():
		for r in reactions:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var n := Style.label(String(r[0]), Style.SMALL, Style.TEXT)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			h.add_child(Widgets.effect("bond", int(r[1])))
			col.add_child(h)
	# The buttons keep to the foot of the screen, whatever the words above them do.
	var foot := HBoxContainer.new()
	foot.name = "CardFoot"
	foot.add_theme_constant_override("separation", 12)
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 28.0
	foot.offset_right = -28.0
	foot.offset_bottom = -float(insets.get("bottom", 0.0)) - 24.0
	foot.offset_top = foot.offset_bottom - Style.TOUCH
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_page.add_child(foot)
	if deck.size() > 2 and _i < deck.size() - 1:
		var skip := Button.new()
		skip.name = "SkipAll"
		skip.text = "Skip all"
		skip.flat = true
		skip.custom_minimum_size = Vector2(150, Style.TOUCH)
		skip.pressed.connect(skip_all)
		foot.add_child(skip)
	_counter = Style.label("%d of %d" % [_i + 1, deck.size()] if deck.size() > 1 else "", Style.SMALL, Style.MUTED)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(_counter)
	if String(c.get("kind", "")) == "captain_fallen" and int(c.get("id", -1)) >= 0:
		var rem := Button.new()
		rem.name = "RememberThem"
		rem.text = "Remember"
		rem.custom_minimum_size = Vector2(170, Style.TOUCH)
		rem.pressed.connect(func(): remember.emit(int(c["id"])))
		foot.add_child(rem)
	_next = Button.new()
	_next.name = "CardNext"
	_next.text = "Next" if _i < deck.size() - 1 else "Carry on"
	_next.custom_minimum_size = Vector2(240, Style.TOUCH)
	Style.make_primary(_next)
	_next.pressed.connect(next_card)
	foot.add_child(_next)
	_enter(c, col, title, big)


func _row(icon_key: String, text: String, tone: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var ic := Widgets.icon_rect(icon_key, 34)
	ic.modulate = Color("8fe07a") if tone == "good" else (Color("ff9b8f") if tone == "bad" else Style.BRASS)
	h.add_child(ic)
	var l := Style.label(text, Style.BODY - 2, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(10, 0)
	h.add_child(l)
	return h


## A strip that darkens from clear to the card's ground, `h` tall at `y`.
func _fade_strip(sz: Vector2, y: float) -> Control:
	var f := Control.new()
	f.position = Vector2(0, y)
	f.size = sz
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.draw.connect(func():
		var clear := Color(0.02, 0.03, 0.07, 0.0)
		var dark := Color(0.02, 0.03, 0.07, 0.95)
		f.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]),
			PackedColorArray([clear, clear, dark, dark])))
	return f


## The card comes in: the words rise, the title stamps on big news, the sound, the buzz.
func _enter(c: Dictionary, col: Control, title: Control, big: bool) -> void:
	var spec: Array = KINDS.get(String(c.get("kind", "")), ["", "", "page"])
	if String(c.get("kind", "")) == "war":
		Sound.play_war_horn()
	else:
		Sound.play(String(spec[2]), 0.0, 0.03)
	if String(c.get("kind", "")) in ["taken", "walls_held", "deed", "village_saved"]:
		Sound.play("cheer", -6.0, 0.03)
	if big:
		Sound.haptic(true)
	if _still:
		return
	col.modulate.a = 0.0
	var y0 := col.position.y
	col.position.y = y0 + 40.0
	var t := col.create_tween().set_parallel()
	t.tween_property(col, "modulate:a", 1.0, 0.25).set_delay(0.12)
	t.tween_property(col, "position:y", y0, 0.35).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_seq.append(t)
	if big:
		title.pivot_offset = Vector2(0, 30)
		title.scale = Vector2(1.18, 1.18)
		var st := title.create_tween()
		st.tween_interval(0.25)
		st.tween_property(title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_seq.append(st)
	# The picture settles in slowly while it's read.
	var inner := _art_box.get_child(0) as Control if _art_box.get_child_count() > 0 else null
	if inner != null:
		inner.pivot_offset = inner.size * 0.5
		inner.scale = Vector2(1.06, 1.06)
		var kb := inner.create_tween()
		kb.tween_property(inner, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A tile's number counts up from nothing.
func _count_chip(chip: Control, n: int) -> void:
	if _still or absi(n) < 2:
		return
	var label: Label = null
	for l in chip.find_children("*", "Label", true, false):
		label = l
	if label == null:
		return
	var text := label.text
	var lead := text.substr(0, 1) if not text.substr(0, 1).is_valid_int() else ""
	var tail := ""
	var digits := text.substr(lead.length())
	var k := 0
	while k < digits.length() and (digits[k].is_valid_int() or digits[k] == ","):
		k += 1
	tail = digits.substr(k)
	var t := label.create_tween()
	t.tween_interval(0.45)
	t.tween_method(func(v: float):
		if is_instance_valid(label):
			label.text = lead + Widgets.thousands(int(round(v))) + tail, 0.0, float(absi(n)), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if is_instance_valid(label):
			label.text = text)
	_seq.append(t)


func _finish_seq() -> void:
	for t in _seq:
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).custom_step(30.0)
	_seq.clear()


# ---------------------------------------------------------------- the pictures

func _build_art(c: Dictionary, box: Control) -> void:
	var sz := box.size
	var kind := String(c.get("kind", ""))
	if kind == "captain_fallen" or kind == "captain_wounded":
		_memorial(c, box, kind == "captain_fallen")
		return
	if kind == "deed":
		_deed(c, box)
		return
	if kind == "chief":
		_banners(box, ["bandits"], "alone", String(c.get("tone", "")) == "good")
		return
	if c.has("place") and Data.SETTLEMENTS.has(String(c["place"])):
		_place(c, box)
		if c.has("face"):
			_face_over(c, box)
		return
	if c.has("face"):
		_lord_in_hall(c, box)
		return
	var banners: Array = c.get("banners", [])
	if not banners.is_empty():
		var how := "alone"
		if kind == "war" or kind == "peace_broken":
			how = "clash"
		elif banners.size() > 1:
			how = "together"
		elif kind in ["crown_fallen", "renounce", "deserted"]:
			how = "falls"
		_banners(box, banners, how, kind != "crown_risk")
		return
	var sky := _sky(sz, Color("1a2240"), Color("0b0f1c"))
	box.add_child(sky)


## A vista of the place, covering the box. With `was`, it first flies the old banner; the
## old flag drops and the new one rises, and the vista changes under it.
func _place(c: Dictionary, box: Control) -> void:
	var id := String(c["place"])
	var world = GameState.world
	var params: Dictionary = SettlementScene.params(world, id)
	var owner := String(c.get("owner", params["owner"]))
	var was := String(c.get("was", ""))
	if not SettlementScene.BANNER.has(owner):
		owner = "bandits"
	match String(c.get("cond", "")):
		"besieged":
			params["condition"] = "besieged"
			params["besieger"] = String(Data.realm_of_culture(GameState.culture)) if GameState.culture != "" else "bandits"
			if GameState.is_crowned():
				params["besieger"] = Data.CROWN
		"burning", "raided":
			params["condition"] = "raided" if String(params["kind"]) == Data.VILLAGE else "healthy"
	params["player"] = ""
	var holder := Control.new()
	holder.name = "Scene"
	holder.size = box.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	var after := _vista(params, owner, box.size)
	holder.add_child(after)
	if was != "" and was != owner and SettlementScene.BANNER.has(was):
		var before := _vista(params, was, box.size)
		holder.add_child(before)
		_banner_swap(box, was, owner, before)
	elif String(c.get("tone", "")) == "bad" and String(c.get("kind", "")) in ["place_lost", "fief_lost"]:
		_banner_swap(box, String(Data.realm_of_culture(GameState.culture)) if not GameState.is_crowned() else Data.CROWN, owner, null)
	else:
		var flag_realm := owner
		var flag := Widgets.banner(flag_realm, Vector2(120, 170))
		flag.position = Vector2(box.size.x - 150, 24)
		box.add_child(flag)
	if String(c.get("cond", "")) in ["burning", "raided"] or String(c.get("kind", "")) in ["fief_burned", "raid"]:
		var fire := _Fire.new()
		fire.name = "Fire"
		fire.size = box.size
		fire.still = _still
		box.add_child(fire)
	if String(c.get("tone", "")) == "bad":
		var wash := ColorRect.new()
		wash.color = Color(0.45, 0.05, 0.04, 0.18)
		wash.size = box.size
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(wash)


func _vista(params: Dictionary, owner: String, sz: Vector2) -> Control:
	var p := params.duplicate(true)
	p["owner"] = owner
	# Painted as wide as it needs to be to cover the box, its foot on the box's foot.
	var w := maxf(sz.x, sz.y * SettlementScene.W / SettlementScene.H)
	var v = SettlementVista.from_preset(p, sz.y)
	v.size = Vector2(w, sz.y)
	v.position = Vector2((sz.x - w) * 0.5, 0)
	v.custom_minimum_size = Vector2(0, 0)
	v.visible = true
	return v


## The old banner comes down and the new one goes up; the place under it changes hands.
func _banner_swap(box: Control, was: String, now: String, before: Control) -> void:
	var fsz := Vector2(130, 190)
	var old := Widgets.banner(was, fsz)
	old.name = "OldBanner"
	old.position = Vector2(box.size.x - 160, 20)
	old.pivot_offset = Vector2(fsz.x * 0.5, 0)
	box.add_child(old)
	var rise := Widgets.banner(now, fsz)
	rise.name = "NewBanner"
	rise.position = Vector2(box.size.x - 160, 20)
	rise.pivot_offset = Vector2(fsz.x * 0.5, 0)
	box.add_child(rise)
	if _still:
		old.visible = false
		if before != null:
			before.visible = false
		return
	rise.scale = Vector2(1, 0)
	var t := box.create_tween()
	t.tween_interval(0.7)
	t.tween_property(old, "position:y", box.size.y * 0.7, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(old, "rotation", 0.3, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(old, "modulate:a", 0.0, 0.6)
	if before != null:
		t.parallel().tween_property(before, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.tween_callback(Sound.play.bind("horn", -4.0, 0.03))
	t.tween_property(rise, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_seq.append(t)


## A lord's face over the place: framed, bottom left, with their name.
func _face_over(c: Dictionary, box: Control) -> void:
	var tex: Texture2D = CaptainArt.texture(c["face"], String(c.get("mood", "")))
	if tex == null:
		return
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w := minf(200.0, box.size.y * 0.5)
	var f := Widgets.framed(pic, Vector2(w, w * 1.25))
	f.name = "Face"
	f.position = Vector2(24, box.size.y - w * 1.25 - 60)
	box.add_child(f)
	if not _still:
		f.modulate.a = 0.0
		var t := f.create_tween()
		t.tween_interval(0.3)
		t.tween_property(f, "modulate:a", 1.0, 0.35)
		_seq.append(t)


## A lord standing in their own hall, close up, with their banner behind.
func _lord_in_hall(c: Dictionary, box: Control) -> void:
	var rec: Dictionary = c["face"]
	var realm := String(c.get("realm", rec.get("realm", "vardmark")))
	var culture := String(rec.get("culture", Data.culture_of(realm) if Data.FACTIONS.has(realm) else "vardish"))
	var hall := HallScene.rect(culture, realm if HallScene.BANNERS.has(realm) else "vardmark", "dusk", hash(realm))
	hall.size = box.size
	hall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(hall)
	var img: Image = LordPortrait.image(rec, false, String(c.get("mood", ""))) if LordPortrait.available() and Style.illustrations_on() else null
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null else CaptainArt.texture(rec, String(c.get("mood", "")))
	if tex == null:
		return
	var pic := TextureRect.new()
	pic.name = "Face"
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var h := box.size.y * 0.92
	pic.size = Vector2(h * 0.75, h)
	pic.position = Vector2((box.size.x - pic.size.x) * 0.5, box.size.y - h + 10)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	if not _still:
		pic.position.y += 30
		pic.modulate.a = 0.0
		var t := pic.create_tween().set_parallel()
		t.tween_property(pic, "position:y", pic.position.y - 30, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(pic, "modulate:a", 1.0, 0.3)
		_seq.append(t)


## The fire at the camp, low, and the captain's face in its light: fallen, eyes shut and
## the colour gone out of the frame; or hurt.
func _memorial(c: Dictionary, box: Control, fallen: bool) -> void:
	var camp := TextureRect.new()
	camp.texture = load("res://assets/locations/company_camp.png") as Texture2D
	camp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	camp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	camp.size = box.size
	camp.modulate = Color(0.45, 0.42, 0.5) if fallen else Color(0.75, 0.72, 0.78)
	box.add_child(camp)
	CampLife.over(camp)
	var dark := ColorRect.new()
	dark.color = Color(0.02, 0.03, 0.07, 0.45 if fallen else 0.25)
	dark.size = box.size
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dark)
	var rec = c.get("captain", {})
	var tex: Texture2D = CaptainArt.texture(rec, "/shut" if fallen else "pain") if typeof(rec) == TYPE_DICTIONARY and not (rec as Dictionary).is_empty() else null
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var w := minf(260.0, box.size.y * 0.55)
		var f := Widgets.framed(pic, Vector2(w, w * 1.25), fallen)
		f.name = "Face"
		f.position = Vector2((box.size.x - w) * 0.5, (box.size.y - w * 1.25) * 0.45)
		box.add_child(f)
		if not _still:
			f.modulate.a = 0.0
			var t := f.create_tween()
			t.tween_interval(0.2)
			t.tween_property(f, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
			_seq.append(t)
	# Their battles, under the face.
	var bits := PackedStringArray()
	if int(c.get("battles", 0)) > 0:
		bits.append("%d battle%s" % [int(c["battles"]), "" if int(c["battles"]) == 1 else "s"])
	if int(c.get("kills", 0)) > 0:
		bits.append("%d foes" % int(c["kills"]))
	if String(c.get("company", "")) != "":
		bits.append(String(c["company"]))
	if not bits.is_empty():
		var l := Style.label(" · ".join(bits), Style.SMALL, Color("e8d9b0"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(0, box.size.y - 120)
		l.size = Vector2(box.size.x, 36)
		box.add_child(l)


## A deed: the company's banner in a slow burst of light.
func _deed(c: Dictionary, box: Control) -> void:
	box.add_child(_sky(box.size, Color("2a1f0c"), Color("0b0f1c")))
	var rays := _Rays.new()
	rays.size = box.size
	rays.still = _still
	box.add_child(rays)
	var realm := Data.CROWN if GameState.is_crowned() else String(Data.realm_of_culture(GameState.culture))
	var fsz := Vector2(170, 240)
	var flag := Widgets.banner(realm, fsz)
	flag.position = Vector2((box.size.x - fsz.x) * 0.5, (box.size.y - fsz.y) * 0.4)
	flag.pivot_offset = Vector2(fsz.x * 0.5, 0)
	box.add_child(flag)
	if not _still:
		flag.scale = Vector2(1, 0)
		var t := flag.create_tween()
		t.tween_interval(0.25)
		t.tween_property(flag, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_seq.append(t)


## Realms' banners under a night sky: clashing in from the sides for war, side by side for
## peace or an alliance, one alone (and falling, for a crown lost or an oath broken).
func _banners(box: Control, realms: Array, how: String, lit: bool) -> void:
	var war := how == "clash"
	box.add_child(_sky(box.size, Color("3a1412") if war else Color("1c2648"), Color("0b0f1c")))
	var hills := _Hills.new()
	hills.size = box.size
	box.add_child(hills)
	var fsz := Vector2(200, 290) if box.size.y > 400.0 else Vector2(150, 220)
	var n := realms.size()
	var y := (box.size.y - fsz.y) * 0.42
	for i in n:
		var realm := String(realms[i])
		var flag := Widgets.banner(realm, fsz)
		flag.name = "Banner_%s" % realm
		var x := (box.size.x - fsz.x) * 0.5
		if n > 1:
			x = box.size.x * (0.3 if i == 0 else 0.7) - fsz.x * 0.5
		flag.position = Vector2(x, y)
		flag.pivot_offset = Vector2(fsz.x * 0.5, 0)
		box.add_child(flag)
		if _still:
			if how == "falls":
				flag.modulate.a = 0.35
			continue
		match how:
			"clash":
				var from := -fsz.x - 40.0 if i == 0 else box.size.x + 40.0
				flag.position.x = from
				flag.rotation = -0.25 if i == 0 else 0.25
				var t := flag.create_tween().set_parallel()
				t.tween_property(flag, "position:x", x + (24.0 if i == 0 else -24.0), 0.45).set_delay(0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
				t.tween_property(flag, "rotation", 0.0, 0.45).set_delay(0.15)
				t.chain().tween_property(flag, "position:x", x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_seq.append(t)
				if i == 0:
					var flash := ColorRect.new()
					flash.color = Color(1.0, 0.75, 0.6, 0.0)
					flash.size = box.size
					flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
					box.add_child(flash)
					var ft := flash.create_tween()
					ft.tween_interval(0.6)
					ft.tween_callback(Sound.play.bind("cav_impact", -2.0, 0.03))
					ft.tween_property(flash, "color:a", 0.35, 0.05)
					ft.tween_property(flash, "color:a", 0.0, 0.4)
					_seq.append(ft)
			"together":
				flag.position.x = x + (-60.0 if i == 0 else 60.0)
				flag.modulate.a = 0.0
				var t := flag.create_tween().set_parallel()
				t.tween_property(flag, "position:x", x, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				t.tween_property(flag, "modulate:a", 1.0, 0.4)
				_seq.append(t)
			"falls":
				var t := flag.create_tween()
				t.tween_interval(0.6)
				t.tween_property(flag, "position:y", box.size.y * 0.75, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				t.parallel().tween_property(flag, "rotation", 0.25, 0.8)
				t.parallel().tween_property(flag, "modulate:a", 0.25, 0.8)
				_seq.append(t)
			_:
				flag.scale = Vector2(1, 0)
				var t := flag.create_tween()
				t.tween_interval(0.2)
				t.tween_property(flag, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_seq.append(t)
	if how == "together" and lit:
		var glow := _Glow.new()
		glow.size = box.size
		glow.still = _still
		box.add_child(glow)


func _sky(sz: Vector2, top: Color, bottom: Color) -> Control:
	var s := _Sky.new()
	s.size = sz
	s.top = top
	s.bottom = bottom
	s.still = _still
	return s


# ---------------------------------------------------------------- small painted things

## A gradient sky with stars that twinkle.
class _Sky extends Control:
	var top := Color.BLACK
	var bottom := Color.BLACK
	var still := false
	var _t := 0.0
	var _stars: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 50:
			_stars.append(Vector3(rng.randf() * size.x, rng.randf() * size.y * 0.6, rng.randf() * TAU))
		set_process(not still)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))
		for s in _stars:
			var a := 0.35 + 0.35 * sin(_t * 1.7 + s.z)
			draw_rect(Rect2(s.x, s.y, 3, 3), Color(1, 1, 0.92, a))


## Dark hills along the foot of the picture.
class _Hills extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for layer in [[0.72, Color("1a1f30"), 0.9], [0.82, Color("10141f"), 1.7]]:
			var pts := PackedVector2Array([Vector2(0, size.y)])
			var base: float = size.y * float(layer[0])
			for i in 25:
				var x := size.x * i / 24.0
				pts.append(Vector2(x, base + sin(i * float(layer[2])) * 18.0 + sin(i * 0.55) * 26.0))
			pts.append(Vector2(size.x, size.y))
			draw_colored_polygon(pts, layer[1])


## Embers rising off a burning place, and the glow of the fire along its foot.
class _Fire extends Control:
	var still := false
	var _t := 0.0
	var _sparks: Array = []
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.seed = 5
		for i in 60:
			_sparks.append(Vector4(_rng.randf() * size.x, _rng.randf(), _rng.randf_range(0.15, 0.4), _rng.randf() * TAU))
		set_process(not still)

	func _process(delta: float) -> void:
		_t += delta
		for i in _sparks.size():
			var s: Vector4 = _sparks[i]
			s.y += delta * s.z
			if s.y > 1.0:
				s = Vector4(_rng.randf() * size.x, 0.0, _rng.randf_range(0.15, 0.4), _rng.randf() * TAU)
			_sparks[i] = s
		queue_redraw()

	func _draw() -> void:
		var flick := 1.0 if still else 0.85 + 0.15 * sin(_t * 9.0)
		var h := size.y * 0.45
		draw_polygon(PackedVector2Array([Vector2(0, size.y - h), Vector2(size.x, size.y - h), size, Vector2(0, size.y)]),
			PackedColorArray([Color(1, 0.4, 0.1, 0.0), Color(1, 0.4, 0.1, 0.0), Color(1, 0.35, 0.1, 0.38 * flick), Color(1, 0.35, 0.1, 0.38 * flick)]))
		if still:
			return
		for sp in _sparks:
			var s: Vector4 = sp
			var y := size.y * (1.0 - s.y)
			var x := s.x + sin(_t * 2.0 + s.w) * 14.0 * s.y
			var a := (1.0 - s.y) * 0.9
			draw_rect(Rect2(x, y, 4, 4), Color(1.0, lerpf(0.85, 0.4, s.y), 0.25, a))


## Slow rays of light turning behind a deed's banner.
class _Rays extends Control:
	var still := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(not still)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var r := maxf(size.x, size.y)
		for i in 16:
			var a := _t * 0.15 + i * TAU / 16.0
			var b := a + TAU / 40.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(b), sin(b)) * r]),
				Color(1.0, 0.82, 0.4, 0.08))
		for ring in [[220.0, 0.08], [140.0, 0.12], [80.0, 0.16]]:
			draw_circle(c, float(ring[0]), Color(1.0, 0.8, 0.4, float(ring[1])))


## A warm glow between two banners that stand together.
class _Glow extends Control:
	var still := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(not still)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.45)
		var b := 1.0 if still else 0.8 + 0.2 * sin(_t * 1.6)
		for ring in [[160.0, 0.06], [100.0, 0.09], [50.0, 0.12]]:
			draw_circle(c, float(ring[0]), Color(1.0, 0.85, 0.5, float(ring[1]) * b))
