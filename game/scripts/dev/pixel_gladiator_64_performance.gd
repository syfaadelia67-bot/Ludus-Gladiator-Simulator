extends Node2D

const RIG_SCENE := preload("res://scenes/dev/PixelGladiatorRig.tscn")
const INSTANCE_COUNTS := [1, 10, 25, 50, 100]
const WARMUP_SECONDS := 1.5
const SAMPLE_SECONDS := 3.0

@onready var instance_root: Node2D = $InstanceRoot
@onready var status_label: Label = $Overlay/Margin/VBox/Status
@onready var result_label: Label = $Overlay/Margin/VBox/Results

var benchmark_results: Array[Dictionary] = []
var _running := false


func _ready() -> void:
    $Overlay/Margin/VBox/Run.pressed.connect(start_benchmark)
    call_deferred("start_benchmark")


func start_benchmark() -> void:
    if _running:
        return
    _running = true
    benchmark_results.clear()
    result_label.text = ""

    for count in INSTANCE_COUNTS:
        await _spawn_count(count)
        status_label.text = "Calentando %d instancias…" % count
        await get_tree().create_timer(WARMUP_SECONDS).timeout
        status_label.text = "Midiendo %d instancias durante %.1f s…" % [count, SAMPLE_SECONDS]
        var sample := await _sample_count(count)
        benchmark_results.append(sample)
        _append_result(sample)
        print("PIXEL64_BENCHMARK %s" % JSON.stringify(sample))

    status_label.text = "Benchmark completo · intervalos comparables"
    _running = false
    print("PIXEL64_BENCHMARK_COMPLETE count=%d" % benchmark_results.size())


func get_benchmark_results() -> Array[Dictionary]:
    return benchmark_results.duplicate(true)


func get_validation_state() -> Dictionary:
    return {
        "running": _running,
        "completed_samples": benchmark_results.size(),
        "method": "%.1fs warmup + %.1fs sample per count" % [WARMUP_SECONDS, SAMPLE_SECONDS],
        "counts": INSTANCE_COUNTS,
    }


func _spawn_count(count: int) -> void:
    for child in instance_root.get_children():
        child.queue_free()
    await get_tree().process_frame

    var columns := 16
    var rows := ceili(float(count) / float(columns))
    var spacing := Vector2(66, 76)
    var width := mini(count, columns) * spacing.x
    var height := rows * spacing.y
    var origin := Vector2((1280.0 - width) * 0.5, (720.0 - height) * 0.5 + 16.0)

    for index in range(count):
        var rig := RIG_SCENE.instantiate() as PixelGladiatorRig
        instance_root.add_child(rig)
        rig.position = origin + Vector2(index % columns, index / columns) * spacing
        rig.set_pixel_scale(1)
        rig.play_animation("idle")
    await get_tree().process_frame


func _sample_count(count: int) -> Dictionary:
    var elapsed := 0.0
    var frames := 0
    var draw_call_sum := 0.0
    var draw_call_peak := 0
    var frame_time_sum_ms := 0.0

    while elapsed < SAMPLE_SECONDS:
        var frame_start := Time.get_ticks_usec()
        await get_tree().process_frame
        var frame_ms := float(Time.get_ticks_usec() - frame_start) / 1000.0
        elapsed += frame_ms / 1000.0
        frames += 1
        frame_time_sum_ms += frame_ms
        var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        draw_call_sum += draw_calls
        draw_call_peak = maxi(draw_call_peak, draw_calls)

    var average_frame_ms := frame_time_sum_ms / maxi(1, frames)
    return {
        "instances": count,
        "sample_seconds": snappedf(elapsed, 0.001),
        "frames": frames,
        "fps_average": snappedf(1000.0 / average_frame_ms, 0.01),
        "frame_ms_average": snappedf(average_frame_ms, 0.001),
        "draw_calls_average": snappedf(draw_call_sum / maxi(1, frames), 0.01),
        "draw_calls_peak": draw_call_peak,
        "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
    }


func _append_result(sample: Dictionary) -> void:
    result_label.text += "%3d · %6.2f FPS · %6.3f ms · %6.1f draws · %.2f MiB\n" % [
        int(sample.instances),
        float(sample.fps_average),
        float(sample.frame_ms_average),
        float(sample.draw_calls_average),
        float(sample.static_memory_bytes) / 1048576.0,
    ]
