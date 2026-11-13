extends SceneTree
## Sets the game up for one shot of the trailer, then lets it play while Movie Maker records.
## Run through tools/trailer/record.sh, which sizes the window and names the output:
##   tools/trailer/record.sh <shot> <seconds> [portrait|landscape]
## The shots are in SHOTS below. Nothing here touches your own campaign: the game doesn't
## save, and preferences go to a scratch file (TRAILER_TMP).
##
## A shot can press replies on cue, as a player's taps would: "taps" is a list of
## [seconds, what], where `what` is a reply's id (Reply_<id>) or words on a button.

const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const Opening = preload("res://scripts/menu/opening.gd")
const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const BattleCam = preload("res://tools/trailer/battle_cam.gd")
const MapCam = preload("res://tools/trailer/map_cam.gd")
const Taps = preload("res://tools/trailer/taps.gd")

## Battles: your people and theirs, the ground (open, hills, woods, river, pass, village),
## the hour, companies a side, and the camera (battle_cam.gd). "hud": keep the game's HUD.
## "advance_at": press Advance all then (for ground where both commanders would wait).
## Landscape, a zoom under about 2.7 shows past the field's edges. The ground is drawn as
## the foe's land (a Kharzani foe: desert), whatever `biome` says.
const SHOTS := {
	"opening": {"kind": "opening"},
	"home": {"kind": "home", "culture": "vardish", "hour": 7.0, "silver": 2400, "renown": 340},
	"warband": {"kind": "scene", "scene": "res://scenes/main_menu.tscn", "culture": "vardish"},
	"map_fly": {"kind": "map", "culture": "vardish", "hour": 5.5, "speed": 2.0, "wait": true,
		"cam": {"from": Vector2(260, 330), "to": Vector2(640, 760), "scale_from": 2.2, "scale_to": 1.5, "time": 14.0}},
	"map_ride": {"kind": "map", "culture": "kharzani", "hour": 16.0, "to": "zeyra", "hud": true},
	"map_isles": {"kind": "map", "culture": "ryumon", "hour": 18.5, "speed": 2.0, "wait": true,
		"cam": {"from": Vector2(880, 250), "to": Vector2(850, 560), "scale_from": 2.6, "scale_to": 2.2, "time": 12.0}},
	"talk_ravensford": {"kind": "talk", "culture": "vardish", "place": "ravensford", "realm": "vardmark", "hour": 10.0,
		"taps": [[5.0, "story"], [9.5, "hill"]]},
	"talk_qasr": {"kind": "talk", "culture": "kharzani", "place": "qasr_hamra", "realm": "kharzan", "hour": 17.5,
		"taps": [[5.0, "story"], [9.5, "hill"]]},
	"talk_kitayama": {"kind": "talk", "culture": "ryumon", "place": "kitayama", "realm": "ryumon", "hour": 9.0,
		"taps": [[5.0, "story"], [9.5, "hill"]]},
	"town_highcliff": {"kind": "settlement", "culture": "vardish", "place": "highcliff", "hour": 11.0},
	"town_khalun": {"kind": "settlement", "culture": "kharzani", "place": "khalun", "hour": 17.0},
	"town_kurogane": {"kind": "settlement", "culture": "ryumon", "place": "kurogane", "hour": 20.5},
	"wedding": {"kind": "wedding", "taps": [[3.0, "begin"], [9.0, "vow_promise"], [15.0, "toast_absent"]]},
	"battle_open": {"kind": "battle", "culture": "vardish", "foe": "kharzani", "site": "open",
		"biome": "vardmark", "hour": 9.0, "seed": 11, "cam": {"mode": "clash", "zoom": 2.6}},
	"battle_hud": {"kind": "battle", "culture": "vardish", "foe": "ryumon", "site": "hills",
		"biome": "vardmark", "hour": 12.0, "seed": 5, "hud": true, "no_title": true},
	"battle_title": {"kind": "battle", "culture": "kharzani", "foe": "vardish", "site": "open",
		"biome": "kharzan", "hour": 7.0, "seed": 21, "cam": {"mode": "pan", "from": Vector2(420, 900), "to": Vector2(420, 640),
		"zoom": 2.4, "time": 7.0}},
	"battle_cavalry": {"kind": "battle", "culture": "vardish", "foe": "kharzani", "site": "open",
		"biome": "kharzan", "hour": 15.5, "seed": 8, "no_title": true, "cam": {"mode": "clash", "zoom": 3.0}},
	"battle_woods": {"kind": "battle", "culture": "ryumon", "foe": "vardish", "site": "woods",
		"biome": "ryumon", "hour": 18.0, "seed": 4, "no_title": true, "cam": {"mode": "clash", "zoom": 2.9}},
	"battle_river": {"kind": "battle", "culture": "vardish", "foe": "ryumon", "site": "river",
		"biome": "vardmark", "hour": 6.5, "seed": 9, "no_title": true, "advance_at": 2.0,
		"cam": {"mode": "clash", "zoom": 2.9}},
	"battle_night": {"kind": "battle", "culture": "ryumon", "foe": "kharzani", "site": "hills",
		"biome": "ryumon", "hour": 22.0, "seed": 14, "no_title": true, "cam": {"mode": "clash", "zoom": 2.8}},
	"battle_archers": {"kind": "battle", "culture": "vardish", "foe": "kharzani", "site": "open",
		"biome": "vardmark", "hour": 16.5, "seed": 30, "no_title": true, "cam": {"mode": "follow", "type": "archers", "team": 1, "zoom": 2.9}},
	"battle_win": {"kind": "battle", "culture": "vardish", "foe": "kharzani", "site": "open", "companies": 10, "foes": 5,
		"biome": "vardmark", "hour": 17.5, "seed": 12, "no_title": true, "fast_until": 40.0, "cam": {"mode": "clash", "zoom": 2.9}},
	"battle_result": {"kind": "battle", "culture": "vardish", "foe": "kharzani", "site": "open", "companies": 8, "foes": 4,
		"biome": "vardmark", "hour": 17.5, "seed": 12, "no_title": true, "hud": true, "fast_until": 60.0},
	"battle_wide": {"kind": "battle", "culture": "vardish", "foe": "kharzani", "site": "open", "companies": 12,
		"biome": "vardmark", "hour": 17.0, "seed": 40, "no_title": true, "cam": {"mode": "clash", "zoom": 2.8, "zoom_to": 3.4, "zoom_time": 14.0}},
}

