## Talking to lords: what they think of you (Regard), what they like, what they want, and
## how far you've gone toward winning them to your crown. The rules only; the conversation
## screen (lord_conversation.gd) says them. Everything here reads and writes the campaign
## through GameState `gs`, and keeps what a lord remembers of your talks in their "talk"
## record, saved with the lord.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Jobs = preload("res://scripts/data/jobs.gd")
const Captains = preload("res://scripts/data/captains.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")

## Conviction a lord needs before they swear to your crown.
const CONVINCED := 100
## A lord who refuses you won't hear of it again for this long.
const REFUSAL_HOURS := 168.0
const REFUSAL_REGARD := -10
## Two arguments they dislike in one case and they refuse.
const BRISTLE_LIMIT := 2
## A story they like, one they don't mind, one they dislike.
const STORY_LIKED := 4
const STORY_PLAIN := 1
const STORY_DISLIKED := -2
## An argument for your crown they like, don't mind, dislike (conviction).
const ARGUMENT_LIKED := 15
const ARGUMENT_PLAIN := 6
const ARGUMENT_DISLIKED := -5
## Their own king's failings, once they've told you of them.
const ARGUMENT_KING := 20
## Silver toward a lord's change of sides: so much silver a point of conviction.
const SILVER_PER_POINT := 50
const SILVER_OFFERS := [500, 1000, 1800]
## Regard counts this much toward conviction (once above zero), and each job done for
## them this much more.
const REGARD_SHARE := 0.5
const JOB_CONVICTION := 10
## A job done for a lord.
const JOB_REGARD := 15
const HAGGLE_REGARD := -2
const HAGGLE_SILVER := {Lords.DARING: 300, Lords.CAUTIOUS: 300, Lords.HONORABLE: 250, Lords.CRUEL: 200}
## How far a band can be from a lord's seat to be their trouble.
const TROUBLE_REACH := 420.0
## Single combat: what winning and losing does.
const DUEL_WIN_REGARD := 10
const DUEL_WIN_REGARD_MILD := 5
const DUEL_LOSE_REGARD := -5
const DUEL_RENOWN := 20
const DUEL_WAIT_HOURS := 72.0
## Tribute to a Cruel lord blocking your road.
const TRIBUTE := 300
const TRIBUTE_REGARD := 5
## Captives.
const CHAINS_REGARD := -15
const CHAINS_HONORABLE := -3

const PRUDENCE := "prudence"
const BOLDNESS := "boldness"
const MODESTY := "modesty"
const FEAR := "fear"
const LIKES := {Lords.CAUTIOUS: PRUDENCE, Lords.DARING: BOLDNESS, Lords.HONORABLE: MODESTY, Lords.CRUEL: FEAR}
const DISLIKES := {Lords.CAUTIOUS: BOLDNESS, Lords.DARING: PRUDENCE, Lords.HONORABLE: FEAR, Lords.CRUEL: MODESTY}
const THEME_WORDS := {PRUDENCE: "a plan", BOLDNESS: "daring", MODESTY: "modesty", FEAR: "a hard hand"}

## Stories the company always has to tell, one of each kind.
const TALES := {
	"tale_prudence": {"theme": PRUDENCE, "title": "Holding the high ground",
		"says": "We once waited two days on a hill for brigands to come to us. Not a man lost."},
	"tale_boldness": {"theme": BOLDNESS, "title": "The charge at dawn",
		"says": "We rode into a camp of twice our number before they'd lit their fires. They never formed up."},
	"tale_modesty": {"theme": MODESTY, "title": "The spoils we gave back",
		"says": "We left a village half of what we took from the raiders who'd robbed it. They needed it more."},
	"tale_fear": {"theme": FEAR, "title": "The last brigands who crossed us",
		"says": "The last band that robbed our wagons, we hanged at the crossroads. The road has been quiet since."},
}

## Regard in words, from the bottom.
const STANDING := [[-50, "Hostile"], [-15, "Bitter"], [0, "Cool"], [10, "Civil"], [30, "Friendly"], [60, "Warm"], [101, "Devoted"]]


# ---------------------------------------------------------------- regard

## The lord's talk record, made on first use.
static func record(l: Dictionary) -> Dictionary:
	if not (l.get("talk") is Dictionary):
		l["talk"] = {}
	return l["talk"]


