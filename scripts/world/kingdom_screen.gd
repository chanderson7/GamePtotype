## Your crown, all on one screen: its name and colour, treasury and income, the road to
## holding every capital; its castles, towns and villages with their garrisons and who
## holds them; your sworn lords with their Regard and your orders; and the other realms,
## at war or at peace, with the terms of peace, a declaration of war and a call to arms.
## The rules are in GameState; this only shows them and asks.
extends Control

const Data = preload("res://scripts/world/world_data.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const Lords = preload("res://scripts/data/lords.gd")
const CourtUI = preload("res://scripts/ui/court_ui.gd")

signal closed
## Asked of the map: look at a place.
signal wants_place(id: String)

var gs = null
var world = null
var tab := "realm"
var _col: VBoxContainer
var _scroll: ScrollContainer
var _flash := ""
## The Court tab's choices: what kind of gathering and where, who to ask; where to call the
## banners; at the council, the aim and who leads.
var _host_kind := 0
var _host_place := ""
var _host_ask := {"friends": true, "persuade": true, "lieges": false}
var _muster_place := ""
var _aim := ""
var _you_lead := true
## Which place list is open ("Host", "Muster" or ""), whether the "⋯" menu is open, and
## which lord speaks at the council.
var _place_open := ""
var _menu_open := false
var _council_lord := -1
## A bar under the page that stays put while it scrolls (the council's March), the
## phone's safe area, and the page last drawn (to keep its scroll on a rebuild).
var _footer: Control = null
var _insets := {}
var _built_tab := ""

const PAGES := ["gathering", "banners", "council"]


static func open(parent: Node, game, start_tab: String = "realm"):
	var k = new()
	k.gs = game
	k.world = game.world
	k.tab = start_tab
	k.name = "Kingdom"
	parent.add_child(k)
	return k


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	# A rebuild of the same page keeps its place: a switch flipped halfway down stays in view.
	var keep := -1
	if _scroll != null and is_instance_valid(_scroll) and _built_tab == tab:
		keep = _scroll.scroll_vertical
	if tab == "council" and not bool(CrownCourt.council_check(gs)["ok"]):
		tab = "banners" if not gs.muster.is_empty() else "court"
	_built_tab = tab
	_footer = null
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var insets: Dictionary = Style.safe_insets(get_viewport())
	_insets = insets
	var root := VBoxContainer.new()
	root.name = "Page"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_draw_page(insets)
	if _footer != null:
		root.add_child(_footer)
		(_scroll.get_child(0) as MarginContainer).add_theme_constant_override("margin_bottom", 24)
	if keep > 0:
		var s := _scroll
		get_tree().process_frame.connect(func():
			if is_instance_valid(s):
				s.scroll_vertical = keep, CONNECT_ONE_SHOT)


func _draw_page(insets: Dictionary) -> void:
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 28 + int(insets.get("top", 0)))
	pad.add_theme_constant_override("margin_bottom", 40 + int(insets.get("bottom", 0)))
	_scroll.add_child(pad)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 16)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_col)
	if not gs.is_crowned():
		_head()
		_col.add_child(_note("You have no crown. Hold a castle or a town as your seat, and raise your banner there."))
		return
	match tab:
		"gathering":
			_gathering_page()
			return
		"banners":
			_banners_page()
			return
		"council":
			_council()
			return
	_head()
	if _flash != "":
		_col.add_child(_card_note(_flash, Style.BRASS))
		_flash = ""
	_col.add_child(Widgets.tab_bar([
		{"id": "realm", "label": "Realm", "badge": 0},
		{"id": "holdings", "label": "Holdings", "badge": 0},
		{"id": "lords", "label": "Lords", "badge": 0},
		{"id": "court", "label": "Court", "badge": CrownCourt.petitions(gs).size() + (1 if CrownCourt.council_check(gs)["ok"] else 0)},
		{"id": "diplomacy", "label": "Diplomacy", "badge": world.crown_enemies().size()},
	], tab, _on_tab, "KingdomTabs"))
	match tab:
		"holdings":
			_holdings()
		"lords":
			_lords()
		"court":
			_court()
		"diplomacy":
			_diplomacy()
		_:
			_realm()


func _on_tab(id: String) -> void:
	tab = id
	_build()


func _head() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var flag := Widgets.banner("crown", Vector2(64, 80))
	flag.name = "CrownBanner"
	row.add_child(flag)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Style.label(Data.title_case(gs.crown_title()) if gs.is_crowned() else "Your Crown", Style.LARGE, Data.crown_color)
	title.name = "CrownTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var display := Style.display_font()
	if display != null:
		title.add_theme_font_override("font", display)
	words.add_child(title)
	if gs.is_crowned():
		var seat: String = world.capital_of(Data.CROWN)
		words.add_child(Style.label("Seat: %s%s" % [Data.settlement(seat)["name"] if seat != "" else "none", " · Victorious" if gs.crown_won else ""], Style.SMALL, Style.MUTED))
	row.add_child(words)
	var x := Button.new()
	x.name = "Close"
	x.icon = Widgets.icon("cancel")
	x.expand_icon = true
	x.custom_minimum_size = Vector2(64, 64)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(close)
	row.add_child(x)
	_col.add_child(row)


func close() -> void:
	closed.emit()
	queue_free()


