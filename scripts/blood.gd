extends RefCounted

const SPLATTER_SHADER := preload("res://sprites/blood_splatter.gdshader")
const MIST_SHADER := preload("res://sprites/spider_mist.gdshader")
const DITHER_SHADER := preload("res://sprites/blood_dither.gdshader")
const BLOOD_TEX := preload("res://sprites/blood_particle.png")

static var _splat_process: ShaderMaterial
static var _mist_process: ShaderMaterial
static var _meshes := {}


static func splatter(pos: Vector3, amount := 60, tex: Texture2D = BLOOD_TEX) -> void:
	_build()
	_emit(pos, _get_meshes(tex)[0], _splat_process, amount, 0.4, 0.4)


static func mist(pos: Vector3, tex: Texture2D = BLOOD_TEX) -> void:
	_build()
	_emit(pos, _get_meshes(tex)[1], _mist_process, 80, 0.8, 0.95)


# Loading screen entry: builds the caches for a texture and emits both effects once
static func warm_up(pos: Vector3, tex: Texture2D = BLOOD_TEX) -> void:
	splatter(pos, 60, tex)
	mist(pos, tex)


# [splatter mesh, mist mesh] for a texture, built once
static func _get_meshes(tex: Texture2D) -> Array:
	if _meshes.has(tex):
		return _meshes[tex]
	var mat := ShaderMaterial.new()
	mat.shader = DITHER_SHADER
	mat.set_shader_parameter("tex", tex)
	var splat := QuadMesh.new()
	splat.size = Vector2(0.24, 0.24)
	splat.material = mat
	var mist_mesh := QuadMesh.new()
	mist_mesh.size = Vector2(0.6, 0.6)
	mist_mesh.material = mat
	_meshes[tex] = [splat, mist_mesh]
	return _meshes[tex]


static func _build() -> void:
	if _splat_process:
		return
	_splat_process = ShaderMaterial.new()
	_splat_process.shader = SPLATTER_SHADER
	_splat_process.set_shader_parameter("speed_min", 1.5)
	_splat_process.set_shader_parameter("speed_max", 3.5)
	_splat_process.set_shader_parameter("spread", 0.5)
	_splat_process.set_shader_parameter("gravity", Vector3(0, -9.8, 0))
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
