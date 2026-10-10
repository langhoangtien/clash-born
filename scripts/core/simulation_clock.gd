class_name SimulationClock
extends RefCounted
## Integer ticks are authoritative. Rendering only supplies elapsed time.

signal ticked(tick_index: int)

const TICKS_PER_SECOND: int = 30
const TICK_SECONDS: float = 1.0 / TICKS_PER_SECOND
const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]

var tick_count: int = 0
var running: bool = false
var speed: float = 1.0
var _accumulator: float = 0.0

func elapsed_seconds() -> float:
	return tick_count * TICK_SECONDS

func advance(frame_seconds: float) -> void:
	if not running or frame_seconds <= 0.0:
		return
	_accumulator += frame_seconds * speed
	while running and _accumulator + 0.000000001 >= TICK_SECONDS:
		_accumulator = maxf(0.0, _accumulator - TICK_SECONDS)
		_tick()

func set_running(value: bool) -> void:
	running = value

func set_speed(value: float) -> void:
	if value in SPEEDS:
		speed = value

func step() -> void:
	if not running:
		_tick()

func reset() -> void:
	running = false
	tick_count = 0
	_accumulator = 0.0

func _tick() -> void:
	tick_count += 1
	ticked.emit(tick_count)
