## Optional visits and read-only memories. Main romance choices live elsewhere.
extends Control

const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

var _person_id := ""
var _scene_id := ""
var _replay := false
var _summary := false
var _progress: Dictionary = {}
var _message := ""
var _col: VBoxContainer


func _ready() -> void:
	_person_id = Scenes.active_person_id
	_build()


func _button(text: String, action: Callable, disabled: bool = false) -> Button:
	var button := Page.button(text, action)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	_col.add_child(button)
	return button


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var world = GameState.world
	if world == null or world.social == null or world.social.get_person(_person_id).is_empty():
		_col = Page.column(self, "Personal conversations", "No available contact.")
		_button("Back", _back)
		return
	var social = world.social
	var person: Dictionary = social.get_person(_person_id)
	var record: Dictionary = social.personal_record(_person_id)
	var subtitle := "Optional stories. No time or supplies spent. Every response is equally welcome."
	if _replay:
		subtitle = "Memory · recalling an earlier visit. Responses here change nothing in your campaign."
	_col = Page.column(self, String(person["name"]) + " · Personal conversations", subtitle)
	if not _message.is_empty():
		_col.add_child(Page.note(_message, Style.BODY, Style.BRASS))
	if _scene_id.is_empty():
		_build_list(social, person, record)
	else:
		_build_reader(record)
	# Focus the heading so ScrollContainer never skips the story to reveal a bottom button.
	var heading := _col.get_child(0) as Control
	heading.focus_mode = Control.FOCUS_ALL
	heading.grab_focus()


func _build_list(social, person: Dictionary, record: Dictionary) -> void:
	var used: int = record["bonus_claims"].size()
	_col.add_child(Page.note("The first three new stories each grant +1 trust (maximum +3). Summaries count too. %d of 3 rewards claimed. Replays never grant rewards." % mini(used, 3)))
	var residence: String = person.get("residence", "")
	var place: String = WorldData.SETTLEMENTS.get(residence, {}).get("name", residence)
	_col.add_child(Page.note("Current residence: " + place))
	for item in social.available_personal_conversations(_person_id, GameState.personal_conversation_context()):
		var id: String = item["scene_id"]
		var replay: bool = item.get("replay", false)
		var resume: bool = record["in_progress"].has(id)
		var prefix := "Remember: " if replay else ("Resume: " if resume else "Visit: ")
		_button(prefix + Stories.SCENES[id]["title"], func(): _open(id, replay), not item["ok"])
		_col.add_child(Page.note(item["reason"], Style.SMALL))
	_button("Back", _back)


func _open(id: String, replay: bool) -> void:
	_message = ""
	_summary = false
	_replay = replay
	if replay:
		var record: Dictionary = GameState.world.social.personal_record(_person_id)
		_progress = {"node": 0, "choice": -1, "context": record["completed"][id]["context"].duplicate(true)}
	else:
		var result := GameState.personal_conversation_action(_person_id, id, "begin")
		if not result.get("ok", false):
			_message = result.get("reason", "Could not start this visit.")
			_build()
			return
		_progress = result["progress"]
	_scene_id = id
	_build()


func _build_reader(record: Dictionary) -> void:
	var scene: Dictionary = Stories.SCENES[_scene_id]
	_col.add_child(Page.note(scene["title"], Style.LARGE, Style.BRASS))
	if _replay:
		var remembered: Dictionary = record["completed"][_scene_id]["context"]
		_col.add_child(Page.note("At the time: " + Relationships.status_label(remembered.get("status", Relationships.UNKNOWN)), Style.SMALL))
	if _summary:
		_col.add_child(Page.note(scene["summary"], Style.BODY, Style.TEXT))
		_button("Return to conversation", func(): _summary = false; _build())
		_button("Close memory" if _replay else "Keep this memory", func(): _finish("summary"))
	elif int(_progress.get("node", 0)) == 0:
		_button("Read a short summary", func(): _summary = true; _build())
		_col.add_child(Page.note(scene["opening"], Style.BODY, Style.TEXT))
		for i in scene["choices"].size():
			_button(scene["choices"][i], func(): _choose(i))
	else:
		var choice := int(_progress["choice"])
		_col.add_child(Page.note("You: " + scene["choices"][choice], Style.BODY, Style.BRASS))
		_col.add_child(Page.note(scene["responses"][choice] + "\n\n" + Stories.ending(_scene_id, _progress["context"], _progress["context"].get("completed", []), _progress["context"].get("choices", {})), Style.BODY, Style.TEXT))
		_button("Close memory" if _replay else "Keep this memory", func(): _finish("finish"))
	_button("Back to memories" if _replay else "Another time · save my place", _list)


func _choose(choice: int) -> void:
	if _replay:
		_progress["choice"] = choice
		_progress["node"] = 1
	else:
		var result := GameState.personal_conversation_action(_person_id, _scene_id, "choose", choice)
		if not result.get("ok", false):
			_message = result.get("reason", "Could not save this response.")
			_build()
			return
		_progress = result["progress"]
	_build()


func _finish(action: String) -> void:
	if not _replay:
		var result := GameState.personal_conversation_action(_person_id, _scene_id, action)
		if not result.get("ok", false):
			_message = result.get("reason", "Could not save this memory.")
			_build()
			return
		_message = "Memory kept. +1 trust." if int(result.get("trust_change", 0)) > 0 else "Memory kept. No additional trust reward."
	_list()


func _list() -> void:
	_scene_id = ""
	_replay = false
	_summary = false
	_build()


func _back() -> void:
	Scenes.go(Scenes.personal_conversation_return)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _scene_id.is_empty():
			_back()
		else:
			_list()
