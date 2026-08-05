extends "res://addons/godot_ai/runtime/game_helper.gd"

## Project-level guard for the Godot AI runtime helper.
##
## Headless test processes have no framebuffer or active editor debugger. The
## upstream helper still created and registered a custom Logger in that mode,
## leaving the Logger and its preloaded script alive until global shutdown.
## Godot then reported one leaked ObjectDB instance and one cached resource.
##
## Normal editor-launched game sessions keep the original helper unchanged.
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	super._ready()
