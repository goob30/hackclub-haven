extends Node3D

@export var body: CharacterBody3D
@export var body_visual: Node3D
@export var gait_group_a: Array[Node3D] = []
@export var gait_group_b: Array[Node3D] = []

@export var walk_speed := 3.0
@export var walk_frequency := 8.0
@export var leg_swing_degrees := 20.0
@export var leg_lift_degrees := 10.0
@export var body_bob_height := 0.04

# Adjust these to match how your leg pivots are oriented.
@export var leg_swing_axis := Vector3(0.0, 0.0, 1.0)
@export var leg_lift_axis := Vector3(1.0, 0.0, 0.0)

var _base_rotations: Dictionary = {}
var _body_rest_position := Vector3.ZERO
var _phase := 0.0


func _ready() -> void:
	for leg in gait_group_a + gait_group_b:
		if is_instance_valid(leg):
			_base_rotations[leg] = leg.rotation

	if is_instance_valid(body_visual):
		_body_rest_position = body_visual.position


func _process(delta: float) -> void:
	if not is_instance_valid(body):
		return

	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	var movement := clampf(speed / maxf(walk_speed, 0.01), 0.0, 1.0)

	_phase += delta * walk_frequency * movement

	_animate_group(gait_group_a, 0.0, movement)
	_animate_group(gait_group_b, PI, movement)

	if is_instance_valid(body_visual):
		var bob := maxf(0.0, sin(_phase * 2.0)) * body_bob_height * movement
		body_visual.position = _body_rest_position + Vector3.UP * bob
  
func _animate_group(legs: Array[Node3D], phase_offset: float, movement: float) -> void:
	for leg in legs:
		if not is_instance_valid(leg) or not _base_rotations.has(leg):
			continue

		var leg_phase := _phase + phase_offset
		var swing := sin(leg_phase) * deg_to_rad(leg_swing_degrees) * movement
		var lift := maxf(0.0, cos(leg_phase)) * deg_to_rad(leg_lift_degrees) * movement

		leg.rotation = _base_rotations[leg] \
			+ leg_swing_axis.normalized() * swing \
			+ leg_lift_axis.normalized() * lift
