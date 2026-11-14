extends SceneTree
## Stages one shot of the "Captains" trailer and lets it play while Movie Maker records it.
##
##   tools/trailer2/shoot.sh <shot>                       record it (frames + sound)
##   tools/trailer2/shoot.sh --probe <shot> [key=value;…] no picture: print what happens, and when
##   godot --headless --path . -s tools/trailer2/stage.gd -- --list
##
## A shot is an entry in SHOTS: what to stage, how long to record ("secs"), and its shape
## ("tall": the game as it is on a phone, 1080x1920; "wide": the field or the map filling a
## 1920x1080 frame with the game's own HUD put away). Nothing here saves a campaign.
##
## Battles are the computer fighting both sides from a seed, so a shot comes out the same
## each time. Three things steer one:
##   "ff": run at eight times speed until this many seconds of the fight have passed;
##   "slow": {"reach", "strike", "pace"}: once the company the lens follows is within `reach`
##           of the enemy (middle to middle), step the fight at `pace` of real speed, in steps
##           that much finer (so slow motion is smooth, not held frames), until the two are
##           `strike` apart, where the lines are seen to meet; then full speed;
##   "lens": where the camera looks (see Lens).
## A fight names its seed, so a shot is the same fight every time. While it runs (recording
## or probing) the shot prints the fight's clock against the recording's: when companies
## meet and break, when a captain falls, what the walls are doing, when it is over. Those
## lines land in $TRAILER_OUT/logs/<shot>.log, and cut.py finds its moments in them.

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const Relationships = preload("res://scripts/data/relationships.gd")

