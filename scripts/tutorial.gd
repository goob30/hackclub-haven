extends Node

const DEMON := preload("res://DemonGround.tscn")
const DUMMY_SCRIPT := preload("res://objects/tutorial_dummy.gd")
const ENEMY_BULLET := preload("res://scenes/EnemyBullet.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const MENU_SCENE := "res://scenes/ui/homescreen.tscn" # placeholder main menu
const SAVE_KEY := &"tutorial_step"

const ARENA_CENTER := Vector3.ZERO
const PLAYER_SPAWN := Vector3(9, 0.5, 0)
const COMBO_GOAL := 3
const MOVE_DISTANCE := 4.0
const STEP_DELAY := 1.2
const PENALTY_READ_TIME := 10.0
const PENALTY_MAX_TIME := 25.0
const BEAM_DELAY := 3.5
const MIN_HEALTH := 30
const ICON_SCALE := 1.25
const FONT_SIZE := int(33 * ICON_SCALE)
const ICON_SIZE := int(33 / ICON_SCALE)
const DONE := Color(0.45, 1.0, 0.45)
const KEY_BG := Color(0.93, 0.93, 0.96)
const KEY_BORDER := Color(0.3, 0.3, 0.36)
const KEY_HIGHLIGHT := Color(1.0, 0.3, 0.2)

const MEDKIT_READ_TIME := 8.0
const MEDKIT_MAX_TIME := 45.0
const MEDKIT_SCRIPT := preload("res://scripts/medkit.gd")

enum Step { MOVE, SHOOT, PARRY, COMBO, PENALTY, MEDKIT, BEAM }

var step := Step.MOVE
var player
var dummy: Node3D

var _moved := 0.0
var _jumped := false
var _double_jumped := false
var _grounded_once := false
var _got_hit := false
var _beam_summoned := false
var _step_time := 0.0
var _next_step := -1
var _delay_left := 0.0
var _medkit: Node3D
var _no_slow_combo := 27

var _ui: CanvasLayer
var _panel: PanelContainer
var _lines: VBoxContainer
var _prompt: CenterContainer
var _prompt_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")
	var b := BULLET_SCENE.instantiate()
	_no_slow_combo = ceili(b.combo_for_no_slow)
	b.free()
	_build_ui()
	_spawn_dummy()
	if player:
		player.auto_beam = false
		player.infinite_ammo = true
		player.health_updated.connect(_on_health_updated)
		player.parry_succeeded.connect(_on_parry)
		_place_player()
	# Progress survives scene reloads (falling out of the map)
	var saved: int = Engine.get_meta(SAVE_KEY, Step.MOVE)
	if saved == Step.PARRY:
		saved = Step.SHOOT
	_set_step(mini(saved, Step.PENALTY))


func _spawn_dummy() -> void:
	dummy = DEMON.instantiate() as Node3D
	dummy.set_script(DUMMY_SCRIPT)
	dummy.set("bullet_scene", ENEMY_BULLET)
	dummy.position = ARENA_CENTER + Vector3.UP * 0.2
	add_child(dummy)


func _spawn_medkit() -> void:
	if is_instance_valid(_medkit):
		return
	var arena := get_tree().get_first_node_in_group("arena") as Coliseum
	if arena == null:
		return
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for i in 200:
		var r := arena.get_inner_radius() * sqrt(randf()) * 0.9
		var a := randf() * TAU
		var from := arena.global_position + Vector3(cos(a) * r, 60.0, sin(a) * r)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		if not arena.BUILDING_NODES.any(func(b): return b.is_ancestor_of(hit.collider)):
			continue
		if hit.position.distance_to(player.global_position) < 10.0:
			continue
		_medkit = MEDKIT_SCRIPT.new()
		_medkit.add_to_group("medkit")
		add_child(_medkit)
		_medkit.global_position = hit.position
		return


func _place_player() -> void:
	player.global_position = PLAYER_SPAWN
	var d := (ARENA_CENTER - PLAYER_SPAWN).normalized()
	var yaw := atan2(-d.x, -d.z)
	player.rotation.y = yaw
	player.rotation_target = Vector3(0, yaw, 0)


func _process(delta: float) -> void:
	var paused := get_tree().paused
	_ui.visible = not paused
	if paused or not is_instance_valid(player):
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_step_time += real_delta
	_update_prompt()

	if _next_step >= 0:
		_delay_left -= real_delta
		if _delay_left <= 0.0:
			var s := _next_step
			_next_step = -1
			_set_step(s)
		return

	match step:
		Step.MOVE:
			_check_move(delta)
		Step.SHOOT:
			if _bullet_returning():
				_set_step(Step.PARRY)
		Step.PARRY:
			if not is_instance_valid(player.bullet):
				_got_hit = true
				_set_step(Step.SHOOT)
		Step.COMBO:
			if player.combo >= COMBO_GOAL:
				_queue_step(Step.PENALTY, STEP_DELAY)
		Step.PENALTY:
			if (_step_time >= PENALTY_READ_TIME and not is_instance_valid(player.bullet)) or _step_time >= PENALTY_MAX_TIME:
				_set_step(Step.MEDKIT)
		Step.MEDKIT:
			var taken := not is_instance_valid(_medkit)
			if (taken and _step_time >= MEDKIT_READ_TIME) or _step_time >= MEDKIT_MAX_TIME:
				_set_step(Step.BEAM)
		Step.BEAM:
			if not _beam_summoned and _step_time >= BEAM_DELAY:
				_beam_summoned = true
				player.summon_beam()
				_refresh_text()


func _check_move(delta: float) -> void:
	var changed := false
	if _moved < MOVE_DISTANCE:
		_moved += Vector2(player.velocity.x, player.velocity.z).length() * delta
		changed = _moved >= MOVE_DISTANCE
	var max_jumps: int = player.number_of_jumps
	if player.is_on_floor() and player.jumps_remaining == max_jumps:
		_grounded_once = true
	if _grounded_once:
		var used: int = max_jumps - player.jumps_remaining
		if not _jumped and used >= 1:
			_jumped = true
			changed = true
		if not _double_jumped and used >= mini(2, max_jumps):
			_double_jumped = true
			changed = true
	if changed:
		_refresh_text()
		if _moved >= MOVE_DISTANCE and _jumped and _double_jumped:
			_queue_step(Step.SHOOT, STEP_DELAY)


func _bullet_returning() -> bool:
	return is_instance_valid(player.bullet) and player.bullet.state == Projectile3D.State.RETURNING


func _set_step(s: int) -> void:
	step = s as Step
	_step_time = 0.0
	Engine.set_meta(SAVE_KEY, Step.MOVE if s == Step.BEAM else s)
	if s == Step.MEDKIT:
		_spawn_medkit()
	if s == Step.BEAM:
		if is_instance_valid(_medkit):
			_medkit.queue_free()
		player.death_scene = MENU_SCENE
	_refresh_text()


func _queue_step(s: int, delay: float) -> void:
	if _next_step >= 0:
		return
	_next_step = s
	_delay_left = delay


func _on_parry() -> void:
	if step == Step.SHOOT or step == Step.PARRY:
		_set_step(Step.COMBO)


# Can't die mid tutorial, only to the final beam
func _on_health_updated(health: int) -> void:
	if step != Step.BEAM and health < MIN_HEALTH and not player.dead:
		player.heal_full()


func _refresh_text() -> void:
	match step:
		Step.MOVE:
			_show([
				[_c(_moved >= MOVE_DISTANCE), "key:W", "key:A", "key:S", "key:D", " Move"],
				[_c(_jumped), "key:SPACE", " Jump"],
				[_c(_double_jumped), "key:SPACE", "key:SPACE", " Jump again in the air to double jump"],
			])
		Step.SHOOT:
			var lines := [["mouse", " Left click to shoot"]]
			if _got_hit:
				lines.push_front([KEY_HIGHLIGHT, "Your bullet can hit you, don't be stupid, and parry it"])
			_show(lines)
		Step.PARRY:
			_show([
				["When time slows, press ", "key:F", " to parry it"],
			])
		Step.COMBO:
			_show([
				[DONE, "parried"],
				["Parry the bullet into an enemy and it bounces back"],
				["Keep parrying to build a combo: Reach a x%d combo" % COMBO_GOAL],
				["mouse", " Shoot, then ", "key:F", " to parry it back"],
			])
		Step.PENALTY:
			_show([
				[DONE, "W combo"],
				["Higher your combo, the less time slows down."],
				["The combo ends when you suck and fail to hit an enemy"],
				["If you spam parry the cooldown is gonna cook you"],
			])
		Step.MEDKIT:
			_show([
				["Medkits spawn every other round on a rooftop"],
				["Grab one to restore your hp"],
			])
		Step.BEAM:
			if _beam_summoned:
				_show([[KEY_HIGHLIGHT, "Someone smites you, idk who tho"]])
			else:
				_show([["If you run out of bullets before you kill every enemy..."]])


func _c(done: bool) -> Color:
	return DONE if done else Color.WHITE


# Tokens: "key:X" key cap, "mouse" left click icon, Color sets text color, anything else is text
func _show(lines: Array) -> void:
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for line in lines:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		var color := Color.WHITE
		for token in line:
			if token is Color:
				color = token
			elif token == "mouse":
				row.add_child(MouseIcon.new(ICON_SIZE * 1.6))
			elif token.begins_with("key:"):
				row.add_child(_key(token.substr(4), ICON_SIZE))
			else:
				row.add_child(_label(token, FONT_SIZE, color))
		_lines.add_child(row)


func _update_prompt() -> void:
	var active: bool = player.slowmo_active and step < Step.PENALTY and not player.dead
	_prompt.visible = active
	_panel.visible = not active and _lines.get_child_count() > 0
	if not active:
		return
	var s := 1.0 if step <= Step.PARRY else 0.7
	_prompt_box.pivot_offset = _prompt_box.size * 0.5
	_prompt_box.scale = Vector2(s, s)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(21)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = -48
	_panel.offset_bottom = -48
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 12)
	_panel.add_child(_lines)

	# Sits just below the crosshair so the incoming bullet stays visible
	_prompt = CenterContainer.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.offset_top = 260
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	_ui.add_child(_prompt)
	_prompt_box = VBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 4)
	_prompt.add_child(_prompt_box)
	var cap := _key("F", 72)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_box.add_child(cap)
	var label := _label("Parry", 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_box.add_child(label)


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", ThemeDB.fallback_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	return l


func _key(text: String, size: int) -> Control:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = KEY_BG
	sb.border_color = KEY_BORDER
	sb.set_border_width_all(maxi(2, size / 12))
	sb.border_width_bottom = maxi(4, size / 5)
	sb.set_corner_radius_all(maxi(4, size / 4))
	sb.content_margin_left = size * 0.4
	sb.content_margin_right = size * 0.4
	sb.content_margin_top = size * 0.05
	sb.content_margin_bottom = size * 0.05
	cap.add_theme_stylebox_override("panel", sb)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, size, Color(0.1, 0.1, 0.12))
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


class MouseIcon extends Control:
	func _init(h: float) -> void:
		custom_minimum_size = Vector2(h * 0.68, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := int(w * 0.5)
		var split := h * 0.44
		var body := StyleBoxFlat.new()
		body.bg_color = KEY_BG
		body.border_color = KEY_BORDER
		body.set_border_width_all(2)
		body.set_corner_radius_all(r)
		draw_style_box(body, Rect2(Vector2.ZERO, size))
		var left := StyleBoxFlat.new()
		left.bg_color = KEY_HIGHLIGHT
		left.corner_radius_top_left = r
		draw_style_box(left, Rect2(Vector2(2, 2), Vector2(w * 0.5 - 2, split - 2)))
		draw_line(Vector2(w * 0.5, 2), Vector2(w * 0.5, split), KEY_BORDER, 2.0)
		draw_line(Vector2(2, split), Vector2(w - 2, split), KEY_BORDER, 2.0)
