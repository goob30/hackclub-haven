extends Node

@export var enemy_scene: PackedScene = preload("res://objects/enemy.tscn")
@export var player: Node3D
@export var count: int = 40
@export var min_radius: float = 8.0
@export var max_radius: float = 40.0
@export var min_height: float = 1.5
@export var max_height: float = 9.0

func _ready() -> void:
	for i in count:
		var enemy := enemy_scene.instantiate() as Node3D
		enemy.set("player", player)
		var angle := randf() * TAU
		var dist := randf_range(min_radius, max_radius)
		enemy.position = Vector3(sin(angle) * dist, randf_range(min_height, max_height), cos(angle) * dist)
		add_child(enemy)