const SHOTS := {
	# ---- the cold open: knights riding home in slow motion, then the blow at full speed
	"charge": {"kind": "battle", "secs": 18, "shape": "wide", "culture": "vardish", "foe": "kharzani",
		"ground": "open", "land": "vardmark", "hour": 6.3, "seed": 3, "order_at": 0.5,
		"army": ["cavalry", "cavalry", "cavalry", "cavalry", "cavalry"],
		"host": ["archers", "infantry", "archers", "infantry", "archers", "spearmen"],
		"slow": {"reach": 170.0, "strike": 72.0, "pace": 0.25},
		"lens": {"look": "squad", "team": 0, "type": "cavalry", "nth": 2, "lead": 0.5, "zoom": 3.4, "ease": 3.0}},
	# ---- the captains
	"roster": {"kind": "warband", "secs": 7, "shape": "tall", "culture": "vardish"},
	"captain": {"kind": "profile", "secs": 7, "shape": "tall", "culture": "vardish"},
	"fire": {"kind": "fire", "secs": 12, "shape": "tall", "culture": "vardish"},
	"fall": {"kind": "battle", "secs": 15, "shape": "tall", "culture": "vardish", "foe": "kharzani",
		"ground": "open", "land": "vardmark", "hour": 16.5, "seed": 19, "more": ["infantry", "spearmen", "archers"], "host": 12,
		"hud": true, "ff": 10.0},
	# ---- the battles
	"clash": {"kind": "battle", "secs": 13, "shape": "wide", "culture": "vardish", "foe": "ryumon",
		"ground": "open", "land": "vardmark", "hour": 11.0, "seed": 17, "army": 12, "host": 12, "order_at": 0.5,
		"lens": {"look": "fight", "zoom": 2.9}},
	"hand": {"kind": "battle", "secs": 14, "shape": "tall", "culture": "ryumon", "foe": "vardish",
		"ground": "hills", "land": "ryumon", "hour": 9.5, "seed": 23, "hud": true, "order_at": 0.5},
	"wood": {"kind": "battle", "secs": 14, "shape": "wide", "culture": "ryumon", "foe": "vardish",
		"ground": "woods", "land": "ryumon", "hour": 17.8, "seed": 6, "order_at": 0.5,
		"lens": {"look": "fight", "zoom": 3.2}},
	"bows": {"kind": "battle", "secs": 13, "shape": "wide", "culture": "kharzani", "foe": "vardish",
		"ground": "open", "land": "kharzan", "hour": 14.0, "seed": 31,
		"army": ["archers", "archers", "archers", "infantry", "spearmen", "infantry", "archers", "cavalry"],
		"lens": {"look": "squad", "team": 0, "type": "archers", "lead": 0.3, "zoom": 3.0}},
	"night": {"kind": "battle", "secs": 13, "shape": "wide", "culture": "vardish", "foe": "ryumon",
		"ground": "hills", "land": "vardmark", "hour": 22.5, "seed": 19, "order_at": 0.5,
		"lens": {"look": "fight", "zoom": 3.0}},
	"ford": {"kind": "battle", "secs": 12, "shape": "wide", "culture": "kharzani", "foe": "ryumon",
		"ground": "river", "land": "kharzan", "hour": 6.8, "seed": 13, "order_at": 0.5,
		"lens": {"look": "fight", "zoom": 3.0}},
	"dusk": {"kind": "battle", "secs": 13, "shape": "wide", "culture": "ryumon", "foe": "kharzani",
		"ground": "open", "land": "ryumon", "hour": 18.6, "seed": 44, "army": 12, "host": 12, "order_at": 0.5,
		"lens": {"look": "fight", "zoom": 2.6, "zoom_to": 3.3, "zoom_secs": 8.0}},
	"won": {"kind": "battle", "secs": 18, "ff": 36.0, "shape": "wide", "culture": "vardish", "foe": "kharzani",
		"ground": "open", "land": "vardmark", "hour": 17.2, "seed": 12, "army": 10, "host": 5,
		"lens": {"look": "fight", "zoom": 2.7}},
	# ---- the walls
	"gate": {"kind": "siege", "secs": 22, "ff": 84.0, "shape": "wide", "culture": "vardish", "foe": "kharzani",
		"place": "qasr_hamra", "hour": 15.0, "seed": 5,
		"army": ["infantry", "infantry", "infantry", "infantry", "spearmen", "spearmen", "spearmen", "archers", "archers", "archers"],
		"host": ["infantry", "infantry", "spearmen", "archers", "archers"],
		"train": ["ram", "ladders", "mantlets", "tower", "thrower", "thrower"], "works": ["bolt", "bolt", "postern"],
		"lens": {"look": "spot", "from": Vector2(420, 560), "to": Vector2(420, 520), "zoom": 3.0, "secs": 10.0}},
	"wall": {"kind": "siege", "secs": 23, "ff": 88.0, "shape": "wide", "culture": "ryumon", "foe": "vardish",
		"place": "ravensford", "hour": 7.0, "seed": 9,
		"army": ["infantry", "infantry", "infantry", "infantry", "spearmen", "spearmen", "spearmen", "archers", "archers", "archers"],
		"host": ["infantry", "infantry", "spearmen", "archers", "archers"],
		"train": ["ram", "ladders", "more_ladders", "mantlets", "tower", "thrower", "thrower"], "works": ["bolt", "bolt", "postern"],
		"lens": {"look": "spot", "from": Vector2(250, 560), "to": Vector2(560, 540), "zoom": 2.8, "secs": 10.0}},
	# ---- the world
	"sea": {"kind": "map", "secs": 8, "shape": "wide", "culture": "kharzani", "hour": 17.4, "pace": 2.0,
		"lens": {"from": Vector2(700, 960), "to": Vector2(560, 560), "scale": 2.4, "scale_to": 1.35, "secs": 8.0}},
	"emir": {"kind": "talk", "secs": 11, "shape": "tall", "culture": "kharzani", "place": "qasr_hamra", "realm": "kharzan",
		"hour": 17.5, "taps": [[3.5, "story"]]},
	"daimyo": {"kind": "talk", "secs": 11, "shape": "tall", "culture": "ryumon", "place": "kitayama", "realm": "ryumon",
		"hour": 8.5, "taps": [[3.5, "story"]]},
	"vows": {"kind": "wedding", "secs": 16, "shape": "tall", "taps": [[2.0, "begin"], [7.0, "vow_promise"]]},
	"town": {"kind": "town", "secs": 7, "shape": "tall", "culture": "ryumon", "place": "kurogane", "hour": 19.5},
}

var gs
var scenes
var shot := ""
var cfg := {}
var probe := false


func _init() -> void:
	var list := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a == "--probe":
			probe = true
		elif a == "--list":
			list = true
	if list:
		for k in SHOTS:
			print("SHOT %s %d %s" % [k, int(SHOTS[k]["secs"]), SHOTS[k]["shape"]])
		quit()
		return
	_begin.call_deferred()


