class_name Projectile3D
extends Area3D

enum State { OUTBOUND, RETURNING }

@export var outbound_speed: float = 45.0
@export var hit_damage: float = 25.0
@export var player_damage: int = 10
@export var hit_player_radius: float = 0.9
@export var lifetime: float = 6.0

@export_subgroup("Parry / Slow-mo")
@export var slow_trigger_time: float = 0.06
@export var parry_range: float = 2.5
@export var min_slow_scale: float = 0.01
@export var combo_for_no_slow: float = 26.67

var state: State = State.OUTBOUND
var direction: Vector3 = Vector3.FORWARD
var player: Node3D
var arena: Coliseum

var _life_left: float = 0.0
var _fire: GPUParticles3D
var _slowmo_on: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	arena = get_tree().get_first_node_in_group("arena") as Coliseum
	_life_left = lifetime
	area_entered.connect(_on_hit)
	_build_visuals()
	_face(direction)

func launch(from_pos: Vector3, dir: Vector3) -> void:
	global_position = from_pos
	direction = dir.normalized()
	_face(direction)

func _physics_process(delta: float) -> void:
	if state == State.OUTBOUND:
		_life_left -= delta
		if _life_left <= 0.0:
			_lose_bullet()
			return

		if is_instance_valid(arena) and not arena.is_inside_bounds(global_position):
			_lose_bullet()
			return

	match state:
		State.OUTBOUND:
			_move_outbound(delta)
		State.RETURNING:
			_move_returning(delta)

func _move_outbound(delta: float) -> void:
	var from := global_position
	var to := from + direction * outbound_speed * delta

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if is_instance_valid(player) and player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result.position
		var collider = result.collider
		if collider is Node and collider.is_in_group("enemy") and collider.has_method("damage"):
			collider.damage(hit_damage)
			state = State.RETURNING
			return
		_lose_bullet()
		return

	global_position = to

func _move_returning(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return

	var target := player.global_position + Vector3.UP * 1.0
	var to_target := target - global_position

	var step := outbound_speed * delta
	var distance := to_target.length()
	if distance <= maxf(hit_player_radius, step):
		if player.has_method("damage"):
			player.damage(player_damage)
		_lose_bullet()
		return

	var time_to_impact := distance / outbound_speed
	if not _slowmo_on and time_to_impact <= slow_trigger_time:
		_start_slowmo()

	direction = to_target.normalized()
	_face(direction)
	global_position += direction * outbound_speed * delta

func _on_hit(other: Area3D) -> void:
	if state != State.OUTBOUND:
		return
	if other.is_in_group("enemy") and other.has_method("damage"):
		other.damage(hit_damage)
		state = State.RETURNING

func _lose_bullet() -> void:
	if is_instance_valid(player) and player.has_method("reset_combo"):
		player.reset_combo()
	queue_free()

func _exit_tree() -> void:
	_end_slowmo()
	Engine.time_scale = 1.0

func slow_scale() -> float:
	var combo: int = 0
	if is_instance_valid(player) and player.has_method("get_combo"):
		combo = player.get_combo()
	var t: float = clampf(float(combo) / maxf(combo_for_no_slow, 1.0), 0.0, 1.0)
	return lerpf(min_slow_scale, 1.0, t * t)

func _start_slowmo() -> void:
	_slowmo_on = true
	Engine.time_scale = slow_scale()
	if is_instance_valid(player) and player.has_method("set_slowmo"):
		player.set_slowmo(true)

func _end_slowmo() -> void:
	if not _slowmo_on:
		return
	_slowmo_on = false
	Engine.time_scale = 1.0
	if is_instance_valid(player) and player.has_method("set_slowmo"):
		player.set_slowmo(false)

func try_parry(aim_point: Vector3, fallback_dir: Vector3) -> bool:
	if state != State.RETURNING or not is_instance_valid(player):
		return false

	var target := player.global_position + Vector3.UP * 1.0
	var distance := global_position.distance_to(target)
	if not _slowmo_on and distance > parry_range:
		return false

	var new_dir := aim_point - global_position
	if new_dir.length_squared() < 0.01:
		new_dir = fallback_dir
	direction = new_dir.normalized()
	_face(direction)
	state = State.OUTBOUND
	_life_left = lifetime
	_end_slowmo()

	if player.has_method("add_combo"):
		player.add_combo()
	return true

func _face(dir: Vector3) -> void:
	if not is_inside_tree() or dir.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT
	look_at(global_position + dir, up)

const MODEL_SCENE := preload("res://player/bullet_model.glb")
const MODEL_SCALE := 0.04

static var _trail_mesh: QuadMesh
static var _trail_process: ParticleProcessMaterial

func _build_visuals() -> void:
	var model: Node3D = MODEL_SCENE.instantiate()
	model.name = "Visual"
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	_fire = _make_fire_trail()
	add_child(_fire)

func _make_fire_trail() -> GPUParticles3D:
	if not _trail_mesh:
		_build_trail_resources()
	var fire := GPUParticles3D.new()
	fire.name = "FireTrail"
	fire.amount = 20
	fire.lifetime = 0.25
	fire.fixed_fps = 12
	fire.interpolate = false
	fire.local_coords = false
	fire.draw_pass_1 = _trail_mesh
	fire.process_material = _trail_process
	fire.position.z = 0.25
	fire.emitting = true
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	return fire

static func _build_trail_resources() -> void:
	var tex: Texture2D = load("res://player/trail.png")

	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	quad_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.albedo_texture = tex
	quad_mat.disable_receive_shadows = true

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.material = quad_mat
	_trail_mesh = quad

	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	colors.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(0.55, 0.45, 0.4, 0.7),
		Color(0.12, 0.08, 0.08, 0.0)])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = colors

	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(0.3, 0.7))
	shrink.add_point(Vector2(0.6, 0.7))
	shrink.add_point(Vector2(0.6, 0.4))
	shrink.add_point(Vector2(0.85, 0.4))
	shrink.add_point(Vector2(0.85, 0.2))
	shrink.add_point(Vector2(1.0, 0.2))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3.ZERO
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 1.0, 0)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.scale_curve = shrink_tex
	pm.color_ramp = color_ramp

	_trail_process = pm