var gs
var scenes
var shot := ""
var cfg := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	var sound = root.get_node("Sound")
	gs.persist = false
	sound.settings_path = OS.get_environment("TRAILER_TMP").path_join("trailer-settings.cfg")
	SaveSlots.dir = "user://trailer_saves"
	sound.set_music_on(false) # the trailer is scored separately; the clips keep the field sounds
	sound.set_sounds_on(true)
	sound.set_illustrations(true)
	sound.set_reduced_motion(false)
	sound.set_instant_text(false)
	sound.set_show_performance(false)
	_seen_every_card()
	cfg = SHOTS.get(shot, {})
	if cfg.is_empty():
		push_error("Unknown shot: %s" % shot)
		quit(1)
		return
	gs.rng.seed = int(cfg.get("seed", 1))
	seed(int(cfg.get("seed", 1)))
	match String(cfg["kind"]):
		"opening":
			gs.world = null
			Opening.played = false
			change_scene_to_file("res://scenes/title.tscn")
		"home":
			_campaign()
			Opening.played = true
			change_scene_to_file("res://scenes/title.tscn")
		"scene":
			_campaign()
			change_scene_to_file(String(cfg["scene"]))
		"map":
			_campaign()
			if cfg.has("to"):
				gs.world.travel(String(cfg["to"]))
			elif bool(cfg.get("wait", false)):
				gs.world.wait(48.0)
			await _open("world_map.tscn")
			var map = current_scene
			map.speed = float(cfg.get("speed", 1.0))
			if map.has_method("_close_sheet"):
				map._close_sheet()
			if cfg.has("cam"):
				var cam := MapCam.new()
				cam.screen = map
				cam.setup(cfg["cam"], bool(cfg.get("hud", false)))
				map.add_child(cam)
		"talk":
			_campaign()
			var p = gs.world.player()
			p.node = String(cfg["place"])
			p.next = ""
			p.path = []
			await _open("world_map.tscn")
			current_scene._close_sheet()
			current_scene._open_talk(_lord_of(String(cfg["realm"]), String(cfg["place"])), "road")
		"settlement":
			_campaign()
			var p = gs.world.player()
			p.node = String(cfg["place"])
			p.next = ""
			p.path = []
			scenes.settlement_arrival_pending = true
			change_scene_to_file("res://scenes/settlement.tscn")
		"wedding":
			await _wedding()
		"battle":
			_setup_battle()
			await _open("battle.tscn")
			_battle_ready(current_scene)
	if cfg.has("taps"):
		var taps := Taps.new()
		taps.tree = self
		taps.plan = cfg["taps"]
		root.add_child(taps)


## A fresh campaign of the shot's people at the shot's hour, where no one stops you on the
## road (so the shot isn't interrupted).
func _campaign() -> void:
	gs.new_campaign(String(cfg.get("culture", "vardish")))
	gs.persist = false
	gs.silver = int(cfg.get("silver", gs.silver))
	gs.renown = int(cfg.get("renown", gs.renown))
	gs.world.hour = float(cfg.get("hour", 8.0))
	_quiet_roads()


func _quiet_roads() -> void:
	var w = gs.world
	w.friendly_quiet_until = 1.0e9
	for b in w.bands():
		b.grace_until = 1.0e9
	for lp in w.lord_parties():
		lp.grace_until = 1.0e9


func _open(file: String) -> void:
	change_scene_to_file("res://scenes/" + file)
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(file) and current_scene.is_node_ready():
			break
	await process_frame