## What a lord thinks of you, -100 to 100: what you've done to them and for them, on top of
## what their realm thinks of you and how famous your company is.
static func regard(gs, l: Dictionary) -> int:
	if gs == null or l.is_empty():
		return 0
	var id := int(l.get("id", -1))
	var realm := String(l.get("realm", ""))
	var seed := int(round(gs.relation_with_realm(realm) * 0.25))
	var fame := mini(int(gs.renown) / 50, 6)
	if String(l.get("bearing", "")) in [Lords.DARING, Lords.CRUEL]:
		fame *= 2
	seed += fame
	if realm == Data.CROWN:
		seed += 10
	elif gs.world != null and gs.world.relation_to_player(realm) == "hostile":
		seed -= 10
	return clampi(gs.relation_with_lord(id) + seed, -100, 100)


static func standing(value: int) -> String:
	for step in STANDING:
		if value < int(step[0]):
			return String(step[1])
	return "Devoted"


## "+12 Friendly".
static func regard_text(value: int) -> String:
	return "%s%d %s" % ["+" if value > 0 else "", value, standing(value)]


static func change_regard(gs, l: Dictionary, amount: int) -> void:
	if amount != 0:
		gs.add_lord_relation(int(l["id"]), amount)


## The lord's first name and house without their title: "Cato Eastbrook".
static func short_name(l: Dictionary) -> String:
	var parts := String(l.get("name", "")).split(" ")
	if parts.size() >= 3 and String(parts[0]) in [Lords.title(String(l.get("culture", ""))), "Lord", "Emir", "Daimyo"]:
		return " ".join(parts.slice(1))
	return String(l.get("name", ""))


static func first_name(l: Dictionary) -> String:
	var s := short_name(l).split(" ")
	return String(s[0]) if not s.is_empty() else String(l.get("name", ""))


static func ruler_name(l: Dictionary) -> String:
	var realm := String(l.get("realm", ""))
	return String(Data.FACTIONS[realm].get("ruler", "their ruler")) if Data.FACTIONS.has(realm) else "their ruler"


# ---------------------------------------------------------------- likes and stories

static func likes(l: Dictionary) -> String:
	return String(LIKES.get(String(l.get("bearing", "")), ""))


static func dislikes(l: Dictionary) -> String:
	return String(DISLIKES.get(String(l.get("bearing", "")), ""))


static func like_known(l: Dictionary) -> bool:
	return int(record(l).get("like_known", 0)) == 1


static func dislike_known(l: Dictionary) -> bool:
	return int(record(l).get("dislike_known", 0)) == 1


## Stories you could tell this lord: from your chronicle first, then the company's tales,
## each told to each lord once. [{id, theme, title, says}]
static func stories(gs, l: Dictionary) -> Array:
	var told: Array = record(l).get("stories", [])
	var out := []
	if gs.world != null:
		for e in gs.world.activity_log:
			var s := _chronicle_story(e)
			if not s.is_empty() and not told.has(s["id"]) and not out.any(func(o): return o["title"] == s["title"]):
				out.append(s)
	for id in TALES:
		if not told.has(id):
			var t: Dictionary = TALES[id].duplicate()
			t["id"] = id
			out.append(t)
	return out


## A deed from the chronicle as a story, or {} if it isn't the company's.
static func _chronicle_story(e: Dictionary) -> Dictionary:
	var kind := String(e.get("type", ""))
	var id := "log_%s_%d" % [kind, int(float(e.get("hour", 0.0)))]
	var place := String(e.get("place", ""))
	var where := String(Data.settlement(place)["name"]) if Data.SETTLEMENTS.has(place) else ""
	match kind:
		"battle_fought":
			if not String(e.get("text", "")).begins_with("Your company won"):
				return {}
			return {"id": id, "theme": PRUDENCE, "title": "The fight near %s" % where if where != "" else "A hard-won fight",
				"says": "Near %s we held our ground and let them come to us. We chose the field; they paid for it." % where if where != "" else "We held our ground and let them come to us."}
		"player_victory":
			return {"id": id, "theme": BOLDNESS, "title": "How we broke a lord's host" + (" at %s" % where if where != "" else ""),
				"says": String(e.get("text", "")).replace("Your warband", "We").replace("crushed", "rode straight through")}
		"grudge_avenged":
			return {"id": id, "theme": FEAR, "title": "A debt of blood, repaid",
				"says": "Someone killed one of ours. We found them. Nobody has tried it since."}
		"job_completed":
			return {"id": id, "theme": MODESTY, "title": "A job done quietly",
				"says": "We did a job for common folk and asked no song for it. %s" % String(e.get("text", "")).replace("Your warband completed", "It was")}
		"fief_defended":
			return {"id": id, "theme": PRUDENCE, "title": "Holding %s" % where if where != "" else "Holding our walls",
				"says": "Raiders came for our lands. We'd seen them coming for a day and were ready on the walls."}
	return {}


