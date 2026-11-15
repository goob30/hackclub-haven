extends Node

# Holds what the loading screen loaded so it stays in the ResourceLoader cache

var loaded := false
var _keep: Array[Resource] = []


func keep(res: Resource) -> void:
	if res:
		_keep.append(res)
