## Music and sound for every screen (an autoload). One piece of music at a time,
## crossfading into the next; the battle's layers kept in step and faded by the fight; a
## pool of players for effects, and another for battle sounds placed where they happen
## (left or right on the screen, quieter and duller far off), each in its group (melee,
## missiles, voices, cues) through a limiter; and a click and a little give on every
## button. Music and sound can each be switched off, and the choice is kept on the device.
##
## The audio itself is rendered by tools/music.py into assets/audio/.
extends Node

const MUSIC_PATH := "res://assets/audio/music/%s.ogg"
const SFX_PATH := "res://assets/audio/sfx/%s.ogg"
const SETTINGS_PATH := "user://settings.cfg"
## Seconds to fade one piece of music into the next.
const FADE := 1.4
## Road, camp and battlefield ambience changes more quickly than music, but never cuts.
const AMBIENCE_FADE := 0.55
const SfxLevels = preload("res://scripts/data/sfx_levels.gd")
## Music sits under the effects; in battle, further under, so the fighting carries over it.
const MUSIC_DB := -7.0
const BATTLE_MUSIC_DB := -11.0
const SILENT_DB := -60.0
## How loud each effect plays, so a click doesn't drown a bell.
const SFX_DB := {
	"click": -14.0, "page": -16.0, "coins": -8.0, "horn": -5.0, "alarm": -6.0,
	"clash1": -15.0, "clash2": -15.0, "clash3": -15.0, "arrows": -11.0, "charge": -7.0,
	"rout": -11.0, "dice": -5.0, "bell": -6.0, "hooves": -15.0,
	"footsteps": -20.0, "camp": -25.0, "morale_low": -10.0, "bond_rank": -8.0, "promotion": -8.0,
	"crossbow": -10.0, "javelin": -11.0, "horsebow": -12.0, "water": -20.0, "birds": -20.0,
	"road_open": -25.0, "road_night": -26.0, "settlement_edge": -26.0,
	"settlement_vardish": -27.0, "settlement_kharzani": -27.0, "settlement_ryumon": -27.0,
	"objective": -6.0,
	"sword": -12.0, "shield": -12.0, "spear": -12.0, "heavy": -11.0, "melee_bed": -15.0,
	"arrows_land": -13.0, "bolts_land": -12.0, "javelins_land": -11.0, "quiver_empty": -12.0,
	"warcry": -10.0, "panic": -12.0, "cheer": -9.0, "gasp": -12.0,
	"cav_impact": -6.0, "brace": -9.0, "captain_down": -6.0,
	"ram": -7.0, "gate_break": -4.0, "ladders": -9.0,
	"call_start": -5.0, "call_charge": -7.0, "call_retreat": -7.0, "reinforce": -8.0,
	"order_select": -15.0, "order_march": -10.0, "order_attack": -9.0, "order_refuse": -10.0,
}
## How loud each battle sound peaks in play: its loudest tenth of a second, in dBFS, before
## where it is on the field and how far out the view is. Each file is trimmed to this from
## its own measured level (scripts/data/sfx_levels.gd), so every take of a sound is as
## loud as the next. The battle music averages about -22 dBFS with the fighting layer up:
## routine blows and missiles peak a few dB over it, voices and charges more, and the
## moments that turn a battle well over it. Loops (the din, hooves, footsteps) sit under it.
const PEAK_DB := {
	"sword": -16.0, "shield": -16.0, "spear": -16.0, "heavy": -15.0, "clash1": -17.0, "clash2": -17.0, "clash3": -17.0,
	"arrows": -17.0, "crossbow": -17.0, "javelin": -17.0, "horsebow": -18.0,
	"arrows_land": -16.0, "bolts_land": -16.0, "javelins_land": -16.0, "quiver_empty": -19.0,
	"warcry": -14.0, "panic": -15.0, "cheer": -14.0, "gasp": -17.0, "rout": -15.0,
	"cav_impact": -11.0, "charge": -13.0, "brace": -14.0, "captain_down": -12.0,
	"ram": -14.0, "gate_break": -10.0, "ladders": -16.0,
	"call_start": -12.0, "call_charge": -12.0, "call_retreat": -12.0, "reinforce": -13.0,
	"melee_bed": -24.0, "hooves": -25.0, "footsteps": -28.0,
}
## Sounds recorded in several takes: "sword" plays one of sword_1..sword_12, never the
## same one twice running.
const BANKS := {"sword": 12, "shield": 12, "spear": 12, "heavy": 12, "arrows_land": 3, "bolts_land": 2,
	"javelins_land": 2, "warcry": 3, "panic": 2, "cheer": 2, "ram": 3}