## Tell `story_id`: they like it, don't mind it or dislike it, and you learn which.
## Returns {ok, regard, reaction, learned}.
static func tell_story(gs, l: Dictionary, story_id: String) -> Dictionary:
	var story := {}
	for s in stories(gs, l):
		if s["id"] == story_id:
			story = s
	if story.is_empty():
		return {"ok": false}
	var t := record(l)
	var told: Array = t.get("stories", [])
	told.append(story_id)
	t["stories"] = told
	var theme := String(story["theme"])
	var name := first_name(l)
	var out := {"ok": true, "theme": theme, "learned": ""}
	if theme == likes(l):
		out["regard"] = STORY_LIKED
		out["reaction"] = _reaction(l, true)
		if not like_known(l):
			out["learned"] = "You learned: %s values %s." % [name, theme]
		t["like_known"] = 1
	elif theme == dislikes(l):
		out["regard"] = STORY_DISLIKED
		out["reaction"] = _reaction(l, false)
		if not dislike_known(l):
			out["learned"] = "You learned: %s has no taste for %s." % [name, THEME_WORDS[theme]]
		t["dislike_known"] = 1
	else:
		out["regard"] = STORY_PLAIN
		out["reaction"] = "\"A good story. The road's shorter for it.\""
	change_regard(gs, l, int(out["regard"]))
	return out


static func _reaction(l: Dictionary, liked: bool) -> String:
	match String(l.get("bearing", "")):
		Lords.CAUTIOUS:
			return "\"Good. Patience wins more wars than glory does. Most captains your age would have drowned their horses for a song.\"" if liked \
				else "\"Brave. Or lucky. Luck runs out, captain, and it usually takes the brave with it.\""
		Lords.DARING:
			return "\"Ha! That's the way of it. Fortune rides with whoever rides first.\"" if liked \
				else "\"Waiting on a hill. I'd have died of boredom before the brigands came.\""
		Lords.HONORABLE:
			return "\"That speaks well of you. A sword that serves the weak is worth ten that serve themselves.\"" if liked \
				else "\"Hanged at a crossroads. There are better ways to keep a road, captain.\""
		Lords.CRUEL:
			return "\"Good. People remember a rope longer than a sermon.\"" if liked \
				else "\"You gave it back? Then you're softer than your banner says.\""
	return "\"Hm.\""


# ---------------------------------------------------------------- news and their king

## What they'd say about their own ruler, and whether it shows doubt (which counts when
## you make your case for a crown).
static func view_of_king(gs, l: Dictionary) -> Dictionary:
	var realm := String(l.get("realm", ""))
	var ruler := ruler_name(l)
	if bool(l.get("ruler", false)):
		return {"doubts": false, "says": "\"I am the crown here. Ask me what I'll do, not what someone else will.\""}
	if realm == Data.CROWN:
		return {"doubts": false, "says": "\"Whatever you ask of me. That was the oath.\""}
	var weary := 0.0
	var lost := false
	if gs.world != null:
		weary = float(gs.world.weariness_of(realm))
		var fief := String(l.get("fief", ""))
		lost = fief == "" or gs.world.owner_of(fief) != realm or gs.world.is_burned(fief)
		for v in gs.world.villages_of(realm):
			if gs.world.is_burned(v):
				lost = true
	if weary >= 40.0 or lost:
		record(l)["doubts_king"] = 1
		return {"doubts": true, "says": "\"%s sits at %s and counts the treasury while our villages burn. I've sent riders. None come back with anything but promises.\"" % [
			ruler, Data.settlement(gs.world.capital_of(realm))["name"] if gs.world != null and gs.world.capital_of(realm) != "" else "court"]}
	return {"doubts": false, "says": "\"%s knows the business of war. I'd follow %s banner into the sea, and so would every lord of ours.\"" % [ruler, ruler + "'s"]}


