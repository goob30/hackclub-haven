extends Node3D

@export var player: Node3D
@export var bullet_scene: PackedScene
@export var attack_range := 30.0
@export var attack_damage := 5
@export var fire_interval := 2.5

@onready var raycast: RayCast3D = $RayCast
@onready var fire_timer: Timer = $Timer
@onready var muzzle_a = $MuzzleA
@onready var muzzle_b = $MuzzleB
@onready var muzzle_particles: GPUParticles3D = $MuzzleA/MuzzleParticles

var health := 25
var time := 0.0
var target_position: Vector3
var destroyed := false


func _ready() -> void:
	target_position = position
	assert(bullet_scene != null, "Assign the EnemyBullet scene to bullet_scene.")

	fire_timer.stop()
	fire_timer.wait_time = fire_interval
	fire_timer.one_shot = false
	fire_timer.start(randf_range(0.1, fire_interval))


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var aim_point = player.global_position + Vector3(0, 0.5, 0)

	look_at(aim_point, Vector3.UP, true)
	raycast.target_position = raycast.to_local(aim_point)

	target_position.y += cos(time * 5.0) * delta
	time += delta
	position = target_position


func damage(amount: int) -> void:
	Audio.play("sounds/enemy_hurt.ogg")
	health -= amount

	if health <= 0 and not destroyed:
		destroy()


func destroy() -> void:
	Audio.play("sounds/enemy_destroy.ogg")
	destroyed = true
	queue_free()


func _on_timer_timeout() -> void:
	if not is_instance_valid(player):
		return

	var aim_point = player.global_position + Vector3(0, 0.5, 0)

	if global_position.distance_to(aim_point) > attack_range:
		return

	raycast.target_position = raycast.to_local(aim_point)
	raycast.force_raycast_update()

	if not raycast.is_colliding():
		return

	var collider = raycast.get_collider()
	if collider != player and not (collider is Node and player.is_ancestor_of(collider)):
		return

	var bullet := bullet_scene.instantiate() as EnemyBullet
	if bullet == null:
		push_error("The root of bullet_scene must use the EnemyBullet script.")
		return

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle_a.global_position
	bullet.launch(
		(aim_point - muzzle_a.global_position).normalized(),
		self,
		attack_damage
	)

	muzzle_particles.emitting = true
	muzzle_particles.restart()

	muzzle_a.frame = 0
	muzzle_a.play("default")
	muzzle_a.rotation_degrees.z = randf_range(-45, 45)

	muzzle_b.frame = 0
	muzzle_b.play("default")
	muzzle_b.rotation_degrees.z = randf_range(-45, 45)

	Audio.play("sounds/enemy_attack.ogg")
