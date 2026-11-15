extends Label

@export var size_xy := Vector2(30.0, 5.0)
@export var speed := 0.5
@export var tilt_degrees := 3.0
@export var home_offset := Vector2.ZERO

var base_pos: Vector2
var t_offset := randf() * TAU

func _ready():
	await get_tree().process_frame   # let the VBox/CenterContainer finish layout
	size.x = get_minimum_size().x
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	# Home = label centered inside its wrapper Control
	base_pos = (get_parent().size - size) / 2.0 + home_offset

func _process(_delta):
	if base_pos == Vector2.ZERO and position != Vector2.ZERO:
		return   # not initialized yet
	var t := Time.get_ticks_msec() / 1000.0 * speed + t_offset
	position = base_pos + Vector2(sin(t) * size_xy.x, sin(2.0 * t) * size_xy.y)
	rotation = deg_to_rad(cos(t) * tilt_degrees)


func _on_settingsbutton_pressed() -> void:
	pass # Replace with function body.