func _note(text: String, color: Color = Style.MUTED, size_px: int = Style.SMALL) -> Label:
	var l := Style.label(text, size_px, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _card_note(text: String, tone: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Flash"
	p.add_theme_stylebox_override("panel", Style.box(Color(tone, 0.12), Color(tone, 0.6), 2, 12))
	p.add_child(_note(text, tone.lightened(0.3)))
	return p


func _button(text: String, act: Callable, id: String, enabled: bool = true, primary: bool = false) -> Button:
	var b := Button.new()
	b.name = id
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	if primary and enabled:
		Style.make_primary(b)
	b.pressed.connect(func():
		Sound.play("click", 0.0, 0.05)
		act.call())
	return b


func _row_panel(tone: Color = Style.RULE) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(Style.PANEL, tone, 2, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_col.add_child(p)
	return v


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	return f


func _act(ok: bool, message: String) -> void:
	if ok:
		_flash = message
	_build()


# ---------------------------------------------------------------- realm

func _realm() -> void:
	var income: Dictionary = gs.crown_income()
	var held: Array = gs.crown_holdings()
	var men := 0
	for l in gs.crown_lords():
		var p = world.party(int(l.get("party", -1)))
		men += world.men_of(p.army) if p != null else world.men_of(l.get("army", []))
	for id in held:
		men += world.men_of(world.garrison_at(id))
	_col.add_child(Widgets.tile_grid([
		Widgets.tile("silver", Widgets.thousands(gs.crown_treasury()), "treasury, +%d/day" % int(income["treasury"])),
		Widgets.tile("silver", "+%d" % int(income["purse"]), "purse/day"),
		Widgets.tile("battle", str(held.size()), "places"),
		Widgets.tile("men", Widgets.thousands(men), "men"),
	]))
	# The treasury: the garrisons and your lords' men are paid from it.
	var t := _row_panel()
	t.add_child(Style.label("Treasury", Style.BODY, Style.TEXT))
	t.add_child(_note("Pays your lords' men and raises your garrisons. Draw from it and your lords notice (%d Regard each)." % gs.DRAW_REGARD))
	var f := _flow()
	f.add_child(_button("Draw %d" % gs.TREASURY_STEP, func(): _act(gs.draw_treasury(gs.TREASURY_STEP), "You drew %d silver." % gs.TREASURY_STEP),
		"Draw", gs.crown_treasury() >= gs.TREASURY_STEP))
	f.add_child(_button("Pay in %d" % gs.TREASURY_STEP, func(): _act(gs.fund_treasury(gs.TREASURY_STEP), "You paid %d silver into the treasury." % gs.TREASURY_STEP),
		"Fund", gs.silver >= gs.TREASURY_STEP))
	t.add_child(f)
	# The goal.
	var g := _row_panel(Data.crown_color if gs.crown_won else Style.RULE)
	var caps: Array = gs.crown_capitals()
	var have: int = caps.filter(func(id): return held.has(id)).size()
	g.add_child(Style.label("Every capital: %d of %d" % [have, caps.size()], Style.BODY, Style.TEXT))
	g.add_child(Widgets.meter(float(have) / caps.size(), Data.crown_color, 12.0))
	g.add_child(_note(", ".join(PackedStringArray(caps.map(func(id): return ("%s (yours)" if held.has(id) else "%s") % Data.settlement(id)["name"])))
		+ (". You hold them all: the Glass Sea has one crown." if gs.crown_won else ". Hold all three and the Glass Sea is yours. Hold nothing for %d days and your crown falls." % gs.CROWN_FALL_DAYS)))
	# Name and colour.
	var n := _row_panel()
	n.add_child(Style.label("Name and colours", Style.BODY, Style.TEXT))
	var edit := LineEdit.new()
	edit.name = "CrownName"
	edit.text = gs.crown_title()
	edit.max_length = 32
	edit.custom_minimum_size = Vector2(0, 64)
	edit.text_submitted.connect(func(text: String):
		gs.set_crown_identity(text, gs.crown_color)
		_build())
	n.add_child(edit)
	var colors := _flow()
	for i in Data.CROWN_COLORS.size():
		var b := Button.new()
		b.name = "Color_%d" % i
		b.text = Data.CROWN_COLOR_NAMES[i]
		b.custom_minimum_size = Vector2(96, 56)
		b.add_theme_stylebox_override("normal", Style.box(Color(Data.CROWN_COLORS[i], 0.25), Data.CROWN_COLORS[i], 4 if i == gs.crown_color else 2, 12))
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		var idx := i
		b.pressed.connect(func():
			gs.set_crown_identity(edit.text, idx)
			_build())
		colors.add_child(b)
	n.add_child(colors)
	n.add_child(_button("Save name", func():
		gs.set_crown_identity(edit.text, gs.crown_color)
		_build(), "SaveName"))


# ---------------------------------------------------------------- holdings

func _holdings() -> void:
	var held: Array = gs.crown_holdings()
	held.sort_custom(func(a, b): return ["town", "castle", "village"].find(String(Data.settlement(a)["type"])) < ["town", "castle", "village"].find(String(Data.settlement(b)["type"])))
	_col.add_child(_note("Castles and towns raise garrisons from the treasury. Grant one to a sworn lord and it becomes their seat; visit one to station your own squads there."))
	for id in held:
		var info: Dictionary = Data.settlement(id)
		var v := _row_panel(Data.crown_color if id == gs.fief_id() else Style.RULE)
		v.name = "Holding_%s" % id
		var top := HBoxContainer.new()
		var name_l := Style.label("%s · %s" % [info["name"], String(info["type"]).capitalize()], Style.BODY, Style.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_l)
		var pin := Button.new()
		pin.icon = Widgets.icon("mappin")
		pin.expand_icon = true
		pin.custom_minimum_size = Vector2(56, 56)
		pin.pressed.connect(func():
			wants_place.emit(id)
			close())
		top.add_child(pin)
		v.add_child(top)
		var bits := PackedStringArray()
		if id == gs.fief_id():
			bits.append("your seat")
		else:
			var holder: Dictionary = gs.holder_of(id)
			if not holder.is_empty():
				bits.append("held by %s" % LordTalk.short_name(holder))
			elif String(info["type"]) != Data.VILLAGE:
				bits.append("no lord holds it")
		if world.garrison_capacity(id) > 0:
			bits.append("garrison %d / %d" % [world.men_of(world.garrison_at(id)), world.garrison_capacity(id)])
			if not gs.stationed_at(id).is_empty():
				bits.append("%d of your squads" % gs.stationed_at(id).size())
		if world.is_burned(id):
			bits.append("burned")
		if world.is_sieged(id):
			bits.append("under siege")
		v.add_child(_note(" · ".join(bits), Style.MUTED))
		# Grant it, right here.
		if gs.crown_fiefs().has(id):
			var f := _flow()
			for l in gs.crown_lords():
				if String(l.get("fief", "")) == id:
					continue
				var lid := int(l["id"])
				f.add_child(_button("Grant to %s" % LordTalk.first_name(l), func():
					_act(gs.grant_fief(id, lid), "%s now holds %s (+%d Regard)." % [LordTalk.short_name(l), info["name"], gs.GRANT_REGARD]), "Grant_%s_%d" % [id, lid]))
			if f.get_child_count() > 0:
				v.add_child(f)


# ---------------------------------------------------------------- lords

func _lords() -> void:
	var lords: Array = gs.crown_lords()
	if lords.is_empty():
		_col.add_child(_note("No lord is sworn to you yet. Win one over on the road (talk of crowns), or have a captive swear."))
		return
	_col.add_child(_note("Order a lord to ride with you (they join your fights), to hold a place, or to go about the realm's business."))
	for l in lords:
		var lid := int(l["id"])
		var v := _row_panel()
		v.name = "CrownLord_%d" % lid
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		var face := TextureRect.new()
		face.texture = CaptainArt.texture(LordVoice.portrait_record(l))
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(60, 80)
		top.add_child(face)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Style.label(LordTalk.short_name(l), Style.BODY, Style.TEXT))
		var fief := String(l.get("fief", ""))
		var p = world.party(int(l.get("party", -1)))
		var order: Dictionary = l.get("order", {}) if l.get("order") is Dictionary else {}
		var doing := "regrouping"
		if String(l.get("state", "")) == "prisoner":
			doing = "a captive of %s" % (String(Data.FACTIONS[String(l["captive_of"])]["name"]) if Data.FACTIONS.has(String(l["captive_of"])) else "the enemy")
		elif p != null:
			match String(order.get("kind", "")):
				"follow":
					doing = "riding with you"
				"guard":
					doing = "holding %s" % Data.settlement(String(order["target"]))["name"]
				_:
					doing = "in your army" if not MarshalArmies.for_party(world, p.id).is_empty() else "about the realm's business"
		var regard := LordTalk.regard(gs, l)
		words.add_child(_note("%s · %s%s · %d men" % [
			"holds %s" % Data.settlement(fief)["name"] if fief != "" else "no fief",
			doing, " · bought" if int(l.get("bought", 0)) == 1 else "", world.men_of(p.army) if p != null else world.men_of(l.get("army", []))]))
		words.add_child(_note("%s%d Regard%s" % ["+" if regard > 0 else "", regard, " · may leave if it falls below 0" if int(l.get("bought", 0)) == 1 else ""],
			Style.MORALE_HIGH if regard >= 10 else (Style.MORALE_MID if regard >= 0 else Style.MORALE_LOW)))
		top.add_child(words)
		v.add_child(top)
		if p != null:
			var f := _flow()
			var kind := String(order.get("kind", ""))
			f.add_child(_button("Ride with me", func(): _act(gs.order_lord(lid, "follow"), "%s rides with you." % LordTalk.short_name(l)), "Follow_%d" % lid, kind != "follow"))
			var hold := fief if fief != "" else String(world.capital_of(Data.CROWN))
			if hold != "":
				f.add_child(_button("Hold %s" % Data.settlement(hold)["name"], func(): _act(gs.order_lord(lid, "guard", hold), "%s holds %s." % [LordTalk.short_name(l), Data.settlement(hold)["name"]]),
					"Guard_%d" % lid, not (kind == "guard" and String(order.get("target", "")) == hold)))
			f.add_child(_button("Free to choose", func(): _act(gs.order_lord(lid, ""), "%s goes about the realm's business." % LordTalk.short_name(l)), "Free_%d" % lid, kind != ""))
			if fief != "":
				f.add_child(_button("Take back %s" % Data.settlement(fief)["name"], func(): _act(gs.revoke_fief(lid), "You took %s back." % Data.settlement(fief)["name"]), "Revoke_%d" % lid))
			v.add_child(f)


# ---------------------------------------------------------------- diplomacy

func _diplomacy() -> void:
	_col.add_child(_note("Calling your lords to war is on the Court tab.", Style.MUTED))
	# Each realm.
	for r in ["vardmark", "kharzan", "ryumon"]:
		if not world.realms.has(r):
			continue
		var name := String(Data.FACTIONS[r]["name"])
		var v := _row_panel(Style.ENEMY if world.at_war(Data.CROWN, r) else Style.RULE)
		v.name = "Realm_%s" % r
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(Widgets.banner(r, Vector2(36, 52)))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Style.label(name, Style.BODY, Style.TEXT))
		var status := "at peace"
		if world.at_war(Data.CROWN, r):
			var since := float(world.wars[world.war_key(Data.CROWN, r)].get("since", world.hour))
			status = "at war with you for %d days" % int((world.hour - since) / 24.0)
		elif world.allied_with_crown(r):
			status = "your ally"
		elif world.has_truce(Data.CROWN, r):
			status = "truce, %d more days" % ceili((world.truce_until(Data.CROWN, r) - world.hour) / 24.0)
		words.add_child(_note("%s · war-weariness %d · %d places · opinion of you %d" % [status, int(world.weariness_of(r)), world.holdings_of(r).size(), gs.relation_with_realm(r)]))
		for t in world.tributes:
			if String(t.get("from", "")) == r and String(t.get("to", "")) == Data.CROWN:
				words.add_child(_note("Pays you %d silver a day, %d days left." % [int(t["daily"]), int(t["days_left"])], Style.MORALE_HIGH))
			elif String(t.get("from", "")) == Data.CROWN and String(t.get("to", "")) == r:
				words.add_child(_note("You pay them %d silver a day, %d days left." % [int(t["daily"]), int(t["days_left"])], Style.MORALE_LOW))
		top.add_child(words)
		v.add_child(top)
		var f := _flow()
		if world.at_war(Data.CROWN, r):
			var pc: Dictionary = gs.crown_peace_check(r)
			var terms: Dictionary = world.peace_terms(Data.CROWN, r)
			var cost := "no tribute"
			if int(terms["daily"]) > 0:
				cost = ("they pay %d a day" if terms["to"] == Data.CROWN else "you pay %d a day") % int(terms["daily"])
			f.add_child(_button("Sue for peace (%s)" % cost, func(): _act(gs.sue_for_peace(r), "Peace with %s." % name), "Peace_%s" % r, bool(pc["ok"])))
			if not bool(pc["ok"]):
				v.add_child(_note(String(pc["reason"])))
		else:
			var wc: Dictionary = gs.war_check(r)
			f.add_child(_button("Declare war", func(): _act(gs.declare_crown_war(r), "Your crown is at war with %s." % name), "War_%s" % r, bool(wc["ok"])))
			if world.can_ally_crown(r):
				f.add_child(_button("Propose alliance", func(): _act(gs.propose_alliance(r), "%s is your ally." % name), "Ally_%s" % r, true, true))
			if not bool(wc["ok"]) and String(wc["reason"]) != "":
				v.add_child(_note(String(wc["reason"])))
		v.add_child(f)


# ---------------------------------------------------------------- the court
# One rule on these pages: a card holds one decision and one button; what the rules are
# lives on the rules sheet behind the "?".

## The Court tab: three cards, each a line of status and a way in.
func _court() -> void:
	_gathering_hub()
	_banners_hub()
	_petitions_card()
	var how := _flat_button("How the king's court works", _open_rules, "CourtRules")
	how.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(how)


func _go(page: String) -> void:
	tab = page
	_place_open = ""
	_menu_open = false
	_build()


func _place_name(id: String) -> String:
	return String(Data.settlement(id)["name"]) if Data.SETTLEMENTS.has(id) else id


func _lord_face(l: Dictionary) -> TextureRect:
	return CourtUI.lord_face(l)


func _face(l: Dictionary, w: float, dim: bool = false) -> Control:
	return CourtUI.face(l, w, dim)


## A sub-page's head: back, the title with a line under it, and "?" (the rules) or "⋯"
## (more) on the right.
func _page_head(title: String, sub: String, back: Callable, right: String = "rules") -> void:
	var row := HBoxContainer.new()
	row.name = "PageHead"
	row.add_theme_constant_override("separation", 12)
	var b := _round_button("‹", back, "Back")
	b.add_theme_font_size_override("font_size", Style.text_size(44))
	row.add_child(b)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := Style.label(title, Style.LARGE, Style.BRASS)
	var display := Style.display_font()
	if display != null:
		t.add_theme_font_override("font", display)
	words.add_child(t)
	if sub != "":
		words.add_child(_note(sub))
	row.add_child(words)
	if right == "rules":
		row.add_child(_round_button("?", _open_rules, "Rules"))
	elif right == "more":
		row.add_child(_round_button("⋯", func():
			_menu_open = not _menu_open
			_build(), "More"))
	_col.add_child(row)
	if right == "more" and _menu_open:
		var d := _button("Dismiss the banners", func():
			CrownCourt.dismiss(gs)
			_menu_open = false
			tab = "court"
			_act(true, "You dismiss the banners. Your lords ride home."), "Dismiss")
		d.add_theme_color_override("font_color", Style.ENEMY_LIGHT)
		d.add_theme_stylebox_override("normal", Style.box(Style.PANEL, Style.ENEMY, 2, 12))
		_col.add_child(d)
	if _flash != "":
		_col.add_child(_card_note(_flash, Style.BRASS))
		_flash = ""


func _round_button(text: String, act: Callable, id: String) -> Button:
	return CourtUI.round_button(text, act, id)


func _flat_button(text: String, act: Callable, id: String) -> Button:
	var b := _button(text, act, id)
	var clear := Style.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 12)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, clear)
	b.add_theme_color_override("font_color", Style.MUTED)
	return b