## The most of one battle sound that may sound at once; more than that, and the newest waits.
const CAPS := {"sword": 3, "shield": 3, "spear": 3, "heavy": 2, "arrows_land": 2, "bolts_land": 2,
	"javelins_land": 2, "warcry": 2, "panic": 2, "cheer": 1, "ram": 1, "brace": 2, "cav_impact": 2}
## Which group (and bus) each battle sound plays in. Anything else is a cue.
const GROUPS := {
	"Melee": ["sword", "shield", "spear", "heavy", "clash1", "clash2", "clash3", "cav_impact", "brace", "charge", "melee_bed", "ram", "gate_break", "ladders"],
	"Missiles": ["arrows", "crossbow", "javelin", "horsebow", "arrows_land", "bolts_land", "javelins_land", "quiver_empty"],
	"Voices": ["warcry", "panic", "cheer", "gasp", "rout", "captain_down"],
}
const POOL_2D := 16
## How far (in screen pixels) a battle sound carries before it fades out entirely.
const HEARING := 2400.0
const POOL := 10

## Tests may use a disposable preference file without touching device settings.
var settings_path := SETTINGS_PATH
var music_on := true
var sounds_on := true
## How loud music and sound play, 0 to 1 (a slider each in Settings), on top of on/off.
var music_volume := 1.0
var sound_volume := 1.0
var romance_invitations := true
var text_scale := 1.0
var reduced_motion := false
## Words in a conversation appear whole rather than being written out.
var instant_text := false
var illustrations_enabled := true
## Vibration on supported devices: a light tap for an accepted order, a stronger one for a
## decisive moment. Separate from reduced motion.
var haptics_enabled := true
## How hard the battle shakes: 0 off, 0.5 light, 1 full. Reduced motion stills it whatever this says.
var shake := 1.0
## A readout of what each battle frame costs (sim, drawing, the renderer), for judging how
## big a battle a device can take.
var show_performance := false
## On a computer, the window fills the screen (F11 or Alt+Enter, or Settings). Kept here
## with the other device preferences; Scenes applies it.
var fullscreen := false
## Pulses sent, for tests (and so a headless run can see them).
var haptic_count := 0
## Until this time, routine contact sounds play quieter, so a critical cue cuts through.
var _duck_until := 0.0
## Routine contact sounds, which give way to critical cues.
const CONTACT := ["clash1", "clash2", "clash3", "arrows", "footsteps", "hooves", "crossbow", "javelin", "horsebow"]
const DUCK_DB := -6.0
var _track := ""
var _music: Array[AudioStreamPlayer] = []
var _current := 0
## The battle's layers, played in step once the fighting starts: drums and ostinato
## (always), the tune (with the fighting), and a winning and a losing layer.
var _layers := {}
var _intensity := 0.0
var _balance := 0.0
var _battle_realm := ""
var _stinger: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _loop_alt: AudioStreamPlayer
var _loop_current := 0
var _loop_name := ""
var _movement_loop: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _last_take := {}
var _melee_bed: AudioStreamPlayer
var _melee := 0.0
## Battle sounds placed so far, by name (for tests, and so a headless run can see them).
var placed := {}
var _streams := {}
var _last := {}
var _fades := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("Sounds")
	# Battle groups: melee, missiles and voices pass through "Field" (dulled when the view is
	# far off); cues go straight to Sounds. A limiter on Sounds keeps a big moment clean.
	_make_bus("Field", "Sounds")
	for group in ["Melee", "Missiles", "Voices"]:
		_make_bus(group, "Field")
	_make_bus("Cues", "Sounds")
	var sounds_bus := AudioServer.get_bus_index("Sounds")
	if AudioServer.get_bus_effect_count(sounds_bus) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(sounds_bus, limiter)
	var field_bus := AudioServer.get_bus_index("Field")
	if AudioServer.get_bus_effect_count(field_bus) == 0:
		var dull := AudioEffectLowPassFilter.new()
		dull.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(field_bus, dull)
	for i in 2:
		var mp := _player("Music")
		mp.finished.connect(_on_music_finished.bind(mp))
		_music.append(mp)
	for key in BATTLE_LAYERS:
		_layers[key] = _player("Music")
	_stinger = _player("Music")
	_stinger.finished.connect(_after_stinger)
	_loop = _player("Sounds")
	_loop_alt = _player("Sounds")
	_movement_loop = _player("Sounds")
	for i in POOL:
		_pool.append(_player("Sounds"))
	for i in POOL_2D:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = HEARING
		p.attenuation = 1.6
		p.panning_strength = 1.6
		add_child(p)
		_pool_2d.append(p)
	_melee_bed = _player("Melee")
	_load_settings()
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	# The battle's time, heard: slowed or stopped, the field dulls and the music steps back.
	if _time_slow != _time_want:
		_time_slow = move_toward(_time_slow, _time_want, delta * TIME_EASE)
		_apply_field()
		_apply_music_volume()
		if _melee_bed.playing:
			_melee_bed.pitch_scale = time_pitch()
	# The din of the melee follows how much of the field is fighting.
	if _melee > 0.0 and not _melee_bed.playing and sounds_on:
		_melee_bed.stream = _stream(SFX_PATH % "melee_bed", true)
		_melee_bed.volume_db = SILENT_DB
		_melee_bed.play()
	if _melee_bed.playing:
		var want_bed := _level_db("melee_bed", "melee_bed") + linear_to_db(maxf(0.01, _melee))
		_melee_bed.volume_db = move_toward(_melee_bed.volume_db, want_bed, delta * 18.0)
		if _melee <= 0.0 and _melee_bed.volume_db <= -55.0:
			_melee_bed.stop()
	# The battle's upper layers follow the fighting, slowly.
	var base: AudioStreamPlayer = _layers["base"]
	if base.playing and not _layers_fading:
		_toward("high", _intensity, delta)
		_toward("win", clampf((_balance - 0.15) / 0.45, 0.0, 1.0), delta)
		_toward("lose", clampf((-_balance - 0.1) / 0.45, 0.0, 1.0), delta)