func _begin() -> void:
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	if not SHOTS.has(shot):
		push_error("No such shot: %s" % shot)
		quit(1)
		return
	cfg = (SHOTS[shot] as Dictionary).duplicate(true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			for pair in a.substr(6).split(";", false):
				var kv := pair.split("=")
				if kv.size() == 2:
					var v = str_to_var(kv[1])
					cfg[kv[0]] = v if v != null else kv[1]
	_house_rules()
	# "cast" seeds the campaign (who your captains are: the same five in every shot); "seed"
	# is the fight's own.
	gs.rng.seed = int(cfg.get("cast", 1))
	seed(int(cfg.get("cast", 1)))
	match String(cfg["kind"]):
		"battle", "siege":
			_muster()
			await _go("battle.tscn")
			_fight(current_scene)
		"warband":
			_campaign()
			_seasoned()
			await _go("main_menu.tscn")
		"profile":
			_campaign()
			_seasoned()
			scenes.active_captain_id = int(gs.army[0]["captain"]["id"])
			scenes.captain_profile_return = "res://scenes/main_menu.tscn"
			await _go("captain_profile.tscn")
		"fire":
			_campaign()
			_seasoned()
			var a: Dictionary = gs.army[0]["captain"]
			var b: Dictionary = gs.army[1]["captain"]
			scenes.active_bond_a_id = int(a["id"])
			scenes.active_bond_b_id = int(b["id"])
			scenes.bond_conversation_return = "res://scenes/main_menu.tscn"
			await _go("bond_conversation.tscn")
		"map":
			_campaign()
			gs.world.wait(48.0)
			await _go("world_map.tscn")
			var map = current_scene
			map.speed = float(cfg.get("pace", 1.0))
			map._close_sheet()
			var chart := Chart.new()
			chart.screen = map
			chart.plan = cfg.get("lens", {})
			map.add_child(chart)
		"talk":
			_campaign()
			_stand_at(String(cfg["place"]))
			await _go("world_map.tscn")
			current_scene._close_sheet()
			current_scene._open_talk(_lord(String(cfg["realm"]), String(cfg["place"])), "road")
		"town":
			_campaign()
			_stand_at(String(cfg["place"]))
			scenes.settlement_arrival_pending = true
			await _go("settlement.tscn")
		"wedding":
			await _wedding_day()
	if cfg.has("taps"):
		var hand := Hand.new()
		hand.tree = self
		hand.cues = cfg["taps"]
		root.add_child(hand)


# ---------------------------------------------------------------- setting up

## Recording never touches a real campaign or the player's settings, plays no music (the
## trailer has its own score; the field's sounds stay), and no one-time card stops a shot.
func _house_rules() -> void:
	var sound = root.get_node("Sound")
	gs.persist = false
	sound.settings_path = OS.get_environment("TRAILER_TMP").path_join("trailer2-settings.cfg")
	SaveSlots.dir = "user://trailer2_saves"
	sound.set_music_on(false)
	sound.set_sounds_on(true)
	sound.set_illustrations(true)
	sound.set_reduced_motion(false)
	sound.set_instant_text(false)
	sound.set_show_performance(false)
	var seen := ConfigFile.new()
	seen.load("user://settings.cfg")
	for k in ["hills", "woods", "river", "pass", "village"]:
		seen.set_value("terrain_hints", k, true)
	for k in ["chief", "ambush", "village", "siege"]:
		seen.set_value("objective_hints", k, true)
	seen.save("user://settings.cfg")


func _campaign() -> void:
	gs.new_campaign(String(cfg.get("culture", "vardish")))
	gs.persist = false
	gs.world.hour = float(cfg.get("hour", 9.0))
	var w = gs.world
	# Nobody stops you on the road while the camera runs.
	w.friendly_quiet_until = 1.0e9
	for band in w.bands():
		band.grace_until = 1.0e9
	for party in w.lord_parties():
		party.grace_until = 1.0e9


## A company with a year behind it: battles fought, a wound or two, and its first two
## captains close enough to talk at the fire.
func _seasoned() -> void:
	gs.silver = 3150
	gs.renown = 410
	gs.battles = 23
	var n := 0
	for s in gs.army:
		var c: Dictionary = s["captain"]
		c["battles"] = 23 - n * 3
		c["kills"] = 41 - n * 7
		n += 1
	var a: Dictionary = gs.army[0]["captain"]
	var b: Dictionary = gs.army[1]["captain"]
	a["history"]["wounds"] = 2
	a["history"]["scars"] = ["A cut over the brow, from the ford.", "A spear's mark on the jaw."]
	a["bonds"][str(b["id"])] = 13.0
	b["bonds"][str(a["id"])] = 13.0
	var rec: Dictionary = gs._ensure_bond_record(int(a["id"]), int(b["id"]))
	rec["shared_battles"] = 19
	rec["last_outcome"] = "victory"
	rec["last_losses"] = 7


func _stand_at(place: String) -> void:
	var me = gs.world.player()
	me.node = place
	me.next = ""
	me.path = []


func _lord(realm: String, place: String) -> int:
	var ruler := 0
	for l in gs.world.lords:
		if String(l["realm"]) != realm:
			continue
		if String(l.get("fief", "")) == place:
			return int(l["id"])
		if bool(l.get("ruler", false)):
			ruler = int(l["id"])
	return ruler


func _go(file: String) -> void:
	change_scene_to_file("res://scenes/" + file)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(file) and current_scene.is_node_ready():
			break
	await process_frame


## The companies of a side: a count (the four kinds in turn) or the kinds by name.
func _kinds(spec, shift: int) -> Array:
	if spec is Array:
		return spec
	var out := []
	for i in int(spec):
		out.append(Troops.ORDER[(i + shift) % 4])
	return out


func _muster() -> void:
	var mine := String(cfg.get("culture", "vardish"))
	var foe := String(cfg.get("foe", "kharzani"))
	gs.new_campaign(mine)
	gs.persist = false
	gs.battles = 10
	gs.world.hour = float(cfg.get("hour", 12.0))
	if cfg.has("more"):
		# The campaign's own five companies, with the captains the other shots show, and more.
		for kind in cfg["more"]:
			gs.army.append(gs._new_squad(kind))
	else:
		gs.army = []
		for kind in _kinds(cfg.get("army", 10), 0):
			gs.army.append(gs._new_squad(kind))
	var host := []
	for kind in _kinds(cfg.get("host", cfg.get("army", 10) if not (cfg.get("army", 10) is Array) else 10), 1):
		var unit := Units.recruit(foe, kind)
		host.append({"id": 9300 + host.size(), "type": kind, "unit": unit, "men": Units.full_size(unit), "culture": foe})
	# The fight names its seed, so the same shot is the same fight every time it is recorded.
	var fight := {"enemy": host, "culture": foe, "name": "the host", "temperament": String(cfg.get("temper", "Reckless")),
		"seed": int(cfg.get("seed", 1)),
		"can_withdraw": true, "objective": "rout"}
	if String(cfg["kind"]) == "siege":
		fight["objective"] = "siege"
		fight["site"] = null
		fight["siege_target"] = String(cfg["place"])
		fight["siege_kind"] = String(cfg.get("walls", "castle"))
		fight["siege_engines"] = {"attacker": cfg.get("train", ["ram", "ladders"]), "defender": cfg.get("works", []),
			"attacker_land": mine, "defender_land": foe}
	else:
		var site := {"type": String(cfg.get("ground", "open")), "seed": int(cfg.get("seed", 1)),
			"biome": String(cfg.get("land", "vardmark")), "fair": true}
		if site["type"] == "river":
			site["river"] = "the Qamar"
		fight["site"] = site
	gs.pending_battle = fight


## The computer commands your side as well as theirs. The battle starts at once; "order_at"
## hands the army back and presses Advance all at that second of the fight.
func _fight(screen) -> void:
	var sim = screen.sim
	sim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER, String(cfg.get("ours", "Hammer")))
	sim.ai[Sim.PLAYER].deploy(sim)
	screen._start_battle()
	var lens: Lens = null
	if cfg.has("lens") and not bool(cfg.get("hud", false)):
		lens = Lens.new()
		lens.screen = screen
		lens.plan = cfg["lens"]
		screen.add_child(lens)
	var pacer := Pacer.new()
	pacer.screen = screen
	pacer.cfg = cfg
	pacer.lens = lens
	screen.add_child(pacer)


