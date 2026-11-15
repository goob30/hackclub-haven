extends Node

# Runs once at startup: loads everything, draws effects once to compile shaders, then opens the menu.
# Nothing is preloaded here so this screen shows up before the heavy loading starts.

const NEXT_SCENE := "res://scenes/ui/homescreen.tscn"
const LOAD_SHARE := 0.85
const FRAME_BUDGET_MS := 12
const STALL_MS := 1500
const WARM_FRAMES := 4
const ITEM_CAM := "Head/Camera/SubViewportContainer/SubViewport/CameraItem"

# Same strings the game passes to Audio.play
const SOUNDS := [
	"sounds/gun_fire.wav",
	"sounds/initial_parry.wav",
	"sounds/final_parry.wav",
	"sounds/enemy_shoot.wav",
	"sounds/enemy_hurt.wav",
	"sounds/enemy_death.wav",
	"sounds/enemy_attack.ogg",
	"sounds/land.ogg",
	"sounds/jump_a.ogg, sounds/jump_b.ogg, sounds/jump_c.ogg",
	"sounds/weapon_change.ogg",
	"sounds/revolver_reload.mp3",
	"sounds/player_hurt.wav",
]

const STREAMS := [
	"res://sounds/ascension to entropy.ogg",
	"res://sounds/ascension to entropy secondary.ogg",
	"res://sounds/walking.ogg",
]

# Leaves first, so the big scenes at the end mostly hit the cache
const PATHS := [
	"res://player/trail.png",
	"res://player/Revolver/cylinder.png",
	"res://player/Revolver/bullet.png",
	"res://sprites/blood_particle.png",
	"res://sprites/drone_blood.png",
	"res://sprites/spider_blood.png",
	"res://sprites/rumble_particle.png",
	"res://sprites/laser_beam_from_god.png",
	"res://sprites/skybox.png",
	"res://sprites/crosshair.png",
	"res://sprites/blob_shadow.png",
	"res://sprites/enemy_projectile_texture.png",
	"res://sprites/drone_texture.png",
	"res://sprites/spider_texture.png",
	"res://sprites/burst_animation.tres",
	"res://arena/assets/Road type 1/road_1_bridge_ramp_2.png",
	"res://sprites/beam_dither.gdshader",
	"res://sprites/blood_dither.gdshader",
	"res://sprites/blood_splatter.gdshader",
	"res://sprites/spider_mist.gdshader",
	"res://shaders/viewmodel_adjust.gdshader",
	"res://shaders/light_steps.gdshader",
	"res://fonts/text_gradient.gdshader",
	"res://scenes/main-environment.tres",
	"res://player/bullet_model.glb",
	"res://player/arms_rig.glb",
	"res://player/Revolver/GLTF/RevolverExport.gltf",
	"res://weapons/revolver_model.tscn",
	"res://weapons/revolver.tres",
	"res://Medkit.tscn",
	"res://arena/assets/plackard_wall/plackard_closed_full.glb",
	"res://arena/assets/Road type 1/road_1_straight.glb",
	"res://arena/assets/Road type 1/road_1_Tjunction.fbx",
	"res://arena/assets/Cones/Traffic_cone_round_rubber.fbx",
	"res://arena/assets/Traffic lights/traffic_light_L.glb",
	"res://arena/assets/Traffic lights/street_light_clean.fbx",
	"res://arena/assets/Vehicles/Car.obj",
	"res://arena/assets/Vehicles/Car2.obj",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_lshape.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_lshape_brick.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_lshape_large_alt.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_lshape_vertical_stripes.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_square_brick.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_square_brick_alt.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_square_concrete.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/flat_square_concrete_alt.tscn",
	"res://arena/assets/Buildings Prebuild/Ready scenes/hangar_1.tscn",
	"res://scenes/bullet.tscn",
	"res://scenes/EnemyBullet.tscn",
	"res://DroneFly.tscn",
	"res://SpiderEnemy.tscn",
	"res://DemonGround.tscn",
	"res://objects/player.tscn",
	"res://scenes/coliseum.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/pause.tscn",
	"res://scenes/main.tscn",
	"res://scenes/tutorial.tscn",
	"res://scenes/ui/homescreen.tscn",
]

@onready var _bar: ProgressBar = %Bar
@onready var _percent: Label = %Percent

var _sync := OS.has_feature("nothreads")
var _target := 0.0
var _shown := 0.0
var _frame_start := 0


func _ready() -> void:
	if AssetCache.loaded:
		get_tree().change_scene_to_file.call_deferred(NEXT_SCENE)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()


func _process(delta: float) -> void:
	_shown = minf(_target, _shown + maxf((_target - _shown) * 6.0, 0.3) * delta)
	_bar.value = _shown * 100.0
	_percent.text = "LOADING %d%%" % int(_shown * 100.0)


func _run() -> void:
	await get_tree().process_frame
	_frame_start = Time.get_ticks_msec()

	var paths := []
	for s in SOUNDS:
		for p in (s as String).split(","):
			paths.append("res://" + p.strip_edges())
	paths.append_array(STREAMS)
	paths.append_array(PATHS)

	var total := paths.size()
	for i in total:
		var res: Resource = await _load(paths[i], i, total)
		AssetCache.keep(res)
		_target = LOAD_SHARE * float(i + 1) / total
		await _breathe()

	for s in SOUNDS:
		Audio.preload_sound(s)
		await _breathe()
	for s in STREAMS:
		Audio.preload_stream(load(s) as AudioStream)
		await _breathe()

	await _warm_up()

	AssetCache.loaded = true
	_target = 1.0
	var waited := 0.0
	while _shown < 1.0 and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	get_tree().change_scene_to_packed(load(NEXT_SCENE) as PackedScene)


