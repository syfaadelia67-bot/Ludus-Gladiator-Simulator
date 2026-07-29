extends SceneTree

const PROTOTYPE := preload("res://scenes/dev/VectorGladiatorPrototype.tscn")
const EXPORTER := preload("res://addons/scalable_vector_shapes_2d/svs_scene_exporter.gd")
const OUTPUT_PATH := "res://assets/dev/vector_prototype/vector_gladiator_idle.png"
const BAKE_FPS := 8


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var prototype := PROTOTYPE.instantiate()
	prototype.auto_cycle = false
	root.add_child(prototype)
	var gladiator: Node2D = prototype.get_node("Gladiator")
	var animation_player: AnimationPlayer = prototype.get_node("AnimationPlayer")
	animation_player.play(&"RESET")
	animation_player.seek(0.0, true)
	gladiator.position = Vector2.ZERO
	await process_frame
	var frames: Array[Image] = await EXPORTER.export_sprite_frames(
		gladiator,
		animation_player,
		"idle",
		BAKE_FPS,
		root,
		func(message: String) -> void: print("VECTOR_BAKE %s" % message),
		false
	)
	if frames.is_empty():
		push_error("Vector bake produced no frames")
		quit(1)
		return
	var frame_size := frames[0].get_size()
	var sheet := Image.create_empty(frame_size.x * frames.size(), frame_size.y, false, frames[0].get_format())
	for index in frames.size():
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, frame_size), Vector2i(frame_size.x * index, 0))
	var save_result := sheet.save_png(OUTPUT_PATH)
	if save_result != OK:
		push_error("Vector bake failed to save spritesheet: %s" % error_string(save_result))
		quit(1)
		return
	print(
		"VECTOR_BAKE_COMPLETE path=%s frames=%d frame_size=%dx%d sheet_size=%dx%d" % [
			OUTPUT_PATH,
			frames.size(),
			frame_size.x,
			frame_size.y,
			sheet.get_width(),
			sheet.get_height(),
		]
	)
	prototype.queue_free()
	await process_frame
	quit()
