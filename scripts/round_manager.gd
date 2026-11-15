extends Node

const DRONE := preload("res://DroneFly.tscn")
const SPIDER := preload("res://SpiderEnemy.tscn")
const DEMON := preload("res://DemonGround.tscn")
const MEDKIT := preload("res://scripts/medkit.gd")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")

# Health units each enemy counts for in the round budget
const DRONE_HEALTH := 1
const SPIDER_HEALTH := 2
const DEMON_HEALTH := 2

enum Kind { DRONE, SPIDER, DEMON }

const BASE_BUDGET := 5
const DRONE_SCALE := 0.4
const ROUND_DELAY := 1.0
const BANNER_TIME := 2.0
const SPAWN_SHAKE := 0.55
const SHIFT_TIME := 2.0
const SHIFT_SHAKE := 2.1
const DUST_LIFETIME := 0.3
const DUST_COLOR := Color(0.5, 0.46, 0.4)
const MIN_PLAYER_DISTANCE := 12.0
const CLEARANCE_RADIUS := 0.8
const SPAWN_ATTEMPTS := 60
const RAY_TOP := 80.0
const RAY_BOTTOM := -40.0
const ARROW_GAP := 0.5
const ARROW_PIXEL_SIZE := 0.0015

static var _arrow_tex: ImageTexture
static var _dust_mesh: QuadMesh
static var _dust_ramp: GradientTexture1D

var round_number := 0
var _waiting := false
var _label: Label
var _banner: Label


func _ready() -> void:
	add_to_group("round_manager")
	_build_label()
	_waiting = true
	await get_tree().create_timer(1.0, false).timeout
	_start_round()


func in_transition() -> bool:
	return _waiting


func _process(_delta: float) -> void:
	if _waiting or round_number == 0:
		return
	if get_tree().get_node_count_in_group("enemy") == 0:
		_waiting = true
		await get_tree().create_timer(ROUND_DELAY, false).timeout
		_start_round()


func _start_round() -> void:
	round_number += 1
	_label.text = "ROUND %d" % round_number
	_banner.text = "ROUND %d" % round_number
	_banner.visible = true
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("reload_weapon"):
		player.reload_weapon()
	_shift_buildings(player)
	await get_tree().create_timer(maxf(BANNER_TIME, SHIFT_TIME), false).timeout
	_banner.visible = false
	var budget := round_number + BASE_BUDGET
	while budget > 0:
		var roll := randf()
		var kind := Kind.DRONE
		if budget >= 2 and roll < 0.25:
			kind = Kind.SPIDER
		elif budget >= 2 and roll < 0.5:
			kind = Kind.DEMON
		_spawn(kind)
		budget -= DRONE_HEALTH if kind == Kind.DRONE else 2
	_maybe_spawn_medkit()
	if player:
		player.shake = SPAWN_SHAKE
	_waiting = false


func _maybe_spawn_medkit() -> void:
	for old in get_tree().get_nodes_in_group("medkit"):
		old.queue_free()
	if round_number % 2 != 0:
		return
	var spot = _find_spot(true)
	if spot == null:
		return
	var kit := MEDKIT.new()
	kit.add_to_group("medkit")
	add_child(kit)
	kit.global_position = spot


# Buildings slide to new heights while dust pours off their base and the camera shakes
func _shift_buildings(player: Node) -> void:
	var arena := get_tree().get_first_node_in_group("arena") as Coliseum
	if arena == null:
		return
	var targets := arena.pick_building_heights()
	var ground_y := arena.global_position.y + 0.15
	var tween := create_tween().set_parallel(true)
	for i in arena.BUILDING_NODES.size():
		var b: Node3D = arena.BUILDING_NODES[i]
		if absf(targets[i] - b.global_position.y) < 0.05:
			continue
		_add_dust(b, ground_y)
		tween.tween_property(b, "global_position:y", targets[i], SHIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if player:
		var shake_fn := func(t: float) -> void:
			if is_instance_valid(player):
				player.shake = SHIFT_SHAKE * (1.0 - t * t)
		tween.tween_method(shake_fn, 0.0, 1.0, SHIFT_TIME)


func _add_dust(b: Node3D, ground_y: float) -> void:
	var box := AABB()
	var first := true
	var inv := b.global_transform.affine_inverse()
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first:
		return

	var yaw := Basis(Vector3.UP, b.global_basis.orthonormalized().get_euler().y)
	var sx := b.global_basis.x.length()
	var sz := b.global_basis.z.length()
	var c := box.get_center()
	var hx := box.size.x * 0.5
	var hz := box.size.z * 0.5
	# [local center, half extents in world units]
	var sides := [
		[Vector3(c.x, 0, box.position.z), Vector3(hx * sx, 0.05, 0.2)],
		[Vector3(c.x, 0, box.end.z), Vector3(hx * sx, 0.05, 0.2)],
		[Vector3(box.position.x, 0, c.z), Vector3(0.2, 0.05, hz * sz)],
		[Vector3(box.end.x, 0, c.z), Vector3(0.2, 0.05, hz * sz)],
	]
	for side in sides:
		var pos: Vector3 = b.global_transform * side[0]
		pos.y = ground_y
		var dust := make_dust(side[1])
		add_child(dust)
		dust.global_transform = Transform3D(yaw, pos)
		get_tree().create_timer(SHIFT_TIME - DUST_LIFETIME, false).timeout.connect(func():
			if is_instance_valid(dust):
				dust.emitting = false)
		get_tree().create_timer(SHIFT_TIME + 0.5, false).timeout.connect(dust.queue_free)


# Static so the loading screen can build it ahead of time
static func make_dust(ext: Vector3) -> GPUParticles3D:
	var dust := GPUParticles3D.new()
	dust.process_material = _dust_process(ext)
	dust.draw_pass_1 = _get_dust_mesh()
	dust.amount = clampi(int(maxf(ext.x, ext.z) * 3.75), 10, 100)
	dust.lifetime = DUST_LIFETIME
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 30, 80))
	dust.emitting = true
	return dust


