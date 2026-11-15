extends Node3D

func _ready() -> void:
	var meshes := find_children("*", "MeshInstance3D", true, false)
	var me: Node = self
	if me is MeshInstance3D:
		meshes.append(me)
	for mesh in meshes:
		var has_body := false
		for child in mesh.get_children():
			if child is StaticBody3D:
				has_body = true
				break
		if not has_body:
			(mesh as MeshInstance3D).create_trimesh_collision()
			for child in mesh.get_children():
				if child is StaticBody3D:
					for shape_node in child.get_children():
						if shape_node is CollisionShape3D and shape_node.shape is ConcavePolygonShape3D:
							shape_node.shape.backface_collision = true
