extends CharacterBody3D

@export_subgroup("Properties")
@export var movement_speed = 12
@export_range(0, 100) var number_of_jumps: int = 2
@export var jump_strength = 11

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

var weapon: Weapon
var weapon_index := 0

var mouse_sensitivity = 700
var gamepad_sensitivity := 0.075

@export_subgroup("Auto Aim")
@export_range(0.0, 30.0) var auto_aim_angle: float = 15.0
@export var auto_aim_range: float = 100.0

@export_subgroup("Parry")
@export var slowmo_sensitivity_mult: float = 0.7
@export var parry_cooldown: float = 0.4

var slowmo_active: bool = false
var combo: int = 0             
var _parry_ready: bool = true  

const MUSIC_INTRO := 5.34

signal slowmo_changed(active: bool)
signal combo_changed(combo: int)
signal parry_succeeded

var mouse_captured := true

var movement_velocity: Vector3
var rotation_target: Vector3

const GRAVITY := 20.0

var health: int = 100
var dead := false
var beam_active := false
var auto_beam := true # out of ammo beam death
var infinite_ammo := false
var death_scene := "" # empty reloads the current scene
var _beam_forced := false
var out_of_ammo := false
var _refill_pending := false # round start reload not finished yet
const BEAM_SHADER := preload("res://sprites/beam_dither.gdshader")
const VIEWMODEL_SHADER := preload("res://shaders/viewmodel_adjust.gdshader")
const DANGER_RESYNC_INTERVAL := 0.5
const BEAM_TEXTURE := preload("res://sprites/laser_beam_from_god.png")
var gravity := 0.0

var previously_floored := false

var jumps_remaining: int

var container_offset = Vector3(1.2, -1.1, -2.75)

var arms_anim: AnimationPlayer

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
var bullet: Projectile3D

signal health_updated
signal ammo_changed(ammo: int, capacity: int)

@onready var camera = $Head/Camera
@onready var muzzle = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
var muzzle_flash := PixelFlash.new()
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var arms = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Arms
@onready var sound_footsteps = $SoundFootsteps
@onready var blaster_cooldown = $Cooldown
@onready var main_music: AudioStreamPlayer = get_node_or_null("../mainmusic")
@onready var danger_music: AudioStreamPlayer = get_node_or_null("../dangermusicadd")

@export var crosshair: TextureRect

# Functions

