extends Node3D

const KEEP := ["REV_Cylinder", "REV_Frame", "REV_Handle", "REV_Trigger", "Hammer", "LOW_CHamberLock", "LOW_CHamberRotate"]

func _ready() -> void:
	var gltf := get_node("Model")
	gltf.scale = Vector3.ONE * 4.0
	for n in gltf.get_children():
		if n.name != "RevolverRig":
			n.queue_free()
	for m in gltf.find_children("*", "MeshInstance3D"):
		if not KEEP.has(String(m.name)):
			m.visible = false
