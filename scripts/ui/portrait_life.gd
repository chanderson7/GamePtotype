## A painted portrait, alive. Edda, Farah and Kaede were painted once per expression, still;
## tools/portrait_faces.py made each painting's other faces from its own pixels (eyes shut
## and half shut, a softer look, a glance aside, a brow raised), and
## assets/shaders/portrait_life.gdshader moves the head and the loose hair.
##
## This decides, moment to moment, which face is worn and how the head sits: a breath in
## the head and the hair always; a blink now and then, in two steps; a glance aside now
## and then; and what a mood calls for (`act`): a brow lifted when amused, a small nod when
## warm, the lids lowered further and the head tilted when thoughtful (the thoughtful
## paintings already look down, so they have no glance to give), a soft look when moved. Its state lives in the
## dictionary a screen keeps for the face (TalkView keeps one per side), so a screen can
## hold any number of faces.
extends RefCounted

const StoryArt = preload("res://scripts/ui/story_art.gd")

## A blink: half shut, shut, half shut, open (seconds from its start).
const BLINK_HALF := 0.03
const BLINK_SHUT := 0.13
const BLINK_LENGTH := 0.17
const BLINK_EVERY := Vector2(2.6, 5.5)
## A glance aside of their own: how often, and how long it's held.
const GLANCE_EVERY := Vector2(7.0, 13.0)
const GLANCE_HOLD := Vector2(0.9, 1.5)
## How long each act takes.
const ACTS := {"brow": 1.5, "nod": 1.7, "glance": 1.6, "soft": 2.2}
## What each mood (StoryArt.EXPRESSIONS) calls for.
const MOODS := {"amused": "brow", "warm": "nod", "thoughtful": "soft"}


## Put `tex` (a painting) on the face kept in `f`: its other faces are found, and what the
## face was doing carries on. False, and nothing kept, if the painting has none.
static func attach(f: Dictionary, tex: Texture2D) -> bool:
	var frames := {}
	for name in StoryArt.FRAMES:
		var made := StoryArt.face_frame(tex, name)
		if made != null:
			frames[name] = made
	if not frames.has("shut"):
		for key in ["frames", "glance", "act", "t"]:
			f.erase(key)
		return false
	f["rest"] = tex
	f["shut"] = frames["shut"]
	f["frames"] = frames
	if not f.has("blink"):
		f["blink"] = {"wait": randf_range(1.2, 4.0), "left": 0.0}
	if not f.has("glance"):
		f["glance"] = {"wait": randf_range(GLANCE_EVERY.x, GLANCE_EVERY.y), "left": 0.0}
	if not f.has("act"):
		f["act"] = {}
	if not f.has("t"):
		f["t"] = randf() * 20.0
	return true


## Whether `tex` is one of the face's own pictures (resting, or one made from it).
static func wears(f: Dictionary, tex: Texture2D) -> bool:
	return tex != null and (tex == f.get("rest") or (f.get("frames", {}) as Dictionary).values().has(tex))


## The face does what `kind` is ("brow", "nod", "glance", "soft"; "" nothing).
static func act(f: Dictionary, kind: String) -> void:
	if f.has("frames") and ACTS.has(kind):
		f["act"] = {"kind": kind, "t": 0.0}


## The act a mood calls for, or "".
static func for_mood(mood: String) -> String:
	return String(MOODS.get(mood, ""))


## Advance the face by `delta` seconds. Returns the picture to wear now and how the head
## sits: {texture, tilt, drop, pitch, sway}.
static func step(f: Dictionary, delta: float) -> Dictionary:
	var t := float(f.get("t", 0.0)) + delta
	f["t"] = t
	var frames: Dictionary = f.get("frames", {})
	var face := ""
	var tilt := 1.0 * sin(t * TAU / 9.0)
	var drop := 0.7 * sin(t * TAU / 3.6)
	var pitch := 0.0
	var sway := 2.4 * sin(t * TAU / 2.6 + 0.6) + 1.0 * sin(t * TAU / 7.0)
	# What a mood called for.
	var a: Dictionary = f.get("act", {})
	if not a.is_empty():
		var at := float(a["t"]) + delta
		a["t"] = at
		match String(a["kind"]):
			"brow":
				var k := _bump(at, 0.0, 0.2, 1.0, 1.3)
				face = "brow2" if k > 0.6 else ("brow1" if k > 0.25 else "")
				tilt += 2.0 * _bump(at, 0.0, 0.3, 1.0, 1.5)
			"nod":
				var n := _bump(at, 0.0, 0.45, 1.05, 1.7)
				face = "half" if n > 0.9 else ("soft" if n > 0.3 else "")
				pitch = 2.8 * n
				drop += 0.5 * n
				tilt -= 0.6 * n
			"glance":
				face = "away" if at > 0.1 and at < 1.4 else ""
			"soft":
				var s := _bump(at, 0.0, 0.5, 1.7, 2.2)
				face = "soft" if s > 0.4 else ""
				tilt += 1.5 * s
		if at >= float(ACTS[String(a["kind"])]):
			f["act"] = {}
	# A glance aside of their own, now and then, when nothing else is going on.
	var g: Dictionary = f.get("glance", {})
	if not g.is_empty():
		if float(g["left"]) > 0.0:
			g["left"] = float(g["left"]) - delta
			if face == "":
				face = "away"
		else:
			g["wait"] = float(g["wait"]) - delta
			if float(g["wait"]) <= 0.0:
				g["wait"] = randf_range(GLANCE_EVERY.x, GLANCE_EVERY.y)
				g["left"] = randf_range(GLANCE_HOLD.x, GLANCE_HOLD.y)
	# A blink closes whatever eyes are worn.
	var b: Dictionary = f.get("blink", {})
	if not b.is_empty():
		if float(b["left"]) > 0.0:
			b["left"] = float(b["left"]) - delta
		else:
			b["wait"] = float(b["wait"]) - delta
			if float(b["wait"]) <= 0.0:
				b["wait"] = randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
				b["left"] = BLINK_LENGTH
		if float(b["left"]) > 0.0:
			var into := BLINK_LENGTH - float(b["left"])
			face = "shut" if into >= BLINK_HALF and into < BLINK_SHUT else "half"
	var tex: Texture2D = frames.get(face, f.get("rest")) if face != "" else f.get("rest")
	if face == "half" and not frames.has("half"):
		tex = frames.get("shut", f.get("rest"))
	return {"texture": tex, "tilt": tilt, "drop": drop, "pitch": pitch, "sway": sway}


## The head as it is in the painting.
const STILL := {"tilt": 0.0, "drop": 0.0, "pitch": 0.0, "sway": 0.0}


## Set the head on `node` (from step(), or STILL).
static func pose(node: CanvasItem, how: Dictionary) -> void:
	var m := node.material as ShaderMaterial if node != null else null
	if m == null:
		return
	for key in STILL:
		m.set_shader_parameter(key, float(how.get(key, 0.0)))


## 0 before a0, rising to 1 by a1, held, falling back to 0 between b0 and b1.
static func _bump(t: float, a0: float, a1: float, b0: float, b1: float) -> float:
	return smoothstep(a0, a1, t) * (1.0 - smoothstep(b0, b1, t))