static func _n(v: int) -> String:
	return CourtUI.n(v)


func _rich(bb: String, color: Color = Style.MUTED, size_px: int = Style.SMALL) -> RichTextLabel:
	return CourtUI.rich(bb, color, size_px)


func _strip(cells: Array, parent: Control = null) -> void:
	(parent if parent != null else _col).add_child(CourtUI.strip(cells))


## A card's title with a quiet count beside it.
func _title(text: String, aside: String = "") -> RichTextLabel:
	return _rich("[color=#%s]%s[/color]%s" % [Style.TEXT.to_html(false), text, ("  ·  " + aside) if aside != "" else ""], Style.MUTED, Style.BODY)


## A card on the Court tab: title, one line of status, and a chevron; tap to go in.
func _hub_card(id: String, title: String, status: String, tone: Color, icon: String, go: Callable) -> VBoxContainer:
	var v := _row_panel(tone)
	var card := v.get_parent() as Control
	card.name = id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Widgets.icon_rect(icon, 44)
	ic.modulate = tone if tone != Style.RULE else Style.BRASS
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(Style.label(title, Style.BODY, Style.TEXT))
	var s := _note(status)
	s.name = "Status"
	words.add_child(s)
	row.add_child(words)
	var chev := Style.label("›", 44, Style.MUTED)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chev)
	v.add_child(row)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	Widgets.on_tap(card, func():
		Sound.play("click", 0.0, 0.05)
		go.call())
	return v


