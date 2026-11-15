extends Node3D

var _anim: AnimationPlayer

const KEEP := ["REV_Cylinder", "REV_Frame", "REV_Handle", "REV_Trigger", "Hammer", "LOW_CHamberLock", "LOW_CHamberRotate"]

func _ready() -> void:
	var gltf := get_node("Model")
	gltf.scale = Vector3.ONE * 6.0
	for n in gltf.get_children():
		if n.name != "RevolverRig" and not n is AnimationPlayer:
			n.queue_free()
	for m in gltf.find_children("*", "MeshInstance3D"):
		if not KEEP.has(String(m.name)):
			m.visible = false

	_anim = gltf.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_anim.animation_finished.connect(_on_anim_finished)

signal ammo_changed(ammo: int, capacity: int)

const SHOTS := 6
const RELOAD_SPEED := 0.5

@export var shoot_speed: float = 2.0

var ammo := SHOTS
var reloading := false
var infinite := false
var _seg_end := -1.0
var _inf_idx := 0

func can_fire() -> bool:
	return ammo > 0 and not reloading

func play_shoot() -> void:
	if not _anim or not can_fire():
		return
	var seg := _anim.get_animation("Shoot").length / SHOTS
	var idx := SHOTS - ammo
	if infinite:
		idx = _inf_idx % SHOTS
		_inf_idx += 1
	else:
		ammo -= 1
		ammo_changed.emit(ammo, SHOTS)
	_seg_end = (idx + 1) * seg
	_anim.play("Shoot", -1, shoot_speed)
	_anim.seek(idx * seg, true)

func reload() -> bool:
	if not _anim or reloading or ammo >= SHOTS:
		return false
	reloading = true
	_seg_end = -1.0
	_anim.play("Reload", -1, RELOAD_SPEED)
	return true

func _process(_delta: float) -> void:
	if _anim and _seg_end >= 0.0 and _anim.current_animation == "Shoot" and _anim.current_animation_position >= _seg_end:
		_anim.pause()
		_seg_end = -1.0
		if ammo == 0 and infinite:
			ammo = SHOTS
			ammo_changed.emit(ammo, SHOTS)
		elif ammo == 0:
			reloading = true
			_anim.play("Reload", -1, RELOAD_SPEED)

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == "Reload":
		ammo = SHOTS
		reloading = false
		ammo_changed.emit(ammo, SHOTS)