## Edda's wedding at Ravensford: her story at its last chapter, a public wedding agreed,
## the days of waiting, then the afternoon itself.
func _wedding_day() -> void:
	gs.new_campaign(Cultures.VARDISH)
	gs.persist = false
	gs.silver = 1200
	gs.food = 500
	var social = gs.world.social
	_stand_at("ravensford")
	var tie: Dictionary = social.relationships["edda"]
	tie["romantic_intent"] = true
	tie["trust"] = 60
	tie["status"] = Relationships.COMMITTED
	social.quests["quest_edda"]["chapter"] = 5
	var edda: Dictionary = social.get_candidate_person("edda")
	social.houses[edda["house_id"]]["standing"] = 30
	social.add_memory(edda["id"], "Shared the story of Edda's spare spoon.", {"kind": "visit", "scene_id": "edda_spare_spoon"})
	scenes.active_candidate_id = "edda"
	scenes.conversation_return = "res://scenes/settlement.tscn"
	await _go("conversation.tscn")
	for reply in ["story", "decide_marry_public", "confirm", "place_ravensford", "back"]:
		current_scene.choose(reply)
	var w = gs.world
	var day: float = w.hour + 96.0
	while w.hour < day:
		w.wait(6.0)
		gs.advance(6.0)
		w.encounter = -1
	_stand_at("ravensford")
	w.hour = floorf(w.hour / 24.0) * 24.0 + 15.0
	scenes.wedding_replay = ""
	scenes.wedding_return = "res://scenes/world_map.tscn"
	await _go("wedding.tscn")


