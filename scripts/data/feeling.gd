## How a line is said, read from its words: the mood on the face that says it (one of
## LordPortrait.MOODS), what their body does with it, and how the one hearing it takes it.
## Talks are written as words only; this gives them faces, so a joke is smiled at, a name
## of the dead is heard with lowered eyes, and a promise is made with set brows. A line with
## nothing in it to read keeps the speaker's resting face (which already shows their temper).
extends RefCounted

## Cues, strongest first: the first that matches a line sets its mood. Each is a mood and a
## pattern matched against the line in lower case.
const CUES := [
	["laugh", "\\bha(ha)+\\b|\\bhah\\b|\\bheh\\b|\\bhee\\b"],
	["grief", "\\b(died|grave|graves|buried|mourn\\w*|the absent|fallen|fell to)\\b|empty place|isn't there|nobody sits|poured you a cup|keep looking for"],
	["angry", "\\b(how dare|damn\\w*|curse\\w*|bastard\\w*|traitor\\w*|insult\\w*|fool|burn the world|finish what|through me|cut your|kill\\w*|blood on|dare you)\\b"],
	["amused", "doesn't count|counts double|call it even|says a lot|don't tell him|first sensible|terrible plan|very loud|it's heavy|in my pack|each other, probably|that's fair|different kind of|(^|\")deal\\.|the arrangement|you're laughing|it's allowed|first to the fire|the river didn't|uncomfortable"],
	["tender", "hold my hand|stay till|stay with me|thank you|you're kind|i'd like you to|don't tell the others|bravest thing|it's the only reason|i'll need it|i wanted you to know|i'll pretend"],
	["fear", "\\b(afraid|fear\\w*|frighten\\w*|scared|terrif\\w*|dread\\w*|shaking|shake|flinch\\w*|won't come back|nightmare\\w*|dream about)\\b"],
	["proud", "\\b(proud|victory|victorious|won(?!')|bravest|stories|verse|annals|earn it|you held|never once|done properly|well done|honou?r\\w*|glory)\\b"],
	["warm", "\\b(thank\\w*|glad|friend\\w*|trust|together|always|promise\\w*|bread|eat|sleep|rest now|we're still here|welcome|good to see|it counted|not such a bad|beside you|let's)\\b"],
	["thoughtful", "\\b(wonder\\w*|i think|do you ever|ever think|someday|when this war|perhaps|maybe|i suppose|what will)\\b"],
	["determined", "\\b(tomorrow|first into|in front|i'm always there|i always|i will|i swear|we swear|vow|on my oath|no out|stays on|i'll hold|i'll be there|keep your place)\\b"],
]
## Questions that are surprise, said alone.
const SURPRISE := ["why?", "really?", "truly?", "is there?", "you did?", "what?", "and first out?", "why mine?", "me?"]

static var _cues: Array = []
static var _you: RegEx
static var _self: RegEx


static func _ready_cues() -> void:
	if not _cues.is_empty():
		return
	for c in CUES:
		var r := RegEx.new()
		r.compile(String(c[1]))
		_cues.append([String(c[0]), r])
	_you = RegEx.new()
	_you.compile("\\byou(r|'re|rs|rself)?\\b")
	_self = RegEx.new()
	_self.compile("\\b(i|i'm|i've|i'll|my|me|mine)\\b")


## The feeling of `text` said by someone of `temper` (a captain's temperament, or ""), or
## `base` when nothing in it says otherwise: {mood, gesture}. Who says it changes how a cue
## shows: fear on a vengeful face is scorn, a tender word from a fragile one comes with a
## blush.
static func read(text: String, temper: String = "", base: String = "") -> Dictionary:
	var mood := mood_of(text, temper, base)
	return {"mood": mood, "gesture": gesture_for(mood)}


static func mood_of(text: String, temper: String = "", base: String = "") -> String:
	_ready_cues()
	var t := text.to_lower().strip_edges().replace("’", "'")
	var words := t.trim_prefix("\"").trim_suffix("\"").strip_edges()
	for c in _cues:
		if (c[1] as RegEx).search(t) == null:
			continue
		match String(c[0]):
			"fear":
				# Someone else's fear is met with scorn or comfort; their own shows.
				if _you.search(t) != null and _self.search(t) == null:
					return {"Vengeful": "tease", "Fragile": "worried"}.get(temper, "warm")
				return "fear" if t.contains("frighten") or t.contains("terrif") or t.contains("dread") else "worried"
			"tender":
				return "shy" if temper == "Fragile" else "warm"
			"angry":
				return "angry" if temper != "Fragile" else "fear"
			"determined":
				return "thoughtful" if words.ends_with("?") else "determined"
			var m:
				return m
	# Nothing to read but how it's said: a pause first is unsure, a bare "Why?" or
	# "Really?" is taken aback, an exclamation is meant. (Any other question is just asked.)
	if words.begins_with("...") or words.begins_with("…"):
		return "shy" if temper == "Fragile" else "thoughtful"
	if SURPRISE.has(words.trim_prefix("...")) or words.ends_with("!?") or words.ends_with("?!"):
		return "surprised"
	if words.ends_with("!"):
		return "determined"
	return base


## What their body does with a mood (TalkView.gesture): a laugh bounces, warmth leans in,
## hurt and fear draw back.
static func gesture_for(mood: String) -> String:
	match mood:
		"laugh", "amused":
			return "bounce"
		"warm", "tease", "angry", "determined", "proud":
			return "lean"
		"sad", "grief", "fear", "worried", "shy", "pain":
			return "back"
	return ""


## How someone of `temper` takes a line said with `mood`: the face they wear while they hear
## it. Laughter is caught, grief shared, anger met by temper.
static func reaction(mood: String, text: String = "", temper: String = "") -> String:
	var t := text.to_lower()
	if t.contains("you're laughing") or t.contains("don't laugh"):
		return "laugh" if t.contains("you're laughing") else "sad"
	match mood:
		"laugh":
			return "laugh" if temper != "Steadfast" else "amused"
		"amused", "tease":
			return "amused" if temper != "Fragile" else "shy"
		"sad", "grief":
			return "sad"
		"pain":
			return "worried"
		"angry":
			return {"Fragile": "fear", "Vengeful": "determined"}.get(temper, "grim")
		"fear", "worried":
			return {"Vengeful": "determined", "Fragile": "worried"}.get(temper, "warm")
		"warm", "proud":
			return "shy" if temper == "Fragile" and (t.contains("you") or t.contains("your")) else "warm"
		"shy":
			return "warm"
		"surprised":
			return "amused"
		"thoughtful":
			return "thoughtful"
		"determined":
			return {"Fragile": "worried", "Vengeful": "determined"}.get(temper, "proud")
	return ""


## The mood a told passage (not said by anyone) sets on everyone hearing it: names of the
## dead lower every eye, a defeat is borne grimly, a victory or a bond's rank is worn with
## pride.
static func scene(text: String) -> String:
	_ready_cues()
	var t := text.to_lower()
	if (_cues[1][1] as RegEx).search(t) != null or t.contains("lost") or t.contains("absent"):
		return "sad"
	if t.contains("defeat") or t.contains("rout") or t.contains("retreat"):
		return "grim"
	if t.contains("bandage") or t.contains("wound"):
		return "worried"
	if t.contains("victory") or t.contains("(rank"):
		return "proud"
	return ""
