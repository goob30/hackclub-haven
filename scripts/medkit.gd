extends Area3D

const MODEL_PATH := "res://Medkit.tscn"
# Source mesh is ~3.6m wide, centered 4.8 units down its local z
const MODEL_SCALE := 0.2
const MODEL_OFFSET := Vector3(0, 0, -4.8)
const HOVER := 0.4

var _t := 0.0
var _visual: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	shape.shape = sphere
	shape.position.y = HOVER
	add_child(shape)
	_visual = _build_visual()
	_visual.position.y = HOVER
	add_child(_visual)
	body_entered.connect(_on_body_entered)


func _build_visual() -> Node3D:
	if ResourceLoader.exists(MODEL_PATH):
		var scene := load(MODEL_PATH) as PackedScene
		if scene:
			var n := scene.instantiate() as Node3D
			for c in n.get_children():
				if c is CollisionShape3D:
					c.queue_free()
			if n is Area3D:
				(n as Area3D).monitoring = false
				(n as Area3D).monitorable = false
			n.position = MODEL_OFFSET
			var pivot := Node3D.new()
			pivot.scale = Vector3.ONE * MODEL_SCALE
			pivot.add_child(n)
			return pivot
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	mi.mesh = box
	return mi


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y += delta * 1.5
	_visual.position.y = HOVER + sin(_t * 2.0) * 0.12


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("heal_full"):
		body.heal_full()
		queue_free()
