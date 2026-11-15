class_name PixelFlash
extends Node3D

var _flash: GPUParticles3D
var _residual: GPUParticles3D

func _init() -> void:
	_flash = _make_flash()
	_residual = _make_residual()
	add_child(_flash)
	add_child(_residual)

const RESIDUAL_DELAY := 0.06

var _shot := 0

func restart() -> void:
	_shot += 1
	var shot := _shot
	_flash.restart()
	await get_tree().create_timer(RESIDUAL_DELAY).timeout
	if shot == _shot:
		_residual.restart()

func set_emitting(on: bool) -> void:
	_flash.emitting = on
	_residual.emitting = on

func _material(additive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://player/trail.png")
	mat.disable_receive_shadows = true
	return mat

func _base(mat: Material, size: float, amount: int, lifetime: float) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.amount = maxi(1, int(amount * 0.25))
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.interpolate = false
	p.draw_pass_1 = quad
	p.layers = 2
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	return p

func _make_flash() -> GPUParticles3D:
	var colors := Gradient.new()
	colors.colors = PackedColorArray([Color(3, 3, 2.4, 1), Color(3, 2.4, 1.2, 1)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.gravity = Vector3.ZERO
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.9
	pm.scale_max = 1.3
	pm.color_ramp = ramp

	var p := _base(_material(true), 0.6, 5, 0.06)
	p.process_material = pm
	return p

func _make_residual() -> GPUParticles3D:
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	colors.colors = PackedColorArray([
		Color(0.5, 0.4, 0.35, 1),
		Color(0.28, 0.22, 0.2, 0.7),
		Color(0.06, 0.04, 0.04, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors

	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.5))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3.ZERO
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.scale_curve = shrink_tex
	pm.color_ramp = ramp

	var p := _base(_material(false), 0.5, 12, 0.2)
	p.fixed_fps = 15
	p.process_material = pm
	return p
