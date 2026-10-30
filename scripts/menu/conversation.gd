## Interactive dialogue, audience choices, story progression, and relationship decisions.
## Pauses the map; returning never advances time or costs resources.
extends Control

const StoryArt = preload("res://scripts/ui/story_art.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

var _col: VBoxContainer
var _candidate_id := "edda"
var _dialogue_response := ""
var _selected_ch1_topic := false


func _ready() -> void:
	_candidate_id = Scenes.active_candidate_id if Scenes.active_candidate_id != "" else "edda"
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var w = GameState.world
	if w == null or w.social == null:
		_col = Page.column(self, "Audience", "No active world.")
		var err_back := Page.button("Back", _back, true)
		_col.add_child(err_back)
		return

	var p: Dictionary = w.social.get_candidate_person(_candidate_id)
	var rel: Dictionary = w.social.get_relationship(_candidate_id)
	var house: Dictionary = w.social.get_house(p.get("house_id", ""))
	var q: Dictionary = w.social.get_quest("quest_%s" % _candidate_id)
	var ch: int = int(q.get("chapter", 1))

	var status_str := Relationships.status_label(String(rel.get("status", Relationships.UNKNOWN)))
	var trust_val: int = int(rel.get("trust", 0))
	var standing_val: int = int(house.get("standing", 0))

	var subtitle := "%s · Trust: %s (%d) · House Standing: %s (%d)" % [
		status_str,
		Relationships.trust_label(trust_val), trust_val,
		Relationships.standing_label(standing_val), standing_val
	]

	_col = Page.column(self, "%s · %s" % [p["name"], p["role"]], subtitle)

	_col.add_child(StoryArt.candidate_portrait(_candidate_id, "concerned" if rel.get("strained", false) else "neutral"))

	# Active narrative or dialogue response
	var sdata: Dictionary = RomanceStories.story_data(_candidate_id)
	var chapters: Dictionary = sdata.get("chapters", {})
	var cinfo: Dictionary = chapters.get(ch, {})

	if _dialogue_response != "":
		_col.add_child(Page.note(_dialogue_response, Style.LARGE, Style.TEXT))
		_col.add_child(HSeparator.new())
	elif not cinfo.is_empty():
		_col.add_child(Page.note(String(cinfo.get("text", "")), Style.BODY, Style.TEXT))
		_col.add_child(HSeparator.new())

	# Strained breach notice if present
	if bool(rel.get("strained", false)):
		_col.add_child(Page.note("Your relationship is currently strained due to a broken promise.", Style.BODY, Color(1, 0.4, 0.4)))
		var r_data: Dictionary = cinfo.get("repair", {})
		if not r_data.is_empty():
			var rep_btn := Page.button(String(r_data.get("text", "Make Restitution")), func():
				_on_choice_selected("repair_promise", r_data.get("response", "")))
			_col.add_child(rep_btn)

	# Build chapter choices
	_build_chapter_choices(ch, cinfo, rel, house)

	_col.add_child(Page.button("Spend time / memories", func():
		Scenes.active_person_id = p["id"]
		Scenes.personal_conversation_return = "res://scenes/conversation.tscn"
		Scenes.go("res://scenes/personal_conversation.tscn")))

	# Leave button
	var leave_btn := Page.button("Leave audience", _back, true)
	_col.add_child(leave_btn)
	var heading := _col.get_child(0) as Control
	heading.focus_mode = Control.FOCUS_ALL
	heading.grab_focus()


func _build_chapter_choices(ch: int, cinfo: Dictionary, rel: Dictionary, house: Dictionary) -> void:
	if cinfo.is_empty():
		return

	match ch:
		1:
			if not _selected_ch1_topic:
				_col.add_child(Page.note("Choose a topic of conversation:"))
				for ch_item in cinfo.get("choices", []):
					var btn := Page.button(String(ch_item["text"]), func():
						_dialogue_response = String(ch_item["response"])
						_selected_ch1_topic = true
						_build())
					_col.add_child(btn)
			else:
				_col.add_child(Page.note(String(cinfo.get("intent_prompt", "Declare your intent:"))))
				for it in cinfo.get("intent_choices", []):
					var btn := Page.button(String(it["text"]), func():
						_on_choice_selected(String(it["id"]), String(it["response"])))
					_col.add_child(btn)
		2:
			_col.add_child(Page.note("How will you respond to her ambition?"))
			for ch_item in cinfo.get("choices", []):
				var btn := Page.button(String(ch_item["text"]), func():
					_on_choice_selected(String(ch_item["id"]), String(ch_item["response"])))
				_col.add_child(btn)
		3:
			_col.add_child(Page.note("Select how to aid the household:"))
			for var_item in cinfo.get("variants", []):
				var btn := Page.button("%s: %s" % [String(var_item["name"]), String(var_item["text"])], func():
					_on_choice_selected(String(var_item["id"]), String(var_item["response"])))
				_col.add_child(btn)
		4:
			if not bool(rel.get("strained", false)):
				_col.add_child(Page.note("Counsel the council:"))
				for ch_item in cinfo.get("choices", []):
					var btn := Page.button(String(ch_item["text"]), func():
						_on_choice_selected(String(ch_item["id"]), String(ch_item["response"])))
					_col.add_child(btn)
		5:
			_col.add_child(Page.note("Choose your future together:"))
			var is_romantic: bool = bool(rel.get("romantic_intent", false))
			var name := String(GameState.world.social.get_candidate_person(_candidate_id).get("name", "her"))

			if is_romantic:
				var m_pub := Page.button("Public Engagement and Marriage (100 silver, 100 food)", func():
					_on_choice_selected("marry_public", "%s accepts. Preparations begin for a public wedding." % name))
				_col.add_child(m_pub)

				var m_priv := Page.button("Private Vows (-10 House Standing if unapproved)", func():
					_on_choice_selected("marry_private", "In a quiet private place, you and %s exchange vows." % name))
				_col.add_child(m_priv)

			var f_btn := Page.button("Sworn Friendship and Alliance Pact", func():
				_on_choice_selected("friendship", "You and %s make a lasting pledge of friendship and cooperation." % name))
			_col.add_child(f_btn)

			var close_btn := Page.button("Remain close without commitment", func():
				_on_choice_selected("remain_close", "You agree to let time and quiet companionship guide what comes next."))
			_col.add_child(close_btn)

			var part_btn := Page.button("Part respectfully", func():
				_on_choice_selected("part_respectfully", "With mutual respect and fond memories, you agree to walk separate paths."))
			_col.add_child(part_btn)


func _on_choice_selected(choice_id: String, success_text: String) -> void:
	var res := GameState.apply_social_choice(_candidate_id, choice_id)
	if res.get("ok", false):
		_dialogue_response = success_text
		_build()
	else:
		_dialogue_response = "Cannot proceed: " + String(res.get("reason", "Action unavailable"))
		_build()


func _back() -> void:
	Scenes.go(Scenes.conversation_return)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
