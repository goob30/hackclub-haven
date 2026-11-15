extends CharacterBody3D

@export var player: Node3D
@export var bullet_scene: PackedScene
@export var head_muzzle: Marker3D

@export var attack_range := 30.0
@export var attack_damage := 5
@export var fire_interval := 2.5
@export var muzzle_forward_offset := 0.8
@export var attack_animation_name: StringName = &"MonsterPSX_Rig|Attack_Lunge"

@onready var raycast: RayCast3D = $RayCast3D
@onready var fire_timer: Timer = $Timer
@onready var muzzle_particles: GPUParticles3D = $GPUParticles3D
@onready var animation_player: AnimationPlayer = find_child(
	"AnimationPlayer", true, false
) as AnimationPlayer

var health := 25
var destroyed := false


func _ready() -> void:
	if not is_instance_valid(player):
		player = _find_player()

	if head_muzzle == null:
		push_error("Assign the HeadMuzzle Marker3D to head_muzzle.")
	if animation_player == null:
		push_error("No AnimationPlayer was found under this enemy.")
	elif not animation_player.has_animation(attack_animation_name):
		push_error("Attack animation not found: " + str(attack_animation_name))
	if bullet_scene == null:
		push_error("Assign the EnemyBullet scene to bullet_scene.")

	raycast.enabled = true

	fire_timer.stop()
	fire_timer.wait_time = maxf(fire_interval, 0.1)
	fire_timer.one_shot = false

	if not fire_timer.timeout.is_connected(_on_timer_timeout):
		fire_timer.timeout.connect(_on_timer_timeout)

	fire_timer.start(randf_range(0.1, fire_timer.wait_time))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# Keep the enemy stationary horizontally.
	velocity.x = 0.0
	velocity.z = 0.0

	if is_instance_valid(player):
		var aim_point := player.global_position + Vector3(0.0, 0.5, 0.0)

		if global_position.distance_squared_to(aim_point) > 0.001:
			look_at(aim_point, Vector3.UP, true)

		raycast.target_position = raycast.to_local(aim_point)

	move_and_slide()


func _on_timer_timeout() -> void:
	if destroyed or not is_instance_valid(player):
		return
	if bullet_scene == null or head_muzzle == null:
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

	var bullet_instance := bullet_scene.instantiate()
	if not bullet_instance is Node3D:
		push_error("The EnemyBullet scene root must be a Node3D.")
		bullet_instance.free()
		return

	var bullet := bullet_instance as Node3D
	if not bullet.has_method("launch"):
		push_error("EnemyBullet needs launch(direction, owner, damage).")
		bullet.free()
		return

	var shot_direction := (aim_point - head_muzzle.global_position).normalized()
	var spawn_position := head_muzzle.global_position \
		+ shot_direction * muzzle_forward_offset

	var scene_root := get_tree().current_scene
	if scene_root == null:
		push_error("There is no current scene to add the bullet to.")
		bullet.free()
		return

	scene_root.add_child(bullet)
	bullet.global_position = spawn_position
	bullet.call("launch", shot_direction, self, attack_damage)

	if animation_player != null and animation_player.has_animation(attack_animation_name):
		animation_player.play(attack_animation_name)

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
