extends Node

# Prints memory/object stats to the console (browser console on web)

const INTERVAL := 5.0
const GROUPS := ["enemy", "medkit", "buildings"]

var _t := 0.0


func _ready() -> void:
	if not (OS.has_feature("web") or OS.is_debug_build()):
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
	if _t < INTERVAL:
		return
	_t = 0.0
	var tree := get_tree()
	var rm = tree.get_first_node_in_group("round_manager")
	var groups := " round=%d" % (rm.round_number if rm else 0)
	for g in GROUPS:
		groups += " %s=%d" % [g, tree.get_node_count_in_group(g)]
	print("[stats] t=%ds fps=%d proc=%.1fms phys=%.1fms objs=%d nodes=%d orphans=%d res=%d mem=%.1fMB vram=%.1fMB draws=%d prims=%d audio_q=%d%s" % [
		int(Time.get_ticks_msec() / 1000.0),
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Audio.queue.size(),
		groups])
