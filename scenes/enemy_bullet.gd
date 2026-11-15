class_name EnemyBullet
extends CharacterBody3D

@export var speed := 16
@export var lifetime := 8.0

var direction := Vector3.ZERO
var shooter: Node
var damage_amount := 5
var time_left := 1.5


func launch(
	flight_direction: Vector3,
	source: Node,
	damage: int
) -> void:
	direction = flight_direction.normalized()
	shooter = source
	if source is PhysicsBody3D:
		add_collision_exception_with(source)
	damage_amount = damage
	time_left = lifetime


func _physics_process(delta: float) -> void:
	if direction.is_zero_approx():
		return

	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return

	var collision := move_and_collide(direction * speed * delta)
	if collision == null:
		return

	var collider = collision.get_collider()
	if collider != shooter and collider.has_method("damage"):
		collider.damage(damage_amount)

	queue_free()