# Yields only once this frame's time budget is used up
func _breathe() -> void:
	if Time.get_ticks_msec() - _frame_start >= FRAME_BUDGET_MS:
		await get_tree().process_frame
		_frame_start = Time.get_ticks_msec()


func _load(path: String, done: int, total: int) -> Resource:
	if not ResourceLoader.exists(path):
		push_warning("Loading screen: missing " + path)
		return null
	if _sync or ResourceLoader.load_threaded_request(path) != OK:
		return load(path)

	var progress := []
	var last := 0.0
	var since := Time.get_ticks_msec()
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return load(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		var p: float = progress[0] if not progress.is_empty() else 0.0
		if p > last:
			last = p
			since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - since > STALL_MS:
			# Never moving at all means the build has no loader threads; block from here on
			if last == 0.0:
				_sync = true
			break
		_target = LOAD_SHARE * (done + p) / total
		await get_tree().process_frame
		_frame_start = Time.get_ticks_msec()
	return ResourceLoader.load_threaded_get(path)


# Draws one of everything behind the opaque UI so shaders and static caches are built now
func _warm_up() -> void:
	var player_script = load("res://objects/player.gd")
	var rounds = load("res://scripts/round_manager.gd")
	var blood = load("res://scripts/blood.gd")
	var home = load("res://scenes/ui/homescreen.gd")
	var shot_script = load("res://scenes/bullet.gd")
	shot_script.warm_up()

	var stage := Node3D.new()
	stage.name = "WarmUp"
	add_child(stage)
	stage.add_child(home.make_backdrop(true))
	await _advance(0.88)

	# Enemies look for a player when they spawn
	var dummy := Node3D.new()
	dummy.add_to_group("player")
	dummy.position = Vector3(0, -500, 0)
	stage.add_child(dummy)

	var rig := _make_view_rig()
	stage.add_child(rig)
	rig.position = Vector3(0, 3, 14)
	player_script.setup_item_view(rig.get_node("Head/Camera/SubViewportContainer"), rig.get_node(ITEM_CAM), stage.get_world_3d().environment)
	_emit_all(rig)
	var view := (rig.get_node("Head/Camera") as Node3D).global_transform
	await _advance(0.91)

	var offsets := [Vector3(-3, 0.5, -8), Vector3(0, -1.5, -8), Vector3(3, -1.5, -8)]
	for kind in 3:
		var enemy: Node3D = rounds.make_enemy(kind)
		enemy.position = view * (offsets[kind] as Vector3)
		stage.add_child(enemy)
		enemy.set_physics_process(false)
		_emit_all(enemy)
		if enemy.has_method("warm_up"):
			enemy.call("warm_up")
	await _advance(0.94)

	var shot := (load("res://scenes/bullet.tscn") as PackedScene).instantiate() as Node3D
	shot.position = view * Vector3(-1.2, 0.3, -4)
	stage.add_child(shot)
	shot.set_physics_process(false)
	shot.set_deferred("monitoring", false)

	var ball := (load("res://scenes/EnemyBullet.tscn") as PackedScene).instantiate() as Node3D
	ball.position = view * Vector3(1.2, 0.3, -4)
	stage.add_child(ball)

	var kit := (load("res://scripts/medkit.gd") as GDScript).new() as Node3D
	kit.position = view * Vector3(0, -1.2, -5)
	stage.add_child(kit)

	var beam: Node3D = player_script.make_beam()
	beam.position = view * Vector3(0, 0, -30)
	stage.add_child(beam)

	var dust: Node3D = rounds.make_dust(Vector3(1.0, 0.05, 0.2))
	dust.position = view * Vector3(0, -1.5, -6)
	stage.add_child(dust)

	blood.warm_up(view * Vector3(-1, 0, -5))
	blood.warm_up(view * Vector3(1, 0, -5), load("res://sprites/drone_blood.png"))

	var hud_text := Label.new()
	hud_text.text = "0"
	var hud_mat := ShaderMaterial.new()
	hud_mat.shader = load("res://fonts/text_gradient.gdshader")
	hud_text.material = hud_mat
	stage.add_child(hud_text)

	for i in WARM_FRAMES:
		await _advance(lerpf(0.94, 0.99, float(i + 1) / WARM_FRAMES))
	stage.queue_free()
	await get_tree().process_frame


func _advance(to: float) -> void:
	_target = to
	await get_tree().process_frame
	_frame_start = Time.get_ticks_msec()


# The real player scene without its script: same cameras, lights and weapon viewport
func _make_view_rig() -> Node3D:
	var rig := (load("res://objects/player.tscn") as PackedScene).instantiate() as Node3D
	var flash: Node3D = rig.get("muzzle_flash")
	rig.set_script(null)
	var steps := rig.get_node_or_null("SoundFootsteps")
	if steps:
		rig.remove_child(steps)
		steps.free()

	var item := rig.get_node(ITEM_CAM) as Node3D
	var holder := item.get_node("Container") as Node3D
	var weapon: Resource = load("res://weapons/revolver.tres")
	var model := (weapon.get("model") as PackedScene).instantiate() as Node3D
	model.position = weapon.get("position")
	model.rotation_degrees = weapon.get("rotation")
	holder.add_child(model)
	if flash:
		item.add_child(flash)
		flash.position = holder.position - (weapon.get("muzzle_position") as Vector3)
	for m in item.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).layers = 2
	return rig


func _emit_all(root: Node) -> void:
	for p in root.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).emitting = true