func _ready():
	add_to_group("player")
	platform_floor_layers = 0
	platform_wall_layers = 0
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	for mesh in arms.find_children("*", "MeshInstance3D"):
		mesh.layers = 2
	arms.visible = false
	ammo_changed.connect(_on_ammo_depleted)
	arms_anim = arms.find_child("AnimationPlayer", true, false)
	hide_right_arm()
	if arms_anim:
		arms_anim.animation_finished.connect(func(_n): arms.visible = false)
	muzzle.visible = false
	muzzle.get_parent().add_child(muzzle_flash)
	muzzle_flash.position = Vector3(0, 0, 10)
	muzzle_flash.set_emitting(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_item_environment()

	weapon = weapons[weapon_index] # Weapon must never be nil
	initiate_change_weapon(weapon_index)

# Weapon camera skips the expensive screen effects (invisible at arm's length)
func _setup_item_environment():
	setup_item_view($Head/Camera/SubViewportContainer as SubViewportContainer, muzzle.get_parent() as Camera3D, get_world_3d().environment)

# Static so the loading screen can build the same weapon view for warm-up
static func setup_item_view(holder: SubViewportContainer, item_cam: Camera3D, world_env: Environment) -> void:
	if world_env == null:
		return
	var env := world_env.duplicate() as Environment
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	# Contrast/saturation go through the container shader instead of a post pass
	env.adjustment_enabled = false
	var item_mat := ShaderMaterial.new()
	item_mat.shader = VIEWMODEL_SHADER
	holder.material = item_mat
	# Own lighting so the night sky doesn't black out the weapon
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = preload("res://sprites/skybox.png")
	sky_mat.energy_multiplier = 0.5
	env.sky = Sky.new()
	env.sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 1.0
	env.ambient_light_sky_contribution = 0.0
	item_cam.environment = env

var shake := 0.0

func _process(delta):
	shake = move_toward(shake, 0.0, delta / maxf(Engine.time_scale, 0.001) * 6.0)
	camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.2
	camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.2
	_update_danger_music(delta)

	_check_beam_death()

	# Handle functions
	if dead or beam_active:
		movement_velocity = Vector3.ZERO
	else:
		handle_controls(delta)
	handle_gravity(delta)
	
	# Movement
	
	var applied_velocity: Vector3
	
	movement_velocity = transform.basis * movement_velocity # Move forward
	
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = - gravity

	velocity = applied_velocity
	move_and_slide()
	
	# Rotation 
	container.position = lerp(container.position, container_offset - (basis.inverse() * applied_velocity / 30), delta * 10)
	
	# Movement sound
	
	var walking: bool = is_on_floor() and (abs(velocity.x) > 1 or abs(velocity.z) > 1)
	if sound_footsteps.stream_paused == walking:
		sound_footsteps.stream_paused = not walking
	
	# Landing after jump or falling
	
	camera.position.y = lerp(camera.position.y, 0.0, delta * 5)
	
	if is_on_floor() and gravity > 1 and !previously_floored: # Landed
		Audio.play("sounds/land.ogg")
		camera.position.y = -0.1
	
	previously_floored = is_on_floor()
	
	# Falling/respawning
	
	if position.y < -10:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()

func _exit_tree():
	Engine.time_scale = 1.0
	Audio.reset_muffle()

# Mouse movement

func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		handle_rotation(event.relative.x, event.relative.y, false)

	if event.is_action_pressed("parry"):
		action_parry()

func handle_controls(delta):
	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
	
	# Movement
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * movement_speed
	
	# Handle Controller Rotation
	var rotation_input := Input.get_vector("camera_right", "camera_left", "camera_down", "camera_up")
	if rotation_input:
		handle_rotation(rotation_input.x, rotation_input.y, true, delta)
	
	# Shooting
	
	action_shoot()
	
	# Jumping
	
	if Input.is_action_just_pressed("jump"):
		if jumps_remaining:
			action_jump()
		
	# Weapon switching

	action_weapon_toggle()

# Camera rotation

func handle_rotation(xRot: float, yRot: float, isController: bool, delta: float = 0.0):
	var look_mult: float = 1.0
	if slowmo_active:
		look_mult = slowmo_sensitivity_mult

	if isController:
		var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
		rotation_target -= Vector3(-yRot, -xRot, 0).limit_length(1.0) * gamepad_sensitivity * look_mult
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = lerp_angle(camera.rotation.x, rotation_target.x, minf(real_delta * 25, 1.0))
		rotation.y = lerp_angle(rotation.y, rotation_target.y, minf(real_delta * 25, 1.0))
	else:
		rotation_target += (Vector3(-yRot, -xRot, 0) / mouse_sensitivity) * look_mult
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = rotation_target.x;
		rotation.y = rotation_target.y;
	
# Handle gravity

func handle_gravity(delta):
	gravity += GRAVITY * delta

	if gravity < 0 and is_on_ceiling():
		gravity = 0
	
	if gravity > 0 and is_on_floor():
		jumps_remaining = number_of_jumps
		gravity = 0

# Jumping

func action_jump():
	Audio.play("sounds/jump_a.ogg, sounds/jump_b.ogg, sounds/jump_c.ogg")
	gravity = - jump_strength
	jumps_remaining -= 1

# Shooting

func action_shoot():
	if Input.is_action_pressed("shoot"):
		if is_instance_valid(bullet): return # Only one bullet in flight at a time
		if !blaster_cooldown.is_stopped(): return # Cooldown for shooting
		var model = container.get_child(0) if container.get_child_count() > 0 else null
		if model and model.has_method("can_fire") and not model.can_fire(): return # Out of ammo / reloading
		
		Audio.play(weapon.sound_shoot)
		
		# Set muzzle flash position, play animation
		

		muzzle.position = container.position - weapon.muzzle_position
		muzzle_flash.position = muzzle.position
		muzzle_flash.restart()
		shake = 1.0
		if model and model.has_method("play_shoot"):
			if "infinite" in model: model.infinite = infinite_ammo
			model.play_shoot()
		
		blaster_cooldown.start(weapon.cooldown)
		
		var new_bullet: Projectile3D = BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(new_bullet)
		
		var item_fov_tan: float = tan(deg_to_rad(muzzle.get_viewport().get_camera_3d().fov * 0.5))
		var main_fov_tan: float = tan(deg_to_rad(camera.fov * 0.5))
		var m: Vector3 = muzzle.position
		var depth := 1.5
		var local_spawn := Vector3(
			m.x / -m.z / item_fov_tan * main_fov_tan * depth,
			m.y / -m.z / item_fov_tan * main_fov_tan * depth,
			-depth)
		var spawn_pos: Vector3 = camera.global_transform * local_spawn
		
		var aim_point: Vector3 = get_auto_aim_point()
		new_bullet.launch(spawn_pos, aim_point - spawn_pos)
		bullet = new_bullet
		

# Returns the nearest enemy centre inside the auto aim cone, else straight ahead

func get_auto_aim_point(default_point: Variant = null) -> Vector3:
	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var best_point: Vector3 = default_point if default_point != null else from + forward * 100.0
	var best_angle: float = deg_to_rad(auto_aim_angle)
	var space := get_world_3d().direct_space_state
	var ignore: Array[RID] = [get_rid()]
	if is_instance_valid(bullet):
		ignore.append(bullet.get_rid())

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get("destroyed"):
			continue
		var target: Vector3 = enemy.global_position + Vector3.UP * 0.25
		var to_enemy: Vector3 = target - from
		if to_enemy.length() > auto_aim_range:
			continue
		var angle: float = forward.angle_to(to_enemy)
		if angle >= best_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, target)
		query.exclude = ignore
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and not (hit.collider is Node and enemy.is_ancestor_of(hit.collider)) and hit.collider != enemy:
			continue
		best_angle = angle
		best_point = target
	return best_point

