extends CharacterBody3D

const Blood := preload("res://scripts/blood.gd")

const ATTACK_ANIM := &"MonsterPSX_Rig|Attack_Lunge"
const IDLE_ANIM := &"MonsterPSX_Rig|Idle_Watchful"
const AIM_OFFSET := Vector3(0.0, 0.5, 0.0)

@export var bullet_scene: PackedScene
@export var attack_damage := 5
@export var fire_interval := 2.0
@export var fire_jitter := 0.5
## Seconds into the attack animation when the ball leaves the hand
@export var release_time := 0.45
@export var muzzle_forward_offset := 0.8
@export var health := 50
@export var tint := Color(1.0, 0.2, 0.15)

var player: Node3D
var destroyed := false
var _cooldown := 0.0
var _anim: AnimationPlayer
var _muzzle: Marker3D
var _raycast: RayCast3D
var _muzzle_particles: GPUParticles3D


func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player") as Node3D
	_muzzle = find_child("Marker3D", true, false) as Marker3D
	_raycast = $RayCast3D
	_raycast.enabled = false
	_muzzle_particles = $GPUParticles3D
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	for m in find_children("WGT_*", "MeshInstance3D", true, false):
		m.visible = false
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi.visible and mi.mesh:
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if mat:
					mat = mat.duplicate()
					mat.albedo_color = tint
					mi.set_surface_override_material(i, mat)
	if _anim and _anim.has_animation(IDLE_ANIM):
		_anim.get_animation(IDLE_ANIM).loop_mode = Animation.LOOP_LINEAR
		_anim.play(IDLE_ANIM)
	_cooldown = randf_range(0.1, fire_interval + fire_jitter)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

	if not is_instance_valid(player):
		return
	var flat := Vector3(player.global_position.x, global_position.y, player.global_position.z)
	if global_position.distance_squared_to(flat) > 0.001:
		look_at(flat, Vector3.UP, true)

	_cooldown -= delta
	if _cooldown <= 0.0 and _can_see_player():
		_cooldown = randf_range(fire_interval - fire_jitter, fire_interval + fire_jitter)
		_attack()


func _can_see_player() -> bool:
	if destroyed or not is_instance_valid(player) or _muzzle == null:
		return false
	_raycast.global_position = _muzzle.global_position
	_raycast.target_position = _raycast.to_local(player.global_position + AIM_OFFSET)
	_raycast.force_raycast_update()
	if not _raycast.is_colliding():
		return false
	var c := _raycast.get_collider()
	return c == player or (c is Node and player.is_ancestor_of(c))


func _attack() -> void:
	if _anim and _anim.has_animation(ATTACK_ANIM):
		_anim.play(ATTACK_ANIM)
		_anim.queue(IDLE_ANIM)
	await get_tree().create_timer(release_time).timeout
	if destroyed or not is_inside_tree() or not _can_see_player():
		return
	_fling()


func _fling() -> void:
	var bullet := bullet_scene.instantiate() as Node3D
	if bullet == null or not bullet.has_method("launch"):
		push_error("bullet_scene must be an EnemyBullet.")
		return
	var aim_point := player.global_position + AIM_OFFSET
	var dir := (aim_point - _muzzle.global_position).normalized()
	var pos := _muzzle.global_position + dir * muzzle_forward_offset
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = pos
	bullet.call("launch", dir, self, attack_damage)
	_muzzle_particles.global_position = pos
	_muzzle_particles.restart()
	_muzzle_particles.emitting = true
	Audio.play("sounds/enemy_shoot.wav")


func damage(amount: int) -> void:
	if destroyed:
		return
	health -= amount
	if health <= 0:
		destroy()
	else:
		Audio.play("sounds/enemy_hurt.wav")
		Blood.splatter(global_position + Vector3(0, 1.2, 0))


func destroy() -> void:
	if destroyed:
		return
	destroyed = true
	set_physics_process(false)
	Audio.play("sounds/enemy_death.wav")
	Blood.mist(global_position + Vector3(0, 1.0, 0))
	queue_free()
