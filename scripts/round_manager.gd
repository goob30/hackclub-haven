extends Node

const DRONE := preload("res://DroneFly.tscn")
const SPIDER := preload("res://SpiderEnemy.tscn")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")

# Health units each enemy counts for in the round budget
const DRONE_HEALTH := 1
const SPIDER_HEALTH := 2

const BASE_BUDGET := 5
const DRONE_SCALE := 0.5
const ROUND_DELAY := 1.0
const BANNER_TIME := 2.0
const SPAWN_SHAKE := 0.8
const MIN_PLAYER_DISTANCE := 12.0
const CLEARANCE_RADIUS := 0.8
const SPAWN_ATTEMPTS := 60
const RAY_TOP := 80.0
const RAY_BOTTOM := -40.0
const ARROW_GAP := 0.5
const ARROW_PIXEL_SIZE := 0.0015

static var _arrow_tex: ImageTexture

var round_number := 0
var _waiting := false
var _label: Label
var _banner: Label


func _ready() -> void:
	_build_label()
	_waiting = true
	await get_tree().create_timer(1.0).timeout
	_start_round()


func _process(_delta: float) -> void:
	if _waiting or round_number == 0:
		return
	if get_tree().get_nodes_in_group("enemy").is_empty():
		_waiting = true
		await get_tree().create_timer(ROUND_DELAY).timeout
		_start_round()


func _start_round() -> void:
	round_number += 1
	_label.text = "ROUND %d" % round_number
	_banner.text = "ROUND %d" % round_number
	_banner.visible = true
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("reload_weapon"):
		player.reload_weapon()
	await get_tree().create_timer(BANNER_TIME).timeout
	_banner.visible = false
	var budget := round_number + BASE_BUDGET
	while budget > 0:
		var spider := budget >= SPIDER_HEALTH and randf() < 0.4
		_spawn(spider)
		budget -= SPIDER_HEALTH if spider else DRONE_HEALTH
	if player:
		player.shake = SPAWN_SHAKE
	_waiting = false


func _spawn(spider: bool) -> void:
	var spot := _find_spot()
	var enemy := (SPIDER if spider else DRONE).instantiate() as Node3D
	if not spider:
		enemy.set("bullet_scene", ENEMY_BULLET)
		enemy.scale = Vector3.ONE * DRONE_SCALE
		spot.y += 1.5
	enemy.position = spot
	_add_arrow(enemy)
	add_child(enemy)


# Always-visible red arrow above the enemy's head, constant on-screen size
func _add_arrow(enemy: Node3D) -> void:
	var top := -INF
	for mi in enemy.find_children("*", "MeshInstance3D", true, false):
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


func _get_arrow_texture() -> ImageTexture:
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
func _find_spot() -> Vector3:
	var arena := get_tree().get_first_node_in_group("arena") as Coliseum
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var space := get_viewport().world_3d.direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = CLEARANCE_RADIUS
	var fallback := Vector3.ZERO

	for i in SPAWN_ATTEMPTS:
		var r := arena.get_inner_radius() * sqrt(randf()) * 0.9
		var a := randf() * TAU
		var from := arena.global_position + Vector3(cos(a) * r, RAY_TOP, sin(a) * r)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, RAY_BOTTOM - RAY_TOP, 0))
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		var pos: Vector3 = hit.position
		fallback = pos
		if player and pos.distance_to(player.global_position) < MIN_PLAYER_DISTANCE:
			continue
		var shape := PhysicsShapeQueryParameters3D.new()
		shape.shape = sphere
		shape.transform = Transform3D(Basis(), pos + Vector3(0, CLEARANCE_RADIUS + 0.1, 0))
		if not space.intersect_shape(shape, 1).is_empty():
			continue
		return pos
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
