extends Node
## Main scene entry point. Routes to the station/server/display scene based
## on `Role.mode` (set from CLI args by the `Role` autoload before any scene
## loads). Keeps `scenes/main.tscn` a pure station scene — this is the only
## thing that knows the three roles share one export.

func _ready() -> void:
	var path := "res://scenes/main.tscn"
	match Role.mode:
		Role.Mode.SERVER:
			path = "res://scenes/server.tscn"
		Role.Mode.DISPLAY:
			path = "res://scenes/display.tscn"
	get_tree().change_scene_to_file.call_deferred(path)
