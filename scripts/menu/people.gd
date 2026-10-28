## People & Letters: known contacts, active personal quests, house pacts, and correspondence.
## Screen pauses the map; returning never advances time or spends money.
extends Control

const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

var _col: VBoxContainer
var _tab := "contacts" # "contacts", "pacts", "letters"


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	_col = Page.column(self, "People & Letters", "Allies, court contacts, house pacts, and dispatches.")

	# Navigation bar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	_col.add_child(bar)

	var btn_contacts := Button.new()
	btn_contacts.text = "Contacts"
	btn_contacts.custom_minimum_size.y = 54
	btn_contacts.pressed.connect(func(): _tab = "contacts"; _build())
	if _tab == "contacts":
		Style.make_primary(btn_contacts)
	bar.add_child(btn_contacts)

	var btn_pacts := Button.new()
	btn_pacts.text = "House Pacts"
	btn_pacts.custom_minimum_size.y = 54
	btn_pacts.pressed.connect(func(): _tab = "pacts"; _build())
	if _tab == "pacts":
		Style.make_primary(btn_pacts)
	bar.add_child(btn_pacts)

	var w = GameState.world
	var unread: int = w.social.unread_letters_count() if w != null and w.social != null else 0
	var btn_letters := Button.new()
	btn_letters.text = "Letters (%d)" % unread if unread > 0 else "Letters"
	btn_letters.custom_minimum_size.y = 54
	btn_letters.pressed.connect(func(): _tab = "letters"; _build())
	if _tab == "letters":
		Style.make_primary(btn_letters)
	bar.add_child(btn_letters)

	match _tab:
		"contacts":
			_build_contacts()
		"pacts":
			_build_pacts()
		"letters":
			_build_letters()

	var back := Page.button("Back", _back, true)
	_col.add_child(back)
	back.grab_focus()


func _build_contacts() -> void:
	var w = GameState.world
	if w == null or w.social == null:
		_col.add_child(Page.note("No active world or social records."))
		return

	_col.add_child(Page.note("COURT RESIDENTS & CANDIDATES", Style.LARGE, Style.BRASS))

	for cand_id in [RomanceStories.EDDA, RomanceStories.FARID, RomanceStories.KAEDE]:
		var p: Dictionary = w.social.get_candidate_person(cand_id)
		if p.is_empty():
			continue
		var rel: Dictionary = w.social.get_relationship(cand_id)
		var hid: String = p.get("house_id", "")
		var house: Dictionary = w.social.get_house(hid)
		var q: Dictionary = w.social.get_quest("quest_%s" % cand_id)

		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		_col.add_child(card)

		var res_name: String = String(WorldData.settlement(String(p.get("residence", "")))["name"]) if WorldData.SETTLEMENTS.has(String(p.get("residence", ""))) else String(p.get("residence", ""))
		var header_text := "%s · %s" % [p["name"], p["role"]]
		card.add_child(Page.note(header_text, Style.LARGE, Style.TEXT))

		var status_str := Relationships.status_label(String(rel.get("status", Relationships.UNKNOWN)))
		var trust_val: int = int(rel.get("trust", 0))
		var trust_str := "%s (%d)" % [Relationships.trust_label(trust_val), trust_val]
		var standing_val: int = int(house.get("standing", 0))
		var standing_str := "%s (%d)" % [Relationships.standing_label(standing_val), standing_val]

		var sub_text := "%s · Trust: %s · House Standing: %s · Residence: %s" % [
			status_str, trust_str, standing_str, res_name
		]
		card.add_child(Page.note(sub_text, Style.BODY, Style.MUTED))

		var mems: Array = rel.get("memories", [])
		if not mems.is_empty():
			card.add_child(Page.note("Latest memory: \"%s\"" % String(mems.back()), Style.SMALL, Style.BRASS))

		# Actions row
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var here: String = w.here()
		var at_same_place: bool = here != "" and here == p.get("residence", "")
		var talk_btn := Button.new()
		talk_btn.text = "Speak with %s" % p["name"] if at_same_place else "Audience (at %s)" % res_name
		talk_btn.custom_minimum_size.y = 54
		talk_btn.pressed.connect(func():
			Scenes.active_candidate_id = cand_id
			Scenes.active_person_id = p["id"]
			Scenes.conversation_return = "res://scenes/people.tscn"
			Scenes.go("res://scenes/conversation.tscn"))
		row.add_child(talk_btn)

		var map_btn := Button.new()
		map_btn.text = "Show on map"
		map_btn.custom_minimum_size.y = 54
		map_btn.pressed.connect(func():
			_back())
		row.add_child(map_btn)

		if cand_id == RomanceStories.EDDA:
			card.add_child(Page.button("Spend time / memories", func():
				Scenes.active_person_id = p["id"]
				Scenes.personal_conversation_return = "res://scenes/people.tscn"
				Scenes.go("res://scenes/personal_conversation.tscn")))
		_col.add_child(HSeparator.new())