# ---------------------------------------------------------------- the fight's clock

## Runs before the battle screen each frame: fast-forwards, steps slow motion finely, gives
## the order to advance, and prints what the fight is doing.
class Pacer extends Node:
	var screen
	var cfg := {}
	var lens: Lens = null
	var _video := 0.0
	var _ordered := false
	var _slowing := 0 # 0 not yet, 1 in slow motion, 2 struck
	var _said := -1.0
	var _fates := {}
	var _standing := {}
	var _touching := {}
	var _gate := -1.0
	var _walls := -1
	var _over := false
	var _clashed := false

	func _ready() -> void:
		process_priority = -1000

	func _process(delta: float) -> void:
		var sim = screen.sim
		if sim == null:
			return
		_video += delta
		if cfg.has("order_at") and not _ordered and sim.time >= float(cfg["order_at"]):
			_ordered = true
			sim.ai[Sim.PLAYER] = null
			screen._on_advance()
		var slow: Dictionary = cfg.get("slow", {})
		if not slow.is_empty() and lens != null and _slowing < 2 and sim.winner == -1:
			var rider = lens.subject(sim)
			if rider != null:
				if _slowing == 0 and not rider.in_contact and lens.gap(sim, rider) <= float(slow.get("reach", 200.0)):
					_slowing = 1
					print("fight %6.2f  video %6.2f  SLOW    begins" % [sim.time, _video])
				elif _slowing == 1 and (rider.in_contact or lens.gap(sim, rider) <= float(slow.get("strike", 0.0))):
					_slowing = 2
					print("fight %6.2f  video %6.2f  IMPACT  the charge strikes" % [sim.time, _video])
		if sim.winner == -1 and sim.time < float(cfg.get("ff", 0.0)):
			screen.speed = 8.0
		elif _slowing == 1:
			# The screen stands still; the fight is stepped here, a fraction of a step a frame.
			screen.speed = 0.0
			if sim.phase == Sim.PHASE_BATTLE:
				sim.step(Sim.STEP * float(slow.get("pace", 0.25)))
		else:
			screen.speed = 1.0
		_report(sim)

	func _report(sim) -> void:
		var stamp := "fight %6.2f  video %6.2f" % [sim.time, _video]
		for sq in sim.squads:
			var who := "%s %s #%d" % ["yours" if sq.team == Sim.PLAYER else "theirs", sq.type, sim.squads.find(sq)]
			if typeof(sq.info) == TYPE_DICTIONARY and sq.info.has("name"):
				who += " (%s)" % String(sq.info["name"])
			var up: bool = sq.is_active()
			if _standing.has(sq) and _standing[sq] and not up:
				print("%s  BREAKS  %s (%d men left) at %s" % [stamp, who, sq.alive_n, sq.avg.round()])
			_standing[sq] = up
			var touch: bool = up and (sq.in_contact or sq.engaged)
			if touch and not _touching.get(sq, false):
				print("%s  MEETS   %s at %s" % [stamp, who, sq.avg.round()])
			_touching[sq] = touch
			var fate := String(sq.captain_fate)
			if fate != "" and _fates.get(sq, "") != fate:
				print("%s  CAPTAIN %s: %s (rolled %d)" % [stamp, who, fate, sq.death_roll])
			_fates[sq] = fate
		if not _clashed:
			var locked := 0
			for sq in sim.squads:
				if sq.team == Sim.PLAYER and sq.type != "archers" and sq.is_active() and sq.in_contact:
					locked += 1
			if locked >= 3:
				_clashed = true
				print("%s  CLASH   three of your companies are in the fight" % stamp)
		if sim.gate_max > 0.0:
			var hp := snappedf(sim.gate_hp / sim.gate_max, 0.25)
			if hp != _gate:
				print("%s  GATE    at %d%%" % [stamp, int(sim.gate_hp / sim.gate_max * 100.0)])
			_gate = hp
			if sim.works != null and int(sim.works.sections_broken) != _walls:
				_walls = int(sim.works.sections_broken)
				print("%s  WALL    %d stretches down" % [stamp, _walls])
		if sim.winner != -1 and not _over:
			_over = true
			print("%s  OVER    %s win" % [stamp, "you" if sim.winner == Sim.PLAYER else "they"])
		var rider = lens.subject(sim) if lens != null else null
		if sim.time - _said >= (0.25 if rider != null and _slowing < 2 else 2.0):
			_said = sim.time
			var men := [0, 0]
			var up := [0, 0]
			for sq in sim.squads:
				if sq.is_active():
					men[sq.team] += sq.alive_n
					up[sq.team] += 1
			var gap := "" if rider == null else "  gap %d" % int(lens.gap(sim, rider))
			print("%s  men %d/%d  companies %d/%d%s" % [stamp, men[0], men[1], up[0], up[1], gap])


