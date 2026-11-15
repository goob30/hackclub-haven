@tool
class_name Coliseum
extends Node3D


const WALL_SCENE := preload("res://arena/assets/plackard_wall/plackard_closed_full.glb")

const MODEL_WIDTH := 3.2
const MODEL_HEIGHT := 2.5
const MODEL_THICKNESS := 0.2
const MODEL_CENTER_X := -1.5

# const BUILDING_DEADZONE_X: Array = [0, 25, 0, 0, 0, 0, 0, 0, 0]
# const BUILDING_DEADZONE_Y: Array = [0, 32, 0, 0, 0, 0, 0, 0, 0]

enum buildingTypes {
	FLAT_LSHAPE,
	FLAT_LSHAPE_BRICK,
	FLAT_LSHAPE_LARGE_ALT,
	FLAT_LSHAPE_VERTICAL_STRIPES,
	FLAT_SQUARE_BRICK,
	FLAT_SQUARE_BRICK_ALT,
	FLAT_SQUARE_CONCRETE,
	FLAT_SQUARE_CONCRETE_ALT,
	HANGAR1
}

const GROUND_TEXTURE := preload("res://arena/assets/Road type 1/road_1_bridge_ramp_2.png")
const BUILDING_FLOORS: Array = [3, 2, 6, 6, 3, 3, 3, 3, 0]
const FLOOR_HEIGHT = 1.608
const PLAYER_SCRIPT := preload("res://objects/player.gd")
const DEFAULT_JUMP_STRENGTH := 11.0
const DEFAULT_JUMPS := 2
const JUMP_FPS := 60.0
const LANDING_MARGIN := 0.3

var BUILDING_NODES: Array

@export_group("Walls")
@export_range(0.5, 20.0, 0.1) var wall_scale: float = 6.0:
	set(v):
		wall_scale = v
		_queue_rebuild()
@export_range(3, 64, 1) var segment_count: int = 16:
	set(v):
		segment_count = v
		_queue_rebuild()
		
@export_range(0.0, 500.0, 0.5) var radius: float = 0.0:
	set(v):
		radius = v
		_queue_rebuild()

@export var flip_walls: bool = false:
	set(v):
		flip_walls = v
		_queue_rebuild()
@export var walls_have_collision: bool = true:
	set(v):
		walls_have_collision = v
		_queue_rebuild()

@export_group("Ground")
@export var ground_enabled: bool = true:
	set(v):
		ground_enabled = v
		_queue_rebuild()
## How far the ground extends past the walls.
@export_range(0.0, 100.0, 0.5) var ground_margin: float = 2.0:
	set(v):
		ground_margin = v
		_queue_rebuild()
@export_range(0.1, 20.0, 0.1) var ground_thickness: float = 1.0:
	set(v):
		ground_thickness = v
		_queue_rebuild()
@export_range(0.5, 20.0, 0.5) var ground_tile_size: float = 4.0
@export var ground_color: Color = Color(0.45, 0.42, 0.38):
	set(v):
		ground_color = v
		_queue_rebuild()

var _dirty := false

# Target world Y for every building, keeping each roof within jump reach
func pick_building_heights() -> Array[float]:
	randomize()
	var ground := global_position.y
	var reach := _max_jump_height()
	var targets: Array[float] = []
	for i in range(BUILDING_NODES.size()):
		var node: Node3D = BUILDING_NODES[i]
		var roof := _roof_y(node) - node.global_position.y
		var min_k := maxi(0, ceili((roof - reach) / FLOOR_HEIGHT))
		var max_k := maxi(min_k, BUILDING_FLOORS[i])
		var current := roundi((ground - node.global_position.y) / FLOOR_HEIGHT)
		var options: Array[int] = []
		for k in range(min_k, max_k + 1):
			if k != current:
				options.append(k)
		if options.is_empty():
			options.append(min_k + 1 if current == min_k else min_k)
		targets.append(ground - options[randi() % options.size()] * FLOOR_HEIGHT)
	return targets