static func _dust_process(extents: Vector3) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extents
	m.direction = Vector3.UP
	m.spread = 75.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 12.0
	m.gravity = Vector3(0, -36.0, 0)
	m.scale_min = 0.6
	m.scale_max = 1.8
	if _dust_ramp == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1.0))
		g.set_color(1, Color(1, 1, 1, 0.0))
		g.add_point(0.35, Color(1, 1, 1, 1.0))
		_dust_ramp = GradientTexture1D.new()
		_dust_ramp.gradient = g
	m.color_ramp = _dust_ramp
	return m


static func _get_dust_mesh() -> QuadMesh:
	if _dust_mesh:
		return _dust_mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://sprites/blood_dither.gdshader")
	mat.set_shader_parameter("tex", preload("res://sprites/rumble_particle.png"))
	_dust_mesh = QuadMesh.new()
	_dust_mesh.size = Vector2(0.5, 0.5)
	_dust_mesh.material = mat
	return _dust_mesh


func _spawn(kind: Kind) -> void:
	var spot = _find_spot(kind == Kind.DEMON)
	if spot == null:
		_spawn(Kind.SPIDER)
		return
	var enemy := make_enemy(kind)
	if kind == Kind.DRONE:
		spot.y += 1.5
	enemy.position = spot
	add_child(enemy)


# Static so the loading screen can spawn the same setup for warm-up
static func make_enemy(kind: Kind) -> Node3D:
	var enemy := [DRONE, SPIDER, DEMON][kind].instantiate() as Node3D
	if kind == Kind.DEMON:
		enemy.set("bullet_scene", ENEMY_BULLET)
	elif kind == Kind.DRONE:
		enemy.set("bullet_scene", ENEMY_BULLET)
		enemy.set("attack_range", INF)
		enemy.scale = Vector3.ONE * DRONE_SCALE
	_add_arrow(enemy)
	return enemy


# Always-visible red arrow above the enemy's head, constant on-screen size
static func _add_arrow(enemy: Node3D) -> void:
	var top := -INF
	for mi in enemy.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("WGT_"):
			continue
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != enemy:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		top = maxf(top, (t * (mi as MeshInstance3D).get_aabb()).end.y)
	if top == -INF:
		top = 1.0

	var extra = enemy.get("size_scale")
	var s: float = enemy.scale.x * (extra if extra != null else 1.0)

	var arrow := Sprite3D.new()
	arrow.texture = _get_arrow_texture()
	arrow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.fixed_size = true
	arrow.no_depth_test = true
	arrow.shaded = false
	arrow.double_sided = true
	arrow.render_priority = 100
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.pixel_size = ARROW_PIXEL_SIZE
	arrow.scale = Vector3.ONE / s
	arrow.position = Vector3(0, top + ARROW_GAP / s, 0)
	enemy.add_child(arrow)


static func _get_arrow_texture() -> ImageTexture:
	if _arrow_tex:
		return _arrow_tex
	const N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		var half := (N - 1 - y) * 0.5
		for x in N:
			var d := absf(x - (N - 1) * 0.5)
			if d <= half + 1.0 and y < N - 1:
				img.set_pixel(x, y, Color(0, 0, 0, 1) if d > half - 1.5 or y < 2 or y > N - 4 else Color(1, 0.1, 0.1, 1))
	_arrow_tex = ImageTexture.create_from_image(img)
	return _arrow_tex


# Rays come from above, so a hit is either a roof or the open floor, never a building interior
func _find_spot(roof_only := false) -> Variant:
	var arena := get_tree().get_first_node_in_group("arena") as Coliseum
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var space := get_viewport().world_3d.direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = CLEARANCE_RADIUS
	var fallback := Vector3.ZERO
	var buildings: Array = arena.BUILDING_NODES
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = sphere

	for i in SPAWN_ATTEMPTS * (4 if roof_only else 1):
		var r := arena.get_inner_radius() * sqrt(randf()) * 0.9
		var a := randf() * TAU
		var from := arena.global_position + Vector3(cos(a) * r, RAY_TOP, sin(a) * r)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, RAY_BOTTOM - RAY_TOP, 0))
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		if roof_only and not buildings.any(func(b): return b.is_ancestor_of(hit.collider)):
			continue
		var pos: Vector3 = hit.position
		fallback = pos
		if player and pos.distance_to(player.global_position) < MIN_PLAYER_DISTANCE:
			continue
		shape.transform = Transform3D(Basis(), pos + Vector3(0, CLEARANCE_RADIUS + 0.1, 0))
		if not space.intersect_shape(shape, 1).is_empty():
			continue
		return pos
	if roof_only:
		return null
	return fallback


func _build_label() -> void:
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	var health: Label = hud.get_node_or_null("Health") if hud else null
	_label = Label.new()
	_label.name = "Round"
	if health:
		_label.label_settings = health.label_settings
		var mat := (health.material as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("top_color", Color(1, 1, 1))
		mat.set_shader_parameter("bottom_color", Color(0.6, 0.6, 0.65))
		_label.material = mat
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.position.y = 16
	(hud if hud else self).add_child(_label)

	_banner = Label.new()
	_banner.name = "RoundBanner"
	_banner.visible = false
	if health:
		_banner.label_settings = health.label_settings
		_banner.material = _label.material
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(hud if hud else self).add_child(_banner)
