extends Control

const MAP := preload("res://scenes/main.tscn")
const SETTINGS := preload("res://scenes/ui/settings.tscn")
const STRIP := ["Player", "HUD", "Enemies", "PauseLayer", "mainmusic", "dangermusicadd"]

@export var orbit_radius := 32.0
@export var orbit_height := 22.0
@export var orbit_speed := 0.12
@export var look_target := Vector3.ZERO

var _cam: Camera3D
var _angle := 0.0
var _settings: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	move_child(holder, 0)
	var vp := SubViewport.new()
	holder.add_child(vp)
	var map := MAP.instantiate()
	for n in STRIP:
		var node := map.get_node_or_null(n)
		if node:
			map.remove_child(node)
			node.free()
	vp.add_child(map)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	vp.add_child(_cam)
	_update_cam()
	var box := $CenterContainer/VBoxContainer
	box.get_node("playbutton").pressed.connect(_on_button_pressed)
	box.get_node("tutorialbutton").pressed.connect(_on_tutorial_pressed)
	box.get_node("settingsButton").pressed.connect(_on_settings_pressed)
	_settings = SETTINGS.instantiate()
	_settings.visible = false
	add_child(_settings)


func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	_update_cam()


func _update_cam() -> void:
	_cam.position = look_target + Vector3(cos(_angle) * orbit_radius, orbit_height, sin(_angle) * orbit_radius)
	_cam.look_at(look_target)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _on_settings_pressed() -> void:
	_settings.visible = true
