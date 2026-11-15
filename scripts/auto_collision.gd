extends Node3D

func _ready() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		var has_body := false
		for child in mesh.get_children():
			if child is StaticBody3D:
				has_body = true
				break
		if not has_body:
			(mesh as MeshInstance3D).create_trimesh_collision()
