extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	if e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		get_viewport().set_input_as_handled()