func _gathering_hub() -> void:
	var mine: Dictionary = gs.my_gathering()
	var status := "Feast, dance or tourney · nothing called"
	if not mine.is_empty():
		var n: int = world.gathering_guests(mine).size()
		status = "Your %s at %s · %s · %d coming" % [String(mine["name"]), _place_name(String(mine["place"])), gs.gathering_when(mine), n]
	_hub_card("GatheringCard", "Hold a gathering", status, Style.RULE if mine.is_empty() else Style.BRASS, "food", func(): _go("gathering"))


func _banners_hub() -> void:
	var status := ""
	var ready := false
	if not gs.banners.is_empty():
		status = CrownCourt.host_status(gs)
	elif not gs.muster.is_empty():
		status = "Gathering at %s · %d of %d in the hall" % [_place_name(String(gs.muster["place"])), CrownCourt.arrived(gs).size(), CrownCourt.muster_lords(gs).size()]
		ready = bool(CrownCourt.council_check(gs)["ok"])
	else:
		var places: Array = gs.host_places()
		var roll: Array = CrownCourt.roll(gs, places[0]) if not places.is_empty() else []
		var comes := roll.filter(func(e): return String(e["status"]) == "comes")
		var men := 0
		for e in comes:
			men += int(e["men"])
		status = "No lord is sworn to you yet" if roll.is_empty() else "%d of %d lords would ride · %d men" % [comes.size(), roll.size(), men]
	var v := _hub_card("BannersCard", "Call the banners", status, Style.ENEMY, "battle", func(): _go("banners"))
	if ready:
		var b := _button("Sit the war council", func(): _go("council"), "OpenCouncil", true, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(b)


## What your lords ask of you, to settle from here or hear at your table.
func _petitions_card() -> void:
	var list: Array = CrownCourt.petitions(gs)
	var v := _row_panel()
	v.get_parent().name = "PetitionsCard"
	v.add_theme_constant_override("separation", 12)
	v.add_child(_title("Petitions", str(list.size()) if not list.is_empty() else ""))
	if list.is_empty():
		v.add_child(_note("Your lords ask nothing of you just now."))
		return
	for i in list.size():
		var p: Dictionary = list[i]
		if i > 0:
			var rule := ColorRect.new()
			rule.color = Style.RULE
			rule.custom_minimum_size = Vector2(0, 2)
			v.add_child(rule)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.add_child(_face(p["lord"], 56))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 8)
		words.add_child(Style.label(LordTalk.short_name(p["lord"]), Style.SMALL, Style.TEXT))
		words.add_child(_note(String(p.get("ask", p["text"]))))
		var f := HBoxContainer.new()
		f.add_theme_constant_override("separation", 8)
		var lid := int(p["lord"]["id"])
		var settle := _button(String(p["settle"]), func():
			var r: Dictionary = CrownCourt.answer(gs, p, true)
			_flash = String(r.get("text", r.get("reason", "")))
			_build(), "Settle_%d" % lid, true, true)
		settle.custom_minimum_size.y = 60
		f.add_child(settle)
		if bool(p["refuse"]):
			var no := _button("Refuse %d" % Gatherings.PETITION_REFUSED, func():
				var r: Dictionary = CrownCourt.answer(gs, p, false)
				_flash = String(r.get("text", r.get("reason", "")))
				_build(), "Refuse_%d" % lid)
			no.custom_minimum_size.y = 60
			f.add_child(no)
		var hint := _rich("[right]%s · table %s[/right]" % [_n(Gatherings.PETITION_AFAR),
			_n(Gatherings.PUBLIC_GRANT_REGARD if String(p["kind"]) == "fief" else Gatherings.PETITION_TABLE)])
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(hint)
		words.add_child(f)
		row.add_child(words)
		v.add_child(row)


