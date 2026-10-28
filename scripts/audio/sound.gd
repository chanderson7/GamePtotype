## Music and sound for every screen (an autoload). One piece of music at a time,
## crossfading into the next; the battle's two layers kept in step, the upper one
## swelling as more of the field is fighting; a small pool of players for effects; and a
## click and a little give on every button. Music and sound can each be switched off,
## and the choice is kept on the device.
##
## The audio itself is rendered by tools/music.py into assets/audio/.
extends Node

const MUSIC_PATH := "res://assets/audio/music/%s.ogg"
const SFX_PATH := "res://assets/audio/sfx/%s.ogg"
const SETTINGS_PATH := "user://settings.cfg"
## Seconds to fade one piece of music into the next.
const FADE := 1.4
## Music sits under the effects.
const MUSIC_DB := -7.0
const SILENT_DB := -60.0
## How loud each effect plays, so a click doesn't drown a bell.
const SFX_DB := {
	"click": -14.0, "page": -16.0, "coins": -8.0, "horn": -5.0, "alarm": -6.0,
	"clash1": -15.0, "clash2": -15.0, "clash3": -15.0, "arrows": -11.0, "charge": -7.0,
	"rout": -11.0, "dice": -5.0, "bell": -6.0, "hooves": -15.0,
	"crossbow": -10.0, "javelin": -11.0, "horsebow": -12.0, "water": -20.0, "birds": -20.0, "objective": -6.0,
}
const POOL := 10

## Tests may use a disposable preference file without touching device settings.
var settings_path := SETTINGS_PATH
var music_on := true
var sounds_on := true
var _track := ""
var _music: Array[AudioStreamPlayer] = []
var _current := 0
var _upper: AudioStreamPlayer
var _intensity := 0.0
var _stinger: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _streams := {}
var _last := {}
var _fades := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("Sounds")
	for i in 2:
		_music.append(_player("Music"))
	_upper = _player("Music")
	_stinger = _player("Music")
	_loop = _player("Sounds")
	for i in POOL:
		_pool.append(_player("Sounds"))
	_load_settings()
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	# The battle's upper layer follows the fighting, slowly.
	if _upper.playing:
		var want := MUSIC_DB + linear_to_db(maxf(0.02, _intensity))
		_upper.volume_db = move_toward(_upper.volume_db, want, delta * 12.0)


# ---------------------------------------------------------------- music

## Fade into the named piece (title, vardish, kharzani, ryumon), unless it's already on.
func play_music(name: String) -> void:
	if name == _track:
		return
	_track = name
	_stop_upper()
	var old := _music[_current]
	_current = 1 - _current
	var next := _music[_current]
	next.stream = _stream(MUSIC_PATH % name, true)
	next.volume_db = SILENT_DB
	next.play()
	_fade(next, MUSIC_DB, FADE)
	_fade(old, SILENT_DB, FADE, true)


## The battle music: the low layer at once, the upper one in step with it and silent
## until the fighting starts.
func play_battle() -> void:
	play_music("battle_low")
	_upper.stream = _stream(MUSIC_PATH % "battle_high", true)
	_upper.volume_db = SILENT_DB
	_intensity = 0.0
	_upper.play(_music[_current].get_playback_position())


## How much of the field is fighting, from 0 to 1.
func set_battle_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)


## A short piece over the end of a battle: the music stops for it.
func stinger(name: String) -> void:
	_track = ""
	_stop_upper()
	for p in _music:
		_fade(p, SILENT_DB, 0.4, true)
	_stinger.stream = _stream(MUSIC_PATH % name, false)
	_stinger.volume_db = MUSIC_DB + 3.0
	_stinger.play()


func _stop_upper() -> void:
	if _upper.playing:
		_fade(_upper, SILENT_DB, 0.6, true)


# ---------------------------------------------------------------- effects

## Play an effect. `jitter` varies its pitch a little each time, so repeats don't sound
## canned; `gap` is the fewest seconds between two plays of the same effect.
func play(name: String, volume_db: float = 0.0, jitter: float = 0.0, gap: float = 0.0) -> void:
	if not sounds_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if gap > 0.0 and now - float(_last.get(name, -99.0)) < gap:
		return
	_last[name] = now
	var stream := _stream(SFX_PATH % name, false)
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
	p.volume_db = float(SFX_DB.get(name, -8.0)) + volume_db
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()


## Keep a looping effect going (hoofbeats on the road, a river at a ford), or stop it
## with "".
func set_loop(name: String) -> void:
	if name == "":
		_loop.stop()
		_loop.set_meta("name", "")
		return
	if _loop.playing and String(_loop.get_meta("name", "")) == name:
		return
	_loop.stream = _stream(SFX_PATH % name, true)
	_loop.volume_db = float(SFX_DB.get(name, -8.0))
	_loop.set_meta("name", name)
	_loop.play()


# ---------------------------------------------------------------- settings

func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	_save_settings()


func set_sounds_on(on: bool) -> void:
	sounds_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sounds"), not on)
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		music_on = bool(cfg.get_value("audio", "music", true))
		sounds_on = bool(cfg.get_value("audio", "sounds", true))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sounds"), not sounds_on)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	# Keep acknowledged hints when changing audio preferences.
	cfg.load(settings_path)
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sounds", sounds_on)
	cfg.save(settings_path)


func has_seen_hint(section: String, key: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		return bool(cfg.get_value(section, key, false))
	return false


func mark_hint_seen(section: String, key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(section, key, true)
	cfg.save(settings_path)


# ---------------------------------------------------------------- buttons

## Every button in the game clicks, and gives a little under the finger.
func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b == null:
		return
	b.pressed.connect(play.bind("click", 0.0, 0.06))
	b.button_down.connect(_squash.bind(b, 0.95))
	b.button_up.connect(_squash.bind(b, 1.0))


func _squash(b: BaseButton, to: float) -> void:
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size * 0.5
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2(to, to), 0.06 if to < 1.0 else 0.12)


# ---------------------------------------------------------------- plumbing

func _make_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, "Master")


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
	var key := "%s/%s" % [path, looped]
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
		if s != null:
			s = s.duplicate()
	elif FileAccess.file_exists(path):
		s = AudioStreamOggVorbis.load_from_file(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = looped
	_streams[key] = s
	return s
