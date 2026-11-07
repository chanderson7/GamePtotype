## Saves beyond the autosave: up to eight of your own, plus two the game keeps for you
## (just before your last battle, and when you last entered a settlement). Each is its
## own file; a small index holds a summary of each (day, place, men, silver, captains...)
## so the list and "what going back undoes" never need to load a campaign. Each file also
## carries its own index entry ("slot"), so a lost or damaged index is rebuilt from the
## files. Files and index are written whole to a temporary file and then renamed into
## place, so a crash mid-write never leaves half a save.
## An Ironman campaign has none of these: the autosave is its only save.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const Captains = preload("res://scripts/data/captains.gd")
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")

const MAX_OWN := 8
const BATTLE := "battle"
const ARRIVAL := "arrival"
const OWN := "own"

const DEFAULT_DIR := "user://saves"
## Where saves live; tests point this somewhere of their own.
static var dir := DEFAULT_DIR


static func _index_path() -> String:
	return dir + "/index.json"


static func _file(id: String) -> String:
	return "%s/%s.json" % [dir, id]


# ---------------------------------------------------------------- reading

## Every save, newest first. An index that's missing, unreadable or empty while save
## files remain is rebuilt from the files.
static func list() -> Array:
	var path := _index_path()
	var data = null
	if FileAccess.file_exists(path):
		data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_ARRAY or (data as Array).is_empty():
		data = rebuild_index()
	var out := []
	for e in data:
		if typeof(e) == TYPE_DICTIONARY and FileAccess.file_exists(_file(String(e.get("id", "")))):
			out.append(e)
	out.sort_custom(func(a, b): return float(a.get("saved", 0)) > float(b.get("saved", 0)))
	return out


static func own() -> Array:
	return list().filter(func(e): return String(e.get("kind", "")) == OWN)


static func automatic() -> Array:
	return list().filter(func(e): return String(e.get("kind", "")) != OWN)


static func entry(id: String) -> Dictionary:
	for e in list():
		if String(e["id"]) == id:
			return e
	return {}


## The save Revert goes back to: the newest of any kind.
static func latest() -> Dictionary:
	var all := list()
	return all[0] if not all.is_empty() else {}


static func spaces_left() -> int:
	return maxi(0, MAX_OWN - own().size())


# ---------------------------------------------------------------- writing

## A save of your own, named after the day and place. Empty when Ironman or all eight
## spaces are used.
static func save_own(gs, name: String = "") -> Dictionary:
	if gs.ironman or gs.world == null or spaces_left() == 0:
		return {}
	var id := "own_%d" % Time.get_ticks_usec() + "_%d" % int(Time.get_unix_time_from_system())
	return _write(gs, id, OWN, name)


## Put where you are now into one of your own saves, keeping its name.
static func overwrite(gs, id: String) -> Dictionary:
	var old := entry(id)
	if gs.ironman or gs.world == null or old.is_empty() or String(old["kind"]) != OWN:
		return {}
	return _write(gs, id, OWN, String(old.get("name", "")))


## A save the game keeps for you: one before battle, one on entering a settlement, each
## replaced by the next.
static func checkpoint(gs, kind: String, label: String) -> Dictionary:
	if gs.ironman or gs.world == null:
		return {}
	return _write(gs, kind, kind, label)


static func rename(id: String, name: String) -> bool:
	var all := list()
	for e in all:
		if String(e["id"]) == id and String(e["kind"]) == OWN:
			e["name"] = name.strip_edges().left(40)
			return _write_index(all)
	return false


static func delete(id: String) -> bool:
	var all := list()
	var kept := all.filter(func(e): return String(e["id"]) != id)
	if kept.size() == all.size():
		return false
	DirAccess.remove_absolute(_file(id))
	return _write_index(kept)


## Forget every save (a new campaign starts clean): every file in the folder, listed or
## not, so none comes back when the index is next rebuilt.
static func clear() -> void:
	var folder := DirAccess.open(dir)
	if folder == null:
		return
	for f in folder.get_files():
		if f.ends_with(".json") or f.ends_with(".tmp"):
			DirAccess.remove_absolute(dir + "/" + f)


## Load a save into the game. It becomes the autosave too, so Continue picks up from it.
## A save from a newer version of the game is refused, and neither it nor the autosave is
## touched.
static func load_into(gs, id: String) -> bool:
	var path := _file(id)
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("army"):
		return false
	if gs.is_newer_save(int(data.get("version", 0))):
		return false
	if not gs.from_dict(data):
		return false
	gs.pending_battle = {}
	gs.save_game()
	return true