# ---------------------------------------------------------------- cameras

## A camera for a field shot, run after the battle screen each frame. The HUD is put away
## and the view carried past the frame's edges, then pointed by "look":
##   "fight": the middle of the companies in contact (all of them until the lines meet)
##   "squad": a company of yours or theirs by "team" and "type" ("nth" among them),
##            leaning "lead" of the way toward the nearest enemy company
##   "spot":  from "from" to "to" (arena units, 840x1260) over "secs"
## "zoom" may ease to "zoom_to" over "zoom_secs"; "ease" is how fast the view catches up.
class Lens extends Node:
	const SPILL := Vector2(240, 240)
	var screen
	var plan := {}
	var _age := 0.0
	var _at := Vector2.ZERO
	var _zoom := 1.0
	var _live := false

	func _ready() -> void:
		process_priority = 1000

	func _process(delta: float) -> void:
		var sim = screen.sim
		if sim == null:
			return
		_age += delta
		for part in [screen.top_panel, screen.bottom_panel, screen.hint_toast, screen.inspect_pill, screen.objective_chip]:
			if part != null:
				part.visible = false
		var frame: Vector2 = screen.get_viewport_rect().size
		screen._view = Rect2(-SPILL, frame + SPILL * 2.0)
		screen._fit_scale = maxf(0.1, minf(frame.x / Sim.ARENA.x, frame.y / Sim.ARENA.y))
		var aim := _aim(sim)
		var zoom := float(plan.get("zoom", 2.8))
		if plan.has("zoom_to"):
			zoom = lerpf(zoom, float(plan["zoom_to"]), smoothstep(0.0, 1.0, clampf(_age / float(plan.get("zoom_secs", 6.0)), 0.0, 1.0)))
		if not _live:
			_live = true
			_at = aim
			_zoom = zoom
		var pull := 1.0 if String(plan.get("look", "fight")) == "spot" else 1.0 - exp(-delta * float(plan.get("ease", 1.4)))
		_at = _at.lerp(aim, pull)
		_zoom = zoom
		screen.cam_center = _at
		screen.cam_zoom = _zoom
		screen._apply_camera()
		screen._redraw()

	## The company a "squad" lens follows: the same one for the whole shot.
	var _subject = null

	func subject(sim):
		if String(plan.get("look", "fight")) != "squad":
			return null
		if _subject == null:
			var skip := int(plan.get("nth", 0))
			for sq in sim.squads:
				if sq.team == int(plan.get("team", 0)) and sq.type == String(plan.get("type", "cavalry")):
					if skip == 0:
						_subject = sq
						break
					skip -= 1
		return _subject

	func _nearest_foe(sim, sq):
		var near = null
		for other in sim.squads:
			if other.team != sq.team and other.is_active():
				if near == null or other.avg.distance_to(sq.avg) < near.avg.distance_to(sq.avg):
					near = other
		return near

	## How far `sq` is from the nearest enemy company, middle to middle.
	func gap(sim, sq) -> float:
		var near = _nearest_foe(sim, sq)
		return 1.0e9 if near == null else sq.avg.distance_to(near.avg)

	func _aim(sim) -> Vector2:
		match String(plan.get("look", "fight")):
			"spot":
				var f := smoothstep(0.0, 1.0, clampf(_age / float(plan.get("secs", 8.0)), 0.0, 1.0))
				return (plan.get("from", Sim.ARENA * 0.5) as Vector2).lerp(plan.get("to", Sim.ARENA * 0.5), f)
			"squad":
				var pick = subject(sim)
				if pick != null:
					var near = _nearest_foe(sim, pick)
					if near == null:
						return pick.avg
					return pick.avg.lerp(near.avg, float(plan.get("lead", 0.0)))
		var sum := Vector2.ZERO
		var weight := 0.0
		for sq in sim.squads:
			if not sq.is_active():
				continue
			var w := float(sq.alive_n) * (4.0 if sq.in_contact or sq.engaged else 0.25)
			sum += sq.avg * w
			weight += w
		return sum / weight if weight > 0.0 else Sim.ARENA * 0.5