# ---------------------------------------------------------------- troubles

## What a lord wants done, and whether you could do it as a job: {kind, text, band, name}
## (kind "job" for one you've taken, "bandits", "war" or "none").
static func trouble(gs, l: Dictionary) -> Dictionary:
	var name := short_name(l)
	var t := record(l)
	var job_id := String(t.get("job", ""))
	if job_id != "":
		for j in gs.active_jobs:
			if String(j.get("id", "")) == job_id:
				return {"kind": "job", "name": String(j.get("target_name", "the brigands")),
					"text": "\"The %s still ride. You gave me your word, captain.\"" % String(j.get("target_name", "brigands"))}
		t["job"] = ""
	var w = gs.world
	if w != null:
		var seat: String = w.seat_of(l)
		var home: Vector2 = Data.pos(seat)
		var best = null
		var best_d := TROUBLE_REACH
		for b in w.bands():
			var d: float = w.party_pos(b).distance_to(home)
			if d < best_d and not gs.active_jobs.any(func(j): return int(j.get("target_party_id", -2)) == b.id):
				best_d = d
				best = b
		if best != null:
			var place: String = w.nearest_place(w.party_pos(best))
			return {"kind": "bandits", "band": best.id, "name": String(best.name),
				"text": "\"%s. They bleed %s every week, and %s sends no one. I keep to my lands, but I cannot be everywhere on them.\"" % [
					String(best.name), Data.settlement(place)["name"] if Data.SETTLEMENTS.has(place) else Data.settlement(seat)["name"], ruler_name(l)]}
		for r in w.realms:
			if r != String(l.get("realm", "")) and w.at_war(String(l.get("realm", "")), r):
				return {"kind": "war", "text": "\"%s. Every week a new village burns. Beat them for me once and I'll remember it.\"" % Data.FACTIONS[r]["name"]}
	return {"kind": "none", "text": "\"My lands are quiet, for once. Ask me again when they're not.\"" if name != "" else "\"Nothing.\""}


static func haggle_silver(l: Dictionary) -> int:
	return int(HAGGLE_SILVER.get(String(l.get("bearing", "")), 250))


## Haggling sours a Cautious or Honorable lord a little.
static func haggle_cost(l: Dictionary) -> int:
	return HAGGLE_REGARD if String(l.get("bearing", "")) in [Lords.CAUTIOUS, Lords.HONORABLE] else 0


static func haggle(gs, l: Dictionary) -> int:
	var t := record(l)
	if int(t.get("haggled", 0)) == 0:
		t["haggled"] = 1
		change_regard(gs, l, haggle_cost(l))
	return haggle_silver(l)


## Take their trouble as a journal job: hunt the band. Pays Regard (and silver, if you
## haggled) when it's scattered. Returns the job, or {} if you can't take it.
static func take_trouble(gs, l: Dictionary, silver: int = 0) -> Dictionary:
	var tr := trouble(gs, l)
	if String(tr.get("kind", "")) != "bandits" or gs.active_jobs.size() >= Jobs.MAX_ACTIVE_JOBS:
		return {}
	var w = gs.world
	var band = w.party(int(tr["band"]))
	if band == null:
		return {}
	var seat: String = w.seat_of(l)
	var job := {
		"id": "lord_%d_%d_%d" % [int(l["id"]), int(band.id), int(w.hour)],
		"type": Jobs.TYPE_HUNT,
		"origin_settlement": seat,
		"title": "Clear %s, for %s" % [String(band.name), short_name(l)],
		"description": "%s asked you to scatter %s, who prey on the lands about %s." % [short_name(l), String(band.name), Data.settlement(seat)["name"]],
		"deadline": w.hour + Jobs.HUNT_DEADLINE_HOURS * 2.0,
		"reward_silver": silver,
		"reward_renown": 5,
		"reward_relation": 0,
		"target_party_id": int(band.id),
		"target_name": String(band.name),
		"for_lord": int(l["id"]),
		"reward_regard": JOB_REGARD,
	}
	gs.active_jobs.append(job)
	record(l)["job"] = job["id"]
	return job