static func _write(gs, id: String, kind: String, name: String) -> Dictionary:
	# A game that isn't saving (tests) leaves the real saves alone.
	if not gs.persist and dir == DEFAULT_DIR:
		return {}
	DirAccess.make_dir_recursive_absolute(dir)
	var data: Dictionary = gs.to_dict()
	var s := summary(gs)
	var e := {"id": id, "kind": kind, "saved": Time.get_unix_time_from_system(), "summary": s,
		"version": int(data.get("version", 0)),
		"name": name if name != "" else "Day %d · %s" % [int(s["day"]), s["place_name"]]}
	# The file carries its own entry, so the index can be rebuilt from the files.
	data["slot"] = e
	if not _write_whole(_file(id), JSON.stringify(data, "", true, true)):
		return {}
	var all := list().filter(func(x): return String(x["id"]) != id)
	all.append(e)
	_write_index(all)
	return e


static func _write_index(all: Array) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	return _write_whole(_index_path(), JSON.stringify(all))


## Write `text` to a temporary file beside `path`, then rename it into place: the old file
## stays whole until the new one is.
static func _write_whole(path: String, text: String) -> bool:
	var temporary := path + ".tmp"
	var f := FileAccess.open(temporary, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true


## The index made again from the save files themselves (each carries its own entry; one
## written before they did gets a summary read from the campaign in it). Written back,
## and returned.
static func rebuild_index() -> Array:
	var out := []
	var folder := DirAccess.open(dir)
	if folder == null:
		return out
	for f in folder.get_files():
		if not f.ends_with(".json") or f == "index.json":
			continue
		var e := _entry_from_file(f.get_basename())
		if not e.is_empty():
			out.append(e)
	if not out.is_empty():
		_write_index(out)
	return out


static func _entry_from_file(id: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(_file(id)))
	if typeof(data) != TYPE_DICTIONARY or not data.has("army"):
		return {}
	var slot = data.get("slot")
	if typeof(slot) == TYPE_DICTIONARY and typeof(slot.get("summary")) == TYPE_DICTIONARY:
		var kept: Dictionary = (slot as Dictionary).duplicate(true)
		kept["id"] = id
		return kept
	var kind: String = id if id in [BATTLE, ARRIVAL] else OWN
	var s := raw_summary(data)
	var named := "Day %d · %s" % [int(s["day"]), String(s["place_name"])]
	return {"id": id, "kind": kind, "saved": float(FileAccess.get_modified_time(_file(id))), "summary": s,
		"version": int(data.get("version", 0)), "name": named}


# ---------------------------------------------------------------- summaries

## What the save list shows and what going back is weighed against.
static func summary(gs) -> Dictionary:
	var w = gs.world
	var hour := int(w.hour) if w != null else 0
	var node := String(w.player().node) if w != null and w.player() != null else ""
	var captains := []
	for e in gs.army:
		var c = e.get("captain")
		if typeof(c) == TYPE_DICTIONARY:
			var face := Captains.face_record(c)
			face["specialization"] = String(c.get("specialization", ""))
			captains.append(face)
	var fallen := []
	for m in gs.fallen:
		if typeof(m) == TYPE_DICTIONARY:
			fallen.append(int(m.get("id", -1)))
	var letters := 0
	if w != null and w.get("social") != null:
		letters = w.social.letters.size()
	return {"day": hour / 24 + 1, "hour": hour, "place": node,
		"place_name": String(Data.settlement(node)["name"]) if Data.SETTLEMENTS.has(node) else "the road",
		"men": gs.total_men(), "silver": int(gs.silver), "food": gs.food_days(), "renown": int(gs.renown),
		"battles": int(gs.battles), "wins": int(gs.wins), "culture": String(gs.culture),
		"captains": captains, "fallen": fallen, "letters": letters,
		"scene": SettlementScene.params(w, node) if Data.SETTLEMENTS.has(node) else {}}


## A summary read straight from a saved campaign, without loading it: what the list needs
## for a save whose index entry was lost. It has no settlement picture.
static func raw_summary(data: Dictionary) -> Dictionary:
	var hour := 0
	var node := ""
	var letters := 0
	var w = data.get("world")
	if typeof(w) == TYPE_DICTIONARY:
		hour = int(w.get("hour", 0))
		var parties = w.get("parties", [])
		if typeof(parties) == TYPE_ARRAY:
			for p in parties:
				if typeof(p) == TYPE_DICTIONARY and String(p.get("kind", "")) == "player":
					node = String(p.get("node", ""))
					break
		var social = w.get("social")
		if typeof(social) == TYPE_DICTIONARY and typeof(social.get("letters")) == TYPE_ARRAY:
			letters = (social["letters"] as Array).size()
	var men := 0
	var captains := []
	var army = data.get("army", [])
	if typeof(army) == TYPE_ARRAY:
		for squad in army:
			if typeof(squad) != TYPE_DICTIONARY:
				continue
			men += int(squad.get("men", 0))
			var c = squad.get("captain")
			if typeof(c) == TYPE_DICTIONARY:
				var face := Captains.face_record(c)
				face["specialization"] = String(c.get("specialization", ""))
				captains.append(face)
	var fallen := []
	var dead = data.get("fallen", [])
	if typeof(dead) == TYPE_ARRAY:
		for m in dead:
			if typeof(m) == TYPE_DICTIONARY:
				fallen.append(int(m.get("id", -1)))
	return {"day": hour / 24 + 1, "hour": hour, "place": node,
		"place_name": String(Data.settlement(node)["name"]) if Data.SETTLEMENTS.has(node) else "the road",
		"men": men, "silver": int(data.get("silver", 0)), "food": int(data.get("food", 0)) / maxi(1, men),
		"renown": int(data.get("renown", 0)), "battles": int(data.get("battles", 0)), "wins": int(data.get("wins", 0)),
		"culture": String(data.get("culture", "")), "captains": captains, "fallen": fallen, "letters": letters,
		"scene": {}}


## What going from `now` back to `then` changes: the numbers side by side, what is
## undone, and the captains who'd be back with you.
static func changes(then: Dictionary, now: Dictionary) -> Dictionary:
	var rows := [
		["Day", "%d · %02d:00" % [int(now["day"]), int(now["hour"]) % 24], "%d · %02d:00" % [int(then["day"]), int(then["hour"]) % 24]],
		["Men", str(int(now["men"])), str(int(then["men"]))],
		["Silver", str(int(now["silver"])), str(int(then["silver"]))],
		["Renown", str(int(now["renown"])), str(int(then["renown"]))],
	]
	var undone := []
	var hours := int(now["hour"]) - int(then["hour"])
	if hours > 0:
		undone.append(["time", "%s of travel and work" % span(hours)])
	var fought := int(now["battles"]) - int(then["battles"])
	var won := int(now["wins"]) - int(then["wins"])
	if fought > 0:
		undone.append(["battle", ("A battle" if fought == 1 else "%d battles" % fought) + (" (won)" if fought == 1 and won == 1 else (" (lost)" if fought == 1 and won == 0 else " (%d won)" % won))])
	var then_caps := {}
	for c in then.get("captains", []):
		then_caps[int(c["id"])] = c
	var now_ids := {}
	for c in now.get("captains", []):
		var id := int(c["id"])
		now_ids[id] = true
		if not then_caps.has(id):
			undone.append(["captain", "%s joining you" % c["first"]])
		elif String(then_caps[id].get("specialization", "")) == "" and String(c.get("specialization", "")) != "":
			undone.append(["rise", "%s's training as %s" % [c["first"], String(c["specialization"]).capitalize()]])
	var letters := int(now.get("letters", 0)) - int(then.get("letters", 0))
	if letters > 0:
		undone.append(["letter", "A letter you received" if letters == 1 else "%d letters you received" % letters])
	var back := []
	var fallen_now: Array = now.get("fallen", [])
	for id in then_caps:
		if not now_ids.has(id):
			var c: Dictionary = then_caps[id]
			back.append({"face": c, "text": "%s, who has fallen since" % c["first"] if fallen_now.has(id) else "%s, who has left since" % c["first"]})
	return {"rows": rows, "undone": undone, "back": back}


## "1 day 17 hours", "5 hours".
static func span(hours: int) -> String:
	var d := hours / 24
	var h := hours % 24
	var parts := []
	if d > 0:
		parts.append("%d day%s" % [d, "" if d == 1 else "s"])
	if h > 0 or d == 0:
		parts.append("%d hour%s" % [h, "" if h == 1 else "s"])
	return " ".join(parts)


## When a save was made, in the player's own time: "Just now", "12 min ago",
## "Today 21:14", "Yesterday 20:02", "3 Nov".
static func when(saved: float) -> String:
	var now := Time.get_unix_time_from_system()
	var ago := now - saved
	if ago < 60.0:
		return "Just now"
	if ago < 3600.0:
		return "%d min ago" % int(ago / 60.0)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(int(saved) + bias)
	var today := Time.get_datetime_dict_from_unix_time(int(now) + bias)
	var days := int((int(now) + bias) / 86400) - int((int(saved) + bias) / 86400)
	if days == 0:
		return "Today %02d:%02d" % [t["hour"], t["minute"]]
	if days == 1:
		return "Yesterday %02d:%02d" % [t["hour"], t["minute"]]
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s" % [t["day"], months[int(t["month"]) - 1]] + ("" if t["year"] == today["year"] else " %d" % t["year"])