## A place, and when tapped the others to choose from. `prefix` names the nodes:
## "<prefix>Place" for the row, "<prefix>At_<id>" for each choice.
func _place_picker(v: VBoxContainer, places: Array, current: String, prefix: String, pick: Callable, sub: Callable) -> void:
	var open := _place_open == prefix and places.size() > 1
	var more := "" if places.size() < 2 else ("▴" if open else "%d more ▾" % (places.size() - 1))
	v.add_child(_choice_row(prefix + "Place", _place_name(current), String(sub.call(current)), more, func():
		_place_open = "" if open else prefix
		_build(), false, true, null, true))
	if not open:
		return
	for id in places:
		if id == current:
			continue
		var pid: String = id
		v.add_child(_choice_row(prefix + "At_" + id, _place_name(id), String(sub.call(id)), "", func():
			pick.call(pid)
			_place_open = ""
			_build()))


## A row you tap: bold words, quiet words after them, something on the right, and in the
## middle anything else (the faces of lords who back an aim).
func _choice_row(id: String, title: String, sub: String, aside: String, act: Callable, lit: bool = false, enabled: bool = true,
		middle: Control = null, boxed: bool = false) -> Button:
	var b := Button.new()
	b.name = id
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var bg := Style.BRASS if lit else (Style.RAISED if boxed else Color(0, 0, 0, 0))
	var edge := Style.BRASS if lit else (Style.RULE if boxed else Color(0, 0, 0, 0))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, Style.box(bg, edge, 2 if boxed or lit else 0, 12))
	b.pressed.connect(func():
		Sound.play("click", 0.0, 0.05)
		act.call())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -18
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := Style.BRASS_INK if lit else (Style.TEXT if enabled else Style.MUTED.darkened(0.3))
	var quiet := Color("5a4413") if lit else Style.MUTED
	var t := Style.label(title, Style.BODY if not boxed else Style.SMALL, ink)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	if sub != "":
		var s := Style.label("· " + sub, Style.SMALL, quiet)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.clip_text = true
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(s)
	else:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(gap)
	if middle != null:
		h.add_child(middle)
	if aside != "":
		var a := Style.label(aside, Style.SMALL, quiet)
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(a)
	b.add_child(h)
	return b


## A muted heading in small capitals over a card's rows.
func _caps(text: String) -> Label:
	return Style.label(text.to_upper(), Style.SMALL, Style.MUTED)


func _red_line(text: String) -> Label:
	var l := _note(text, Style.ENEMY_LIGHT)
	l.name = "Why"
	return l


# ---------------------------------------------------------------- hold a gathering

func _gathering_page() -> void:
	_page_head("Hold a gathering", "%d silver · %d rations in your purse" % [gs.silver, gs.food], func(): _go("court"))
	var mine: Dictionary = gs.my_gathering()
	if not mine.is_empty():
		var v := _row_panel(Style.BRASS)
		v.get_parent().name = "GatheringCard"
		var place := String(mine["place"])
		var n: int = world.gathering_guests(mine).size()
		v.add_child(_title("Your %s at %s" % [String(mine["name"]), _place_name(place)]))
		v.add_child(_note("%s · %d lord%s coming" % [Gatherings.upper_first(gs.gathering_when(mine)), n, "" if n == 1 else "s"], Style.TEXT))
		if world.here() == place:
			v.add_child(_note("You're there."))
		else:
			v.add_child(_note("%s away. Be there the first night." % Gatherings.upper_first(CrownCourt._ride_words(world.hours_to(place)))))
			v.add_child(_button("Show %s on the map" % _place_name(place), func(): _show_place(place), "ShowGathering"))
		return
	var places: Array = gs.host_places()
	if places.is_empty():
		_col.add_child(_note("You hold no castle or town to hold court in."))
		return
	if not places.has(_host_place):
		_host_place = places[0]
	var kinds := [Gatherings.FEAST, Gatherings.DANCE, Gatherings.TOURNEY]
	var kind: String = kinds[_host_kind]
	var v := _row_panel()
	v.get_parent().name = "GatheringCard"
	v.add_theme_constant_override("separation", 12)
	v.add_child(Widgets.segmented(["Feast", "Dance", "Tourney"], _host_kind, func(i: int):
		_host_kind = i
		_build(), "HostKind"))
	v.add_child(_note({Gatherings.FEAST: "Three nights at table; dancing on the last.",
		Gatherings.DANCE: "Three nights of music; a partner each night.",
		Gatherings.TOURNEY: "A day at the lists, then a feast. The crowd remembers the winner."}[kind]))
	_place_picker(v, places, _host_place, "Host", func(id: String): _host_place = id, func(id: String) -> String:
		var host: Dictionary = gs.host_lord_at(id)
		if id == world.capital_of(Data.CROWN):
			return "your seat"
		return "%s hosts" % LordTalk.first_name(host) if not host.is_empty() else "your hall")
	v.add_child(_rich("%s, three nights. Be there the first night (%s if not)." % [
		Gatherings.upper_first(gs.gathering_when({"starts_hour": world.gathering_start_hour()})), _n(Gatherings.ABSENT_KING_REGARD)]))
	# Guests.
	var who: Dictionary = gs.host_invitees(_host_place)
	var asked: int = (who["sworn"] as Array).size()
	for key in ["friends", "persuade", "lieges"]:
		if bool(_host_ask[key]):
			asked += (who[key] as Array).size()
	var g := _row_panel()
	g.get_parent().name = "GuestsCard"
	g.add_theme_constant_override("separation", 0)
	g.add_child(_title("Guests", "%d asked" % asked))
	g.add_child(_ask_row("sworn", "Your sworn lords", str((who["sworn"] as Array).size()), true, false))
	g.add_child(_ask_row("friends", "Lords who like you", str((who["friends"] as Array).size()) if not (who["friends"] as Array).is_empty() else "none near", bool(_host_ask["friends"]), true))
	g.add_child(_ask_row("persuade", "Lords to win over", str((who["persuade"] as Array).size()) if not (who["persuade"] as Array).is_empty() else "none near", bool(_host_ask["persuade"]), true))
	if not (who["lieges"] as Array).is_empty():
		g.add_child(_ask_row("lieges", "Their lieges", str((who["lieges"] as Array).size()), bool(_host_ask["lieges"]), true,
			"" if bool(_host_ask["lieges"]) else "left out %s" % _n(Gatherings.SNUB_REGARD)))
	var cells := [[str(Gatherings.HOST_SILVER), "silver"], [str(Gatherings.HOST_FOOD), "rations"]]
	if kind == Gatherings.TOURNEY:
		cells.append([str(Gatherings.TOURNEY_PURSE), "purse"])
	cells.append(["3", "nights"])
	_strip(cells)
	var check: Dictionary = gs.host_check(_host_place, kind)
	if not bool(check["ok"]):
		_col.add_child(_red_line(String(check["reason"])))
	var send := _button("Send the invitations", func():
		var r: Dictionary = gs.host_gathering(kind, _host_ask, _host_place)
		if bool(r.get("ok", false)):
			Sound.play("horn")
			tab = "court"
		_act(bool(r.get("ok", false)), "Riders go out with your invitations. %d lord%s will come." % [int(r.get("guests", 0)), "" if int(r.get("guests", 0)) == 1 else "s"]),
		"SendInvitations", bool(check["ok"]), true)
	send.custom_minimum_size.y = 84
	_col.add_child(send)
	var foot := _note("At your own table you honour a lord, hear petitions and speak.")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(foot)