func _toward(key: String, level: float, delta: float) -> void:
	var p: AudioStreamPlayer = _layers[key]
	var want := BATTLE_MUSIC_DB + linear_to_db(maxf(0.02, level))
	p.volume_db = move_toward(p.volume_db, want, delta * 12.0)


# ---------------------------------------------------------------- music

## The battle music's layers (all one length, in step) and its tempo.
const BATTLE_LAYERS := ["base", "high", "win", "lose"]
const BATTLE_REALMS := ["vardish", "kharzani", "ryumon", "siege"]
## Seconds in a bar of the battle music (120 beats a minute, four to the bar).
const BATTLE_BAR := 2.0
## Where a quiet battle layer rests: the floor _toward() fades down to.
const LAYER_FLOOR_DB := BATTLE_MUSIC_DB - 34.0
var _layers_fading := false


## The realms' road themes don't play end to end forever: after each time through, the
## road and the wind have the map to themselves for a while, and then the tune comes back.
const RESTING := ["vardish", "kharzani", "ryumon"]
const REST_MIN := 25.0
const REST_MAX := 55.0
## Whether the music is resting between plays of a road theme (for tests and the map).
var resting := false


## Fade into the named piece (title, vardish, kharzani, ryumon, ...), unless it's already on.
func play_music(name: String) -> void:
	if name == _track:
		return
	_track = name
	resting = false
	_stop_layers()
	var old := _music[_current]
	_current = 1 - _current
	var next := _music[_current]
	next.stream = _stream(MUSIC_PATH % name, not RESTING.has(name))
	next.volume_db = SILENT_DB
	next.play()
	_fade(next, MUSIC_DB, FADE)
	_fade(old, SILENT_DB, FADE, true)


## A road theme has played through: rest, then play it again if it's still the one wanted.
func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p != _music[_current] or not RESTING.has(_track):
		return
	var track := _track
	resting = true
	await get_tree().create_timer(randf_range(REST_MIN, REST_MAX)).timeout
	if _track != track or p != _music[_current] or p.playing:
		return
	resting = false
	p.volume_db = SILENT_DB
	p.play()
	_fade(p, MUSIC_DB, FADE * 2.0)


## The battle begins: while you deploy, the realm's drone and heartbeat drum. `realm` is
## whose music it is (the enemy's people), or "siege" for an assault on walls.
func play_battle(realm: String = "vardish") -> void:
	_battle_realm = realm if BATTLE_REALMS.has(realm) else "vardish"
	_intensity = 0.0
	_balance = 0.0
	play_music("deploy_" + _battle_realm)


