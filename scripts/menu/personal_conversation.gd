## Illustrated visits: short saved beats, read-only history and immutable archive replays.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/ui/story_art.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

var _person_id := ""
var _scene_id := ""
var _replay := false
var _summary := false
var _history := false
var _progress: Dictionary = {}
var _message := ""
var _col: VBoxContainer

func _ready() -> void:
	_person_id = Scenes.active_person_id
	_build()

func _button(text: String, action: Callable, disabled: bool = false) -> Button:
	var button := Page.button(text, action)
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
	var heading := String(person["name"]) + " · Personal conversations"
	var subtitle := "Optional stories. No time or supplies spent. Every response is equally welcome."
	if not _scene_id.is_empty():
		heading = Stories.SCENES[_scene_id]["title"]
		subtitle = "Edda · Optional visit" if not _replay else "Memory · No rewards or campaign changes"
	_col = Page.column(self, heading, subtitle)
	if not _message.is_empty():
		_col.add_child(Page.note(_message, Style.BODY, Style.BRASS))
	if _scene_id.is_empty():
		_build_list(social, person, record)
	else:
		_build_reader(record)
	# Focus the heading without scrolling past the passage to the bottom controls.
	var title := _col.get_child(0) as Control
	title.focus_mode = Control.FOCUS_ALL
	title.grab_focus()

func _build_list(social, person: Dictionary, record: Dictionary) -> void:
	_col.add_child(Art.identity())
	var used: int = record["bonus_claims"].size()
	_col.add_child(Page.note("The first three new stories each grant +1 trust (maximum +3). Summaries count too. %d of 3 rewards claimed. Replays never grant rewards." % mini(used, 3)))
	var residence: String = person.get("residence", "")
	_col.add_child(Page.note("Current residence: " + String(WorldData.SETTLEMENTS.get(residence, {}).get("name", residence))))
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
	_history = false
	_replay = replay
	if replay:
		var record: Dictionary = GameState.world.social.personal_record(_person_id)
		_progress = {"node": 0, "choice": -1, "context": record["completed"][id]["context"].duplicate(true)}
		Stories.normalize_reader(id, _progress)
	else:
		var result := GameState.personal_conversation_action(_person_id, id, "begin")
		if not result.get("ok", false):
			_message = result.get("reason", "Could not start this visit.")
			_build()
			return
		_progress = result["progress"]
	_scene_id = id
	_build()

func _toolbar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_col.add_child(row)
	for item in [["Summary", func(): _summary = true; _history = false; _build()],
		["History", func(): _history = true; _summary = false; _build()],
		["Leave", _list]]:
		var b := Page.button(item[0], item[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)

func _sequence() -> Array:
	return Stories.beats(_scene_id, int(_progress["node"]), int(_progress["choice"]), _progress["context"])

func _build_reader(record: Dictionary) -> void:
	var scene: Dictionary = Stories.SCENES[_scene_id]
	_toolbar()
	if _replay:
		_col.add_child(Page.note("At the time: " + Relationships.status_label(record["completed"][_scene_id]["context"].get("status", Relationships.UNKNOWN)), Style.SMALL))
	if _summary:
		_col.add_child(Page.note("The short version", Style.LARGE, Style.BRASS))
		_col.add_child(Page.note(scene["summary"], Style.BODY, Style.TEXT))
		_button("Return to conversation", func(): _summary = false; _build())
		_button("Close memory" if _replay else "Keep this memory", func(): _finish("summary"))
		return
	if _history:
		_col.add_child(Page.note("Conversation so far", Style.LARGE, Style.BRASS))
		_button("Return to conversation", func(): _history = false; _build())
		var seen: Array = []
		if int(_progress["node"]) == 1:
			seen.append_array(Stories.beats(_scene_id, 0, -1, _progress["context"]))
		seen.append_array(_sequence().slice(0, int(_progress["furthest_beat"]) + 1))
		for beat in seen:
			_col.add_child(Page.note(beat["speaker"], Style.SMALL, Style.BRASS))
			_col.add_child(Page.note(beat["text"], Style.BODY, Style.TEXT))
		return
	var sequence := _sequence()
	var position := int(_progress["beat"])
	var beat: Dictionary = sequence[position]
	var setting := "common_room" if _scene_id in ["edda_spare_spoon", "edda_ledger_blot", "edda_place_no_task"] else ""
	_col.add_child(Art.stage(beat["expression"], setting))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 1, 12))
	_col.add_child(panel)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 12)
	panel.add_child(lines)
	lines.add_child(Page.note(beat["speaker"], Style.SMALL, Style.BRASS))
	var passage := Page.note(beat["text"], Style.BODY, Style.TEXT)
	passage.name = "CurrentPassage"
	lines.add_child(passage)
	var phase := "Opening" if int(_progress["node"]) == 0 else "After your reply"
	_col.add_child(Page.note("%s · %d / %d" % [phase, position + 1, sequence.size()], Style.SMALL))
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	_col.add_child(navigation)
	var previous := Page.button("Previous", func(): _move("previous"))
	previous.disabled = position == 0
	previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(previous)
	if position < sequence.size() - 1:
		var next := Page.button("Continue", func(): _move("advance"), true)
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(next)
	elif int(_progress["node"]) == 0:
		_col.add_child(Page.note("Your reply · every response is equally welcome", Style.SMALL))
		for i in scene["choices"].size():
			_button(scene["choices"][i], func(): _choose(i))
	else:
		_button("Close memory" if _replay else "Keep this memory", func(): _finish("finish"))
	_col.add_child(Page.note("Your place is saved as you read." if not _replay else "Exploring a memory never changes the original visit.", Style.SMALL))

func _move(action: String) -> void:
	if _replay:
		_progress["beat"] = clampi(int(_progress["beat"]) + (1 if action == "advance" else -1), 0, _sequence().size() - 1)
		_progress["furthest_beat"] = maxi(int(_progress["furthest_beat"]), int(_progress["beat"]))
	else:
		var result := GameState.personal_conversation_action(_person_id, _scene_id, action)
		if not result.get("ok", false):
			_message = result.get("reason", "Could not save your place.")
			_build()
			return
		_progress = result["progress"]
	_message = ""
	_build()

func _choose(choice: int) -> void:
	if _replay:
		_progress["choice"] = choice
		_progress["node"] = 1
		_progress["beat"] = 0
		_progress["furthest_beat"] = 0
	else:
		var result := GameState.personal_conversation_action(_person_id, _scene_id, "choose", choice)
		if not result.get("ok", false):
			_message = result.get("reason", "Could not save this response.")
			_build()
			return
		_progress = result["progress"]
	_message = ""
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
	_history = false
	_build()

func _back() -> void:
	Scenes.go(Scenes.personal_conversation_return)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _summary or _history:
			_summary = false
			_history = false
			_build()
		elif _scene_id.is_empty():
			_back()
		else:
			_list()
