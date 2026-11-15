extends Node

# SFX pool adapted from KidsCanCode, plus muffle (low-pass) control

const FIXED_PITCH := ["res://sounds/gun_fire.wav"]

var num_players = 12
var bus = "sfx"

var music_volume := 1.0:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_apply_volume("music", music_volume)
var sfx_volume := 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_volume("sfx", sfx_volume)

var available = []
var queue = []

const OPEN_HZ := 20500.0
const MUFFLED_HZ := 1300.0
const FADE_TIME := 0.3
const MUFFLE_BUSES := ["music", "Master"]

var _slowmo := false
var _paused := false
var _cutoff := OPEN_HZ
var _tween: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(bus) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, "Master")
	_apply_volume("music", music_volume)
	_apply_volume("sfx", sfx_volume)
	for i in num_players:
		var p = AudioStreamPlayer.new()
		add_child(p)
		available.append(p)
		p.volume_db = -10
		p.finished.connect(_on_stream_finished.bind(p))
		p.bus = bus
	_apply_cutoff(OPEN_HZ)

func _on_stream_finished(stream):
	available.append(stream)

func play(sound_path): # Path (or multiple, separated by commas)
	var sounds = sound_path.split(",")
	queue.append("res://" + sounds[randi() % sounds.size()].strip_edges())

func _process(_delta):
	if not queue.is_empty() and not available.is_empty():
		var p = available.pop_front()
		var path: String = queue.pop_front()
		p.stream = load(path)
		p.pitch_scale = 1.0 if FIXED_PITCH.has(path) else randf_range(0.9, 1.1)
		p.play()

func set_slowmo(on: bool) -> void:
	_slowmo = on
	_update_muffle()

func set_paused(on: bool) -> void:
	_paused = on
	_update_muffle()

func reset_muffle() -> void:
	_slowmo = false
	_paused = false
	_update_muffle()

func _update_muffle() -> void:
	var target := MUFFLED_HZ if (_slowmo or _paused) else OPEN_HZ
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(_apply_cutoff, _cutoff, target, FADE_TIME)

func _apply_cutoff(hz: float) -> void:
	_cutoff = hz
	for bus_name in MUFFLE_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx == -1:
			continue
		for i in AudioServer.get_bus_effect_count(idx):
			var fx := AudioServer.get_bus_effect(idx, i)
			if fx is AudioEffectLowPassFilter:
				fx.cutoff_hz = hz

func _apply_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
