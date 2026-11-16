## Married life: her hand in your affairs (docs/married-life-plan.md). What the one you
## married, and her house, can do for you, by the same honest rules as the rest of the
## campaign: nothing is made from nowhere (silver and food come from her house lord's
## purse, men from her seat's garrison) and nothing teleports (a cart or an envoy rides
## the roads and takes the time they take).
##
## - Her own part, with public or private vows: a standing benefit, one ask on a cooldown,
##   and letters that come when you need them. Edda (the household) answers money and
##   food; Farah (the envoy) enemies and politics; Kaede (the archive) what you can't see.
## - Her house's part, with the pact (a public wedding or a sworn friendship): men for
##   your squads, and its lord holding a place for you.
## - Her seat: home (the wounded heal faster), and in danger (she writes; the call to its
##   walls comes for you too).
## - Travelling together, and being taken if you lose, and brought home.
##
## Static functions on GameState (`gs`), like LordTalk; the state is kept in the social
## sim's `household`, so it's saved with it. Words are in married_lines.gd and letters.gd.
extends RefCounted

const WorldData = preload("res://scripts/world/world_data.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Units = preload("res://scripts/data/units.gd")
const Troops = preload("res://scripts/data/troops.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const Letters = preload("res://scripts/data/letters.gd")
const Lines = preload("res://scripts/data/married_lines.gd")

const EDDA := "edda"
const FARAH := "farid"
const KAEDE := "kaede"

# ---- her house's help
## Men her house sends from its seat's garrison at a time, and what the garrison keeps.
const HOUSE_MEN_MAX := 24
const GARRISON_KEEP := 40
## The house's military help (men, or holding a place) once in this many hours.
const MILITARY_COOLDOWN_HOURS := 336.0
## How long her house's lord holds a place for you.
const HOLD_HOURS := 48.0
## Places offered: your fief, where you are, and this many friendly ones nearest you.
const NEAR_PLACES := 4

# ---- Edda
const FIEF_TAX_MULT := 1.2
const SUPPLY_FOOD := 120
## What her house pays for each ration it sends.
const SUPPLY_FOOD_PRICE := 1
const CART_SPEED := 30.0
## A band this close to the cart takes it.
const AMBUSH_RADIUS := 30.0
## At most one "you're short" letter in this many hours.
const SHORT_LETTER_GAP_HOURS := 168.0

# ---- Farah
const RANSOM_MULT := 1.25
const REPARATIONS_MULT := 0.5
const ENVOY_SPEED := 45.0
const ENVOY_COOLDOWN_HOURS := 240.0
## A truce brings your standing with the realm up to this (no longer hostile).
const TRUCE_RELATION := -10
## A ruler who thinks less of you than this won't receive her.
const TRUCE_MIN_REGARD := -40
const GOOD_WORD := 10
## She speaks well of you to lords who think less of you than this.
const GOOD_WORD_BELOW := 40
const ENVOY_LORDS := 4

# ---- Kaede
const LOOKUP_COOLDOWN_HOURS := 48.0
const LOOKUP_DELAY_HOURS := 12.0
const LOOKUP_PLACES := 6
const LOOKUP_LORDS := 6
const MAP_GAP_HOURS := 168.0
const MAP_RANGE := 260.0

# ---- home and her seat
const HOME_HEAL_MULT := 2.0
const SEAT_HELD_STANDING := 5

# ---- travelling together
## While she rides with you her ask is ready this much sooner (its cooldown times this).
const TRAVEL_ASK_MULT := 0.5
const RANSOM_SILVER := 250
const HOUSE_PAYS_AFTER_HOURS := 240.0
const HOUSE_PAYS_STANDING := -5


# ---------------------------------------------------------------- who, and where

static func _social(gs):
	return gs.world.social if gs != null and gs.world != null else null


## The married-life state, with every key there.
static func hh(gs) -> Dictionary:
	var soc = _social(gs)
	if soc == null:
		return {}
	var h: Dictionary = soc.household
	for k in ["convoys", "warned_armies", "spoken_well"]:
		if not h.has(k):
			h[k] = []
	for k in ["ask_hour", "sent", "captive", "besieged", "marked_band", "returning"]:
		if not h.has(k):
			h[k] = {}
	if not h.has("with_company"):
		h["with_company"] = ""
	return h


## The one you're married to, or "".
static func spouse(gs) -> String:
	var soc = _social(gs)
	if soc == null:
		return ""
	for cand in soc.relationships:
		if String(soc.relationships[cand].get("status", "")) == Relationships.MARRIED:
			return String(cand)
	return ""


static func person(gs, cand: String) -> Dictionary:
	var soc = _social(gs)
	return soc.get_candidate_person(cand) if soc != null else {}


static func name_of(gs, cand: String) -> String:
	return String(person(gs, cand).get("name", cand.capitalize()))


static func house_of(gs, cand: String) -> Dictionary:
	var soc = _social(gs)
	return soc.get_house(String(person(gs, cand).get("house_id", ""))) if soc != null else {}


## Her house's lord (its head), or {}.
static func house_lord(gs, cand: String) -> Dictionary:
	var soc = _social(gs)
	if soc == null:
		return {}
	var head: Dictionary = soc.get_person(String(house_of(gs, cand).get("head_person_id", "")))
	var id := int(head.get("lord_id", -1))
	return gs.world.lord_by_id(id) if id >= 0 else {}


## Whether her house stands with you: a pact (a public wedding or a sworn friendship).
static func pact_active(gs, cand: String) -> bool:
	var soc = _social(gs)
	if soc == null:
		return false
	var p: Dictionary = soc.get_pact(String(person(gs, cand).get("house_id", "")))
	return not p.is_empty() and String(p.get("status", "active")) == "active"


## Where she lives.
static func home_of(gs, cand: String) -> String:
	return String(person(gs, cand).get("residence", ""))


static func captive(gs) -> Dictionary:
	return hh(gs).get("captive", {})


static func is_held(gs, cand: String) -> bool:
	return String(captive(gs).get("cand", "")) == cand and cand != ""


## Who rides with your company, or "".
static func with_company(gs) -> String:
	return String(hh(gs).get("with_company", "")) if _social(gs) != null else ""


## Whether her own part is on: you're married to her and she isn't held.
static func role_on(gs, cand: String) -> bool:
	return cand != "" and spouse(gs) == cand and not is_held(gs, cand)


static func _place_name(id: String) -> String:
	return String(WorldData.settlement(id)["name"]) if WorldData.SETTLEMENTS.has(id) else "the road"


static func _player_pos(gs) -> Vector2:
	return gs.world.party_pos(gs.world.player())


## Where the company is, as a place: where it stands, or the nearest place on the road.
static func _here_or_near(gs) -> String:
	var here: String = gs.world.here()
	return here if here != "" else String(gs.world.nearest_place(_player_pos(gs)))


static func _when(gs, hours: float) -> String:
	if hours <= 1.0:
		return "within the hour"
	if hours < 24.0:
		return "in %d hours" % ceili(hours)
	var days := ceili(hours / 24.0)
	return "in %d day%s" % [days, "" if days == 1 else "s"]


# ---------------------------------------------------------------- standing benefits

## Edda keeps your fief's accounts: its daily tax, times this.
static func fief_tax_mult(gs) -> float:
	return FIEF_TAX_MULT if role_on(gs, EDDA) else 1.0


## Farah's word with the houses: a captive's house pays this much more ransom.
static func ransom_mult(gs) -> float:
	return RANSOM_MULT if role_on(gs, FARAH) else 1.0


## Farah carries your reparations: they cost this much of the price.
static func reparations_mult(gs) -> float:
	return REPARATIONS_MULT if role_on(gs, FARAH) else 1.0


## Kaede's records: whether the map's place sheets show what she knows of every place.
static func knows_places(gs) -> bool:
	return role_on(gs, KAEDE)


## Resting at her seat while she's home: the wounded heal this much faster again.
static func heal_mult(gs) -> float:
	var cand := spouse(gs)
	if cand == "" or not gs.is_resting() or _social(gs).away_from_home(cand):
		return 1.0
	var here: String = gs.world.here()
	return HOME_HEAL_MULT if here != "" and here == home_of(gs, cand) else 1.0


# ---------------------------------------------------------------- her ask

static func _cooldown(gs, cand: String) -> float:
	var base: float = {EDDA: Relationships.GRANT_COOLDOWN_HOURS, FARAH: ENVOY_COOLDOWN_HOURS, KAEDE: LOOKUP_COOLDOWN_HOURS}.get(cand, 0.0)
	return base * (TRAVEL_ASK_MULT if with_company(gs) == cand else 1.0)


## When her ask was last given (Edda's shares the household grant's clock).
static func _asked_at(gs, cand: String) -> float:
	if cand == EDDA:
		return float(_social(gs).limits.get("last_grant_hour", -999.0))
	return float(hh(gs)["ask_hour"].get(cand, -999999.0))


## Whether you can ask her now: {ok, reason}.
static func ask_ready(gs, cand: String) -> Dictionary:
	if spouse(gs) != cand:
		return {"ok": false, "reason": "only for the one you married"}
	if is_held(gs, cand):
		return {"ok": false, "reason": "%s is held by %s" % [name_of(gs, cand), String(captive(gs).get("captor", "her captors"))]}
	var ready := _asked_at(gs, cand) + _cooldown(gs, cand)
	if gs.world.hour < ready:
		return {"ok": false, "reason": "again %s" % _when(gs, ready - gs.world.hour)}
	return {"ok": true, "reason": ""}


# ---------------------------------------------------------------- the roads: carts and envoys

static func _route_hours(w, from: String, route: Array, speed: float) -> float:
	var hours := 0.0
	var a := from
	for b in route:
		hours += w.road_length(a, String(b)) / (minf(speed, WorldSim.SEA_SPEED) if w.is_sea(a, String(b)) else speed)
		a = String(b)
	return hours


## How long from `from` to `to` at `speed`: by road, or straight there if no road is found.
static func _hours_between(w, from: String, to: String, speed: float) -> float:
	if from == to or not WorldData.SETTLEMENTS.has(from) or not WorldData.SETTLEMENTS.has(to):
		return 0.0
	var route: Array = w.path(from, to)
	if route.is_empty():
		return WorldData.pos(from).distance_to(WorldData.pos(to)) / minf(speed, WorldSim.SEA_SPEED)
	return _route_hours(w, from, route, speed)


static func _new_convoy(gs, kind: String, cand: String, from: String, to: String, speed: float, extra: Dictionary) -> Dictionary:
	var h := hh(gs)
	var w = gs.world
	var nid := int(h.get("next_id", 1))
	h["next_id"] = nid + 1
	var route: Array = w.path(from, to) if from != to else []
	var c := {"id": nid, "kind": kind, "cand": cand, "from": from, "to": to, "path": route, "depart": w.hour,
		"arrive": w.hour + _hours_between(w, from, to, speed), "state": "riding", "food": 0, "silver": 0, "purpose": {}}
	c.merge(extra, true)
	(h["convoys"] as Array).append(c)
	return c


## Where a cart or an envoy is on the map now: along its road, by the time it has ridden.
static func convoy_pos(gs, c: Dictionary) -> Vector2:
	var nodes: Array = [String(c.get("from", ""))]
	nodes.append_array(c.get("path", []))
	if nodes.size() == 1 and String(c.get("to", "")) != nodes[0]:
		nodes.append(String(c.get("to", "")))
	if String(c.get("state", "")) != "riding" or nodes.size() < 2:
		return WorldData.pos(String(c.get("to", c.get("from", ""))))
	var w = gs.world
	var span := maxf(0.001, float(c["arrive"]) - float(c["depart"]))
	var t := clampf((float(w.hour) - float(c["depart"])) / span, 0.0, 1.0)
	var total := 0.0
	for i in range(1, nodes.size()):
		total += w.road_length(String(nodes[i - 1]), String(nodes[i]))
	var left := total * t
	for i in range(1, nodes.size()):
		var a := String(nodes[i - 1])
		var b := String(nodes[i])
		var leg: float = w.road_length(a, b)
		if left <= leg:
			return WorldData.pos(a).lerp(WorldData.pos(b), left / maxf(0.001, leg))
		left -= leg
	return WorldData.pos(String(nodes.back()))


static func convoys(gs) -> Array:
	return hh(gs).get("convoys", []) if _social(gs) != null else []


static func _drop(gs, c: Dictionary) -> void:
	(hh(gs)["convoys"] as Array).erase(c)


static func _letter(gs, cand: String, key: String, place: String, extra: Dictionary = {}, delay: float = 0.0) -> void:
	var soc = _social(gs)
	var p := person(gs, cand)
	if soc == null or p.is_empty():
		return
	var hour: float = gs.world.hour
	soc.add_letter(String(p["id"]), key, "", hour, place, extra, hour + delay if delay > 0.0 else -1.0)
	hh(gs)["sent"][key] = hour


static func _memory(gs, cand: String, text: String, info: Dictionary = {}) -> void:
	var soc = _social(gs)
	var p := person(gs, cand)
	if soc != null and not p.is_empty():
		var full := {"kind": "note", "candidate": cand}
		full.merge(info, true)
		soc.add_memory(String(p["id"]), text, full)


# ---------------------------------------------------------------- Edda: the supply train

## What her house would load on a cart now: {ok, reason, food, silver}. Food first (it's a
## supply train), then the household grant's silver, all from her house lord's purse
## while it keeps its reserve.
static func supply_load(gs) -> Dictionary:
	if not pact_active(gs, EDDA):
		return {"ok": false, "reason": "her house wasn't asked: no pact"}
	var lord := house_lord(gs, EDDA)
	if lord.is_empty() or String(lord.get("state", "")) == "prisoner":
		return {"ok": false, "reason": "her house's lord can't send it now"}
	var available := int(lord.get("silver", 0)) - Relationships.LORD_MIN_RESERVE
	if available <= 0:
		return {"ok": false, "reason": "her house's purse is low"}
	var food := mini(SUPPLY_FOOD, available / SUPPLY_FOOD_PRICE)
	var silver := mini(Relationships.GRANT_MAX_SILVER, available - food * SUPPLY_FOOD_PRICE)
	return {"ok": true, "reason": "", "food": food, "silver": silver}


## Whether Edda can send a train now: {ok, reason, food, silver}.
static func supply_check(gs) -> Dictionary:
	var ready := ask_ready(gs, EDDA)
	if not bool(ready["ok"]):
		return ready
	for c in convoys(gs):
		if String(c.get("kind", "")) == "supply":
			return {"ok": false, "reason": "a train is already on its way"}
	return supply_load(gs)


## Where a cart or her house's lord can go for you: where you are (a town or castle), your
## fief, and the friendly towns and castles nearest you, none under siege. [{id, name, hours}].
static func near_places(gs, include_fief: bool = false) -> Array:
	var w = gs.world
	var out := []
	var seen := {}
	var add := func(id: String) -> void:
		if id == "" or seen.has(id) or not WorldData.SETTLEMENTS.has(id):
			return
		seen[id] = true
		out.append({"id": id, "name": _place_name(id), "hours": w.hours_to(id)})
	var here: String = w.here()
	if here != "" and String(WorldData.settlement(here)["type"]) != WorldData.VILLAGE and not w.is_sieged(here) \
			and w.relation_to_player(w.owner_of(here)) != "hostile":
		add.call(here)
	if include_fief:
		add.call(gs.wedding_seat())
	var others := []
	for id in WorldData.SETTLEMENTS:
		if seen.has(id) or String(WorldData.settlement(id)["type"]) == WorldData.VILLAGE or w.is_sieged(id):
			continue
		if w.relation_to_player(w.owner_of(id)) == "hostile":
			continue
		others.append([WorldData.pos(id).distance_to(_player_pos(gs)), id])
	others.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	for o in others.slice(0, NEAR_PLACES):
		add.call(String(o[1]))
	return out


## Edda sends a cart from her seat to `to`: {ok, reason, convoy}.
static func send_supply(gs, to: String) -> Dictionary:
	var check := supply_check(gs)
	if not bool(check["ok"]):
		return check
	if not WorldData.SETTLEMENTS.has(to):
		return {"ok": false, "reason": "there's no such place"}
	var lord := house_lord(gs, EDDA)
	var food := int(check["food"])
	var silver := int(check["silver"])
	lord["silver"] = int(lord["silver"]) - food * SUPPLY_FOOD_PRICE - silver
	_social(gs).limits["last_grant_hour"] = gs.world.hour
	var c := _new_convoy(gs, "supply", EDDA, home_of(gs, EDDA), to, CART_SPEED, {"food": food, "silver": silver})
	_memory(gs, EDDA, "Sent a supply train to %s: %d rations and %d silver." % [_place_name(to), food, silver])
	return {"ok": true, "reason": "", "convoy": c}


static func _ambushed(gs, c: Dictionary) -> bool:
	var at := convoy_pos(gs, c)
	for b in gs.world.bands():
		if gs.world.party_pos(b).distance_to(at) <= AMBUSH_RADIUS:
			return true
	return false


static func _cart_lost(gs, c: Dictionary) -> void:
	var near: String = gs.world.nearest_place(convoy_pos(gs, c))
	_drop(gs, c)
	_letter(gs, EDDA, "supply_lost", home_of(gs, EDDA), {"at": _place_name(near)})
	_memory(gs, EDDA, "Lost a supply train to bandits near %s." % _place_name(near))
	gs._note(Lines.fill(Lines.SUPPLY_LOST_NOTE, {"name": name_of(gs, EDDA), "at": _place_name(near)}))


static func _collect(gs, c: Dictionary) -> void:
	_drop(gs, c)
	gs.food += int(c.get("food", 0))
	gs.silver += int(c.get("silver", 0))
	gs._note(Lines.fill(Lines.SUPPLY_MET_NOTE, {"name": name_of(gs, EDDA), "place": _place_name(String(c["to"])),
		"food": str(int(c.get("food", 0))), "silver": str(int(c.get("silver", 0)))}))
	_memory(gs, EDDA, "Her supply train met the company at %s." % _place_name(String(c["to"])))


# ---------------------------------------------------------------- Farah: the envoy

## Where Farah could carry a letter: [{kind ("truce" | "word"), realm | lord_id, name, to}].
## A truce with each realm that bars you for your own standing; a good word with up to
## ENVOY_LORDS lords you've met who think little of you and aren't your enemies.
static func envoy_targets(gs) -> Array:
	var w = gs.world
	var out := []
	for realm in WorldData.FACTIONS:
		if realm == WorldData.BANDITS or realm == WorldData.CROWN:
			continue
		if gs.barred_by(realm) == "standing" and w.capital_of(realm) != "":
			out.append({"kind": "truce", "realm": realm, "name": String(WorldData.FACTIONS[realm]["name"]), "to": w.capital_of(realm)})
	var spoken: Array = hh(gs)["spoken_well"]
	var lords := []
	for l in w.lords:
		var realm := String(l.get("realm", ""))
		if int(l.get("met_player", 0)) <= 0 or String(l.get("state", "")) == "prisoner" or spoken.has(int(l["id"])) or realm == WorldData.CROWN:
			continue
		if w.relation_to_player(realm) == "hostile" or LordTalk.regard(gs, l) >= GOOD_WORD_BELOW or w.seat_of(l) == "":
			continue
		lords.append(l)
	lords.sort_custom(func(a, b): return LordTalk.regard(gs, a) < LordTalk.regard(gs, b))
	for l in lords.slice(0, ENVOY_LORDS):
		out.append({"kind": "word", "lord_id": int(l["id"]), "name": LordTalk.short_name(l), "to": w.seat_of(l)})
	return out


## Farah rides with a letter for `target` (one of envoy_targets): {ok, reason, convoy}.
static func send_envoy(gs, target: Dictionary) -> Dictionary:
	var ready := ask_ready(gs, FARAH)
	if not bool(ready["ok"]):
		return ready
	var to := String(target.get("to", ""))
	if not WorldData.SETTLEMENTS.has(to):
		return {"ok": false, "reason": "there's nowhere to take it"}
	var from := _here_or_near(gs) if with_company(gs) == FARAH else home_of(gs, FARAH)
	var purpose := {"kind": String(target["kind"]), "name": String(target.get("name", ""))}
	if target.has("realm"):
		purpose["realm"] = String(target["realm"])
	if target.has("lord_id"):
		purpose["lord_id"] = int(target["lord_id"])
	hh(gs)["ask_hour"][FARAH] = gs.world.hour
	var c := _new_convoy(gs, "envoy", FARAH, from, to, ENVOY_SPEED, {"purpose": purpose})
	_memory(gs, FARAH, "Rode to %s with a letter for %s." % [_place_name(to), String(purpose["name"])])
	return {"ok": true, "reason": "", "convoy": c}


## She's there: what came of it, by the rules, and her letter saying so.
static func _envoy_arrives(gs, c: Dictionary) -> void:
	_drop(gs, c)
	var w = gs.world
	var purpose: Dictionary = c.get("purpose", {})
	var key := "envoy_refused"
	var outcome := ""
	match String(purpose.get("kind", "")):
		"truce":
			var realm := String(purpose.get("realm", ""))
			var ruler := {}
			for l in w.lords_of(realm):
				if bool(l.get("ruler", false)):
					ruler = l
			if gs.barred_by(realm) != "standing":
				key = "envoy_done"
				outcome = Lines.fill(Lines.TRUCE_NOT_NEEDED, {"realm": String(purpose.get("name", ""))})
			elif not ruler.is_empty() and LordTalk.regard(gs, ruler) < TRUCE_MIN_REGARD:
				outcome = Lines.fill(Lines.TRUCE_REFUSED, {"realm": String(purpose.get("name", "")), "ruler": LordTalk.short_name(ruler)})
			else:
				key = "envoy_done"
				gs.add_realm_relation(realm, maxi(0, TRUCE_RELATION - gs.relation_with_realm(realm)))
				outcome = Lines.fill(Lines.TRUCE_GRANTED, {"realm": String(purpose.get("name", "")),
					"ruler": LordTalk.short_name(ruler) if not ruler.is_empty() else "the throne"})
		"word":
			var l: Dictionary = w.lord_by_id(int(purpose.get("lord_id", -1)))
			if l.is_empty() or String(l.get("state", "")) == "prisoner":
				outcome = Lines.fill(Lines.WORD_MISSED, {"lord": String(purpose.get("name", ""))})
			else:
				key = "envoy_done"
				LordTalk.change_regard(gs, l, GOOD_WORD)
				(hh(gs)["spoken_well"] as Array).append(int(l["id"]))
				outcome = Lines.fill(Lines.WORD_GIVEN, {"lord": LordTalk.short_name(l)})
	_letter(gs, FARAH, key, String(c.get("to", "")), {"outcome": outcome})


# ---------------------------------------------------------------- Kaede: the archive

## Places she can look up: the castles and towns nearest you. [{id, name}].
static func lookup_places(gs) -> Array:
	var near := []
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.VILLAGE:
			near.append([WorldData.pos(id).distance_to(_player_pos(gs)), id])
	near.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	return near.slice(0, LOOKUP_PLACES).map(func(o): return {"id": String(o[1]), "name": _place_name(String(o[1]))})


## Lords she can look up: those you've met. [{id, name}].
static func lookup_lords(gs) -> Array:
	var out := []
	for l in gs.world.lords:
		if int(l.get("met_player", 0)) > 0:
			out.append({"id": int(l["id"]), "name": LordTalk.short_name(l)})
	out.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
	return out.slice(0, LOOKUP_LORDS)


## What her records say of a place, as she'd write it.
static func place_facts(gs, id: String) -> String:
	var w = gs.world
	var bits := PackedStringArray()
	for line in String(w.settlement_intelligence(id)).split("\n", false):
		bits.append(String(line).strip_edges())
	if w.is_sieged(id):
		var army: Dictionary = w.sieging_army(id)
		bits.append("Under siege by %s." % String(WorldData.FACTIONS.get(String(army.get("realm", "")), {}).get("name", "an army")))
	return ". ".join(bits).replace("..", ".") + "."


## What her records say of a lord, as she'd write it.
static func lord_facts(gs, l: Dictionary) -> String:
	var w = gs.world
	var who := LordTalk.short_name(l)
	var where := ""
	if String(l.get("state", "")) == "prisoner":
		where = "%s is a captive just now." % who
	else:
		var p = w.party(int(l.get("party", -1))) if l.get("party") != null else null
		var at: String = String(w.nearest_place(w.party_pos(p))) if p != null else String(w.seat_of(l))
		where = "%s is %s %s." % [who, "riding near" if p != null and p.moving() else "at", _place_name(at)]
	var realm := String(WorldData.FACTIONS.get(String(l.get("realm", "")), {}).get("name", "no realm"))
	var line := "%s He holds for %s, and the clerks call him %s. He counts you %s." % [where, realm,
		String(l.get("bearing", "honourable")).to_lower(), LordTalk.standing(LordTalk.regard(gs, l)).to_lower()]
	var sour: String = gs.sour_reason(l)
	if sour != "":
		line += " He %s." % sour
	return line


## Ask Kaede to look up a place (`kind` "place", `id` a settlement) or a lord ("lord", his
## id as text). Her letter comes LOOKUP_DELAY_HOURS later: {ok, reason}.
static func look_up(gs, kind: String, id: String) -> Dictionary:
	var ready := ask_ready(gs, KAEDE)
	if not bool(ready["ok"]):
		return ready
	var subject := ""
	var facts := ""
	if kind == "place":
		if not WorldData.SETTLEMENTS.has(id):
			return {"ok": false, "reason": "there's no such place"}
		subject = _place_name(id)
		facts = place_facts(gs, id)
	else:
		var l: Dictionary = gs.world.lord_by_id(int(id))
		if l.is_empty():
			return {"ok": false, "reason": "there's no such lord"}
		subject = LordTalk.short_name(l)
		facts = lord_facts(gs, l)
	hh(gs)["ask_hour"][KAEDE] = gs.world.hour
	var from := _here_or_near(gs) if with_company(gs) == KAEDE else home_of(gs, KAEDE)
	_letter(gs, KAEDE, "lookup", from, {"subject_name": subject, "facts": facts}, 0.0 if with_company(gs) == KAEDE else LOOKUP_DELAY_HOURS)
	return {"ok": true, "reason": ""}


# ---------------------------------------------------------------- her house's help

## Whether her house can send men now: {ok, reason, men}.
static func men_check(gs, cand: String) -> Dictionary:
	if not pact_active(gs, cand):
		return {"ok": false, "reason": "her house wasn't asked: no pact", "men": 0}
	var w = gs.world
	var house := house_of(gs, cand)
	var seat := String(house.get("seat", home_of(gs, cand)))
	if w.here() != seat:
		return {"ok": false, "reason": "at %s, where its garrison is" % _place_name(seat), "men": 0}
	var owner: String = w.owner_of(seat)
	if owner != String(house.get("realm", owner)):
		return {"ok": false, "reason": "her house no longer holds %s" % _place_name(seat), "men": 0}
	if gs.is_at_war_with(owner):
		return {"ok": false, "reason": "%s's realm is at war with you" % _place_name(seat), "men": 0}
	var last := float(_social(gs).limits.get("last_military_help_hour", -999.0))
	if w.hour < last + MILITARY_COOLDOWN_HOURS:
		return {"ok": false, "reason": "again %s" % _when(gs, last + MILITARY_COOLDOWN_HOURS - w.hour), "men": 0}
	var need := 0
	for s in gs.army:
		need += maxi(0, _full(s) - int(s["men"]) - int(s.get("wounded", 0)))
	if need <= 0:
		return {"ok": false, "reason": "your squads are full", "men": 0}
	var spare: int = w.men_of(w.garrison_at(seat)) - GARRISON_KEEP
	if spare <= 0:
		return {"ok": false, "reason": "the garrison can't spare men", "men": 0}
	return {"ok": true, "reason": "", "men": mini(HOUSE_MEN_MAX, mini(need, spare))}


static func _full(s: Dictionary) -> int:
	var unit_id := String(s.get("unit", ""))
	return Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(String(s["type"]))


## Her house sends men from its seat's garrison to your understrength squads (smallest
## first, as raw recruits): {ok, reason, men}.
static func ask_men(gs, cand: String) -> Dictionary:
	var check := men_check(gs, cand)
	if not bool(check["ok"]):
		return check
	var w = gs.world
	var seat := String(house_of(gs, cand).get("seat", home_of(gs, cand)))
	var left := int(check["men"])
	# Out of the garrison, its biggest squads first.
	var garrison: Array = w.garrison_at(seat)
	var take := left
	var by_size := garrison.duplicate()
	by_size.sort_custom(func(a, b): return int(a["men"]) > int(b["men"]))
	for sq in by_size:
		if take <= 0:
			break
		var t := mini(take, int(sq["men"]) - 1)
		sq["men"] = int(sq["men"]) - t
		take -= t
	var given := left - take
	# Into your squads, the emptiest first, diluting their experience as hiring does.
	var squads: Array = gs.army.duplicate()
	squads.sort_custom(func(a, b): return float(a["men"]) / float(_full(a)) < float(b["men"]) / float(_full(b)))
	var left_to_give := given
	for s in squads:
		if left_to_give <= 0:
			break
		var room := maxi(0, _full(s) - int(s["men"]) - int(s.get("wounded", 0)))
		var add := mini(room, left_to_give)
		if add <= 0:
			continue
		var before := int(s["men"])
		var earned_floor := (Troops.level_for(int(s.get("xp", 0))) - 1) * Troops.XP_PER_LEVEL
		s["xp"] = maxi(int(int(s.get("xp", 0)) * float(before) / float(before + add)), earned_floor)
		s["men"] = before + add
		left_to_give -= add
	_social(gs).limits["last_military_help_hour"] = w.hour
	_memory(gs, cand, "Her house sent %d men from %s to the company." % [given, _place_name(seat)])
	return {"ok": true, "reason": "", "men": given}


## Where her house's lord could hold for you: your fief, where you are, the friendly
## places nearest you; none held by a realm at war with his. [{id, name, hours}].
static func hold_places(gs, cand: String) -> Array:
	var lord := house_lord(gs, cand)
	var realm := String(lord.get("realm", ""))
	return near_places(gs, true).filter(func(p): return realm == "" or not gs.world.at_war(gs.world.owner_of(String(p["id"])), realm))


## Whether her house's lord can ride out to hold a place for you: {ok, reason}.
static func hold_check(gs, cand: String) -> Dictionary:
	if not pact_active(gs, cand):
		return {"ok": false, "reason": "her house wasn't asked: no pact"}
	var w = gs.world
	var lord := house_lord(gs, cand)
	if lord.is_empty():
		return {"ok": false, "reason": "her house has no lord to send"}
	var who := LordTalk.short_name(lord)
	if String(lord.get("state", "")) == "prisoner":
		return {"ok": false, "reason": "%s is a captive" % who}
	if gs.is_at_war_with(String(lord.get("realm", ""))):
		return {"ok": false, "reason": "%s's realm is at war with you" % who}
	var p = w.party(int(lord.get("party", -1))) if lord.get("party") != null else null
	if p == null:
		return {"ok": false, "reason": "%s is raising men at home" % who}
	if String(lord.get("job", "")) == "army" or not w.MarshalArmies.for_party(w, p.id).is_empty():
		return {"ok": false, "reason": "%s rides with the marshal" % who}
	if w.men_of(p.army) < int(lord.get("full", 0)) * Lords.REFILL_BELOW:
		return {"ok": false, "reason": "%s's men are spent" % who}
	var order: Dictionary = lord.get("order", {}) if lord.get("order") is Dictionary else {}
	if String(order.get("house", "")) != "":
		return {"ok": false, "reason": "%s already holds %s for you" % [who, _place_name(String(order.get("target", "")))]}
	var last := float(_social(gs).limits.get("last_military_help_hour", -999.0))
	if w.hour < last + MILITARY_COOLDOWN_HOURS:
		return {"ok": false, "reason": "again %s" % _when(gs, last + MILITARY_COOLDOWN_HOURS - w.hour)}
	return {"ok": true, "reason": ""}


## Her house's lord rides to `target` and holds it for HOLD_HOURS: {ok, reason}.
static func hold_place(gs, cand: String, target: String) -> Dictionary:
	var check := hold_check(gs, cand)
	if not bool(check["ok"]):
		return check
	if not hold_places(gs, cand).any(func(p): return String(p["id"]) == target):
		return {"ok": false, "reason": "he can't hold that place for you"}
	var lord := house_lord(gs, cand)
	lord["order"] = {"kind": "guard", "target": target, "until": gs.world.hour + HOLD_HOURS, "house": String(person(gs, cand).get("house_id", ""))}
	lord["think_at"] = gs.world.hour
	_social(gs).limits["last_military_help_hour"] = gs.world.hour
	_memory(gs, cand, "%s rode to hold %s for the company." % [LordTalk.short_name(lord), _place_name(target)])
	return {"ok": true, "reason": ""}


# ---------------------------------------------------------------- her seat in danger

## Whether the call to the walls of `target` comes for you: it's her seat, you're married,
## and its owner isn't your enemy.
static func defends_for_her(gs, target: String) -> bool:
	var cand := spouse(gs)
	return cand != "" and target == home_of(gs, cand) and not gs.is_at_war_with(gs.world.owner_of(target))


## You held her seat's walls and won.
static func on_seat_defended(gs, target: String) -> void:
	var cand := spouse(gs)
	if cand != "" and target == home_of(gs, cand):
		hh(gs)["besieged"]["defended"] = true


static func _check_seat(gs, cand: String) -> void:
	var w = gs.world
	var h := hh(gs)
	var res := home_of(gs, cand)
	var siege: Dictionary = h["besieged"]
	var army: Dictionary = w.sieging_army(res) if res != "" else {}
	if not army.is_empty():
		if int(siege.get("army_id", -1)) != int(army.get("id", -2)):
			h["besieged"] = {"army_id": int(army["id"]), "place": res, "defended": false,
				"owner": String(w.owner_of(res)), "realm": String(army.get("realm", ""))}
			if not _social(gs).away_from_home(cand):
				_letter(gs, cand, "seat_besieged", res, {"enemy": String(WorldData.FACTIONS.get(String(army.get("realm", "")), {}).get("name", "an army"))})
		return
	if siege.is_empty():
		return
	# The siege is over: held (and you were on the walls), or lost (she has moved).
	var place := String(siege.get("place", ""))
	if bool(siege.get("defended", false)) and w.owner_of(place) == String(siege.get("owner", "")):
		var house := house_of(gs, cand)
		if not house.is_empty():
			house["standing"] = clampi(int(house.get("standing", 0)) + SEAT_HELD_STANDING, Relationships.STANDING_MIN, Relationships.STANDING_MAX)
		_letter(gs, cand, "seat_held", place)
		_memory(gs, cand, "You held the walls of %s for her." % _place_name(place))
	h["besieged"] = {}


# ---------------------------------------------------------------- letters when they're needed

static func _sent_since(gs, key: String, gap: float) -> bool:
	return gs.world.hour < float(hh(gs)["sent"].get(key, -999999.0)) + gap


## Once a day: what each of them writes about what's happening.
static func day(gs) -> void:
	var cand := spouse(gs)
	if cand == "" or _social(gs) == null:
		return
	_captive_day(gs)
	if not role_on(gs, cand):
		return
	match cand:
		EDDA:
			if gs.short_of_silver() and not _sent_since(gs, "household_short", SHORT_LETTER_GAP_HOURS) and bool(supply_check(gs)["ok"]):
				var near := near_places(gs)
				if not near.is_empty():
					_letter(gs, EDDA, "household_short", home_of(gs, EDDA), {"near": String(near[0]["name"])})
		FARAH:
			_army_warnings(gs)
		KAEDE:
			_band_map(gs)


## Farah hears of a marshal's muster against your fief, her seat, or a holding of the realm
## you serve, and writes once per army.
static func _army_warnings(gs) -> void:
	var w = gs.world
	var watched := {}
	if gs.wedding_seat() != "":
		watched[gs.wedding_seat()] = true
	watched[home_of(gs, FARAH)] = true
	if gs.has_contract():
		for id in w.holdings_of(gs.contract_realm()):
			watched[String(id)] = true
	var warned: Array = hh(gs)["warned_armies"]
	for a in w.campaign_armies:
		var target := String(a.get("target", ""))
		if not (String(a.get("state", "")) in ["gathering", "marching"]) or not watched.has(target) or warned.has(int(a["id"])):
			continue
		warned.append(int(a["id"]))
		var leader: Dictionary = w.lord_by_id(int(a.get("leader", -1)))
		_letter(gs, FARAH, "army_warning", home_of(gs, FARAH), {"realm": String(WorldData.FACTIONS.get(String(a.get("realm", "")), {}).get("name", "An army")),
			"target": _place_name(target), "leader": LordTalk.short_name(leader) if not leader.is_empty() else "their marshal"})
	while warned.size() > 30:
		warned.pop_front()


## Kaede's map, once a week, when a band roams near you.
static func _band_map(gs) -> void:
	if _sent_since(gs, "kaede_map", MAP_GAP_HOURS):
		return
	var w = gs.world
	var at := _player_pos(gs)
	var best = null
	var best_d := MAP_RANGE
	for b in w.bands():
		var d: float = w.party_pos(b).distance_to(at)
		if d <= best_d:
			best_d = d
			best = b
	if best == null:
		return
	var near: String = w.nearest_place(w.party_pos(best))
	hh(gs)["marked_band"] = {"party_id": int(best.id), "until": w.hour + MAP_GAP_HOURS, "name": String(best.name)}
	_letter(gs, KAEDE, "kaede_map", home_of(gs, KAEDE), {"near": _place_name(near)})


## A reply that does something: Edda's "send the train".
static func on_reply(gs, letter: Dictionary, reply_id: String) -> Dictionary:
	if String(letter.get("template_key", "")) == "household_short" and reply_id == "send":
		var near := near_places(gs)
		if near.is_empty():
			return {"ok": false, "reason": "there's nowhere safe to send it"}
		return send_supply(gs, String(near[0]["id"]))
	return {"ok": true, "reason": ""}


# ---------------------------------------------------------------- travelling together

## Whether she can come with you now: {ok, reason}.
static func join_check(gs, cand: String) -> Dictionary:
	if spouse(gs) != cand:
		return {"ok": false, "reason": "only the one you married"}
	if is_held(gs, cand):
		return {"ok": false, "reason": "she's held"}
	if with_company(gs) == cand:
		return {"ok": false, "reason": "she rides with you already"}
	if gs.world.here() != home_of(gs, cand) or _social(gs).away_from_home(cand):
		return {"ok": false, "reason": "from her seat, %s" % _place_name(home_of(gs, cand))}
	return {"ok": true, "reason": ""}


static func join(gs, cand: String) -> Dictionary:
	var check := join_check(gs, cand)
	if not bool(check["ok"]):
		return check
	var h := hh(gs)
	h["with_company"] = cand
	h["joined_hour"] = gs.world.hour
	h["joined_battles"] = int(gs.battles)
	h["returning"] = {}
	_memory(gs, cand, "Rode out with the company from %s." % _place_name(home_of(gs, cand)))
	return {"ok": true, "reason": ""}


## She rides home: back at her seat when the road allows.
static func send_home(gs, cand: String) -> Dictionary:
	if with_company(gs) != cand:
		return {"ok": false, "reason": "she isn't with you"}
	var h := hh(gs)
	h["with_company"] = ""
	var from := _here_or_near(gs)
	var home := home_of(gs, cand)
	var hours := _hours_between(gs.world, from, home, CART_SPEED)
	h["returning"] = {"cand": cand, "until": gs.world.hour + hours}
	_memory(gs, cand, "Rode home to %s from %s." % [_place_name(home), _place_name(from)])
	return {"ok": true, "reason": "", "hours": hours}


## Whether she's on the road home (after riding with you) just now.
static func returning(gs, cand: String) -> bool:
	var r: Dictionary = hh(gs).get("returning", {})
	return String(r.get("cand", "")) == cand and gs.world.hour < float(r.get("until", 0.0))


## The company lost a fight with her riding in it: she's taken by whoever beat you.
static func on_battle_lost(gs, enemy_lord_id: int, party_id: int, captor_name: String) -> void:
	var cand := with_company(gs)
	if cand == "":
		return
	var h := hh(gs)
	h["with_company"] = ""
	var held := {"cand": cand, "since": gs.world.hour, "captor": captor_name}
	if enemy_lord_id >= 0:
		held["kind"] = "lord"
		held["lord_id"] = enemy_lord_id
	elif party_id >= 0:
		held["kind"] = "band"
		held["party_id"] = party_id
	else:
		return
	h["captive"] = held
	_memory(gs, cand, "Taken by %s when the company was beaten." % captor_name)
	gs._note(Lines.fill(Lines.TAKEN_NOTE, {"name": name_of(gs, cand), "captor": captor_name}))


## You beat whoever holds her: she's free.
static func on_battle_won(gs, enemy_lord_id: int, party_id: int) -> void:
	var held := captive(gs)
	if held.is_empty():
		return
	if (String(held.get("kind", "")) == "lord" and enemy_lord_id >= 0 and int(held.get("lord_id", -1)) == enemy_lord_id) \
			or (String(held.get("kind", "")) == "band" and party_id >= 0 and int(held.get("party_id", -1)) == party_id):
		release(gs, "battle")


## Where her captor is now, as a place, or "".
static func captor_place(gs) -> String:
	var held := captive(gs)
	var w = gs.world
	if String(held.get("kind", "")) == "lord":
		var l: Dictionary = w.lord_by_id(int(held.get("lord_id", -1)))
		if l.is_empty():
			return ""
		var p = w.party(int(l.get("party", -1))) if l.get("party") != null else null
		return String(w.nearest_place(w.party_pos(p))) if p != null else w.seat_of(l)
	var b = w.party(int(held.get("party_id", -1)))
	return String(w.nearest_place(w.party_pos(b))) if b != null else ""


## Whether you can pay her ransom now: {ok, reason}.
static func ransom_check(gs) -> Dictionary:
	var held := captive(gs)
	if held.is_empty():
		return {"ok": false, "reason": "no one is held"}
	if String(held.get("kind", "")) != "lord":
		return {"ok": false, "reason": "bandits don't bargain: beat them"}
	if gs.silver < RANSOM_SILVER:
		return {"ok": false, "reason": "need %d silver" % RANSOM_SILVER}
	return {"ok": true, "reason": ""}


static func pay_ransom(gs) -> Dictionary:
	var check := ransom_check(gs)
	if not bool(check["ok"]):
		return check
	gs.silver -= RANSOM_SILVER
	var l: Dictionary = gs.world.lord_by_id(int(captive(gs).get("lord_id", -1)))
	if not l.is_empty():
		l["silver"] = int(l.get("silver", 0)) + RANSOM_SILVER
	release(gs, "ransom")
	return {"ok": true, "reason": ""}


## She's free, and home: `how` is "battle", "ransom", "escaped" or "house".
static func release(gs, how: String) -> void:
	var held := captive(gs)
	var cand := String(held.get("cand", ""))
	if cand == "":
		return
	hh(gs)["captive"] = {}
	if how == "house":
		var house := house_of(gs, cand)
		if not house.is_empty():
			house["standing"] = clampi(int(house.get("standing", 0)) + HOUSE_PAYS_STANDING, Relationships.STANDING_MIN, Relationships.STANDING_MAX)
	_letter(gs, cand, "home_again_" + how, home_of(gs, cand), {"captor": String(held.get("captor", ""))})
	_memory(gs, cand, String(Lines.ROAD_HOME_MEMORY.get(how, Lines.ROAD_HOME_MEMORY["escaped"])) % String(held.get("captor", "")),
		{"kind": "note", "road_home": how})
	gs._note(Lines.fill(String(Lines.HOME_NOTE.get(how, Lines.HOME_NOTE["escaped"])), {"name": name_of(gs, cand), "captor": String(held.get("captor", ""))}))


## Her captor fell (taken, killed, scattered): she walks free in the confusion. After
## HOUSE_PAYS_AFTER_HOURS her house pays for her.
static func _captive_day(gs) -> void:
	var held := captive(gs)
	if held.is_empty():
		return
	var w = gs.world
	if String(held.get("kind", "")) == "lord":
		var l: Dictionary = w.lord_by_id(int(held.get("lord_id", -1)))
		if l.is_empty() or String(l.get("state", "")) == "prisoner":
			release(gs, "escaped")
			return
	elif w.party(int(held.get("party_id", -1))) == null:
		release(gs, "escaped")
		return
	if w.hour >= float(held.get("since", w.hour)) + HOUSE_PAYS_AFTER_HOURS:
		release(gs, "house")


# ---------------------------------------------------------------- each step

## As time passes: carts and envoys ride, arrive, or are taken; a waiting cart meets you;
## her seat's danger is noticed; a captive's captor is checked.
static func step(gs) -> void:
	var soc = _social(gs)
	if soc == null:
		return
	var cand := spouse(gs)
	if cand == "" and soc.household.is_empty():
		return
	var w = gs.world
	for c in convoys(gs).duplicate():
		match String(c.get("state", "")):
			"riding":
				if String(c.get("kind", "")) == "supply" and _ambushed(gs, c):
					_cart_lost(gs, c)
				elif w.hour >= float(c.get("arrive", 0.0)):
					if String(c.get("kind", "")) == "supply":
						c["state"] = "waiting"
					else:
						_envoy_arrives(gs, c)
			"waiting":
				if w.here() == String(c.get("to", "")):
					_collect(gs, c)
	var h := hh(gs)
	var mark: Dictionary = h["marked_band"]
	if not mark.is_empty() and (w.hour >= float(mark.get("until", 0.0)) or w.party(int(mark.get("party_id", -1))) == null):
		h["marked_band"] = {}
	var r: Dictionary = h["returning"]
	if not r.is_empty() and w.hour >= float(r.get("until", 0.0)):
		h["returning"] = {}
	if cand != "":
		_check_seat(gs, cand)
		if not captive(gs).is_empty():
			_captive_day(gs)


# ---------------------------------------------------------------- the Journal

static func commitments(gs) -> Array:
	var out := []
	if _social(gs) == null:
		return out
	var w = gs.world
	for c in convoys(gs):
		var cname := name_of(gs, String(c.get("cand", "")))
		var to := String(c.get("to", ""))
		if String(c.get("kind", "")) == "supply":
			var load := "%d rations, %d silver" % [int(c.get("food", 0)), int(c.get("silver", 0))]
			var waiting := String(c.get("state", "")) == "waiting"
			out.append({"id": "household_convoy_%d" % int(c["id"]), "kind": "household", "title": "%s's supply train" % cname,
				"objective": ("It waits for you at %s." % _place_name(to)) if waiting else ("On the road to %s. Bandits on the way will take it." % _place_name(to)),
				"place": to, "reward": load, "cost": "", "hours_left": -1.0 if waiting else maxf(0.0, float(c["arrive"]) - w.hour), "blocked": ""})
		else:
			out.append({"id": "household_convoy_%d" % int(c["id"]), "kind": "household",
				"title": "%s's letter for %s" % [cname, String(c.get("purpose", {}).get("name", ""))],
				"objective": "She rides to %s. She'll write what comes of it." % _place_name(to), "place": to,
				"reward": "a truce" if String(c.get("purpose", {}).get("kind", "")) == "truce" else "+%d Regard" % GOOD_WORD,
				"cost": "", "hours_left": maxf(0.0, float(c["arrive"]) - w.hour), "blocked": ""})
	for l in w.lords:
		var order: Dictionary = l.get("order", {}) if l.get("order") is Dictionary else {}
		if String(order.get("house", "")) == "":
			continue
		var at := String(order.get("target", ""))
		out.append({"id": "household_hold_%d" % int(l["id"]), "kind": "household",
			"title": "%s holds %s for you" % [LordTalk.short_name(l), _place_name(at)],
			"objective": "Her house's lord rides there with his men and holds it.", "place": at, "reward": "",
			"cost": "", "hours_left": maxf(0.0, float(order.get("until", w.hour)) - w.hour), "blocked": ""})
	var cand := spouse(gs)
	var siege: Dictionary = hh(gs)["besieged"]
	if cand != "" and not siege.is_empty():
		var place := String(siege.get("place", ""))
		out.append({"id": "household_siege", "kind": "household", "title": "%s is under siege" % _place_name(place),
			"objective": "%s's seat is besieged. Ride there: the call to its walls comes for you." % name_of(gs, cand),
			"place": place, "reward": "her house's thanks", "cost": "", "hours_left": -1.0, "blocked": ""})
	var mark: Dictionary = hh(gs)["marked_band"]
	if not mark.is_empty():
		var b = w.party(int(mark.get("party_id", -1)))
		if b != null:
			var near: String = w.nearest_place(w.party_pos(b))
			out.append({"id": "household_band", "kind": "household", "title": "A band on Kaede's map",
				"objective": "%s, near %s." % [String(mark.get("name", "Bandits")), _place_name(near)], "place": near,
				"reward": "", "cost": "", "hours_left": maxf(0.0, float(mark.get("until", w.hour)) - w.hour), "blocked": ""})
	var held := captive(gs)
	if not held.is_empty():
		var at := captor_place(gs)
		var who := name_of(gs, String(held.get("cand", "")))
		var how := ("Ransom her from her page (%d silver), or beat them." % RANSOM_SILVER) if String(held.get("kind", "")) == "lord" else "Beat them: bandits don't bargain."
		out.append({"id": "household_road_home", "kind": "household", "title": "A road home",
			"objective": "%s is held by %s%s. %s" % [who, String(held.get("captor", "her captors")), (" near %s" % _place_name(at)) if at != "" else "", how],
			"place": at, "reward": "%s home" % who, "cost": "",
			"hours_left": maxf(0.0, float(held.get("since", w.hour)) + HOUSE_PAYS_AFTER_HOURS - w.hour),
			"blocked": ""})
	return out
