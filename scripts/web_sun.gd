extends DirectionalLight3D

# Sun shadows are too costly on the web build


func _ready() -> void:
	if OS.has_feature("web"):
		shadow_enabled = false
