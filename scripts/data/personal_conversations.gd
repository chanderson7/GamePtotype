## Time together: the visits you share with Edda, Farah and Kaede. Original, optional
## backstory. Nothing in a visit is scored: every answer is a right one, and what changes
## is what she says back and what she remembers later.
##
## A visit is told in parts. Each part is some lines, then a point where you say something:
## how you come in, a reaction to what she's said, and last the answer that matters most
## here. Then the closing. The scenes themselves are in visits_edda.gd, visits_farah.gd and
## visits_kaede.gd, eight each, in the order they open:
##
##   "title", "rank" (C, B, A or S), "requires_any" (visits, one of which must be done),
##   "coda" (needs the main story's commitment or friendship), "setting" (a location plate)
##   "parts": [{"face", "text", "options": [{"say", "tone", "reply", "mark", "when",
##       "face", "memory"}]}]
##   "closing", "closing_face", "summary" (the short version), "memory" (the memory book's line)
##
## Text is paragraphs with a blank line between; "Edda: " and "You: " begin a spoken one.
## A paragraph that begins "[?a,!b] " is told only when a holds and b doesn't, where a and b
## are marks, visits already shared (by id), "romantic" or "friend". An option's "mark" is
## remembered: later visits, greetings and letters read it. "when" ("romantic" or "friend")
## offers an option on that route only. "tone" is the kind of thing it is to say (TONES).
## An answer's "memory" replaces the visit's line in the memory book.
extends RefCounted

const Edda = preload("res://scripts/data/visits_edda.gd")
const Farah = preload("res://scripts/data/visits_farah.gd")
const Kaede = preload("res://scripts/data/visits_kaede.gd")

## The content's version. 1: one passage and one answer. 2: parts, with a choice in each.
## A visit finished under version 1 keeps its place in the memory book and tells itself
## again; it left no marks, and on the retelling you answer afresh (which changes nothing).
const VERSION := 2
## Presentation is versioned independently of the content.
const READER_VERSION := 2

## The kinds of thing you can say: the icon and the word under an option.
const TONES := {
	"ask": ["talk", "ask"], "tease": ["lucky", "tease"], "share": ["cup", "something of yours"],
	"comfort": ["peace", "kindly"], "quiet": ["moon", "quietly"], "help": ["bond", "lend a hand"],
	"heart": ["heart", "from the heart"], "warm": ["sun", "as a friend"],
}

static var SCENES: Dictionary = _all()


static func _all() -> Dictionary:
	var out := {}
	for source in [Edda.SCENES, Farah.SCENES, Kaede.SCENES]:
		for id in source:
			out[id] = source[id]
	return out


static func ids_for(candidate_id: String) -> Array:
	var result: Array = []
	for scene_id in SCENES:
		if String(scene_id).begins_with(candidate_id + "_"):
			result.append(scene_id)
	return result


## How many parts a visit has before its closing.
static func part_count(scene_id: String) -> int:
	return (SCENES.get(scene_id, {}).get("parts", []) as Array).size()


## What your saved answers have left behind: the marks of every option picked, in every
## visit finished (or, with `scene_id` and `picks`, in the one being told as well).
static func marks(choices: Dictionary, scene_id: String = "", picks: Array = []) -> Array:
	var out := []
	var all := choices.duplicate()
	if scene_id != "":
		all[scene_id] = picks
	for id in all:
		if not (all[id] is Array) or not SCENES.has(id):
			continue
		var parts: Array = SCENES[id]["parts"]
		var mine: Array = all[id]
		for i in mini(mine.size(), parts.size()):
			var opts: Array = parts[i]["options"]
			var p := int(mine[i])
			if p >= 0 and p < opts.size() and opts[p].has("mark") and not out.has(String(opts[p]["mark"])):
				out.append(String(opts[p]["mark"]))
	return out


## Everything a conditional line can ask about, for a visit's context: marks, visits
## already shared, and the route.
static func flags(context: Dictionary, scene_id: String = "", picks: Array = []) -> Dictionary:
	var on := {}
	for id in context.get("completed", []):
		on[String(id)] = true
	for m in marks(context.get("choices", {}), scene_id, picks):
		on[m] = true
	on["romantic" if bool(context.get("romantic", false)) else "friend"] = true
	return on