## The map with its HUD put away, the view gliding from "from" to "to" (map units) while its
## scale eases from "scale" to "scale_to" over "secs".
class Chart extends Node:
	var screen
	var plan := {}
	var _age := 0.0

	func _ready() -> void:
		process_priority = 1000

	func _process(delta: float) -> void:
		_age += delta
		for part in ["top_panel", "bottom_bar", "sheet_panel", "pinned_chip"]:
			var node = screen.get(part)
			if node != null and node is CanvasItem:
				node.visible = false
		screen._view = Rect2(Vector2.ZERO, screen.get_viewport_rect().size)
		var f := smoothstep(0.0, 1.0, clampf(_age / float(plan.get("secs", 8.0)), 0.0, 1.0))
		screen.cam_center = (plan.get("from", Vector2(500, 700)) as Vector2).lerp(plan.get("to", Vector2(500, 700)), f)
		screen.cam_scale = lerpf(float(plan.get("scale", 1.6)), float(plan.get("scale_to", plan.get("scale", 1.6))), f)
		screen._clamp_camera()
		screen._sync_layers()
		screen.queue_redraw()


## A player's thumb: presses a reply (Reply_<id>) or a button by its words at a second of
## the recording, waiting until the button is there to press.
class Hand extends Node:
	var tree: SceneTree
	var cues: Array = []
	var _age := 0.0
	var _next := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_age += delta
		if _next >= cues.size() or _age < float(cues[_next][0]):
			return
		var scene := tree.current_scene
		if scene == null:
			return
		var want := String(cues[_next][1])
		var button := scene.find_child("Reply_" + want, true, false) as Button
		if button == null or not button.is_visible_in_tree() or button.disabled:
			button = null
			for node in scene.find_children("*", "Button", true, false):
				var b := node as Button
				if b.is_visible_in_tree() and not b.disabled and (b.text.to_lower().contains(want.to_lower()) or String(b.name).to_lower().contains(want.to_lower())):
					button = b
					break
		if button != null:
			button.pressed.emit()
			_next += 1
