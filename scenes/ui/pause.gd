extends Control

var is_in_pause := false

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
	if Input.is_action_just_pressed("pause"):
		set_pause(not is_in_pause)

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
