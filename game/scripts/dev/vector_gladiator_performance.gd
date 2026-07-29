extends Node2D

const PROTOTYPE := preload("res://scenes/dev/VectorGladiatorPrototype.tscn")
const SAMPLE_COUNTS := [1, 10, 25, 50]
const SAMPLE_SECONDS := 3.0

var _sample_index := 0
var _sample_elapsed := 0.0
var _frames := 0
var _instances: Array[Node] = []


func _ready() -> void:
	_start_sample(SAMPLE_COUNTS[_sample_index])


func _process(delta: float) -> void:
	_sample_elapsed += delta
	_frames += 1
	if _sample_elapsed < SAMPLE_SECONDS:
		return
	var average_fps := float(_frames) / _sample_elapsed
	var average_frame_ms := 1000.0 / maxf(average_fps, 0.001)
	print(
		"VECTOR_PERF count=%d fps=%.2f frame_ms=%.3f objects=%d draw_calls=%d" % [
			SAMPLE_COUNTS[_sample_index],
			average_fps,
			average_frame_ms,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		]
	)
	_sample_index += 1
	if _sample_index >= SAMPLE_COUNTS.size():
		print("VECTOR_PERF_COMPLETE")
		get_tree().quit()
		return
	_start_sample(SAMPLE_COUNTS[_sample_index])


func _start_sample(instance_count: int) -> void:
	for instance in _instances:
		instance.queue_free()
	_instances.clear()
	_sample_elapsed = 0.0
	_frames = 0
	var columns := 10
	for index in instance_count:
		var instance := PROTOTYPE.instantiate()
		instance.auto_cycle = false
		instance.scale = Vector2(0.18, 0.18)
		instance.position = Vector2(90 + (index % columns) * 115, 125 + (index / columns) * 120)
		instance.get_node("UI").visible = false
		instance.get_node("Background").visible = false
		instance.get_node("Ground").visible = false
		add_child(instance)
		instance.get_node("AnimationPlayer").play(&"idle")
		_instances.append(instance)
	print("VECTOR_PERF_SAMPLE count=%d" % instance_count)
