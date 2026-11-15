extends Control

var is_in_pause := false
var _game_over := false

const MENU_SCENE := "res://scenes/ui/homescreen.tscn"


func _ready() -> void:
	$CenterContainer/VBoxContainer/exitbutton.pressed.connect(_on_exitbutton_pressed)


func _on_settingsbutton_pressed() -> void:
	$settingscontrol.visible = true


func _on_exitbutton_pressed() -> void:
	set_pause(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _game_over:
		set_pause(not is_in_pause)

# Pause menu reused as the end screen, with a play again button
func show_game_over(title: String) -> void:
	if _game_over:
		return
	_game_over = true
	var box := $CenterContainer/VBoxContainer
	for l in box.find_children("pauselabel", "Label", true, false):
		l.text = title
		l.add_theme_font_size_override("font_size", 80)
		l.size = Vector2.ZERO
		if "base_pos" in l:
			l.base_pos = (l.get_parent().size - l.size) / 2.0
	var restart: Button = $CenterContainer/VBoxContainer/exitbutton.duplicate(0)
	restart.text = "PLAY AGAIN"
	restart.pressed.connect(_on_restart_pressed)
	var gap: Control = $CenterContainer/VBoxContainer/margin2.duplicate(0)
	var at: int = $CenterContainer/VBoxContainer/settingsbutton.get_index()
	box.add_child(restart)
	box.move_child(restart, at)
	box.add_child(gap)
	box.move_child(gap, at + 1)
	set_pause(true)


func _on_restart_pressed() -> void:
	set_pause(false)
	get_tree().reload_current_scene()


func set_pause(on: bool) -> void:
	is_in_pause = on
	visible = on
	if not on:
		$settingscontrol.visible = false
	get_tree().paused = on
	Audio.set_paused(on)
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		get_window().grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.mouse_captured = true

func _exit_tree() -> void:
	if is_in_pause:
		Audio.set_paused(false)