func _ask_row(key: String, text: String, count: String, on: bool, can_change: bool, warn: String = "") -> Control:
	var row := HBoxContainer.new()
	row.name = "Ask_" + key
	row.custom_minimum_size.y = 76
	row.add_theme_constant_override("separation", 12)
	var words := _rich("[color=#%s]%s[/color]  ·  %s%s" % [Style.TEXT.to_html(false), text, count, ("   " + warn) if warn != "" else ""])
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	if can_change:
		row.add_child(Widgets.switch(on, func(state: bool):
			_host_ask[key] = state
			_build.call_deferred(), "Switch_" + key, text))
	else:
		var always := Style.label("Always", Style.SMALL, Style.BRASS)
		always.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(always)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var rule := ColorRect.new()
	rule.color = Style.RULE
	rule.custom_minimum_size = Vector2(0, 2)
	wrap.add_child(rule)
	wrap.add_child(row)
	return wrap


func _show_place(id: String) -> void:
	wants_place.emit(id)
	queue_free()


# ---------------------------------------------------------------- call the banners

func _banners_page() -> void:
	if not gs.banners.is_empty():
		_page_head("Your banners", "", func(): _go("court"))
		var v := _row_panel(Style.ENEMY)
		v.get_parent().name = "BannersCard"
		v.add_child(_title(CrownCourt.host_status(gs)))
		if String(gs.banners["led"]) == "you":
			v.add_child(_note("They ride with you and fight where you fight."))
		v.add_child(_button("Dismiss the banners", func():
			CrownCourt.dismiss(gs)
			tab = "court"
			_act(true, "You dismiss the banners. Your lords ride home."), "Dismiss"))
		return
	if not gs.muster.is_empty():
		_muster_page()
		return
	_page_head("Call the banners", "Every sworn lord rides to one place and waits for you.", func(): _go("court"))
	var places: Array = gs.host_places()
	if places.is_empty():
		_col.add_child(_note("You hold no castle or town to muster at."))
		return
	if not places.has(_muster_place):
		_muster_place = places[0]
	var v := _row_panel()
	v.get_parent().name = "BannersCard"
	v.add_child(_caps("Muster at"))
	_place_picker(v, places, _muster_place, "Muster", func(id: String): _muster_place = id, func(id: String) -> String:
		return "your seat" if id == world.capital_of(Data.CROWN) else "")
	var roll: Array = CrownCourt.roll(gs, _muster_place)
	var comes := roll.filter(func(e): return String(e["status"]) == "comes")
	var r := _row_panel()
	r.get_parent().name = "RollCard"
	r.add_theme_constant_override("separation", 0)
	r.add_child(_title("Who answers", "%d of %d" % [comes.size(), roll.size()] if not roll.is_empty() else ""))
	if roll.is_empty():
		r.add_child(_note("No lord is sworn to you yet."))
	var men := 0
	var slowest := 0.0
	for e in roll:
		var st := String(e["status"])
		var word: String = {"comes": "Comes", "refuses": "Refuses %d" % Lords.MUSTER_REFUSED_REGARD, "holds": "Stays", "captive": "Captive", "away": "Away"}[st]
		var tone: Color = {"comes": Style.MORALE_HIGH, "refuses": Style.ENEMY_LIGHT}.get(st, Style.MUTED)
		var sub := "%d men · %s" % [int(e["men"]), CrownCourt._ride_short(float(e["hours"]))] if st == "comes" else String(e["why"])
		r.add_child(_lord_row(e["lord"], sub, word, tone, st != "comes"))
		if st == "comes":
			men += int(e["men"])
			slowest = maxf(slowest, float(e["hours"]))
	_strip([[str(men), "men"], ["Day %d" % (int(slowest / 24.0) + 1), "all in"],
		[str(int(ceil(men / 10.0)) * Lords.MUSTER_SILVER_PER_10), "silver a day"], [str(gs.crown_treasury()), "treasury"]])
	var check: Dictionary = CrownCourt.call_check(gs, _muster_place)
	if not bool(check["ok"]):
		_col.add_child(_red_line(String(check["reason"])))
	var call := _button("Call the banners to %s" % _place_name(_muster_place), func():
		_act(CrownCourt.call_banners(gs, _muster_place), "Riders go out with your summons."), "CallBanners", bool(check["ok"]), true)
	call.custom_minimum_size.y = 84
	_col.add_child(call)
	var when := _note("The council sits once %d lords are in the hall." % Lords.ARMY_MIN_MEMBERS)
	when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(when)
	# The quick call: two ready lords from your capital, on their own.
	var targets := _targets()
	if not targets.is_empty():
		var t: String = targets[0]
		if bool(gs.call_check(t)["ok"]):
			var quick := _flat_button("Or send two ready lords at %s  ›" % _place_name(t), func():
				_act(gs.call_to_arms(t), "Your lords gather to march on %s." % _place_name(t)), "Call_%s" % t)
			quick.alignment = HORIZONTAL_ALIGNMENT_CENTER
			_col.add_child(quick)


