## Company deeds: optional goals the company can reach in its own time. Each one is earned
## once, from real campaign events, and gives the company a name it may carry (a title,
## nothing more: no bonuses). Reaching one never ends the campaign.
extends RefCounted

const WorldData = preload("res://scripts/world/world_data.gd")

## id: {title (the name it earns), goal (what to do), need (how many)}.
## None needs a romance or a particular people.
const DEEDS := {
	"contract": {"title": "the Sworn Blades", "goal": "Serve a mercenary contract to its end.", "need": 1},
	"villages": {"title": "the Shield of the Villages", "goal": "Hold three villages against raiders.", "need": 3},
	"jobs": {"title": "the Reliable", "goal": "Finish five jobs for settlements.", "need": 5},
	"chiefs": {"title": "the Chiefbreakers", "goal": "Cut down three bandit chiefs.", "need": 3},
	"lord": {"title": "the Lordtakers", "goal": "Take an enemy lord captive.", "need": 1},
	"walls": {"title": "the Wallbreakers", "goal": "Storm a castle or town.", "need": 1},
	"veteran": {"title": "the Old Guard", "goal": "Keep a captain alive through ten battles.", "need": 10},
	"pact": {"title": "Friends of a House", "goal": "Form a lasting pact with a noble house.", "need": 1},
	"fief": {"title": "the Landed", "goal": "Hold a fief of your own.", "need": 1},
	"renown": {"title": "the Renowned", "goal": "Reach 300 renown.", "need": 300},
	# After the crown: every castle and town on the map flying your banner at once. Its
	# need is the number of walled seats there are (see seats_total()).
	"keeper_of_the_sea": {"title": "Keepers of the Glass Sea", "goal": "Hold every castle and town on the map under your crown at once.", "need": 9},
}
const ORDER := ["contract", "jobs", "villages", "chiefs", "lord", "walls", "veteran", "pact", "fief", "renown", "keeper_of_the_sea"]


## Every castle and town on the map: the seats a crown must hold to keep the Glass Sea.
static func seats_total() -> int:
	var n := 0
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.VILLAGE:
			n += 1
	return n


## The castles and towns your crown holds now.
static func seats_held(gs) -> int:
	if gs.world == null or not gs.is_crowned():
		return 0
	var n := 0
	for id in gs.world.holdings_of(WorldData.CROWN):
		if String(WorldData.settlement(id)["type"]) != WorldData.VILLAGE:
			n += 1
	return n


## How far the company has come toward `id`: what it has, capped at what's needed.
static func progress(gs, id: String) -> int:
	var need := int(DEEDS[id]["need"])
	var have := 0
	match id:
		"jobs":
			have = gs.completed_jobs.size()
		"veteran":
			for s in gs.army:
				if s.get("captain") is Dictionary:
					have = maxi(have, int(s["captain"].get("battles", 0)))
		"pact":
			if gs.world != null and gs.world.social != null:
				have = gs.world.social.pacts.size()
		"fief":
			have = 1 if gs.has_fief() else 0
		"renown":
			have = gs.renown
		"keeper_of_the_sea":
			have = seats_held(gs)
		_:
			have = int(gs.deed_counts.get(id, 0))
	return mini(have, need)


static func done(gs, id: String) -> bool:
	return gs.deeds.has(id)


## Award every deed newly reached. Returns the ids awarded now. Each is awarded once.
static func check(gs) -> Array:
	var new_ids: Array = []
	for id in ORDER:
		if gs.deeds.has(id):
			continue
		if progress(gs, id) >= int(DEEDS[id]["need"]):
			var day: int = int(gs.world.hour / 24.0) + 1 if gs.world != null else 1
			gs.deeds[id] = {"day": day}
			new_ids.append(id)
	return new_ids
