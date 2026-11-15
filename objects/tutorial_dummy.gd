extends "res://objects/demon_enemy.gd"

# Tutorial target: can't die, only shoots when allowed

const HEALTH_FLOOR := 100000

var firing_enabled := false
var _home := Vector3.ZERO


func _ready() -> void:
	super()
	_home = global_position
	health = HEALTH_FLOOR


# Stays planted even when the player walks into it
func _physics_process(delta: float) -> void:
	super(delta)
	global_position.x = _home.x
	global_position.z = _home.z


func _can_see_player() -> bool:
	return firing_enabled and super()


func damage(amount: int) -> void:
	health = maxi(health, HEALTH_FLOOR)
	super(amount)


# Out of bounds kill just puts it back
func destroy() -> void:
	global_position = _home
	velocity = Vector3.ZERO