# Toggle between available weapons (listed in 'weapons')

func action_weapon_toggle():
	if weapons.size() < 2:
		return
	if Input.is_action_just_pressed("weapon_toggle"):
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		
		Audio.play("sounds/weapon_change.ogg")

# Initiates the weapon changing animation (tween)

func initiate_change_weapon(index):
	weapon_index = index
	
	var tween := get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon) # Changes the model

func reload_weapon() -> void:
	for n in container.get_children():
		if n.has_method("reload") and n.reload():
			Audio.play("sounds/revolver_reload.mp3")
		if n.get("reloading"):
			_refill_pending = true

# Switches the weapon model (off-screen)

func change_weapon():
	weapon = weapons[weapon_index]

	# Step 1. Remove previous weapon model(s) from container
	
	for n in container.get_children():
		container.remove_child(n)
	
	# Step 2. Place new weapon model in container
	
	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)
	
	if weapon_model.has_signal("ammo_changed"):
		weapon_model.ammo_changed.connect(ammo_changed.emit)
		ammo_changed.emit(weapon_model.ammo, weapon_model.SHOTS)
	else:
		ammo_changed.emit(-1, 0)
	
	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	
	# Step 3. Set model to only render on layer 2 (the weapon camera)
	
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
		
	crosshair.texture = weapon.crosshair

var _round_manager

func _in_round_transition() -> bool:
	if not is_instance_valid(_round_manager):
		_round_manager = get_tree().get_first_node_in_group("round_manager")
	return _round_manager != null and _round_manager.in_transition()

func heal_full() -> void:
	health = 100
	health_updated.emit(health)

func damage(amount):
	if _in_round_transition():
		return
	health = maxi(health - amount, 0)
	shake = 1.5
	Audio.play("sounds/player_hurt.wav")
	health_updated.emit(health) # Update health on HUD

	if health < 1 and not dead:
		_die()

func _on_ammo_depleted(ammo: int, _capacity: int) -> void:
	out_of_ammo = ammo == 0
	if ammo != 0:
		_refill_pending = false

func _beam_allowed() -> bool:
	if _beam_forced:
		return not dead
	if not auto_beam or not out_of_ammo or _refill_pending or dead or _in_round_transition():
		return false
	return get_tree().get_node_count_in_group("enemy") > 0

func _check_beam_death() -> void:
	if beam_active or is_instance_valid(bullet) or not _beam_allowed():
		return
	_beam_death()

func summon_beam() -> void:
	_beam_forced = true
	if not beam_active and not dead:
		_beam_death()

func _beam_death() -> void:
	beam_active = true
	Engine.time_scale = 1.0
	Audio.reset_muffle()
	$Head/Camera/SubViewportContainer.visible = false
	var size := BEAM_SIZE
	var beam := make_beam()
	var mat := beam.material_override as ShaderMaterial
	var fwd: Vector3 = -camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var spot: Vector3 = global_position + fwd * 1.6 + right * 0.7
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 5.0, spot + Vector3.DOWN * 50.0)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var floor_y: float = hit.position.y if hit else global_position.y - 1.0
	get_parent().add_child(beam)
	beam.global_position = Vector3(spot.x, floor_y + size * 5.0, spot.z)
	beam.look_at(Vector3(global_position.x, beam.global_position.y, global_position.z), Vector3.UP)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		if not _beam_allowed():
			beam.queue_free()
			beam_active = false
			if not dead:
				$Head/Camera/SubViewportContainer.visible = true
			return
		health = 0
		health_updated.emit(health)
		if not dead:
			_die()
		var fade := create_tween()
		fade.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 1.4)
		fade.tween_callback(beam.queue_free))