func _build_pacts() -> void:
	var w = GameState.world
	if w == null or w.social == null:
		return

	_col.add_child(Page.note("HOUSE PACTS & COOPERATION", Style.LARGE, Style.BRASS))
	var pact_list: Dictionary = w.social.pacts
	if pact_list.is_empty():
		_col.add_child(Page.note("No active house pacts. Complete a shared service or wedding to negotiate an alliance pact."))
		return

	for hid in pact_list:
		var pact: Dictionary = pact_list[hid]
		var house: Dictionary = w.social.get_house(hid)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		_col.add_child(card)

		card.add_child(Page.note("%s · %s" % [house["name"], String(pact["status"]).capitalize()], Style.LARGE, Style.TEXT))
		var sites: Array = pact.get("protected_sites", [])
		var site_names := []
		for s in sites:
			if WorldData.SETTLEMENTS.has(s):
				site_names.append(String(WorldData.settlement(s)["name"]))
		card.add_child(Page.note("Protected districts: %s" % (", ".join(site_names) if not site_names.is_empty() else "None"), Style.BODY, Style.MUTED))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var grant_btn := Button.new()
		grant_btn.text = "Request Grant (150 silver)"
		grant_btn.custom_minimum_size.y = 54
		grant_btn.pressed.connect(func():
			var res := GameState.request_household_grant(hid)
			if res.get("ok", false):
				_build()
			else:
				var lbl := Page.note(String(res.get("reason", "Grant unavailable")), Style.BODY, Color(1, 0.4, 0.4))
				card.add_child(lbl))
		row.add_child(grant_btn)

		var sponsor_btn := Button.new()
		sponsor_btn.text = "Sponsor Muster (150 silver)"
		sponsor_btn.custom_minimum_size.y = 54
		sponsor_btn.pressed.connect(func():
			var seat: String = String(house.get("seat", ""))
			var res := GameState.sponsor_replacements(hid, seat, "settlement", 150)
			if res.get("ok", false):
				_build()
			else:
				var lbl := Page.note(String(res.get("reason", "Sponsorship failed")), Style.BODY, Color(1, 0.4, 0.4))
				card.add_child(lbl))
		row.add_child(sponsor_btn)

		_col.add_child(HSeparator.new())


func _build_letters() -> void:
	var w = GameState.world
	if w == null or w.social == null:
		return

	_col.add_child(Page.note("CORRESPONDENCE & DISPATCHES", Style.LARGE, Style.BRASS))
	var list: Array = w.social.letters
	if list.is_empty():
		_col.add_child(Page.note("No letters in your dispatch bag."))
		return

	for l in list:
		var sender_pid: String = l.get("sender_id", "")
		var person: Dictionary = w.social.get_person(sender_pid)
		var sender_name := String(person.get("name", "Unknown"))
		var dest: String = String(l.get("destination", ""))
		var dest_name := String(WorldData.settlement(dest)["name"]) if WorldData.SETTLEMENTS.has(dest) else dest

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_col.add_child(box)

		var read: bool = bool(l.get("read", false))
		var prefix := "[Unread] " if not read else ""
		box.add_child(Page.note("%sLetter from %s" % [prefix, sender_name], Style.BODY, Style.BRASS if not read else Style.TEXT))
		box.add_child(Page.note("Regarding: %s at %s" % [String(l.get("template_key", "")).replace("_", " ").capitalize(), dest_name], Style.SMALL, Style.MUTED))

		var open_btn := Button.new()
		open_btn.text = "Mark Read" if not read else "Read"
		open_btn.custom_minimum_size.y = 44
		open_btn.pressed.connect(func():
			l["read"] = true
			_build())
		box.add_child(open_btn)

		_col.add_child(HSeparator.new())


func _back() -> void:
	Scenes.go(Scenes.people_return)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