## While the banners gather: who's in the hall, who's on the road, and the council.
func _muster_page() -> void:
	var place := String(gs.muster["place"])
	var day := int((world.hour - float(gs.muster["called_hour"])) / 24.0) + 1
	_page_head("Call the banners", "Gathering at %s · day %d" % [_place_name(place), day], func(): _go("court"), "more")
	var here: Array = CrownCourt.arrived(gs)
	var all: Array = CrownCourt.muster_lords(gs)
	var r := _row_panel(Style.ENEMY)
	r.get_parent().name = "BannersCard"
	r.add_theme_constant_override("separation", 0)
	r.add_child(_title("In the hall", "%d of %d" % [here.size(), all.size()]))
	var men := 0
	for l in all:
		var p = world.party(int(l.get("party", -1)))
		var n: int = world.men_of(p.army) if p != null else 0
		men += n
		var there: bool = here.has(l)
		var away := CrownCourt._ride_short(world._hours(p, p.next if p.moving() else p.node, place)) if p != null else "far"
		r.add_child(_lord_row(l, "%d men" % n, "In the hall" if there else "%s away" % away, Style.MORALE_HIGH if there else Style.MUTED, not there))
	_strip([[str(men), "men"], ["%d/%d" % [here.size(), all.size()], "in the hall"], [str(CrownCourt.muster_upkeep(gs)), "silver a day"], [str(gs.crown_treasury()), "treasury"]])
	var c: Dictionary = CrownCourt.council_check(gs)
	if not bool(c["ok"]):
		_col.add_child(_red_line(String(c["reason"])))
	var sit := _button("Sit the war council", func(): _go("council"), "OpenCouncil", bool(c["ok"]), true)
	sit.custom_minimum_size.y = 84
	_col.add_child(sit)
	if world.here() != place:
		_col.add_child(_flat_button("Show %s on the map" % _place_name(place), func(): _show_place(place), "ShowMuster"))


## One lord on a roll: face, name, a quiet line, and a word on the right.
func _lord_row(l: Dictionary, sub: String, word: String, tone: Color, dim: bool = false) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var rule := ColorRect.new()
	rule.color = Style.RULE
	rule.custom_minimum_size = Vector2(0, 2)
	wrap.add_child(rule)
	var row := HBoxContainer.new()
	row.name = "Lord_%d" % int(l["id"])
	row.add_theme_constant_override("separation", 14)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	m.add_child(_face(l, 48, dim))
	row.add_child(m)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.add_child(Style.label(LordTalk.short_name(l), Style.SMALL, Style.MUTED if dim else Style.TEXT))
	var s := Style.label(sub, Style.SMALL, Style.MUTED)
	s.clip_text = true
	words.add_child(s)
	row.add_child(words)
	var w := Style.label(word, Style.SMALL, tone)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(w)
	wrap.add_child(row)
	return wrap


# ---------------------------------------------------------------- the war council

func _council() -> void:
	var place := String(gs.muster["place"])
	var here: Array = CrownCourt.arrived(gs)
	var all: Array = CrownCourt.muster_lords(gs)
	var day := int((world.hour - float(gs.muster["called_hour"])) / 24.0) + 1
	var road := all.size() - here.size()
	_page_head("War council", "%s · day %d · %d in the hall%s" % [_place_name(place), day, here.size(), (" · %d on the road" % road) if road > 0 else ""],
		func(): _go("banners"), "more")
	# The lords: a face each; the one you've picked says their piece.
	var speaker: Dictionary = {}
	for l in here:
		if int(l["id"]) == _council_lord:
			speaker = l
	if speaker.is_empty():
		speaker = here[0]
		_council_lord = int(speaker["id"])
	var lv := _row_panel()
	lv.get_parent().name = "Council"
	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", 8)
	for l in here:
		var on: bool = l == speaker
		var b := Button.new()
		b.name = "Speaker_%d" % int(l["id"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 150)
		var lit := Style.box(Color(Style.BRASS, 0.14), Style.BRASS, 2, 14)
		var flat := Style.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 14)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, lit if on else flat)
		var lid := int(l["id"])
		b.pressed.connect(func():
			Sound.play("click", 0.0, 0.05)
			_council_lord = lid
			_build())
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 4)
		var f := _face(l, 72, not on)
		f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(f)
		var nm := Style.label(LordTalk.first_name(l), Style.SMALL, Style.TEXT if on else Style.MUTED)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		col.add_child(nm)
		b.add_child(col)
		faces.add_child(b)
	lv.add_child(faces)
	var sp = world.party(int(speaker.get("party", -1)))
	var bubble := PanelContainer.new()
	bubble.name = "Counsel"
	bubble.add_theme_stylebox_override("panel", Style.box(Style.RAISED, Style.RULE, 2, 14))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bv.add_child(_note("%s · %d men · %s" % [LordTalk.short_name(speaker), world.men_of(sp.army) if sp != null else 0, String(speaker.get("bearing", ""))]))
	bv.add_child(_note(String(CrownCourt.counsel(gs, speaker)["says"]), Style.TEXT, Style.BODY))
	bubble.add_child(bv)
	lv.add_child(bubble)
	# The aims, each with the faces of the lords whose counsel names it.
	var aims: Array = CrownCourt.aims(gs)
	var backers := {}
	for l in here:
		var c: Dictionary = CrownCourt.counsel(gs, l)
		for a in aims:
			if not bool(a["ok"]) or String(a["aim"]) != String(c["aim"]):
				continue
			if String(c.get("target", "")) != "" and String(a["target"]) != String(c["target"]):
				continue
			if not backers.has(String(a["id"])):
				backers[String(a["id"])] = []
			backers[String(a["id"])].append(l)
			break
	var chosen := {}
	for a in aims:
		if String(a["id"]) == _aim and bool(a["ok"]):
			chosen = a
	if chosen.is_empty():
		for a in aims:
			if bool(a["ok"]):
				chosen = a
				_aim = String(a["id"])
				break
	var av := _row_panel()
	av.get_parent().name = "Aims"
	av.add_theme_constant_override("separation", 2)
	av.add_child(_caps("The aim"))
	for a in aims:
		var aid := String(a["id"])
		var mids: Control = null
		if backers.has(aid):
			var hb := HBoxContainer.new()
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_theme_constant_override("separation", 4)
			for l in backers[aid]:
				hb.add_child(_face(l, 32))
			mids = hb
		var kind := String(a["aim"])
		av.add_child(_choice_row("Aim_" + aid, String(a["label"]), "", String(a.get("short", a["sub"])), func():
			_aim = aid
			# Only a lord leads a raid: choosing one hands them the host.
			if kind == CrownCourt.RAID:
				_you_lead = false
			_build(), aid == _aim and bool(a["ok"]), bool(a["ok"]), mids))
	# Who leads.
	var marshal: Dictionary = CrownCourt.lord_marshal(gs)
	var ld := _row_panel()
	ld.get_parent().name = "Leads"
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 16)
	var cap := _caps("Leads")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lr.add_child(cap)
	var seg := Widgets.segmented(["You", LordTalk.first_name(marshal) if not marshal.is_empty() else "A lord"], 0 if _you_lead else 1, func(i: int):
		_you_lead = i == 0
		_build(), "Lead")
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_child(seg)
	ld.add_child(lr)
	var raid := not chosen.is_empty() and String(chosen["aim"]) == CrownCourt.RAID
	if raid and _you_lead:
		ld.add_child(_red_line("A raid needs a lord to lead it."))
	else:
		ld.add_child(_note("They ride with you and fight where you fight, sieges too." if _you_lead
			else "%s marches the host on their own. You stay free." % (LordTalk.short_name(marshal) if not marshal.is_empty() else "A lord")))
	# The bar at the foot: what it comes to, and March.
	var prov: Dictionary = CrownCourt.provisions(gs)
	var riders := _riders(chosen)
	var men := 0
	for l in riders:
		var p = world.party(int(l.get("party", -1)))
		men += world.men_of(p.army) if p != null else 0
	var mc: Dictionary = CrownCourt.march_check(gs, chosen, _you_lead) if not chosen.is_empty() else {"ok": false, "reason": "nothing to do"}
	var days := int((Lords.HOST_PAID_HOURS if bool(prov["paid"]) else Lords.HOST_UNPAID_HOURS) / 24.0)
	var go := _button("March!", func(): _open_march_sheet(chosen), "March", bool(mc["ok"]), true)
	go.custom_minimum_size = Vector2(220, 88)
	_set_footer("%d men · %d days" % [men, days],
		("%d silver from the treasury" % int(prov["cost"])) if bool(prov["paid"]) else "The treasury can't pay %d: three days out" % int(prov["cost"]), go)