const BEAM_SIZE := 8.0

# Static so the loading screen can draw it once ahead of time
static func make_beam() -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.render_priority = 100
	mat.set_shader_parameter("tex", BEAM_TEXTURE)
	var quad := QuadMesh.new()
	quad.size = Vector2(BEAM_SIZE, BEAM_SIZE * 10.0)
	var beam := MeshInstance3D.new()
	beam.mesh = quad
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return beam

func _die() -> void:
	dead = true
	Engine.time_scale = 1.0
	Audio.play("sounds/enemy_death.wav")
	Audio.reset_muffle()
	$Head/Camera/SubViewportContainer.visible = false
	crosshair.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 100
	var red := ColorRect.new()
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red.color = Color(0.8, 0.0, 0.0, 0.0)
	layer.add_child(red)
	add_child(layer)
	var head := $Head
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(head, "rotation:z", deg_to_rad(90), 1.4)
	tw.tween_property(head, "position:y", 0.4, 1.4)
	tw.tween_property(camera, "rotation:x", 0.0, 1.4)
	tw.tween_property(red, "color:a", 0.3, 1.4)
	tw.chain().tween_interval(3.0)
	tw.chain().tween_callback(_after_death)

func _after_death() -> void:
	if death_scene.is_empty():
		get_tree().reload_current_scene()
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(death_scene)

func hide_right_arm():
	var skels := arms.find_children("*", "Skeleton3D")
	var skel: Skeleton3D = skels[0] if skels.size() > 0 else null
	if skel and arms_anim:
		var anim := arms_anim.get_animation("jab_L")
		for i in range(anim.get_track_count() - 1, -1, -1):
			if str(anim.track_get_path(i).get_concatenated_subnames()).ends_with("R"):
				anim.remove_track(i)
		for b in skel.get_bone_count():
			var bn := skel.get_bone_name(b)
			if bn.begins_with("shoulder") and bn.ends_with("R"):
				skel.set_bone_pose_scale(b, Vector3.ZERO)

func action_parry():
	if not _parry_ready: return
	if not is_instance_valid(bullet): return
	if bullet.state != Projectile3D.State.RETURNING: return
	if arms_anim:
		arms.visible = true
		arms_anim.stop()
		arms_anim.play("jab_L", -1, 3.0)

	_parry_ready = false
	get_tree().create_timer(parry_cooldown, true, false, true).timeout.connect(_on_parry_cooldown_done)

	var forward: Vector3 = -camera.global_transform.basis.z
	var parried: bool = bullet.try_parry(get_auto_aim_point(get_crosshair_point()), forward)
	if parried:
		Audio.play("sounds/final_parry.wav")
		Audio.play(weapon.sound_shoot)
		parry_succeeded.emit()

func _on_parry_cooldown_done():
	_parry_ready = true

func get_crosshair_point() -> Vector3:
	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var to: Vector3 = from + forward * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true 
	var ignore: Array[RID] = [get_rid()]
	if is_instance_valid(bullet):
		ignore.append(bullet.get_rid())
	query.exclude = ignore

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return to
	var hit_pos: Vector3 = result["position"]
	return hit_pos

func get_combo() -> int:
	return combo

func add_combo():
	combo += 1
	combo_changed.emit(combo)

func reset_combo():
	combo = 0
	combo_changed.emit(combo)

func set_slowmo(active: bool):
	slowmo_active = active
	Audio.set_slowmo(active)
	slowmo_changed.emit(active)

var _danger_resync_wait := 0.0

# Danger layer fades in at low health, kept in sync with the main track after its intro
func _update_danger_music(delta: float) -> void:
	if not main_music or not danger_music:
		return
	_danger_resync_wait -= delta / maxf(Engine.time_scale, 0.001)
	var main_pos := main_music.get_playback_position()
	if main_pos < MUSIC_INTRO:
		if danger_music.playing:
			danger_music.stop()
	else:
		var expected := main_pos - MUSIC_INTRO
		if not danger_music.playing:
			danger_music.play(expected)
			_danger_resync_wait = DANGER_RESYNC_INTERVAL
		elif _danger_resync_wait <= 0.0 and absf(danger_music.get_playback_position() - expected) > 0.03:
			# Rate limited so a seek can't retrigger every frame
			danger_music.seek(expected)
			_danger_resync_wait = DANGER_RESYNC_INTERVAL
	var target_db := -10.0 if health < 35 else -80.0
	if not is_equal_approx(danger_music.volume_db, target_db):
		danger_music.volume_db = move_toward(danger_music.volume_db, target_db, 70.0 * delta)