## A job done for a lord: called when it completes.
static func job_done(gs, job: Dictionary) -> String:
	var lid := int(job.get("for_lord", -1))
	if lid < 0 or gs.world == null:
		return ""
	var l: Dictionary = gs.world.lord_by_id(lid)
	if l.is_empty():
		return ""
	var t := record(l)
	t["jobs_done"] = int(t.get("jobs_done", 0)) + 1
	t["job"] = ""
	change_regard(gs, l, int(job.get("reward_regard", JOB_REGARD)))
	return "%s hears of it: +%d Regard." % [short_name(l), int(job.get("reward_regard", JOB_REGARD))]


# ---------------------------------------------------------------- winning them over

## Whether you can make your case for your crown to this lord now: {ok, reason}.
static func persuade_check(gs, l: Dictionary) -> Dictionary:
	if not gs.is_crowned():
		return {"ok": false, "reason": "raise your own banner first"}
	if bool(l.get("ruler", false)):
		return {"ok": false, "reason": "rulers never change sides"}
	if String(l.get("realm", "")) == Data.CROWN:
		return {"ok": false, "reason": "already sworn to you"}
	if String(l.get("state", "")) == "prisoner":
		return {"ok": false, "reason": "not while they're a captive"}
	var t := record(l)
	if gs.world != null and gs.world.hour < float(t.get("refused_until", 0.0)):
		return {"ok": false, "reason": "they refused you; ask again in %d days" % ceili((float(t["refused_until"]) - gs.world.hour) / 24.0)}
	if gs.world != null and int(l.get("party", -1)) >= 0 and not MarshalArmies.for_party(gs.world, int(l["party"])).is_empty():
		return {"ok": false, "reason": "not while they march in their king's army"}
	if regard(gs, l) < -20:
		return {"ok": false, "reason": "they think too little of you"}
	return {"ok": true, "reason": ""}


## How convinced they are, 0 up: Regard (above zero), jobs done for them, their king's
## failings once told, your arguments and your silver.
static func conviction(gs, l: Dictionary) -> int:
	var t := record(l)
	var c := int(round(maxf(0.0, regard(gs, l)) * REGARD_SHARE))
	c += mini(int(t.get("jobs_done", 0)), 3) * JOB_CONVICTION
	c += int(t.get("case", 0)) + int(t.get("silver_pts", 0))
	# Guests at your own gathering arrive warmer to your case.
	if gs.has_method("gathering_conviction"):
		c += int(gs.gathering_conviction(l))
	return maxi(0, c)


static func conviction_word(c: int) -> String:
	if c >= CONVINCED:
		return "convinced"
	if c >= 70:
		return "wavering"
	if c >= 40:
		return "listening"
	return "unmoved"


## What they say when you first raise a crown.
static func objection(l: Dictionary) -> String:
	match String(l.get("bearing", "")):
		Lords.CAUTIOUS:
			return "\"A new crown is a fragile thing. If it falls, my house falls with it.\""
		Lords.DARING:
			return "\"Your crown? I've heard of it. What has it done that's worth my name?\""
		Lords.HONORABLE:
			return "\"I swore an oath to %s. You'd have me break it for what, exactly?\"" % ruler_name(l)
		Lords.CRUEL:
			return "\"Everyone wants something from me. What do I get, and what happens if I say no?\""
	return "\"Why should I?\""


## Arguments still open to you: [{id, says, theme, points, tag}]. Tags only say what you know.
static func arguments(gs, l: Dictionary) -> Array:
	var used: Array = record(l).get("args", [])
	var places := 0
	if gs.world != null:
		places = gs.world.holdings_of(Data.CROWN).size()
	var out := []
	var all := [
		{"id": "strength", "theme": PRUDENCE, "says": "My crown holds %s and loses none of %s. It is the safe road, not the bold one." % [
			"%d places" % places if places != 1 else "its seat", "them" if places != 1 else "it"]},
		{"id": "glory", "theme": BOLDNESS, "says": "Ride under my banner and there's glory enough for both of us."},
		{"id": "counsel", "theme": MODESTY, "says": "I don't ask you to kneel. I ask for your counsel at my table."},
		{"id": "fear", "theme": FEAR, "says": "Those who stand against my crown don't stand for long."},
	]
	if int(record(l).get("doubts_king", 0)) == 1:
		all.push_front({"id": "king", "theme": "", "says": "%s leaves your lands to burn. I won't." % ruler_name(l)})
	for a in all:
		if used.has(a["id"]):
			continue
		var pts := argument_points(l, a)
		var tag := "+%d · their king's failings" % pts if a["id"] == "king" else ""
		if tag == "":
			if a["theme"] == likes(l) and like_known(l):
				tag = "+%d · they value %s" % [pts, a["theme"]]
			elif a["theme"] == dislikes(l) and dislike_known(l):
				tag = "%d · they dislike %s" % [pts, THEME_WORDS[a["theme"]]]
			else:
				tag = "a guess · learn what they like first"
		a["points"] = pts
		a["tag"] = tag
		out.append(a)
	return out


