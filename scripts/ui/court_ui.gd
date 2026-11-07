## Pieces the court's screens share (the Crown screen's Court tab and your own hall): a
## lord's face, Regard in colour, round glyph buttons, a strip of numbers, bottom sheets,
## and the sheet that holds the court's rules, so the cards themselves can stay short.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const Lords = preload("res://scripts/data/lords.gd")


static func lord_face(l: Dictionary) -> TextureRect:
	var face := TextureRect.new()
	face.texture = CaptainArt.texture(LordVoice.portrait_record(l))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(60, 80)
	return face


## A lord's portrait in the game's arched frame, `w` wide.
static func face(l: Dictionary, w: float, dim: bool = false) -> Control:
	var f := Widgets.framed(lord_face(l), Vector2(w, roundf(w * 1.25)), dim)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f


## A round button with a glyph: "?" (the rules), "⋯" (more), "×" (close), "‹" (back).
## Each glyph is drawn as its icon; the word goes in the tooltip.
const GLYPH_ICONS := {"?": ["book", "How it works"], "⋯": ["menu", "More"], "×": ["cancel", "Close"], "‹": ["back", "Back"]}


static func round_button(text: String, act: Callable, id: String) -> Button:
	var b := Button.new()
	b.name = id
	if GLYPH_ICONS.has(text):
		b.icon = Widgets.icon(String(GLYPH_ICONS[text][0]))
		b.tooltip_text = String(GLYPH_ICONS[text][1])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 36)
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(c, Style.MUTED)
	else:
		b.text = text
	b.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
	b.add_theme_color_override("font_color", Style.MUTED)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, Style.box(Color(0, 0, 0, 0), Style.RULE, 2, 40))
	b.pressed.connect(func():
		Sound.play("click", 0.0, 0.05)
		act.call())
	return b


## Coloured words: a Regard change in green or red, inside a line of text.
static func n(v: int) -> String:
	return "[color=#%s]%+d[/color]" % [Style.MORALE_HIGH.to_html(false) if v >= 0 else Style.ENEMY_LIGHT.to_html(false), v]


## Words with colour in them (bbcode), wrapping.
static func rich(bb: String, color: Color = Style.MUTED, size_px: int = Style.SMALL) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", Style.text_size(size_px))
	r.add_theme_color_override("default_color", color)
	r.text = bb
	return r


## The icon each strip word takes, when a cell doesn't name its own.
const STRIP_ICONS := {"silver": "silver", "silver a day": "silver", "purse": "silver", "rations": "food", "men": "men",
	"nights": "moon", "all in": "day", "days": "day", "treasury": "chest", "in the hall": "keep", "lords": "crown"}


## Numbers side by side, each with its icon: [[value, word], ...] or [[value, word, icon]].
static func strip(cells: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Strip"
	var sb := Style.box(Style.PANEL, Style.RULE, 2, 14)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var g := GridContainer.new()
	g.columns = mini(maxi(1, cells.size()), 4)
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 10)
	for c in cells:
		var word := String(c[1])
		var key := String(c[2]) if c.size() > 2 else String(STRIP_ICONS.get(word, ""))
		var v := VBoxContainer.new()
		v.name = "Cell_%s" % (key if key != "" else word.replace(" ", "_"))
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		var top := HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_theme_constant_override("separation", 6)
		if key != "":
			top.add_child(Widgets.icon_rect(key, 30.0))
		var big := Style.label(String(c[0]), Style.BODY, Style.TEXT)
		big.name = "Value"
		top.add_child(big)
		v.add_child(top)
		var w := Style.label(word, Style.SMALL, Style.MUTED)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w.clip_text = true
		v.add_child(w)
		g.add_child(v)
	p.add_child(g)
	return p


## A sheet that slides over the page from the bottom; tap above it or its ✕ to close.
## Built on Widgets.sheet; `title` heads it (or set it after with sheet_title).
static func sheet(parent: Node, sheet_name: String, _insets: Dictionary = {}, title: String = "") -> VBoxContainer:
	var old := parent.get_node_or_null(sheet_name)
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	return Widgets.sheet(parent as Control, title, sheet_name)


## A sheet's title (the sheet has its own ✕). `_close_on` is kept for older callers.
static func sheet_title(v: VBoxContainer, text: String, _close_on: Control = null) -> void:
	var n: Node = v
	while n != null and n.name != "SheetPanel":
		n = n.get_parent()
	var t: Label = n.find_child("SheetTitle", true, false) as Label if n != null else null
	if t == null:
		v.add_child(Style.label(text, Style.LARGE, Style.BRASS))
		return
	t.text = text
	if text.length() > 18:
		t.add_theme_font_size_override("font_size", Style.text_size(Style.LARGE))


