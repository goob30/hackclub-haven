extends RefCounted

const SPLATTER_SHADER := preload("res://sprites/blood_splatter.gdshader")
const MIST_SHADER := preload("res://sprites/spider_mist.gdshader")
const DITHER_SHADER := preload("res://sprites/blood_dither.gdshader")
const BLOOD_TEX := preload("res://sprites/blood_particle.png")

static var _material: ShaderMaterial
static var _splat_mesh: QuadMesh
static var _splat_process: ShaderMaterial
static var _mist_mesh: QuadMesh
static var _mist_process: ShaderMaterial


static func splatter(pos: Vector3, amount := 60) -> void:
	_build()
	_emit(pos, _splat_mesh, _splat_process, amount, 0.4, 0.4)


static func mist(pos: Vector3) -> void:
	_build()
	_emit(pos, _mist_mesh, _mist_process, 80, 0.8, 0.95)


static func _build() -> void:
	if _material:
		return
	_material = ShaderMaterial.new()
	_material.shader = DITHER_SHADER
	_material.set_shader_parameter("tex", BLOOD_TEX)
	_splat_mesh = QuadMesh.new()
	_splat_mesh.size = Vector2(0.24, 0.24)
	_splat_mesh.material = _material
	_splat_process = ShaderMaterial.new()
	_splat_process.shader = SPLATTER_SHADER
	_splat_process.set_shader_parameter("speed_min", 1.5)
	_splat_process.set_shader_parameter("speed_max", 3.5)
	_splat_process.set_shader_parameter("spread", 0.5)
	_splat_process.set_shader_parameter("gravity", Vector3(0, -9.8, 0))
	_mist_mesh = QuadMesh.new()
	_mist_mesh.size = Vector2(0.6, 0.6)
	_mist_mesh.material = _material
	_mist_process = ShaderMaterial.new()
	_mist_process.shader = MIST_SHADER


static func _emit(pos: Vector3, mesh: Mesh, process: ShaderMaterial, amount: int, lifetime: float, explosiveness: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var p := GPUParticles3D.new()
	p.process_material = process
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = explosiveness
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	p.emitting = true
	tree.current_scene.add_child(p)
	p.global_position = pos
	tree.create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