static func argument_points(l: Dictionary, a: Dictionary) -> int:
	if a["id"] == "king":
		return ARGUMENT_KING
	if a["theme"] == likes(l):
		return ARGUMENT_LIKED
	if a["theme"] == dislikes(l):
		return ARGUMENT_DISLIKED
	return ARGUMENT_PLAIN


## Make an argument. Returns {ok, points, reaction, refused, sworn}.
static func argue(gs, l: Dictionary, arg_id: String) -> Dictionary:
	if not persuade_check(gs, l)["ok"]:
		return {"ok": false}
	var arg := {}
	for a in arguments(gs, l):
		if a["id"] == arg_id:
			arg = a
	if arg.is_empty():
		return {"ok": false}
	var t := record(l)
	var used: Array = t.get("args", [])
	used.append(arg_id)
	t["args"] = used
	var pts := int(arg["points"])
	t["case"] = int(t.get("case", 0)) + pts
	var out := {"ok": true, "points": pts, "refused": false, "sworn": false}
	if pts < 0:
		t["bristle"] = int(t.get("bristle", 0)) + 1
		if not dislike_known(l) and arg_id != "king":
			out["learned"] = "You learned: %s has no taste for %s." % [first_name(l), THEME_WORDS[arg["theme"]]]
		t["dislike_known"] = 1
		if int(t["bristle"]) >= BRISTLE_LIMIT:
			refuse(gs, l)
			out["refused"] = true
			out["reaction"] = "\"Enough. I've heard what kind of crown this is. Ride on, and don't ask me again this week.\""
			return out
		out["reaction"] = "\"That's meant to persuade me?\""
	elif pts >= ARGUMENT_LIKED:
		if not like_known(l) and arg_id != "king":
			out["learned"] = "You learned: %s values %s." % [first_name(l), arg["theme"]]
			t["like_known"] = 1
		out["reaction"] = "\"...That is no small thing. Go on.\""
	else:
		out["reaction"] = "\"Perhaps. Words are cheap on the road.\""
	out["sworn"] = conviction(gs, l) >= CONVINCED
	return out


## Silver toward their change of sides.
static func offer_silver(gs, l: Dictionary, amount: int) -> Dictionary:
	if not persuade_check(gs, l)["ok"] or amount <= 0 or int(gs.silver) < amount:
		return {"ok": false}
	gs.silver -= amount
	var t := record(l)
	var pts := amount / SILVER_PER_POINT
	t["silver_pts"] = int(t.get("silver_pts", 0)) + pts
	t["silver_paid"] = int(t.get("silver_paid", 0)) + amount
	var said := "\"Silver. Well. It buys a great many swords.\"" if String(l.get("bearing", "")) == Lords.CRUEL else "\"That's a serious sum. It would rebuild what this war has burned.\""
	return {"ok": true, "points": pts, "reaction": said, "sworn": conviction(gs, l) >= CONVINCED}


static func refuse(gs, l: Dictionary) -> void:
	var t := record(l)
	t["refused_until"] = gs.world.hour + REFUSAL_HOURS if gs.world != null else REFUSAL_HOURS
	t["bristle"] = 0
	change_regard(gs, l, REFUSAL_REGARD)


