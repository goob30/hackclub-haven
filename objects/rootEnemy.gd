extends CharacterBody3D

@export var player: Node3D
@export var bullet_scene: PackedScene
@export var attack_range := 30.0
@export var attack_damage := 5
@export var fire_interval := 2.5

@export var hover_height := 0.2
@export var hover_speed := 2.0
@export var muzzle_forward_offset := 0.8

@export var avoid_distance := 5.0
@export var escape_distance := 7.0
@export var avoid_speed := 5.0
@export var return_speed := 2.0
@export var acceleration := 12.0

@onready var drone_shape: CollisionShape3D = $CollisionShape3D
@onready var raycast: RayCast3D = $RayCast3D
@onready var fire_timer: Timer = $Timer
@onready var muzzle_particles: GPUParticles3D = $GPUParticles3D

var muzzle: Marker3D
var health := 25
var destroyed := false
var _home_position := Vector3.ZERO
var _time := 0.0
var _is_evading := false
var _movement_velocity := Vector3.ZERO


func _ready() -> void:
	_home_position = global_position
	muzzle = find_child("Muzzle", true, false) as Marker3D

	if drone_shape.shape == null:
		push_error("Assign a shape to the drone's CollisionShape3D.")

	if not is_instance_valid(player):
		player = _find_player()

	raycast.enabled = true

	if bullet_scene == null:
		push_error("Assign the EnemyBullet scene to bullet_scene.")
	else:
		fire_timer.stop()
		fire_timer.wait_time = maxf(fire_interval, 0.1)
		fire_timer.one_shot = false

		if not fire_timer.timeout.is_connected(_on_timer_timeout):
			fire_timer.timeout.connect(_on_timer_timeout)

		fire_timer.start(randf_range(0.1, fire_timer.wait_time))


func _physics_process(delta: float) -> void:
	_time += delta

	var target_position := _home_position
	var movement_speed := return_speed

	if is_instance_valid(player):
		var player_offset := global_position - player.global_position
		var distance_to_player := player_offset.length()

		if not _is_evading and distance_to_player < avoid_distance:
			_is_evading = true
		elif _is_evading and distance_to_player > escape_distance:
			_is_evading = false

		if _is_evading:
			var away_direction := Vector3(player_offset.x, 0.0, player_offset.z)

			if away_direction.length_squared() < 0.001:
				away_direction = global_transform.basis.z
				away_direction.y = 0.0

			if away_direction.length_squared() < 0.001:
				away_direction = Vector3.RIGHT

			target_position = player.global_position + away_direction.normalized() * escape_distance
			target_position.y = _home_position.y
			movement_speed = avoid_speed

	target_position.y += sin(_time * hover_speed) * hover_height

	var offset_to_target := target_position - global_position
	var desired_velocity := Vector3.ZERO

	if offset_to_target.length() > 0.05:
		desired_velocity = offset_to_target.normalized() * movement_speed

	_movement_velocity = _movement_velocity.move_toward(
		desired_velocity,
		acceleration * delta
	)

	_move_without_crossing_walls(_movement_velocity * delta)

	if is_instance_valid(player):
		var aim_point := player.global_position + Vector3(0.0, 0.5, 0.0)

		if global_position.distance_squared_to(aim_point) > 0.001:
			look_at(aim_point, Vector3.UP, false)

		raycast.target_position = raycast.to_local(aim_point)


func _move_without_crossing_walls(motion: Vector3) -> void:
	if motion.length_squared() < 0.000001:
		return
	if drone_shape.shape == null:
		return

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = drone_shape.shape
	query.transform = drone_shape.global_transform
	query.motion = motion
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	if fractions.size() < 2:
		push_error("The drone wall collision shape cast failed.")
		return

	global_position += motion * clampf(fractions[0], 0.0, 1.0)


func _on_timer_timeout() -> void:
	if destroyed or not is_instance_valid(player) or bullet_scene == null:
		return

	var aim_point := player.global_position + Vector3(0.0, 0.5, 0.0)
	if global_position.distance_to(aim_point) > attack_range:
		return

	raycast.target_position = raycast.to_local(aim_point)
	raycast.force_raycast_update()

	if not raycast.is_colliding():
		return

	var collider := raycast.get_collider()
	var hit_player := collider == player

	if collider is Node and player.is_ancestor_of(collider):
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

	Audio.play("sounds/enemy_attack.ogg")


func damage(amount: int) -> void:
	if destroyed:
		return

	health -= amount
	Audio.play("sounds/enemy_hurt.ogg")

	if health <= 0:
		destroy()


func destroy() -> void:
	if destroyed:
		return

	destroyed = true
	Audio.play("sounds/enemy_destroy.ogg")
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
