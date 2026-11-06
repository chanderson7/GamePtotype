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
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var insets: Dictionary = Style.safe_insets(get_viewport())
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
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
	], "court" if tab == "council" else tab, _on_tab, "KingdomTabs"))
	match tab:
		"holdings":
			_holdings()
		"lords":
			_lords()
		"court":
			_court()
		"council":
			_council()
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


## A full-width button whose words wrap: for choices that need a line of explanation.
func _wide_button(text: String, act: Callable, id: String, enabled: bool = true, primary: bool = false) -> Button:
	var b := _button(text, act, id, enabled, primary)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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

func _court() -> void:
	_gathering_card()
	_banners_card()
	_petitions_card()


func _place_name(id: String) -> String:
	return String(Data.settlement(id)["name"]) if Data.SETTLEMENTS.has(id) else id


func _chips(texts: Array, tone: Color = Style.MORALE_MID) -> HFlowContainer:
	return Widgets.chip_row(texts.map(func(t): return Widgets.chip(String(t), tone, "·")))


func _lord_face(l: Dictionary) -> TextureRect:
	var face := TextureRect.new()
	face.texture = CaptainArt.texture(LordVoice.portrait_record(l))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(60, 80)
	return face


## Hold a gathering: a feast, a dance or a tourney, at any castle or town of yours, and who to ask.
func _gathering_card() -> void:
	var v := _row_panel(Data.crown_color)
	v.get_parent().name = "GatheringCard"
	v.add_child(Style.label("Hold a gathering", Style.BODY, Style.TEXT))
	var mine: Dictionary = gs.my_gathering()
	if not mine.is_empty():
		var place := String(mine["place"])
		var n: int = world.gathering_guests(mine).size()
		var where := "You're there." if world.here() == place else "You're %s away: be there on the first night." % CrownCourt._ride_words(world.hours_to(place))
		v.add_child(_note("Your %s at %s: %s. %d lord%s coming. %s" % [String(mine["name"]), _place_name(place), gs.gathering_when(mine), n, "" if n == 1 else "s", where], Style.BRASS))
		if world.here() != place:
			v.add_child(_button("Show %s on the map" % _place_name(place), func(): _show_place(place), "ShowGathering"))
		return
	var places: Array = gs.host_places()
	if places.is_empty():
		v.add_child(_note("You hold no castle or town to hold court in."))
		return
	if not places.has(_host_place):
		_host_place = places[0]
	var kinds := [Gatherings.FEAST, Gatherings.DANCE, Gatherings.TOURNEY]
	v.add_child(Widgets.segmented(["Feast", "Dance", "Tourney"], _host_kind, func(i: int):
		_host_kind = i
		_build(), "HostKind"))
	var kind: String = kinds[_host_kind]
	v.add_child(_note({Gatherings.FEAST: "Three nights at table; the dancing on the last.",
		Gatherings.DANCE: "Three nights of music; a partner each night.",
		Gatherings.TOURNEY: "A day at the lists, your captains against your lords' champions, then a feast. The crowd remembers the winner."}[kind], Style.TEXT))
	v.add_child(_note("Where", Style.BRASS))
	var f := _flow()
	for id in places:
		var host: Dictionary = gs.host_lord_at(id)
		var label := "%s · %s" % [_place_name(id), "your seat" if id == world.capital_of(Data.CROWN) else ("%s hosts in your name" % LordTalk.short_name(host) if not host.is_empty() else "your hall")]
		var pid: String = id
		f.add_child(_button(label, func():
			_host_place = pid
			_build(), "HostAt_" + id, true, id == _host_place))
	v.add_child(f)
	v.add_child(_note("%s, three nights. You needn't be there to call it; be there on the first night, or your lords drink without you (%d Regard with those you're winning over)." % [
		Gatherings.upper_first(gs.gathering_when({"starts_hour": world.gathering_start_hour()})), Gatherings.ABSENT_KING_REGARD]))
	var who: Dictionary = gs.host_invitees(_host_place)
	var names := func(list: Array) -> String:
		var out := PackedStringArray()
		for l in list.slice(0, 3):
			out.append(LordTalk.short_name(l) if bool(l.get("ruler", false)) else LordTalk.first_name(l))
		if list.size() > 3:
			out.append("%d more" % (list.size() - 3))
		return ", ".join(out) if not out.is_empty() else "none near"
	v.add_child(_ask_row("sworn", "Your sworn lords · %d" % (who["sworn"] as Array).size(), "they always come", true, false))
	v.add_child(_ask_row("friends", "Lords who think well of you · %d" % (who["friends"] as Array).size(),
		"Regard %d or more · %s" % [Gatherings.HOST_FRIEND_REGARD, names.call(who["friends"])], bool(_host_ask["friends"]), true))
	v.add_child(_ask_row("persuade", "Lords you want to win over · %d" % (who["persuade"] as Array).size(),
		"they come unless they despise you · %s" % names.call(who["persuade"]), bool(_host_ask["persuade"]), true))
	if not (who["lieges"] as Array).is_empty():
		v.add_child(_ask_row("lieges", "Their lieges · %s" % names.call(who["lieges"]),
			"leaving out a liege whose lords you ask is a snub (%d)" % Gatherings.SNUB_REGARD, bool(_host_ask["lieges"]), true))
	v.add_child(_note("At your own table: a seat of honour for one lord, a castle granted before everyone (+%d Regard), petitions heard (+%d), and a king's speech in place of a toast." % [
		Gatherings.PUBLIC_GRANT_REGARD, Gatherings.PETITION_TABLE], Style.TEXT))
	var cost := ["%d silver" % Gatherings.HOST_SILVER, "%d rations" % Gatherings.HOST_FOOD]
	if kind == Gatherings.TOURNEY:
		cost.append("purse %d" % Gatherings.TOURNEY_PURSE)
	cost.append("no enemy lords within two days")
	v.add_child(_chips(cost))
	var check: Dictionary = gs.host_check(_host_place, kind)
	v.add_child(_button("Send the invitations", func():
		var r: Dictionary = gs.host_gathering(kind, _host_ask, _host_place)
		if bool(r.get("ok", false)):
			Sound.play("horn")
		_act(bool(r.get("ok", false)), "Riders go out with your invitations. %d lord%s will come." % [int(r.get("guests", 0)), "" if int(r.get("guests", 0)) == 1 else "s"]),
		"SendInvitations", bool(check["ok"]), true))
	if not bool(check["ok"]):
		v.add_child(_note(String(check["reason"]), Style.MORALE_LOW))