## They swear: their realm becomes yours, and their castle and its villages with it.
## "Bought" when silver made more than half the case: such a lord may leave again if they
## come to think badly of you. Returns {ok, fief, villages, men, bought, from}.
static func swear(gs, l: Dictionary) -> Dictionary:
	if not persuade_check(gs, l)["ok"] or conviction(gs, l) < CONVINCED:
		return {"ok": false}
	var w = gs.world
	var was := String(l.get("realm", ""))
	var t := record(l)
	var c := conviction(gs, l)
	var bought := int(t.get("silver_pts", 0)) * 2 > c
	var fief := String(l.get("fief", ""))
	var held: bool = fief != "" and w.owner_of(fief) == was
	l["realm"] = Data.CROWN
	l["sworn_from"] = was
	l["bought"] = 1 if bought else 0
	var lp = w.party(int(l.get("party", -1)))
	if lp != null:
		lp.faction = Data.CROWN
	var villages := []
	if held:
		for v in Data.SETTLEMENTS:
			if String(Data.SETTLEMENTS[v].get("bound_to", "")) == fief:
				villages.append(v)
		w.set_owner(fief, Data.CROWN)
		l["fief"] = fief
	else:
		l["fief"] = ""
	l["job"] = ""
	l["target"] = ""
	t["case"] = 0
	t["silver_pts"] = 0
	t["args"] = []
	if w.realms.has(was):
		gs.add_realm_relation(was, -30)
	change_regard(gs, l, 10)
	w.emit_event({"type": "lord_sworn", "lord": String(l["name"]), "from": was})
	var men := 0
	if lp != null:
		men = w.men_of(lp.army)
	return {"ok": true, "fief": fief if held else "", "villages": villages, "men": men, "bought": bought, "from": was}


## A lord bought with silver who now thinks badly of you goes back to the realm they came
## from, castle and all. Called once a day. Returns the names of any who left.
static func bought_lords_day(gs) -> Array:
	var gone := []
	if gs.world == null or not gs.is_crowned():
		return gone
	var w = gs.world
	for l in w.lords:
		if String(l.get("realm", "")) != Data.CROWN or int(l.get("bought", 0)) != 1:
			continue
		var back := String(l.get("sworn_from", ""))
		if not w.realms.has(back) or regard(gs, l) >= 0:
			continue
		l["realm"] = back
		l["bought"] = 0
		var lp = w.party(int(l.get("party", -1)))
		if lp != null:
			lp.faction = back
		var fief := String(l.get("fief", ""))
		if fief != "" and w.owner_of(fief) == Data.CROWN and fief != gs.fief_id():
			w.set_owner(fief, back)
			l["fief"] = fief
		gone.append(String(l["name"]))
	return gone


# ---------------------------------------------------------------- steel

## Whether you could challenge this lord to battle: {ok, reason, war} where `war` says
## whether it would start one.
static func challenge_check(gs, l: Dictionary) -> Dictionary:
	var realm := String(l.get("realm", ""))
	if realm == Data.CROWN:
		return {"ok": false, "reason": "they're sworn to you", "war": false}
	if gs.has_contract() and gs.contract_realm() == realm:
		return {"ok": false, "reason": "you're under contract to them", "war": false}
	if gs.has_fief() and gs.fief_realm() == realm:
		return {"ok": false, "reason": "you hold land of their crown", "war": false}
	if gs.world == null or gs.world.party(int(l.get("party", -1))) == null:
		return {"ok": false, "reason": "they're not in the field", "war": false}
	var hostile: bool = gs.world.relation_to_player(realm) == "hostile"
	return {"ok": true, "reason": "", "war": not hostile}


## What a battle with them would risk: {mine, theirs, lost, wins}.
static func stakes(gs, l: Dictionary) -> Dictionary:
	var lp = gs.world.party(int(l.get("party", -1)))
	var fighters := []
	for s in gs.army:
		if int(s["men"]) > 0:
			fighters.append(s)
	var theirs: Array = lp.army if lp != null else []
	var odds: Dictionary = preload("res://scripts/battle/auto_resolve.gd").odds(fighters, theirs)
	return {"mine": gs.total_men(), "theirs": gs.world.men_of(theirs), "lost": int(odds["lost"]), "wins": bool(odds["player_wins"])}


## Tribute: a Cruel lord takes silver to let you pass.
static func tribute_check(gs, l: Dictionary) -> Dictionary:
	if String(l.get("bearing", "")) != Lords.CRUEL or gs.world == null or gs.world.relation_to_player(String(l.get("realm", ""))) != "hostile":
		return {"ok": false, "reason": ""}
	if int(gs.silver) < TRIBUTE:
		return {"ok": false, "reason": "you haven't %d silver" % TRIBUTE}
	return {"ok": true, "reason": ""}


