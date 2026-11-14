class_name Projectile3D
extends Area3D

# A visible, fast-moving bullet. Spawned by the player (see player.gd).
# OUTBOUND: flies straight, hits an enemy -> RETURNING, hits anything else -> lost.
# RETURNING: homes in on the player, ignores walls.

enum State { OUTBOUND, RETURNING }

@export var outbound_speed: float = 45.0   # fast, but still readable by the eye
@export var return_speed: float = 35.0
@export var hit_damage: float = 25.0       # damage dealt to an enemy
@export var player_damage: int = 10        # damage dealt to the player on return
@export var hit_player_radius: float = 0.9 # distance at which the returning bullet "reaches" the player
@export var lifetime: float = 6.0
@export var trail_delay: float = 0.12     # seconds after firing before the fire trail starts

var state: State = State.OUTBOUND
var direction: Vector3 = Vector3.FORWARD
var player: Node3D

var _life_left: float = 0.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	_life_left = lifetime
	area_entered.connect(_on_hit)
	_build_visuals()
	_face(direction)

# Call right after adding to the scene tree
func launch(from_pos: Vector3, dir: Vector3) -> void:
	global_position = from_pos
	direction = dir.normalized()
	_face(direction)

func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return

	match state:
		State.OUTBOUND:
			_move_outbound(delta)
		State.RETURNING:
			_move_returning(delta)

func _move_outbound(delta: float) -> void:
	var from := global_position
	var to := from + direction * outbound_speed * delta

	# Sweep a ray from old to new position so the bullet can't skip through thin walls.
	# Bodies only (walls); enemies are Area3Ds and are handled by area_entered.
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if is_instance_valid(player) and player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result.position
		_lose_bullet()
		return

	global_position = to

func _move_returning(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return

	var target := player.global_position + Vector3.UP * 1.0
	var to_target := target - global_position

	if to_target.length() <= hit_player_radius:
		if player.has_method("damage"):
			player.damage(player_damage)
		_lose_bullet()
		return

	direction = to_target.normalized()
	_face(direction)
	global_position += direction * return_speed * delta

func _on_hit(other: Area3D) -> void:
	# Only enemies are Area3Ds that matter; only react while flying outward.
	if state != State.OUTBOUND:
		return
	if other.is_in_group("enemy") and other.has_method("damage"):
		other.damage(hit_damage)
		queue_free() # For now the bullet just disappears. Later: state = State.RETURNING

func _lose_bullet() -> void:
	# Later: Run.bullet_lost() goes here
	queue_free()

# --- Visuals -------------------------------------------------------------

# Point the bullet's nose (-Z) along dir
func _face(dir: Vector3) -> void:
	if not is_inside_tree() or dir.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT
	look_at(global_position + dir, up)

func _build_visuals() -> void:
	# Brass material
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.82, 0.6, 0.18)
	brass.metallic = 1.0
	brass.metallic_specular = 0.8
	brass.roughness = 0.28
	brass.emission_enabled = true
	brass.emission = Color(1.0, 0.55, 0.1)
	brass.emission_energy_multiplier = 0.35

	# Cylinder meshes point along Y, so rotate the holder to make Y point along -Z (forward)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotation_degrees.x = -90.0
	add_child(visual)

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.09
	body_mesh.bottom_radius = 0.09
	body_mesh.height = 0.4
	body_mesh.material = brass
	body.mesh = body_mesh
	visual.add_child(body)

	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.09
	nose_mesh.height = 0.2
	nose_mesh.material = brass
	nose.mesh = nose_mesh
	nose.position.y = 0.3
	visual.add_child(nose)

	var fire := _make_fire_trail()
	add_child(fire)
	# Start the trail a moment after firing so it isn't in your face
	get_tree().create_timer(trail_delay).timeout.connect(func():
		if is_instance_valid(fire):
			fire.emitting = true)

func _make_fire_trail() -> GPUParticles3D:
	# Soft round sprite
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64

	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.albedo_texture = tex
	quad_mat.disable_receive_shadows = true

	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	quad.material = quad_mat

	# Yellow-white -> orange -> red -> transparent
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	colors.colors = PackedColorArray([
		Color(1.0, 0.85, 0.45, 0.45),
		Color(1.0, 0.5, 0.1, 0.35),
		Color(0.8, 0.2, 0.05, 0.18),
		Color(0.2, 0.05, 0.05, 0.0)])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = colors

	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07
	pm.direction = Vector3.ZERO
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, 1.5, 0) # flames drift upward
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.scale_curve = shrink_tex
	pm.color_ramp = color_ramp

	var fire := GPUParticles3D.new()
	fire.name = "FireTrail"
	fire.amount = 90
	fire.lifetime = 0.35
	fire.local_coords = false # particles stay where they were emitted -> a trail behind the bullet
	fire.draw_pass_1 = quad
	fire.process_material = pm
	fire.position.z = 0.25 # tail end of the bullet
	fire.emitting = false # switched on after trail_delay, see _build_visuals()
	fire.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	return fire