## Everything the cards no longer spell out, read once.
static func open_rules(parent: Control, insets: Dictionary = {}) -> void:
	var body := sheet(parent, "RulesSheet", insets, "The king's court")
	body.add_theme_constant_override("separation", 14)
	var head := func(text: String):
		body.add_child(Widgets.section(text))
	var rule := func(term: String, bb: String):
		body.add_child(rich("[color=#%s]%s[/color]   %s" % [Style.TEXT.to_html(false), term, bb]))
	head.call("Gatherings")
	rule.call("Anywhere", "At your seat or any hall you hold. In a lord's hall, they host in your name: %s." % n(Gatherings.HOST_IN_NAME_REGARD))
	rule.call("The first night", "Be there, or the lords you're winning over: %s." % n(Gatherings.ABSENT_KING_REGARD))
	rule.call("Their lieges", "Asking a liege's lords without the liege is a snub: %s." % n(Gatherings.SNUB_REGARD))
	head.call("At your own table")
	rule.call("Seat of honour", "One lord, %s. Lords of more renown, %s." % [n(Gatherings.HONOUR_REGARD), n(Gatherings.PASSED_OVER_REGARD)])
	rule.call("Petitions", "Heard at table %s, from afar %s, refused %s. A castle granted before everyone %s, and %s with each lord who sees it." % [
		n(Gatherings.PETITION_TABLE), n(Gatherings.PETITION_AFAR), n(Gatherings.PETITION_REFUSED), n(Gatherings.PUBLIC_GRANT_REGARD), n(Gatherings.PUBLIC_GRANT_WITNESS)])
	rule.call("The speech", "Needs renown %d. %s with each lord in the hall; at war, your sworn lords ride when called for a week." % [Gatherings.SPEECH_RENOWN, n(Gatherings.SPEECH_REGARD)])
	rule.call("Gifts", "%d silver a head, %s each." % [Gatherings.KING_GIFT_SILVER, n(Gatherings.KING_GIFT_REGARD)])
	rule.call("The tourney", "Up to %d of your captains against each lord's champion. Purse %d. Wounds, never deaths." % [Gatherings.TOURNEY_CAPTAINS, Gatherings.TOURNEY_PURSE])
	head.call("The banners")
	rule.call("Who rides", "Every sworn lord. Those holding a place by your order stay, and captives. A bought lord who thinks little of you refuses: %s." % n(Lords.MUSTER_REFUSED_REGARD))
	rule.call("Upkeep", "%d silver a day for every ten men, from the treasury. Unfed more than a day, they go home." % Lords.MUSTER_SILVER_PER_10)
	rule.call("The council", "Sits once %d lords are in the hall. Provisions paid up front: %d days out. Unpaid: %d." % [
		Lords.ARMY_MIN_MEMBERS, int(Lords.HOST_PAID_HOURS / 24.0), int(Lords.HOST_UNPAID_HOURS / 24.0)])
	rule.call("Who leads", "You: they ride with you and join your fights and sieges. A lord: the host marches on its own. Only a lord leads a raid.")
	rule.call("Regard", "Each lord who rides %s, once. Counsel you pass over %s. An Honorable lord asked to raid rides home, %s." % [
		n(Lords.MUSTER_RIDE_REGARD), n(Lords.COUNSEL_IGNORED_REGARD), n(Lords.RAID_REFUSED_REGARD)])


## Any portrait texture in the arched frame, `w` wide.
static func portrait(tex: Texture2D, w: float, dim: bool = false) -> Control:
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var f := Widgets.framed(pic, Vector2(w, roundf(w * 1.25)), dim)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f


## A face you tap: a portrait over a first name, lit in brass when chosen.
static func face_button(tex: Texture2D, label: String, id: String, act: Callable, lit: bool = false, w: float = 64.0) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, roundf(w * 1.25) + 52.0)
	var box := Style.box(Color(Style.BRASS, 0.18) if lit else Color(0, 0, 0, 0), Style.BRASS if lit else Color(0, 0, 0, 0), 2, 14)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, box)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	var f := portrait(tex, w, not lit)
	f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(f)
	var nm := Style.label(label, Style.SMALL, Style.TEXT if lit else Style.MUTED)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	col.add_child(nm)
	b.add_child(col)
	b.pressed.connect(func():
		Sound.play("click", 0.0, 0.05)
		act.call())
	return b
