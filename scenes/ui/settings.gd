extends Control

@onready var _sfx: HSlider = $CenterContainer/VBoxContainer/sfxvol/HSlider
@onready var _music: HSlider = $CenterContainer/VBoxContainer/musicvol/HSlider


func _ready() -> void:
	for s in [_sfx, _music]:
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
	_sfx.value = Audio.sfx_volume
	_music.value = Audio.music_volume
	_sfx.value_changed.connect(func(v): Audio.sfx_volume = v)
	_music.value_changed.connect(func(v): Audio.music_volume = v)


func _on_backbutton_pressed() -> void:
	visible = false
