class_name EnemyBullet
extends CharacterBody3D

const TRAIL_TEX := preload("res://sprites/blood_particle.png")

static var _trail_mesh: QuadMesh
static var _trail_process: ParticleProcessMaterial

@export var speed := 16
@export var lifetime := 8.0

var direction := Vector3.ZERO
var shooter: Node
var damage_amount := 5
var time_left := 1.5


# Loading screen entry: builds the shared trail resources
static func warm_up() -> void:
	if not _trail_mesh:
		_build_trail_resources()


func _ready() -> void:
	warm_up()
	var trail := GPUParticles3D.new()
	trail.name = "BloodTrail"
	trail.amount = 5
	trail.lifetime = 0.25
	trail.fixed_fps = 12
	trail.interpolate = false
	trail.local_coords = false
	trail.draw_pass_1 = _trail_mesh
	trail.process_material = _trail_process
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	trail.scale = Vector3.ONE / scale.x
	trail.emitting = true
	add_child(trail)


static func _build_trail_resources() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = TRAIL_TEX
	mat.disable_receive_shadows = true
	_trail_mesh = QuadMesh.new()
	_trail_mesh.size = Vector2(0.4, 0.4)
	_trail_mesh.material = mat

	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	colors.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(0.8, 0.45, 0.45, 0.7),
		Color(0.25, 0.05, 0.05, 0.0)])
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
