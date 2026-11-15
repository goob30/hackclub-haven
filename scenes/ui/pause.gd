extends Control

var is_in_pause := false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		set_pause(not is_in_pause)

func set_pause(on: bool) -> void:
	is_in_pause = on
	visible = on
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