## Who rides if the council chooses `aim`: everyone in the hall, but an Honorable lord
## won't raid.
func _riders(aim: Dictionary) -> Array:
	var here: Array = CrownCourt.arrived(gs)
	if not aim.is_empty() and String(aim["aim"]) == CrownCourt.RAID:
		return here.filter(func(l): return String(l.get("bearing", "")) != Lords.HONORABLE)
	return here


## A bar under the page that doesn't scroll: two lines on the left, a button on the right.
func _set_footer(big: String, small: String, button: Button) -> void:
	var bar := PanelContainer.new()
	bar.name = "Footer"
	var sb := Style.box(Style.PANEL, Style.RULE, 0, 0)
	sb.border_width_top = 2
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.content_margin_left = 32
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18 + float(_insets.get("bottom", 0))
	bar.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Style.label(big, Style.LARGE, Style.TEXT))
	words.add_child(_note(small))
	h.add_child(words)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(button)
	bar.add_child(h)
	_footer = bar


# ---------------------------------------------------------------- sheets

func _sheet(sheet_name: String) -> VBoxContainer:
	return CourtUI.sheet(self, sheet_name, _insets)


func _sheet_title(v: VBoxContainer, text: String, close_on: Control) -> void:
	CourtUI.sheet_title(v, text, close_on)


## Before the host rides: what it costs, and what each lord makes of it.
func _open_march_sheet(aim: Dictionary) -> void:
	if aim.is_empty():
		return
	var v := _sheet("MarchSheet")
	var layer := v.get_parent().get_parent() as Control
	_sheet_title(v, String(aim["label"]), layer)
	var riders := _riders(aim)
	var men := 0
	for l in riders:
		var p = world.party(int(l.get("party", -1)))
		men += world.men_of(p.army) if p != null else 0
	var marshal: Dictionary = CrownCourt.lord_marshal(gs)
	v.add_child(_note("%d men ride %s · %s" % [men, "with you" if _you_lead else "under %s" % LordTalk.short_name(marshal), String(aim.get("short", aim["sub"]))]))
	var list := PanelContainer.new()
	list.name = "WhoRides"
	list.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Style.RULE, 2, 14))
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	list.add_child(lv)
	var wanted := {CrownCourt.STORM: "wanted a siege", CrownCourt.RELIEVE: "wanted to relieve", CrownCourt.MARCH: "wanted to hold the march", CrownCourt.RAID: "wanted the raid"}
	for l in CrownCourt.arrived(gs):
		var c: Dictionary = CrownCourt.counsel(gs, l)
		var sub := ""
		var deltas := []
		if not riders.has(l):
			sub = "won't burn farms · rides home"
			deltas = [Lords.RAID_REFUSED_REGARD]
		elif String(c["aim"]) == String(aim["aim"]):
			sub = "rides · their counsel"
			deltas = [Lords.MUSTER_RIDE_REGARD]
		else:
			sub = "rides · %s" % wanted.get(String(c["aim"]), "wanted otherwise")
			deltas = [Lords.MUSTER_RIDE_REGARD, Lords.COUNSEL_IGNORED_REGARD]
		var row := _lord_row(l, sub, "", Style.MUTED, not riders.has(l))
		var line := row.get_child(1) as HBoxContainer
		line.remove_child(line.get_child(line.get_child_count() - 1))
		var d := _rich("[right]%s[/right]" % "  ".join(deltas.map(func(x): return _n(int(x)))), Style.MUTED, Style.BODY)
		d.custom_minimum_size.x = 120
		d.size_flags_horizontal = Control.SIZE_SHRINK_END
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(d)
		if lv.get_child_count() == 0:
			row.get_child(0).visible = false
		lv.add_child(row)
	v.add_child(list)
	var prov: Dictionary = CrownCourt.provisions(gs)
	var pr := HBoxContainer.new()
	var pl := _note("Provisions for %s days" % ("six" if bool(prov["paid"]) else "three"))
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(pl)
	pr.add_child(_rich("[right][color=#%s]%d[/color] silver · %d left[/right]" % [Style.TEXT.to_html(false), int(prov["cost"]), int(prov["treasury"]) - int(prov["cost"])]
		if bool(prov["paid"]) else "[right]the treasury can't pay[/right]"))
	v.add_child(pr)
	var target := _place_name(String(aim.get("target", ""))) if String(aim.get("target", "")) != "" else ""
	var words: String = {CrownCourt.STORM: "March on %s" % target, CrownCourt.RELIEVE: "Ride to %s" % target,
		CrownCourt.MARCH: "Ride the march", CrownCourt.RAID: "Send the raid"}.get(String(aim["aim"]), "March!")
	var go := _button(words, func():
		layer.queue_free()
		var ok: bool = CrownCourt.march(gs, aim, _you_lead)
		if ok:
			Sound.play("horn")
			tab = "court"
		_act(ok, "The council rises. Your banners ride."), "MarchConfirm", true, true)
	go.custom_minimum_size.y = 88
	v.add_child(go)
	v.add_child(_flat_button("Back to the council", func(): layer.queue_free(), "NotYet"))


## Everything the cards no longer spell out, read once.
func _open_rules() -> void:
	CourtUI.open_rules(self, _insets)


## Enemy castles and towns, nearest your seat first.
func _targets() -> Array:
	var seat: String = world.capital_of(Data.CROWN)
	var out := []
	for id in Data.SETTLEMENTS:
		if Data.is_village(id) or not world.at_war(Data.CROWN, world.owner_of(id)):
			continue
		out.append(id)
	if seat != "":
		var at: Vector2 = Data.pos(seat)
		out.sort_custom(func(a, b): return Data.pos(a).distance_to(at) < Data.pos(b).distance_to(at))
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
