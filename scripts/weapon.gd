extends Resource
class_name Weapon

@export_subgroup("Model")
@export var model: PackedScene # Model of the weapon
@export var position: Vector3 # On-screen position
@export var rotation: Vector3 # On-screen rotation
@export var muzzle_position: Vector3 # On-screen position of muzzle flash

@export_subgroup("Properties")
@export_range(0.1, 1) var cooldown: float = 0.1 # Firerate

@export_subgroup("Sounds")
@export var sound_shoot: String # Sound path

@export_subgroup("Crosshair")
@export var crosshair: Texture2D # Image of crosshair on-screen