static func pay_tribute(gs, l: Dictionary) -> bool:
	if not tribute_check(gs, l)["ok"]:
		return false
	gs.silver -= TRIBUTE
	change_regard(gs, l, TRIBUTE_REGARD)
	var lp = gs.world.party(int(l.get("party", -1)))
	if lp != null:
		lp.grace_until = gs.world.hour + 24.0
		if String(l.get("job", "")) == "chase":
			l["job"] = ""
			l["think_at"] = gs.world.hour
	if gs.world.encounter == int(l.get("party", -2)):
		gs.world.encounter = -1
	return true


## Captains who could stand as your champion: up to three, unwounded, most seasoned first.
static func champions(gs) -> Array:
	var out := []
	for s in gs.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("wounded", 0)) <= 0:
			out.append({"squad": int(s["id"]), "captain": c, "type": String(s["type"])})
	out.sort_custom(func(a, b): return int(a["captain"].get("battles", 0)) > int(b["captain"].get("battles", 0)))
	return out.slice(0, 3)


static func duel_check(gs, l: Dictionary) -> Dictionary:
	if String(l.get("state", "")) == "prisoner" or gs.world == null or gs.world.party(int(l.get("party", -1))) == null:
		return {"ok": false, "reason": "they're not in the field"}
	if gs.world.hour < float(record(l).get("duel_at", -1000.0)) + DUEL_WAIT_HOURS:
		return {"ok": false, "reason": "you fought them only lately"}
	if champions(gs).is_empty():
		return {"ok": false, "reason": "no captain fit to fight"}
	return {"ok": true, "reason": ""}


## A captain's chance against this lord's champion.
static func duel_chance(captain: Dictionary, l: Dictionary) -> float:
	var mine := 60.0 + float(captain.get("battles", 0)) * 4.0 + float(captain.get("kills", 0)) * 0.1 \
		+ (25.0 if bool(captain.get("is_hero", false)) else 0.0)
	var theirs := 60.0 + float(l.get("renown", 40)) * 0.25
	return clampf(mine / (mine + theirs), 0.2, 0.8)


## Single combat, champion against champion; no armies, no war.
## Returns {ok, won, regard, renown, captain}.
static func duel(gs, l: Dictionary, squad_id: int) -> Dictionary:
	if not duel_check(gs, l)["ok"]:
		return {"ok": false}
	var champ := {}
	for c in champions(gs):
		if int(c["squad"]) == squad_id:
			champ = c["captain"]
	if champ.is_empty():
		return {"ok": false}
	record(l)["duel_at"] = gs.world.hour
	var won: bool = gs.world.rng.randf() < duel_chance(champ, l)
	var out := {"ok": true, "won": won, "captain": String(champ.get("name", "your champion"))}
	if won:
		out["regard"] = duel_win_regard(l)
		out["renown"] = DUEL_RENOWN
		gs.renown += DUEL_RENOWN
	else:
		out["regard"] = DUEL_LOSE_REGARD
		out["renown"] = 0
		champ["wounded"] = Captains.WOUND_BATTLES
	change_regard(gs, l, int(out["regard"]))
	return out


static func duel_win_regard(l: Dictionary) -> int:
	return DUEL_WIN_REGARD if String(l.get("bearing", "")) in [Lords.CRUEL, Lords.DARING] else DUEL_WIN_REGARD_MILD


# ---------------------------------------------------------------- captives

## Keep a captive in chains: they resent it, and Honorable lords everywhere hear of it.
static func keep_in_chains(gs, l: Dictionary) -> void:
	change_regard(gs, l, CHAINS_REGARD)
	if gs.world == null:
		return
	for o in gs.world.lords:
		if o != l and String(o.get("bearing", "")) == Lords.HONORABLE:
			change_regard(gs, o, CHAINS_HONORABLE)


## Lords you've met: greeted on the road, fought, held, sworn, or talked with.
static func met(gs, l: Dictionary) -> bool:
	return int(l.get("greeted", 0)) == 1 or int(l.get("met_player", 0)) > 0 or String(l.get("captive_of", "")) == "player" \
		or String(l.get("realm", "")) == Data.CROWN or not (l.get("talk", {}) as Dictionary).is_empty() or gs.lord_relations.has(int(l.get("id", -1)))
