extends Control

var is_in_pause = false
var pm
var main


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pm = get_node("../pausemenu")
	main = get_node("../")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") && !is_in_pause:
		pm.visible = true
		is_in_pause = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	elif Input.is_action_just_pressed("pause") && is_in_pause:
		pm.visible = false
		is_in_pause = false
		get_tree().paused = false
		get_window().grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.mouse_captured = true
