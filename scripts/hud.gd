extends CanvasLayer

var combo_label: Label

const CYL_SIZE := 160.0
const BULLET_SIZE := 38.0
const SLOT_RADIUS := 51.2
const SLOTS := 6

var _ammo_root: Control
var _cylinder: Control
var _rounds: Array[TextureRect] = []
var _steps := 0
var _count := SLOTS
var _tween: Tween
var _shake := 0.0

func _ready():
	var health_label: Label = $Health
	combo_label = Label.new()
	combo_label.name = "Combo"
	combo_label.label_settings = health_label.label_settings
	combo_label.position = health_label.position + Vector2(0, -50)
	combo_label.visible = false
	add_child(combo_label)

	_build_ammo()

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("combo_changed"):
		player.combo_changed.connect(_on_combo_changed)
	if player and player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_on_ammo_changed)

func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 5.0)
	_cylinder.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 8.0

func _on_health_updated(health):
	$Health.text = str(health) + "%"

func _on_combo_changed(combo: int):
	combo_label.text = "x" + str(combo) + " COMBO"
	combo_label.visible = combo > 0

func _build_ammo() -> void:
	_ammo_root = Control.new()
	_ammo_root.name = "Ammo"
	_ammo_root.visible = false
	_ammo_root.anchor_left = 1.0
	_ammo_root.anchor_right = 1.0
	_ammo_root.anchor_top = 1.0
	_ammo_root.anchor_bottom = 1.0
	_ammo_root.offset_left = -CYL_SIZE - 24.0
	_ammo_root.offset_right = -24.0
	_ammo_root.offset_top = -CYL_SIZE - 24.0
	_ammo_root.offset_bottom = -24.0
	add_child(_ammo_root)

	_cylinder = TextureRect.new()
	_cylinder.texture = load("res://player/Revolver/cylinder.png")
	_cylinder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cylinder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cylinder.size = Vector2.ONE * CYL_SIZE
	_cylinder.pivot_offset = Vector2.ONE * CYL_SIZE * 0.5
	_ammo_root.add_child(_cylinder)

	var bullet_tex: Texture2D = load("res://player/Revolver/bullet.png")
	for i in SLOTS:
		var a := deg_to_rad(i * 60.0)
		var r := TextureRect.new()
		r.texture = bullet_tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.size = Vector2.ONE * BULLET_SIZE
		r.position = Vector2.ONE * CYL_SIZE * 0.5 + Vector2(sin(a), -cos(a)) * SLOT_RADIUS - Vector2.ONE * BULLET_SIZE * 0.5
		_cylinder.add_child(r)
		_rounds.append(r)

func _on_ammo_changed(ammo: int, capacity: int) -> void:
	if ammo < 0:
		_ammo_root.visible = false
		return
	_ammo_root.visible = true
	if ammo >= capacity:
		for r in _rounds:
			r.visible = true
		_count = capacity
		return
	if ammo < _count:
		_count = ammo
		_steps += 1
		_shake = 1.0
		var top := posmod(-_steps, SLOTS)
		if _tween:
			_tween.kill()
		_tween = create_tween().set_ignore_time_scale(true)
		_tween.tween_property(_cylinder, "rotation_degrees", _steps * 60.0, 0.08)
		_tween.tween_callback(func(): _rounds[top].visible = false)