func _ask_row(key: String, text: String, sub: String, on: bool, can_change: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "Ask_" + key
	row.add_theme_constant_override("separation", 12)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(Style.label(text, Style.SMALL, Style.TEXT))
	words.add_child(_note(sub))
	row.add_child(words)
	if can_change:
		row.add_child(Widgets.switch(on, func(state: bool): _host_ask[key] = state, "Switch_" + key, text))
	else:
		row.add_child(Style.label("Always", Style.SMALL, Style.BRASS))
	return row


func _show_place(id: String) -> void:
	wants_place.emit(id)
	queue_free()


## Call the banners: every sworn lord to a muster. While they gather, who's there; once
## they ride, how the host fares.
func _banners_card() -> void:
	var v := _row_panel(Style.ENEMY)
	v.get_parent().name = "BannersCard"
	v.add_child(Style.label("Call the banners", Style.BODY, Style.TEXT))
	if not gs.banners.is_empty():
		v.add_child(_note(CrownCourt.host_status(gs) + ".", Style.TEXT))
		if String(gs.banners["led"]) == "you":
			v.add_child(_note("They follow you and fight where you fight, sieges too.", Style.MUTED))
		v.add_child(_button("Dismiss the banners", func():
			CrownCourt.dismiss(gs)
			_act(true, "You dismiss the banners. Your lords ride home."), "Dismiss"))
		return
	if not gs.muster.is_empty():
		var place := String(gs.muster["place"])
		var here: Array = CrownCourt.arrived(gs)
		var all: Array = CrownCourt.muster_lords(gs)
		v.add_child(_note("Your banners gather at %s: %d of %d lords in the hall." % [_place_name(place), here.size(), all.size()], Style.TEXT))
		for l in all:
			var p = world.party(int(l.get("party", -1)))
			var there: bool = here.has(l)
			v.add_child(_roll_row(LordTalk.short_name(l), "%d men · %s" % [world.men_of(p.army) if p != null else 0,
				"in the hall" if there else CrownCourt._ride_words(world._hours(p, p.next if p.moving() else p.node, place)) + " away"],
				Style.MORALE_HIGH if there else Style.MUTED))
		v.add_child(_chips(["the treasury feeds them · %d silver a day (%d)" % [CrownCourt.muster_upkeep(gs), gs.crown_treasury()]]))
		var c: Dictionary = CrownCourt.council_check(gs)
		var f := _flow()
		f.add_child(_button("Open the war council", func():
			tab = "council"
			_build(), "OpenCouncil", bool(c["ok"]), true))
		if world.here() != place:
			f.add_child(_button("Show %s" % _place_name(place), func(): _show_place(place), "ShowMuster"))
		f.add_child(_button("Dismiss the banners", func():
			CrownCourt.dismiss(gs)
			_act(true, "You dismiss the banners. Your lords ride home."), "Dismiss"))
		v.add_child(f)
		if not bool(c["ok"]):
			v.add_child(_note(String(c["reason"])))
		return
	v.add_child(_note("Summon every sworn lord to a muster. They ride in and wait for you; the war council sits once two are in the hall, and decides what the host does and who leads it.", Style.TEXT))
	var places: Array = gs.host_places()
	if places.is_empty():
		v.add_child(_note("You hold no castle or town to muster at."))
		return
	if not places.has(_muster_place):
		_muster_place = places[0]
	v.add_child(_note("Where", Style.BRASS))
	var f := _flow()
	for id in places:
		var pid: String = id
		f.add_child(_button(_place_name(id) + (" · your seat" if id == world.capital_of(Data.CROWN) else ""), func():
			_muster_place = pid
			_build(), "MusterAt_" + id, true, id == _muster_place))
	v.add_child(f)
	v.add_child(_note("Who answers", Style.BRASS))
	var roll: Array = CrownCourt.roll(gs, _muster_place)
	if roll.is_empty():
		v.add_child(_note("No lord is sworn to you yet."))
	for e in roll:
		var tone: Color = {"comes": Style.MORALE_HIGH, "refuses": Style.MORALE_MID}.get(String(e["status"]), Style.MUTED)
		var what := "%d men · %s · comes" % [int(e["men"]), String(e["why"])] if String(e["status"]) == "comes" else String(e["why"])
		if String(e["status"]) == "refuses":
			what += " · %d Regard" % Lords.MUSTER_REFUSED_REGARD
		v.add_child(_roll_row(LordTalk.short_name(e["lord"]), what, tone))
	v.add_child(_chips(["they ride in as fast as their roads allow", "the treasury feeds them · a silver a day for every ten men",
		"you lead, or name a marshal, at the council"]))
	var check: Dictionary = CrownCourt.call_check(gs, _muster_place)
	v.add_child(_button("Call the banners to %s" % _place_name(_muster_place), func():
		_act(CrownCourt.call_banners(gs, _muster_place), "Riders go out with your summons."), "CallBanners", bool(check["ok"]), true))
	if not bool(check["ok"]):
		v.add_child(_note(String(check["reason"]), Style.MORALE_LOW))
	# The quick call: two ready lords from your capital, on their own.
	var targets := _targets()
	if not targets.is_empty():
		var t: String = targets[0]
		var qc: Dictionary = gs.call_check(t)
		v.add_child(_wide_button("Or send two ready lords on their own: march on %s" % _place_name(t), func():
			_act(gs.call_to_arms(t), "Your lords gather to march on %s." % _place_name(t)), "Call_%s" % t, bool(qc["ok"])))
		if not bool(qc["ok"]):
			v.add_child(_note(String(qc["reason"])))


func _roll_row(who: String, what: String, tone: Color) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	r.add_child(Style.label(who, Style.SMALL, Style.TEXT))
	var n := _note(what, tone)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(n)
	return r


## What your lords ask of you, to settle from afar or hear at your table.
func _petitions_card() -> void:
	var list: Array = CrownCourt.petitions(gs)
	var v := _row_panel()
	v.get_parent().name = "PetitionsCard"
	v.add_child(Style.label("Petitions · %d" % list.size() if not list.is_empty() else "Petitions", Style.BODY, Style.TEXT))
	if list.is_empty():
		v.add_child(_note("Your lords ask nothing of you just now."))
		return
	v.add_child(_note("Settled from here: +%d Regard. Heard at your own table: +%d, and a castle granted there is worth +%d." % [
		Gatherings.PETITION_AFAR, Gatherings.PETITION_TABLE, Gatherings.PUBLIC_GRANT_REGARD]))
	for i in list.size():
		var p: Dictionary = list[i]
		v.add_child(_note(String(p["text"]), Style.TEXT))
		var f := _flow()
		var lid := int(p["lord"]["id"])
		f.add_child(_button(String(p["settle"]), func():
			var r: Dictionary = CrownCourt.answer(gs, p, true)
			_flash = String(r.get("text", r.get("reason", "")))
			_build(), "Settle_%d" % lid, true, true))
		if bool(p["refuse"]):
			f.add_child(_button("Refuse (%d)" % Gatherings.PETITION_REFUSED, func():
				var r: Dictionary = CrownCourt.answer(gs, p, false)
				_flash = String(r.get("text", r.get("reason", "")))
				_build(), "Refuse_%d" % lid))
		v.add_child(f)


# ---------------------------------------------------------------- the war council

func _council() -> void:
	var c: Dictionary = CrownCourt.council_check(gs)
	if not bool(c["ok"]):
		tab = "court"
		_court()
		return
	var place := String(gs.muster["place"])
	var here: Array = CrownCourt.arrived(gs)
	var all: Array = CrownCourt.muster_lords(gs)
	var h := _row_panel(Style.ENEMY)
	h.get_parent().name = "Council"
	h.add_child(Style.label("War council at %s" % _place_name(place), Style.LARGE, Style.TEXT))
	h.add_child(_note("Day %d of the muster · %d lord%s in the hall · %d on the road" % [int((world.hour - float(gs.muster["called_hour"])) / 24.0) + 1,
		here.size(), "" if here.size() == 1 else "s", all.size() - here.size()]))
	for l in here:
		var v := _row_panel()
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(_lord_face(l))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Style.label(LordTalk.short_name(l), Style.BODY, Style.TEXT))
		var p = world.party(int(l.get("party", -1)))
		var counsel: Dictionary = CrownCourt.counsel(gs, l)
		words.add_child(_note("%d men · %s · %s" % [world.men_of(p.army) if p != null else 0, String(l.get("bearing", "")), String(counsel["says"])]))
		top.add_child(words)
		v.add_child(top)
	for l in all:
		if here.has(l):
			continue
		var p = world.party(int(l.get("party", -1)))
		_row_panel().add_child(_note("Still on the road: %s · %d men · %s away" % [LordTalk.short_name(l), world.men_of(p.army) if p != null else 0,
			CrownCourt._ride_words(world._hours(p, p.next if p.moving() else p.node, place)) if p != null else "far"]))
	var aims: Array = CrownCourt.aims(gs)
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
	var v := _row_panel(Data.crown_color)
	v.add_child(Style.label("The aim", Style.BODY, Style.TEXT))
	for a in aims:
		var aid := String(a["id"])
		v.add_child(_wide_button("%s · %s" % [String(a["label"]), String(a["sub"])] if String(a["sub"]) != "" else String(a["label"]), func():
			_aim = aid
			_build(), "Aim_" + aid, bool(a["ok"]), aid == _aim))
	v.add_child(_note("Who leads", Style.BRASS))
	var marshal: Dictionary = CrownCourt.lord_marshal(gs)
	v.add_child(Widgets.segmented(["You", LordTalk.short_name(marshal) if not marshal.is_empty() else "A lord"], 0 if _you_lead else 1, func(i: int):
		_you_lead = i == 0
		_build(), "Lead"))
	v.add_child(_note("Led by you, the host follows your company and fights where you fight, sieges too. Led by a lord, it marches on its own." if _you_lead
		else "%s leads the host as marshal and marches on his own. You may ride with it from its sheet on the map." % (LordTalk.short_name(marshal) if not marshal.is_empty() else "A lord")))
	var prov: Dictionary = CrownCourt.provisions(gs)
	v.add_child(_chips(["%d men" % int(prov["men"]),
		("%d days of provisions · %d silver from the treasury (%d)" % [int(prov["days"]), int(prov["cost"]), int(prov["treasury"])]) if bool(prov["paid"])
			else "the treasury can't pay %d for provisions: three days out" % int(prov["cost"]),
		"+%d Regard with each lord who rides, once" % Lords.MUSTER_RIDE_REGARD,
		"a lord whose counsel you pass over: %d" % Lords.COUNSEL_IGNORED_REGARD]))
	var mc: Dictionary = CrownCourt.march_check(gs, chosen, _you_lead) if not chosen.is_empty() else {"ok": false, "reason": "nothing to do"}
	var bf := _flow()
	bf.add_child(_button("March!", func():
		var ok: bool = CrownCourt.march(gs, chosen, _you_lead)
		if ok:
			Sound.play("horn")
			tab = "court"
		_act(ok, "The council rises. Your banners ride."), "March", bool(mc["ok"]), true))
	bf.add_child(_button("Not yet", func():
		tab = "court"
		_build(), "NotYet"))
	bf.add_child(_button("Dismiss the banners", func():
		CrownCourt.dismiss(gs)
		tab = "court"
		_act(true, "You dismiss the banners. Your lords ride home."), "Dismiss"))
	v.add_child(bf)
	if not bool(mc["ok"]):
		v.add_child(_note(Gatherings.upper_first(String(mc["reason"])) + ".", Style.MORALE_LOW))


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