## The lines are ordered forward: the full battle music, every layer starting together,
## the drums and ostinato at once and the rest silent until the fight calls for them.
func battle_clash() -> void:
	if _battle_realm == "" or _layers["base"].playing:
		return
	_track = "battle"
	var names := {"base": "base_%s" % _battle_realm, "high": "high_%s" % _battle_realm, "win": "turn_win", "lose": "turn_lose"}
	_layers_fading = false
	for key in BATTLE_LAYERS:
		var p: AudioStreamPlayer = _layers[key]
		p.stream = _stream(MUSIC_PATH % names[key], true)
		# The upper layers wait just under hearing, so they answer the fight quickly.
		p.volume_db = SILENT_DB if key == "base" else LAYER_FLOOR_DB
	for key in BATTLE_LAYERS:
		_layers[key].play(0.0)
	_fade(_layers["base"], BATTLE_MUSIC_DB, 0.8)
	for p in _music:
		_fade(p, SILENT_DB, 1.2, true)


## How much of the field is fighting, from 0 to 1.
func set_battle_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)


## Who is winning, from -1 (your lines are breaking) to 1 (theirs are).
func set_battle_balance(value: float) -> void:
	_balance = clampf(value, -1.0, 1.0)


## A short piece over the end of a battle. It waits for the next half bar of the battle
## music so the music ends on the beat, then a quiet piece plays under the results.
func stinger(name: String) -> void:
	_track = "stinger:" + name
	_battle_realm = ""
	var wait := 0.0
	var base: AudioStreamPlayer = _layers["base"]
	if base.playing:
		var half := BATTLE_BAR / 2.0
		wait = half - fmod(base.get_playback_position(), half)
		if wait < 0.12:
			wait += half
	for p in _music:
		_fade(p, SILENT_DB, 0.4, true)
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
		if _track != "stinger:" + name:
			return
	_stop_layers(0.25)
	_stinger.stream = _stream(MUSIC_PATH % name, false)
	_stinger.volume_db = MUSIC_DB + 3.0
	_stinger.play()


## After the stinger, the quiet piece for the results (unless something else has
## started meanwhile).
func _after_stinger() -> void:
	if _track.begins_with("stinger:"):
		var won := _track == "stinger:victory"
		play_music("rest_victory" if won else "rest_defeat")


func _stop_layers(seconds: float = 0.6) -> void:
	if not _layers["base"].playing:
		return
	_layers_fading = true
	for key in BATTLE_LAYERS:
		_fade(_layers[key], SILENT_DB, seconds, true)


# ---------------------------------------------------------------- effects