## Authored text as paragraphs, keeping only the conditional ones whose conditions hold
## (and dropping the condition itself).
static func paragraphs(text: String, on: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for p in tagged_paragraphs(text, on):
		out.append(String(p["text"]))
	return out


## The same paragraphs, each with what it was conditional on: [{text, conds}] (`conds`
## the conditions that held, without any "!").
static func tagged_paragraphs(text: String, on: Dictionary) -> Array:
	var out := []
	var buffer := PackedStringArray()
	var lines := text.split("\n")
	lines.append("")
	for raw in lines:
		var line := raw.strip_edges()
		if line != "":
			buffer.append(line)
			continue
		if buffer.is_empty():
			continue
		var para := " ".join(buffer)
		buffer.clear()
		var conds := []
		if para.begins_with("[?"):
			var end := para.find("]")
			var holds := true
			for cond in para.substr(2, end - 2).split(",", false):
				var c := cond.strip_edges()
				holds = holds and (not on.has(c.substr(1)) if c.begins_with("!") else on.has(c))
				if not c.begins_with("!"):
					conds.append(c)
			if not holds:
				continue
			para = para.substr(end + 1).strip_edges()
		out.append({"text": para, "conds": conds})
	return out


## The options offered at a part's point, for this route: [{index, say, tone, ...}]. The
## index is the option's place in the scene's own list, which is what a save keeps.
static func options(scene_id: String, part: int, context: Dictionary) -> Array:
	var out := []
	var parts: Array = SCENES.get(scene_id, {}).get("parts", [])
	if part < 0 or part >= parts.size():
		return out
	var route := "romantic" if bool(context.get("romantic", false)) else "friend"
	var all: Array = parts[part]["options"]
	for i in all.size():
		var when := String(all[i].get("when", ""))
		if when == "" or when == route:
			var o: Dictionary = (all[i] as Dictionary).duplicate()
			o["index"] = i
			out.append(o)
	return out


## Whether `choice` is one of the options offered at this part's point.
static func offers(scene_id: String, part: int, context: Dictionary, choice: int) -> bool:
	for o in options(scene_id, part, context):
		if int(o["index"]) == choice:
			return true
	return false


## The lines of one part, in order: what you said at the point before it and her answer,
## then the part's own text. Part `part_count` is the closing. Each line is
## {speaker, text, expression}. [] if the point before it hasn't been answered.
static func beats(scene_id: String, part: int, picks: Array, context: Dictionary) -> Array:
	var scene: Dictionary = SCENES.get(scene_id, {})
	if scene.is_empty():
		return []
	var parts: Array = scene["parts"]
	if part < 0 or part > parts.size() or picks.size() < part:
		return []
	var on := flags(context, scene_id, picks.slice(0, part))
	# What you said in visits before this one: a line that turns on one of these is her
	# remembering it (the route, a visit being done, or an answer given a moment ago in
	# this same visit, is not).
	var others: Dictionary = (context.get("choices", {}) as Dictionary).duplicate()
	others.erase(scene_id)
	var earlier := {}
	for m in marks(others):
		earlier[m] = true
	var closing := part == parts.size()
	var face := String(scene.get("closing_face", "warm")) if closing else String(parts[part].get("face", "neutral"))
	var result: Array = []
	if part > 0:
		var before: Array = parts[part - 1]["options"]
		var p := int(picks[part - 1])
		if p < 0 or p >= before.size():
			return []
		var said: Dictionary = before[p]
		var mine := {"speaker": "You", "text": String(said["say"]), "expression": face}
		# An answer she will keep: it leaves a mark that later visits and letters read.
		if said.has("mark"):
			mine["kept"] = true
		result.append(mine)
		_tell(result, String(said.get("reply", "")), on, String(said.get("face", face)), earlier)
	_tell(result, String(scene["closing"]) if closing else String(parts[part]["text"]), on, face, earlier)
	return result


static func _tell(into: Array, text: String, on: Dictionary, face: String, earlier: Dictionary = {}) -> void:
	for para in tagged_paragraphs(text, on):
		var speaker := "Narrator"
		var line := String(para["text"])
		for name in ["Edda", "Farah", "Kaede", "You"]:
			if line.begins_with(name + ": "):
				speaker = name
				line = line.trim_prefix(name + ": ")
				break
		var beat := {"speaker": speaker, "text": line, "expression": face}
		if speaker != "You" and (para["conds"] as Array).any(func(c): return earlier.has(c)):
			beat["remembered"] = true
		into.append(beat)


## Everything told before `part`: the earlier parts, each with the answer given.
static func told_before(scene_id: String, part: int, picks: Array, context: Dictionary) -> Array:
	var out: Array = []
	for i in part:
		out.append_array(beats(scene_id, i, picks, context))
	return out


## The memory book's line for a visit: the last answer's own, if it has one.
static func memory_text(scene_id: String, picks: Array = []) -> String:
	var scene: Dictionary = SCENES[scene_id]
	var parts: Array = scene["parts"]
	if picks.size() >= parts.size() and not parts.is_empty():
		var last: Array = parts[parts.size() - 1]["options"]
		var p := int(picks[parts.size() - 1])
		if p >= 0 and p < last.size() and last[p].has("memory"):
			return String(last[p]["memory"])
	return String(scene["memory"])


## The answers kept for a finished visit, as the reader wants them: one per part, -1 where
## none was given (the short version, or a visit from before there were parts).
static func kept_picks(scene_id: String, kept) -> Array:
	var out: Array = []
	for i in part_count(scene_id):
		out.append(int(kept[i]) if kept is Array and i < (kept as Array).size() else -1)
	return out


## A reading position made whole: which part, the answers so far, and the line within
## the part. Older positions (one passage, one answer) start the visit again.
static func normalize_reader(scene_id: String, progress: Dictionary) -> void:
	var picks: Array = []
	for p in progress.get("picks", []):
		picks.append(int(p))
	var part := clampi(int(progress.get("part", 0)), 0, mini(picks.size(), part_count(scene_id)))
	progress["part"] = part
	progress["picks"] = picks.slice(0, part)
	progress.erase("node")
	progress.erase("choice")
	var sequence := beats(scene_id, part, progress["picks"], progress.get("context", {}))
	var last := maxi(0, sequence.size() - 1)
	progress["beat"] = clampi(int(progress.get("beat", 0)), 0, last)
	progress["furthest_beat"] = clampi(int(progress.get("furthest_beat", progress["beat"])), progress["beat"], last)
	progress["reader_version"] = READER_VERSION
