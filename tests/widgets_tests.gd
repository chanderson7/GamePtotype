## The shared kit builds what it says: chips with shapes or icons, the priced button,
## sheets that close, meters with marks, badges, and nothing it makes is under SMALL.
##   godot --headless --path . -s tests/widgets_tests.gd
extends SceneTree

const Widgets = preload("res://scripts/ui/widgets.gd")
const Style = preload("res://scripts/ui/style.gd")
const Page = preload("res://scripts/ui/menu_page.gd")

var passed := 0
var failed := 0


func assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed += 1
		print("  ok    %s" % msg)
	else:
		failed += 1
		print("  FAIL  %s" % msg)


## Every label the kit makes is at least SMALL.
func _small_labels(n: Node, out: Array) -> void:
	if n is Label and (n as Label).get_theme_font_size("font_size") < Style.SMALL:
		out.append("%s '%s'" % [n.name, (n as Label).text])
	for c in n.get_children():
		_small_labels(c, out)


func _init() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var made: Array = []

	var status := Widgets.chip("Steady", Style.MORALE_HIGH)
	assert_true(status.find_child("Shape", true, false) != null and (status.find_child("Shape", true, false) as Label).text == "▲",
		"a status chip leads with its shape")
	var silver := Widgets.chip("150", Style.TEXT, "", "silver")
	assert_true(silver.find_child("Icon", true, false) != null and silver.find_child("Shape", true, false) == null,
		"a quantity chip leads with its icon and no shape")
	var gold := Widgets.chip("Promotion", Style.BRASS, "★", "", true)
	assert_true((gold.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Style.BRASS, "a gold chip has a brass edge")
	made += [status, silver, gold]

	var up := Widgets.effect("bond", 12)
	var down := Widgets.effect("silver", -40, "/day")
	assert_true((up.find_child("Text", true, false) as Label).text == "+12", "an effect says its sign")
	assert_true((down.find_child("Text", true, false) as Label).text == "−40/day", "a loss uses a real minus and its suffix")
	made += [up, down, Widgets.stat("men", "11/12"), Widgets.icon_value("clock", "8 h")]

	var hire := Button.new()
	hire.name = "Hire"
	hire.text = "Hire"
	hire.disabled = true
	var priced := Widgets.priced(hire, [["silver", "180"]], "Need 40 more silver")
	assert_true(priced.get_child(0) == hire and priced.find_child("Cost", true, false) != null, "a priced button keeps its cost under it")
	assert_true(priced.find_child("WhyNot", true, false) != null, "a greyed button says why under it")
	assert_true(hire.custom_minimum_size.y >= Style.TOUCH, "a priced button is a full touch target")
	made.append(priced)

	var m := Widgets.meter(0.5, Style.BRASS, 12.0, [0.75])
	assert_true(is_equal_approx(float(m.get_meta("frac")), 0.5), "a meter remembers its fill")
	made.append(m)

	var badge := Widgets.count_badge(3)
	var none := Widgets.count_badge(0)
	assert_true(badge.visible and not none.visible, "a count badge hides at zero")
	made += [badge, none, Widgets.rank_badge("B"), Widgets.store_tile("Granary", "food", 120, 250, "+15 a day", "Full")]

	var tile := Widgets.icon_tile("mail", "Courier", true, func(): pass)
	assert_true(tile.custom_minimum_size.y >= Style.TOUCH, "an icon tile is a full touch target")
	var info := Widgets.icon_button("book", func(): pass, "About this place", "Info")
	assert_true(info.custom_minimum_size.x >= Style.TOUCH and info.tooltip_text != "", "an icon button is a touch target with its word as a tooltip")
	var back := Widgets.back_button(func(): pass)
	assert_true(back.icon != null and back.name == "Back", "Back has the back arrow")
	made += [tile, info, back]

	var seg := Widgets.segmented(["", "Lords"], 1, func(_i): pass, "Filter", ["crown", ""])
	assert_true((seg.find_child("Tab_0", true, false) as Button).icon != null, "a segment can be an icon")
	made.append(seg)

	var two := Widgets.bottom_bar([Widgets.back_button(func(): pass), Button.new()], {}, "Bar")
	var row := two.get_child(0) as HBoxContainer
	assert_true(row.get_child(1).size_flags_stretch_ratio > row.get_child(0).size_flags_stretch_ratio, "the primary in a bottom bar is the wider")
	made.append(two)

	var card_col := Widgets.card(host, "Next pay", "in 5 h", Style.MUTED, true)
	assert_true(card_col.find_child("CardAside", true, false) != null, "a card has its aside")

	for w in made:
		host.add_child(w)
	var small: Array = []
	_small_labels(host, small)
	assert_true(small.is_empty(), "nothing the kit makes is under SMALL%s" % ("" if small.is_empty() else ": " + ", ".join(PackedStringArray(small))))

	var closed := [false]
	var col := Widgets.sheet(host, "Station a squad", "StationSheet", func(): closed[0] = true)
	assert_true(host.get_node_or_null("StationSheet") != null and col.name == "SheetBody", "a sheet opens over its host")
	Widgets.close_sheet(col)
	assert_true(closed[0], "closing a sheet from inside it runs on_close")

	assert_true(Style.time_short(0.5) == "under 1 h" and Style.time_short(8.2) == "8 h" and Style.time_short(30) == "1 day"
		and Style.time_short(72) == "3 days", "ride times read one way")

	var page_root := Control.new()
	root.add_child(page_root)
	var page := Page.frame(page_root)
	assert_true(page.name == "PageColumn" and page_root.get_node_or_null("Background") != null, "a page frame has its background and column")

	for key in ["clock", "day", "sun", "moon", "fire", "bond", "level", "vengeful", "steadfast", "fragile", "lucky", "mentor",
			"bold", "flank", "rear", "pause", "play", "fast", "menu", "peace", "sail", "militia", "armor", "damage", "chest"]:
		assert_true(Widgets.icon(key) != null, "the %s icon loads" % key)

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
