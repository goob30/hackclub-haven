extends CharacterBody3D

const MIST_SHADER := preload("res://sprites/spider_mist.gdshader")
static var _mist_mesh: QuadMesh
static var _mist_process: ShaderMaterial

@export var move_speed := 3.8
@export var stop_distance := 1.0
@export var attack_damage := 10
@export var attack_interval := 1.5
@export var bite_windup := 0.0
@export var health := 50
@export var size_scale := 2.0
@export var reverse_facing := false

var player: Node3D
var raycast: RayCast3D
var attack_timer: Timer
var attack_area: Area3D
var bite_particles: GPUParticles3D
var bite_point: Marker3D
var hit_particles: GPUParticles3D

var destroyed := false
var is_biting := false
var cooldown := 0.0


func _ready() -> void:
	add_to_group("enemy")
	scale *= size_scale
	player = _find_player()

	raycast = find_child("RayCast3D", true, false) as RayCast3D
	if raycast == null:
		raycast = find_child("RayCast", true, false) as RayCast3D

	attack_timer = find_child("AttackTimer", true, false) as Timer
	if attack_timer == null:
		attack_timer = find_child("Timer", true, false) as Timer

	attack_area = find_child("AttackArea", true, false) as Area3D
	bite_particles = find_child("BiteParticles", true, false) as GPUParticles3D
	bite_point = find_child("BitePoint", true, false) as Marker3D
	hit_particles = find_child("HitParticles", true, false) as GPUParticles3D

	if raycast != null:
		raycast.enabled = true
	else:
		push_error("No RayCast3D or RayCast was found under the spider.")

	if attack_area != null:
		attack_area.monitoring = true
	else:
		push_error("No AttackArea was found under the spider.")

	if bite_point == null:
		push_error("Add a Marker3D named BitePoint at the spider's mouth.")

	if bite_particles == null:
		push_error("Add a GPUParticles3D named BiteParticles for the bite effect.")


func _physics_process(delta: float) -> void:
	if destroyed or not is_inside_tree():
		return

	cooldown -= delta
	if cooldown <= 0.0 and not is_biting and _can_bite_player():
		_bite()
		if destroyed or not is_inside_tree():
			return

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if is_instance_valid(player) and player.is_inside_tree():
		var offset := player.global_position - global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)

		if horizontal.length() > 0.5:
			var facing_direction := -horizontal if reverse_facing else horizontal
			look_at(global_position + facing_direction, Vector3.UP, false)

		if horizontal.length() <= stop_distance:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var direction := horizontal.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed

		if raycast != null:
			var aim_point := player.global_position + Vector3(0.0, 0.5, 0.0)
			raycast.target_position = raycast.to_local(aim_point)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


func _bite() -> void:
	cooldown = attack_interval
	if bite_windup > 0.0:
		is_biting = true
		await get_tree().create_timer(bite_windup).timeout

		if not is_instance_valid(self) or destroyed:
			return

		is_biting = false

	# Recheck so the player can dodge during the wind-up.
	if not _can_bite_player():
		return

	if bite_particles != null and bite_point != null:
		bite_particles.global_transform = bite_point.global_transform
		bite_particles.emitting = true
		bite_particles.restart()

	if is_instance_valid(player) and player.has_method("damage"):
		player.damage(attack_damage)
	elif is_instance_valid(player):
		push_warning("The player needs a damage(amount) method.")

	Audio.play("sounds/enemy_attack.ogg")


func _can_bite_player() -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if attack_area == null or raycast == null:
		return false
	if not attack_area.overlaps_body(player):
		return false

	var aim_point := player.global_position + Vector3(0.0, 0.5, 0.0)
	raycast.target_position = raycast.to_local(aim_point)
	raycast.force_raycast_update()

	if not raycast.is_colliding():
		return false

	var collider := raycast.get_collider()
	return collider == player or (
		collider is Node and player.is_ancestor_of(collider)
	)


func _find_player() -> Node3D:
	var grouped_player := get_tree().get_first_node_in_group("player")
	if grouped_player is Node3D:
		return grouped_player

	var named_player := get_tree().root.find_child("Player", true, false)
	if named_player is Node3D:
		return named_player

	push_error("Add the player to the 'player' group or name it Player.")
	return null


func damage(amount: int) -> void:
	if destroyed:
		return

	health -= amount

	if health <= 0:
		destroy()
	elif hit_particles != null:
		hit_particles.restart()
		hit_particles.emitting = true


func destroy() -> void:
	Audio.play("sounds/enemy_destroy.ogg")
	destroyed = true
	_spawn_mist()
	queue_free()


func _spawn_mist() -> void:
	if hit_particles == null or not is_inside_tree():
		return

	if _mist_mesh == null:
		var hit_mesh := hit_particles.draw_pass_1 as QuadMesh
		_mist_mesh = QuadMesh.new()
		_mist_mesh.size = Vector2(0.6, 0.6)
		_mist_mesh.material = hit_mesh.material
		_mist_process = ShaderMaterial.new()
		_mist_process.shader = MIST_SHADER

	var mist := GPUParticles3D.new()
	mist.process_material = _mist_process
	mist.draw_pass_1 = _mist_mesh
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.amount = 80
	mist.lifetime = 0.8
	mist.one_shot = true
	mist.explosiveness = 0.95
	mist.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	mist.emitting = true

	var root := get_tree().current_scene
	root.add_child(mist)
	mist.global_position = global_position + Vector3.UP * 0.4

	get_tree().create_timer(mist.lifetime + 0.5).timeout.connect(mist.queue_free)