func randomize_building_heights() -> void:
	var targets := pick_building_heights()
	for i in range(BUILDING_NODES.size()):
		(BUILDING_NODES[i] as Node3D).global_position.y = targets[i]


func _roof_y(node: Node3D) -> float:
	var top := -INF
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y)
	return top


# Feet rise per jump, minus the per-frame Euler loss (~v*dt/2)
func _max_jump_height() -> float:
	var p = get_tree().get_first_node_in_group("player")
	var v: float = p.jump_strength if p else DEFAULT_JUMP_STRENGTH
	var n: int = p.number_of_jumps if p else DEFAULT_JUMPS
	var per_jump: float = v * v / (2.0 * PLAYER_SCRIPT.GRAVITY) - v / (2.0 * JUMP_FPS)
	return n * per_jump - LANDING_MARGIN


func is_inside_bounds(world_pos: Vector3) -> bool:
	var p := to_local(world_pos)
	var outer := get_inner_radius() / cos(PI / segment_count)
	return Vector2(p.x, p.z).length() <= outer and p.y <= MODEL_HEIGHT * wall_scale and p.y >= -ground_thickness

func _queue_rebuild() -> void:
	if not is_inside_tree() or _dirty:
		return
	_dirty = true
	_rebuild.call_deferred()

func get_inner_radius() -> float:
	if radius > 0.0:
		return radius
	var width := MODEL_WIDTH * wall_scale
	return width / (2.0 * tan(PI / segment_count))

func _rebuild() -> void:
	_dirty = false
	for child in get_children():
		child.free()

	var inner := get_inner_radius()
	var seg_width := 2.0 * inner * tan(PI / segment_count)
	var width_scale := seg_width / MODEL_WIDTH

	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)

	for i in segment_count:
		var angle := TAU * i / segment_count
		var wall := Node3D.new()
		wall.name = "Wall%d" % i
		walls.add_child(wall)
		wall.position = Vector3(sin(angle), 0.0, cos(angle)) * inner
		wall.rotation.y = angle + (PI if flip_walls else 0.0)

		var model := WALL_SCENE.instantiate() as Node3D
		model.scale = Vector3(width_scale, wall_scale, wall_scale)
		model.position.x = - MODEL_CENTER_X * width_scale
		wall.add_child(model)

		if walls_have_collision:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(seg_width, MODEL_HEIGHT * wall_scale, MODEL_THICKNESS * wall_scale)
			shape.shape = box
			shape.position.y = box.size.y * 0.5
			body.add_child(shape)
			wall.add_child(body)

	if ground_enabled:
		var ground_radius := inner / cos(PI / segment_count) + ground_margin # reach the polygon corners
		var ground := StaticBody3D.new()
		ground.name = "Ground"
		add_child(ground)

		var mesh_instance := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = ground_radius
		cylinder.bottom_radius = ground_radius
		cylinder.height = ground_thickness
		cylinder.radial_segments = 96
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = GROUND_TEXTURE
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE / ground_tile_size
		cylinder.material = mat
		mesh_instance.mesh = cylinder
		ground.add_child(mesh_instance)

		var col := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = ground_radius
		cyl_shape.height = ground_thickness
		col.shape = cyl_shape
		ground.add_child(col)

		ground.position.y = - ground_thickness * 0.5

func _ready() -> void:
	add_to_group("arena")
	BUILDING_NODES = [
	get_node("../flat_Lshape"),
	get_node("../flat_Lshape_brick"),
	get_node("../flat_Lshape_large_alt"),
	get_node("../flat_Lshape_vertical_stripes"),
	get_node("../flat_square_brick"),
	get_node("../flat_square_brick_alt"),
	get_node("../flat_square_concrete"),
	get_node("../flat_square_concrete_alt"),
	get_node("../Hangar1"),
]
	_rebuild()
	if not Engine.is_editor_hint():
		randomize_building_heights()
