class_name Projectile3D
extends Area3D

@export var speed: float = 5.0
@export var turn_rate: float = 3.0         # max rad/sec at full homing. Turn radius ≈ speed / turn_rate
@export var homing_ramp_time: float = 0.6  # seconds to go from weak to full homing after a bounce
@export var lifetime: float = 10.0
@export var bounce_cooldown: float = 0.15

var velocity: Vector3 = Vector3.ZERO
var player: Node3D
var isShot: bool = false

var _ignore_time: float = 0.0
var _life_left: float = 0.0
var _homing_blend: float = 1.0   # 0 = no steering, 1 = full steering

var _home_pos: Vector3

func _ready() -> void:
	_home_pos = global_position
	player = get_tree().get_first_node_in_group("player") as Node3D

	if player == null:
		push_error("Projectile3D: no node in group 'player'")
	else:
		player.justShot.connect(_on_player_just_shot)

	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	deactivate()

func get_player_pos() -> Vector3:
	if is_instance_valid(player):
		return player.global_position + Vector3.UP * 1.0   # aim at the body, not the feet
	return Vector3.ZERO

func _on_player_just_shot() -> void:
	if not isShot:
		activate(_home_pos)

# Call this to fire the bullet (from the player, a manager, or the signal)
func activate(from_pos: Vector3) -> void:
	global_position = from_pos
	isShot = true
	visible = true
	set_deferred("monitoring", true)
	_life_left = lifetime
	_ignore_time = 0.0
	_homing_blend = 1.0

	var to_player := get_player_pos() - global_position
	velocity = to_player.normalized() * speed if to_player.length_squared() > 0.0001 else Vector3.FORWARD * speed

func deactivate() -> void:
	isShot = false
	visible = false
	velocity = Vector3.ZERO
	global_position = _home_pos
	set_deferred("monitoring", false)


func _physics_process(delta: float) -> void:
	if not isShot:
		return

	_life_left -= delta
	if _life_left <= 0.0:
		deactivate()
		return

	_ignore_time = maxf(_ignore_time - delta, 0.0)
	_homing_blend = move_toward(_homing_blend, 1.0, delta / homing_ramp_time)

	if is_instance_valid(player):
		var desired := (get_player_pos() - global_position).normalized()
		_steer_toward(desired, turn_rate * _homing_blend * delta)

	global_position += velocity * delta

# Rotate velocity toward target_dir by at most max_angle radians -> smooth arc
func _steer_toward(target_dir: Vector3, max_angle: float) -> void:
	var cur := velocity.normalized()
	var angle := cur.angle_to(target_dir)
	if angle < 0.0001:
		return

	var axis := cur.cross(target_dir)
	if axis.length_squared() < 0.0001:
		# Facing directly away from the target: pick any perpendicular axis
		axis = cur.cross(Vector3.UP)
		if axis.length_squared() < 0.0001:
			axis = cur.cross(Vector3.RIGHT)

	velocity = cur.rotated(axis.normalized(), minf(angle, max_angle)) * speed

func _on_hit(other: Node) -> void:
	if not isShot:
		return

	if other == player:
		if other.has_method("damage"):
			other.damage(10)
		deactivate()
	elif other.is_in_group("enemy"):
		if _ignore_time <= 0.0:
			_reflect_off(other as Node3D)
	else:
		# Anything else (walls, static geometry) kills the bullet
		deactivate()

func _reflect_off(enemy: Node3D) -> void:
	_ignore_time = bounce_cooldown

	var normal := (global_position - enemy.global_position).normalized()
	velocity = velocity.bounce(normal).normalized() * speed
	global_position += normal * 0.2

	# Weak steering right after the bounce, ramping up -> curved return path
	_homing_blend = 0.15
