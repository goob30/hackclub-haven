extends Control

const MAP := preload("res://scenes/main.tscn")
const MENU_MUSIC := preload("res://sounds/menu_music.mp3")
const SETTINGS := preload("res://scenes/ui/settings.tscn")
const AUTO_COLLISION := preload("res://scripts/auto_collision.gd")
const STRIP := ["Player", "HUD", "Enemies", "PauseLayer", "mainmusic", "dangermusicadd"]

@export var orbit_radius := 32.0
@export var orbit_height := 22.0
@export var orbit_speed := 0.12
@export var look_target := Vector3.ZERO
@export_group("Background cost")
@export var background_shadows := false
## 2 renders the backdrop at half resolution
@export_range(1, 4) var background_shrink := 1

var _cam: Camera3D
var _angle := 0.0
var _settings: Control


func _ready() -> void:
	if not AssetCache.loaded:
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/loading.tscn")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var music := AudioStreamPlayer.new()
	var stream := MENU_MUSIC.duplicate() as AudioStreamMP3
	stream.loop = true
	music.stream = stream
	music.bus = &"music"
	music.autoplay = true
	add_child(music)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.stretch_shrink = background_shrink
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	move_child(holder, 0)
	var vp := SubViewport.new()
	vp.positional_shadow_atlas_size = 0
	holder.add_child(vp)
	vp.add_child(make_backdrop(background_shadows))
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


# The map is only scenery here: no collision, no per-frame logic, optional sun shadows.
# Static so the loading screen can reuse it for shader warm-up
static func make_backdrop(shadows: bool) -> Node:
	var map := MAP.instantiate()
	for n in STRIP:
		var node := map.get_node_or_null(n)
		if node:
			map.remove_child(node)
			node.free()
	for n in map.find_children("*", "", true, false):
		if n.get_script() == AUTO_COLLISION:
			n.set_script(null)
	var arena := map.get_node_or_null("Coliseum")
	if arena:
		arena.set("walls_have_collision", false)
	var sun := map.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = shadows
	map.process_mode = Node.PROCESS_MODE_DISABLED
	return map


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