## The lord of `realm` who holds `place`, else its ruler.
func _lord_of(realm: String, place: String) -> int:
	for l in gs.world.lords:
		if String(l["realm"]) == realm and String(l.get("fief", "")) == place:
			return int(l["id"])
	for l in gs.world.lords:
		if String(l["realm"]) == realm and bool(l.get("ruler", false)):
			return int(l["id"])
	return 0


## The one-time cards a battle stops for (the ground's rules, an objective's) count as seen,
## so no shot waits on a tap.
func _seen_every_card() -> void:
	var f := ConfigFile.new()
	f.load("user://settings.cfg")
	for k in ["hills", "woods", "river", "pass", "village"]:
		f.set_value("terrain_hints", k, true)
	for k in ["chief", "ambush", "village", "siege"]:
		f.set_value("objective_hints", k, true)
	f.save("user://settings.cfg")


## Edda's wedding at Ravensford, the way tests/wedding_tests.gd gets there: her story at its
## last chapter, yes to a public wedding, the days of waiting, then the day itself.
func _wedding() -> void:
	gs.new_campaign(Cultures.VARDISH)
	gs.persist = false
	gs.silver = 1000
	gs.food = 500
	var soc = gs.world.social
	gs.world.player().node = "ravensford"
	var rel: Dictionary = soc.relationships["edda"]
	rel["romantic_intent"] = true
	rel["trust"] = 60
	rel["status"] = Relationships.COMMITTED
	soc.quests["quest_edda"]["chapter"] = 5
	var person: Dictionary = soc.get_candidate_person("edda")
	soc.houses[person["house_id"]]["standing"] = 30
	soc.add_memory(person["id"], "Shared the story of Edda's spare spoon.", {"kind": "visit", "scene_id": "edda_spare_spoon"})
	scenes.active_candidate_id = "edda"
	scenes.conversation_return = "res://scenes/settlement.tscn"
	await _open("conversation.tscn")
	var talk = current_scene
	for id in ["story", "decide_marry_public", "confirm", "place_ravensford", "back"]:
		talk.choose(id)
	var w = gs.world
	var until: float = w.hour + 96.0
	while w.hour < until:
		w.wait(6.0)
		gs.advance(6.0)
		w.encounter = -1
	w.player().node = "ravensford"
	w.player().next = ""
	w.hour = floorf(w.hour / 24.0) * 24.0 + 15.0
	gs.fallen.append({"first": "Rowan", "name": "Rowan"})
	scenes.wedding_replay = ""
	scenes.wedding_return = "res://scenes/world_map.tscn"
	await _open("wedding.tscn")


## Your warband (with its captains) against a host of `foe`, on the shot's ground and hour.
func _setup_battle() -> void:
	var culture := String(cfg["culture"])
	var foe := String(cfg["foe"])
	gs.new_campaign(culture)
	gs.persist = false
	gs.battles = 10 # past the first battles' narration
	gs.world.hour = float(cfg.get("hour", 12.0))
	var n := int(cfg.get("companies", 10))
	gs.army = []
	for i in n:
		gs.army.append(gs._new_squad(Troops.ORDER[i % 4]))
	var theirs := []
	for i in int(cfg.get("foes", n)):
		var t2: String = Troops.ORDER[(i + 1) % 4]
		var u2 := Units.recruit(foe, t2)
		theirs.append({"id": 9100 + i, "type": t2, "unit": u2, "men": Units.full_size(u2), "culture": foe})
	var site := {"type": String(cfg.get("site", "open")), "seed": int(cfg.get("seed", 1)),
		"biome": String(cfg.get("biome", "vardmark")), "fair": true}
	if site["type"] == "river":
		site["river"] = "the Raven"
	gs.pending_battle = {"enemy": theirs, "culture": foe, "site": site, "objective": "rout",
		"name": String(cfg.get("name", "the host")), "temperament": "", "can_withdraw": true}


## The computer takes your side too; the fight starts with its title, and the camera is ours.
func _battle_ready(screen) -> void:
	var sim = screen.sim
	sim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
	sim.ai[Sim.PLAYER].deploy(sim)
	if not bool(cfg.get("no_title", false)):
		screen._on_fight()
	else:
		screen._start_battle()
	if cfg.has("advance_at"):
		# As a player would: your commander steps aside and you press Advance all.
		var go := func():
			if is_instance_valid(screen):
				screen.sim.ai[Sim.PLAYER] = null
				screen._on_advance()
		create_timer(float(cfg["advance_at"])).timeout.connect(go)
	if cfg.has("fast_until"):
		screen.speed = 6.0
		var until := float(cfg["fast_until"])
		var slow := func():
			if is_instance_valid(screen):
				screen.speed = 1.0
		create_timer(until / 6.0).timeout.connect(slow)
	if bool(cfg.get("hud", false)) and not cfg.has("cam"):
		return
	var cam := BattleCam.new()
	cam.screen = screen
	cam.setup(cfg.get("cam", {}), bool(cfg.get("hud", false)))
	screen.add_child(cam)