## Play an effect. `jitter` varies its pitch a little each time, so repeats don't sound
## canned; `gap` is the fewest seconds between two plays of the same effect.
func play(name: String, volume_db: float = 0.0, jitter: float = 0.0, gap: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if gap > 0.0 and now - float(_last.get(name, -99.0)) < gap:
		return
	_last[name] = now
	if now < _duck_until and CONTACT.has(name):
		volume_db += DUCK_DB
	var file := take(name)
	var stream := _stream(SFX_PATH % file, false)
	if stream == null:
		return
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[0]
		_pool.push_back(_pool.pop_front())
	p.stream = stream
	p.volume_db = _level_db(name, file) + volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	p.bus = group_of(name)
	p.play()


## The file to play for `name`: one of its takes if it has several (never the one just
## played), else the name itself.
func take(name: String) -> String:
	var n := int(BANKS.get(name, 0))
	if n <= 1:
		return name if n == 0 else name + "_1"
	var last := int(_last_take.get(name, 0))
	var pick := randi_range(1, n - 1)
	if pick >= last:
		pick += 1
	_last_take[name] = pick
	return "%s_%d" % [name, pick]


## The bus a sound plays on: its battle group, or Cues.
func group_of(name: String) -> String:
	for group in GROUPS:
		if (GROUPS[group] as Array).has(_family(name)):
			return group
	return "Cues" if _family(name) != "click" else "Sounds"


## "call_start_vardish" -> "call_start", "sword" -> "sword".
func _family(name: String) -> String:
	for prefix in ["call_start", "call_charge", "call_retreat", "reinforce"]:
		if name.begins_with(prefix):
			return prefix
	return name


func _base_db(name: String) -> float:
	return float(SFX_DB.get(name, SFX_DB.get(_family(name), -8.0)))


## The volume to play `file` (one take of the sound `name`) at: a battle sound is trimmed
## from its measured level to its target peak; anything else plays at its set level.
func _level_db(name: String, file: String) -> float:
	var family := _family(name)
	if PEAK_DB.has(family) and SfxLevels.LOUDEST.has(file):
		return float(PEAK_DB[family]) - float(SfxLevels.LOUDEST[file])
	return _base_db(name)


## A battle sound where it happens: `at` is its place on the screen, so it sounds from
## that side, and quieter the farther it is from the middle of the view.
func play_at(name: String, at: Vector2, volume_db: float = 0.0, jitter: float = 0.0, gap: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key := "@" + name
	if gap > 0.0 and now - float(_last.get(key, -99.0)) < gap:
		return
	var cap := int(CAPS.get(name, 3))
	var busy := 0
	var free: AudioStreamPlayer2D = null
	for q in _pool_2d:
		if q.playing:
			if String(q.get_meta("family", "")) == name:
				busy += 1
		elif free == null:
			free = q
	if busy >= cap or free == null:
		return
	_last[key] = now
	if now < _duck_until and (CONTACT.has(name) or GROUPS["Melee"].has(name) or GROUPS["Missiles"].has(name)):
		volume_db += DUCK_DB
	var file := take(name)
	var stream := _stream(SFX_PATH % file, false)
	if stream == null:
		return
	free.stream = stream
	free.bus = group_of(name)
	free.global_position = at
	free.volume_db = _level_db(name, file) + volume_db
	free.pitch_scale = pitch * time_pitch() * (1.0 + randf_range(-jitter, jitter))
	free.set_meta("family", name)
	free.play()
	placed[name] = int(placed.get(name, 0)) + 1


## How much of the field is locked in melee, from 0 to 1: the din follows it.
func set_melee(level: float) -> void:
	_melee = clampf(level, 0.0, 1.0)


## How far out the battle view is, from 0 (close in) to 1 (the whole field): far off, the
## fighting sounds duller and a little quieter.
func set_field_distance(far: float) -> void:
	_far = clampf(far, 0.0, 1.0)
	_apply_field()


## The field bus as the view and the battle's time leave it: duller and a little quieter far
## out, and much duller (and quieter) the slower the fight runs, down to a muffle when paused.
func _apply_field() -> void:
	var bus := AudioServer.get_bus_index("Field")
	if bus == -1:
		return
	var dull := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	if dull != null:
		var by_view := lerpf(20000.0, 4500.0, _far)
		var by_time := lerpf(20000.0, SLOW_CUTOFF, pow(_time_slow, 0.6))
		dull.cutoff_hz = minf(by_view, by_time)
	AudioServer.set_bus_volume_db(bus, lerpf(0.0, -2.5, _far) + lerpf(0.0, SLOW_FIELD_DB, _time_slow))


# ---------------------------------------------------------------- the battle's time

## How far out the view is (0 close, 1 the whole field), and how slowed the fight sounds
## (0 at full pace, 1 stopped), eased toward what the battle last reported.
var _far := 0.0
var _time_slow := 0.0
var _time_want := 0.0
## Stopped, the field is heard through a wall: cut to this, quieter by this, the music down
## by this, and the men's sounds pitched down toward this.
const SLOW_CUTOFF := 700.0
const SLOW_FIELD_DB := -4.0
const SLOW_MUSIC_DB := -9.0
const SLOW_PITCH := 0.82
## How quickly the sound follows the time (whole range per second / this).
const TIME_EASE := 4.0


## The battle says how fast it runs, every frame: 1 full pace, 0 paused.
func set_battle_time(pace: float) -> void:
	_time_want = clampf(1.0 - pace, 0.0, 1.0)


## How slowed the battle sounds now, 0 to 1.
func time_slowed() -> float:
	return _time_slow


## The pitch the field's sounds play at under the battle's time.
func time_pitch() -> float:
	return lerpf(1.0, SLOW_PITCH, _time_slow)


## The battle is over: its din and everything placed on the field stop.
func end_battle_sounds() -> void:
	_melee = 0.0
	_melee_bed.stop()
	_melee_bed.pitch_scale = 1.0
	for q in _pool_2d:
		q.stop()
	_time_want = 0.0
	_time_slow = 0.0
	_apply_music_volume()
	set_field_distance(0.0)


# ---------------------------------------------------------------- warming up

## Every battle sound that can play in the first seconds of a fight, read in before it so the
## first blow, charge or volley doesn't wait on the disk. Called while the screen is dark
## between the map and the field. Returns how many streams were read.
func warm_battle(realm: String = "") -> int:
	var n := 0
	var names: Array = []
	for family in PEAK_DB:
		var takes := int(BANKS.get(family, 0))
		if takes > 1:
			for k in takes:
				names.append("%s_%d" % [family, k + 1])
		elif family in ["call_start", "call_charge", "call_retreat", "reinforce"]:
			for c in ["vardish", "kharzani", "ryumon"]:
				names.append("%s_%s" % [family, c])
		else:
			names.append(family)
	names.append_array(["order_select", "order_march", "order_attack", "order_refuse", "charge", "horn", "dice", "bell", "morale_low"])
	for name in names:
		var looped: bool = name in ["melee_bed", "hooves", "footsteps"]
		if _stream(SFX_PATH % name, looped) != null:
			n += 1
	if realm != "":
		for key in ["base_%s" % realm, "high_%s" % realm, "turn_win", "turn_lose"]:
			if _stream(MUSIC_PATH % key, true) != null:
				n += 1
	return n


## A restrained arrival accent whose instrument and pitch reflect the place's culture.
func play_culture_accent(culture: String) -> void:
	match culture:
		"kharzani": play("page", -1.0, 0.01, 0.0, 0.78)
		"ryumon": play("page", -2.0, 0.01, 0.0, 1.32)
		_: play("page", 0.0, 0.01, 0.0, 0.96)


## Phase 4.7 war and siege sound cues
func play_war_horn() -> void:
	play("horn", 2.0, 0.02, 1.0, 0.9)


func play_place_fallen() -> void:
	play("objective", 3.0, 0.0, 1.0, 1.0)


func play_siege_drums() -> void:
	play("charge", 0.0, 0.04, 2.5, 0.65)


## Crossfade the current ambience (road, camp or battlefield), or fade it out with "".
func set_loop(name: String) -> void:
	if name == _loop_name:
		return
	_loop_name = name
	var current: AudioStreamPlayer = _loop if _loop_current == 0 else _loop_alt
	var other: AudioStreamPlayer = _loop_alt if _loop_current == 0 else _loop
	if name == "":
		_fade(current, SILENT_DB, AMBIENCE_FADE, true)
		if other.playing:
			_fade(other, SILENT_DB, AMBIENCE_FADE, true)
		return
	var stream := _stream(SFX_PATH % name, true)
	if stream == null:
		_loop_name = ""
		return
	other.stream = stream
	other.volume_db = SILENT_DB
	other.set_meta("name", name)
	other.play()
	_fade(other, float(SFX_DB.get(name, -8.0)), AMBIENCE_FADE)
	if current.playing:
		_fade(current, SILENT_DB, AMBIENCE_FADE, true)
	_loop_current = 1 - _loop_current


## Battle movement gets its own channel, so footsteps or hooves can sit over terrain
## ambience without either loop cutting the other off.
func set_movement_loop(name: String) -> void:
	_set_named_loop(_movement_loop, name)


func _set_named_loop(player: AudioStreamPlayer, name: String) -> void:
	if name == "":
		player.stop()
		player.set_meta("name", "")
		return
	if player.playing and String(player.get_meta("name", "")) == name:
		return
	player.stream = _stream(SFX_PATH % name, true)
	if player.stream == null:
		return
	player.volume_db = _level_db(name, name)
	player.set_meta("name", name)
	player.play()


# ---------------------------------------------------------------- feel tuning

## Multipliers on the battle's feel, for tuning on a device (Settings › Developer): how hard
## the field shakes, how long a blow or a fall freezes it, how far men lunge and flinch, how
## quickly the camera follows, and how strong vibrations are. 1 is as designed.
const FEEL := ["shake", "hitstop", "motion", "camera", "haptics"]
const FEEL_MIN := 0.0
const FEEL_MAX := 2.0
var feel := {"shake": 1.0, "hitstop": 1.0, "motion": 1.0, "camera": 1.0, "haptics": 1.0}


func set_feel(key: String, value: float, save: bool = true) -> void:
	if not FEEL.has(key):
		return
	feel[key] = clampf(value, FEEL_MIN, FEEL_MAX)
	if save:
		_save_settings()


func reset_feel() -> void:
	for key in FEEL:
		feel[key] = 1.0
	_save_settings()


# ---------------------------------------------------------------- settings

func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	_save_settings()


func set_sounds_on(on: bool) -> void:
	sounds_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sounds"), not on)
	_save_settings()


## A slider's 0 to 1 as the ear hears it: squared, so the middle of the slider is the middle
## of the loudness rather than nearly full.
static func volume_db(level: float) -> float:
	return linear_to_db(maxf(0.0001, level * level))


## Set while a slider moves (`save` false) and once more when it's let go (`save` true).
func set_music_volume(level: float, save: bool = true) -> void:
	music_volume = clampf(level, 0.0, 1.0)
	_apply_music_volume()
	if save:
		_save_settings()


func set_sound_volume(level: float, save: bool = true) -> void:
	sound_volume = clampf(level, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sounds"), volume_db(sound_volume))
	if save:
		_save_settings()


func _apply_music_volume() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, volume_db(music_volume) + SLOW_MUSIC_DB * _time_slow)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		music_on = bool(cfg.get_value("audio", "music", true))
		sounds_on = bool(cfg.get_value("audio", "sounds", true))
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
		sound_volume = clampf(float(cfg.get_value("audio", "sound_volume", 1.0)), 0.0, 1.0)
		for key in FEEL:
			feel[key] = clampf(float(cfg.get_value("feel", key, 1.0)), FEEL_MIN, FEEL_MAX)
		romance_invitations = bool(cfg.get_value("gameplay", "romance_invitations", true))
		text_scale = float(cfg.get_value("presentation", "text_scale", 1.0))
		if text_scale not in [1.0, 1.25, 1.5]:
			text_scale = 1.0
		reduced_motion = bool(cfg.get_value("presentation", "reduced_motion", false))
		instant_text = bool(cfg.get_value("presentation", "instant_text", false))
		illustrations_enabled = bool(cfg.get_value("presentation", "illustrations", true))
		haptics_enabled = bool(cfg.get_value("presentation", "haptics", true))
		shake = float(cfg.get_value("presentation", "shake", 1.0))
		show_performance = bool(cfg.get_value("debug", "performance", false))
		fullscreen = bool(cfg.get_value("presentation", "fullscreen", false))
		if shake not in [0.0, 0.5, 1.0]:
			shake = 1.0
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sounds"), not sounds_on)
	_apply_music_volume()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sounds"), volume_db(sound_volume))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	# Keep acknowledged hints when changing audio preferences.
	cfg.load(settings_path)
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sounds", sounds_on)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sound_volume", sound_volume)
	for key in FEEL:
		cfg.set_value("feel", key, float(feel[key]))
	cfg.set_value("gameplay", "romance_invitations", romance_invitations)
	cfg.set_value("presentation", "text_scale", text_scale)
	cfg.set_value("presentation", "reduced_motion", reduced_motion)
	cfg.set_value("presentation", "instant_text", instant_text)
	cfg.set_value("presentation", "illustrations", illustrations_enabled)
	cfg.set_value("presentation", "haptics", haptics_enabled)
	cfg.set_value("presentation", "shake", shake)
	cfg.set_value("presentation", "fullscreen", fullscreen)
	cfg.set_value("debug", "performance", show_performance)
	_write_settings(cfg)


## Settings are written whole to a temporary file and renamed into place, so a crash
## mid-write never leaves a half-written file that reads as no settings at all.
func _write_settings(cfg: ConfigFile) -> bool:
	var temporary := settings_path + ".tmp"
	if cfg.save(temporary) == OK and DirAccess.rename_absolute(temporary, settings_path) == OK:
		return true
	DirAccess.remove_absolute(temporary)
	return false


func romance_invitations_enabled() -> bool:
	return romance_invitations


func set_romance_invitations(enabled: bool) -> void:
	romance_invitations = enabled
	_save_settings()


func has_seen_hint(section: String, key: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		return bool(cfg.get_value(section, key, false))
	return false


func mark_hint_seen(section: String, key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(section, key, true)
	_write_settings(cfg)


# ---------------------------------------------------------------- buttons

## How far a button sinks under the thumb, and how long it takes to sink and spring back.
const PRESS_SCALE := 0.95
const PRESS_IN := 0.06
const PRESS_OUT := 0.18


## Every button in the game clicks, and gives a little under the finger: it sinks when
## pressed and springs back with a small overshoot when let go. A primary (brass) button
## also gives a light tick of vibration when it fires. Under Reduced motion the button
## stays still; the click and the tick remain. A button that animates its own scale opts
## out with the meta "no_press_feel".
func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b == null:
		return
	b.pressed.connect(play.bind("click", 0.0, 0.06))
	b.pressed.connect(func():
		if b.has_meta("primary"):
			haptic(false))
	b.button_down.connect(_squash.bind(b, true))
	b.button_up.connect(_squash.bind(b, false))


func _squash(b: BaseButton, down: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or b.has_meta("no_press_feel"):
		return
	if reduced_motion or (down and b.disabled):
		b.scale = Vector2.ONE
		return
	if not down and b.scale == Vector2.ONE:
		return
	b.pivot_offset = b.size * 0.5
	var old = b.get_meta("press_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var t := b.create_tween()
	b.set_meta("press_tween", t)
	if down:
		t.tween_property(b, "scale", Vector2.ONE * PRESS_SCALE, PRESS_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_release_when_free(b)
	else:
		t.tween_property(b, "scale", Vector2.ONE, PRESS_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A press that a scrolling page takes over never sends button_up: let go of it once the
## button is no longer held.
func _release_when_free(b: BaseButton) -> void:
	get_tree().create_timer(0.3).timeout.connect(func():
		if not is_instance_valid(b) or not b.is_inside_tree():
			return
		if b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] and not b.toggle_mode:
			_release_when_free(b)
		else:
			_squash(b, false))


# ---------------------------------------------------------------- plumbing

func _make_bus(name: String, send: String = "Master") -> void:
	if AudioServer.get_bus_index(name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, send)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _fade(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool = false) -> void:
	if _fades.has(p) and is_instance_valid(_fades[p]):
		(_fades[p] as Tween).kill()
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, seconds)
	if stop_after:
		t.tween_callback(p.stop)
	_fades[p] = t


## An audio file, imported if the editor has done so, read straight from disk if not
## (headless runs of a fresh checkout). Null if it's missing.
func _stream(path: String, looped: bool) -> AudioStream:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		var wav_path := path.get_basename() + ".wav"
		if ResourceLoader.exists(wav_path) or FileAccess.file_exists(wav_path):
			path = wav_path
	var key := "%s/%s" % [path, looped]
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
		if s != null:
			s = s.duplicate()
	elif FileAccess.file_exists(path):
		s = AudioStreamWAV.load_from_file(path) if path.get_extension().to_lower() == "wav" else AudioStreamOggVorbis.load_from_file(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = looped
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
	_streams[key] = s
	return s


func set_text_scale(value: float) -> void:
	text_scale = value if value in [1.0, 1.25, 1.5] else 1.0
	_save_settings()

func set_show_performance(enabled: bool) -> void:
	show_performance = enabled
	_save_settings()

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_save_settings()


func set_instant_text(enabled: bool) -> void:
	instant_text = enabled
	_save_settings()

func set_illustrations(enabled: bool) -> void:
	illustrations_enabled = enabled
	_save_settings()

func set_haptics(enabled: bool) -> void:
	haptics_enabled = enabled
	_save_settings()

func set_shake(level: float) -> void:
	shake = level if level in [0.0, 0.5, 1.0] else 1.0
	_save_settings()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_save_settings()


## Vibrations by weight, each [milliseconds, strength 0-1]: a tap for an accepted order or a
## button, a firmer knock for a refused order, an impact for a charge into your men or a
## line breaking, heavy for the end of a battle, and the longest for a captain's fall.
const PULSES := {"tap": [15, 0.4], "refuse": [35, 0.7], "impact": [50, 0.85], "heavy": [90, 1.0], "death": [140, 1.0]}
## The last pulse sent, by name (for tests).
var last_pulse := ""


## A short vibration, if the player wants them: `strong` for a decisive moment.
func haptic(strong: bool = false) -> void:
	pulse("heavy" if strong else "tap")


## A vibration of the named weight (see PULSES).
func pulse(kind: String) -> void:
	if not haptics_enabled:
		return
	var p: Array = PULSES.get(kind, PULSES["tap"])
	haptic_count += 1
	last_pulse = kind if PULSES.has(kind) else "tap"
	Input.vibrate_handheld(int(p[0]), float(p[1]) * clampf(float(feel["haptics"]), 0.0, 1.0))


## Quiet routine contact sounds for a moment, so a critical cue is heard over the press.
func duck(seconds: float = 0.8) -> void:
	_duck_until = Time.get_ticks_msec() / 1000.0 + seconds
