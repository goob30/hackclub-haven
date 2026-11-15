extends CharacterBody3D

const Blood := preload("res://scripts/blood.gd")
const DRONE_BLOOD := preload("res://sprites/drone_blood.png")
const AIM_OFFSET := Vector3(0.0, 0.5, 0.0)

@export var player: Node3D
@export var bullet_scene: PackedScene
@export var attack_range := 30.0
@export var attack_damage := 5
@export var fire_interval := 2.0
@export var fire_jitter := 0.5

@export var hover_height := 0.2
@export var hover_speed := 2.0
@export var muzzle_forward_offset := 0.8


@onready var raycast: RayCast3D = $RayCast3D
@onready var muzzle_particles: GPUParticles3D = $GPUParticles3D

var muzzle: Marker3D
var health := 25
var destroyed := false
var _home_position := Vector3.ZERO
var _time := 0.0
var _fire_wait := 0.0
var _fire_cooldown := INF


func _ready() -> void:
	add_to_group("enemy")
	_home_position = global_position
	muzzle = find_child("Muzzle", true, false) as Marker3D

	if not is_instance_valid(player):
		player = _find_player()

	# Only queried on demand when firing
	raycast.enabled = false

	if bullet_scene == null:
		push_error("Assign the EnemyBullet scene to bullet_scene.")
	else:
		_fire_wait = maxf(fire_interval, 0.1)
		_fire_cooldown = randf_range(0.1, _fire_wait)


func _physics_process(delta: float) -> void:
	_time += delta
	global_position.y = _home_position.y + sin(_time * hover_speed) * hover_height

	var has_player := is_instance_valid(player)
	var player_pos: Vector3 = player.global_position if has_player else Vector3.ZERO

	if has_player:
		var aim_point := player_pos + AIM_OFFSET
		if global_position.distance_squared_to(aim_point) > 0.001:
			look_at(aim_point, Vector3.UP, false)

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown += maxf(randf_range(fire_interval - fire_jitter, fire_interval + fire_jitter), 0.1)
		_try_fire()


func _try_fire() -> void:
	if destroyed or not is_instance_valid(player) or bullet_scene == null:
		return

	var aim_point := player.global_position + AIM_OFFSET
	if global_position.distance_squared_to(aim_point) > attack_range * attack_range:
		return

	raycast.target_position = raycast.to_local(aim_point)
	raycast.force_raycast_update()

	if not raycast.is_colliding():
		return

	var collider := raycast.get_collider()
	var hit_player := collider == player

	if not hit_player and collider is Node and player.is_ancestor_of(collider):
		hit_player = true

	if not hit_player:
		return

	var bullet := bullet_scene.instantiate() as Node3D
	if bullet == null:
		push_error("The root of bullet_scene must be a Node3D.")
		return

	if not bullet.has_method("launch"):
		push_error("EnemyBullet needs a launch(direction, owner, damage) method.")
		bullet.free()
		return

	var direction := (aim_point - global_position).normalized()
	var spawn_position := global_position + direction * muzzle_forward_offset

	if is_instance_valid(muzzle):
		spawn_position = muzzle.global_position

	var scene_root := get_tree().current_scene
	if scene_root == null:
		push_error("There is no current scene to add the bullet to.")
		bullet.free()
		return

	scene_root.add_child(bullet)
	bullet.global_position = spawn_position
	bullet.call("launch", (aim_point - spawn_position).normalized(), self, attack_damage)

	muzzle_particles.global_position = spawn_position
	muzzle_particles.emitting = true
	muzzle_particles.restart()

	Audio.play("sounds/enemy_shoot.wav")


func damage(_amount: int) -> void:
	destroy()


func destroy() -> void:
	if destroyed:
		return

	destroyed = true
	set_physics_process(false)
	Audio.play("sounds/enemy_death.wav")
	Blood.splatter(global_position, 60, DRONE_BLOOD)
	Blood.mist(global_position, DRONE_BLOOD)
	queue_free()


func _find_player() -> Node3D:
	var grouped_player := get_tree().get_first_node_in_group("player")
	if grouped_player is Node3D:
		return grouped_player

	var named_player := get_tree().root.find_child("Player", true, false)
	if named_player is Node3D:
		return named_player

	push_error("Assign the player, add it to the 'player' group, or name it Player.")
	return null
