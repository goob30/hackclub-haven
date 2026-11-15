extends Node3D

@export var player: Node3D
@export var melee_range := 2.0
@export var move_speed := 3.0
@export var attack_damage := 10
@export var attack_interval := 1.5

@onready var raycast: RayCast3D = $RayCast
@onready var attack_timer: Timer = $Timer
@onready var attack_area: Area3D = $AttackArea
@onready var slash_particles: GPUParticles3D = $SlashParticles

var health := 25
var time := 0.0
var starting_position: Vector3
var destroyed := false


func _ready() -> void:
	starting_position = global_position

	attack_timer.stop()
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.start(randf_range(0.1, attack_interval))


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	time += delta

	var aim_point = player.global_position + Vector3(0, 0.5, 0)
	var to_player = player.global_position - global_position
	var horizontal_to_player = Vector3(to_player.x, 0, to_player.z)

	if horizontal_to_player.length() > melee_range:
		global_position += horizontal_to_player.normalized() * move_speed * delta

	global_position.y = starting_position.y + sin(time * 2.0) * 0.2

	if global_position.distance_to(aim_point) > 0.01:
		look_at(aim_point, Vector3.UP, true)

	raycast.target_position = raycast.to_local(aim_point)


func _on_timer_timeout() -> void:
	if not is_instance_valid(player):
		return

	var aim_point = player.global_position + Vector3(0, 0.5, 0)

	if global_position.distance_to(aim_point) > melee_range:
		return

	# Don't slash through walls.
	raycast.target_position = raycast.to_local(aim_point)
	raycast.force_raycast_update()

	if not raycast.is_colliding():
		return

	var collider = raycast.get_collider()
	if collider != player and not (collider is Node and player.is_ancestor_of(collider)):
		return

	# The Area3D defines the actual melee hitbox.
	var player_in_attack_area := false
	for body in attack_area.get_overlapping_bodies():
		if body == player or (body is Node and player.is_ancestor_of(body)):
			player_in_attack_area = true
			break

	if not player_in_attack_area:
		return

	slash_particles.emitting = true
	slash_particles.restart()

	if player.has_method("damage"):
		player.damage(attack_damage)

	Audio.play("sounds/enemy_attack.ogg")


func damage(amount: int) -> void:
	Audio.play("sounds/enemy_hurt.ogg")
	health -= amount

	if health <= 0 and not destroyed:
		destroy()


func destroy() -> void:
	Audio.play("sounds/enemy_destroy.ogg")
	destroyed = true
	queue_free()
