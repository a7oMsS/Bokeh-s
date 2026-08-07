extends AudioStreamPlayer2D
class_name CondenseChargeAudio

@export var base_pitch_range := Vector2(0.85, 1.05)
@onready var _bus_index := AudioServer.get_bus_index(RitualConstants.AUDIO_BUS_CONDENSE)
@onready var _filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_bus_index, 0)

var _pitch_seed := 1.0


func start() -> void:
	_pitch_seed = randf_range(base_pitch_range.x, base_pitch_range.y)
	pitch_scale = _pitch_seed
	volume_db = -15.0
	bus = RitualConstants.AUDIO_BUS_CONDENSE
	play()


func update(progress: float, quality: float) -> void:
	if not playing:
		return
	volume_db = lerp(-15.0, -6.0, progress)
	_filter.cutoff_hz = lerp(400.0, 12000.0, progress)
	pitch_scale = _pitch_seed + (quality * 0.25)


## Fades and stops without touching the shared bus filter — a new charge
## may already be writing to it by the time this one finishes fading.
func stop_fade() -> void:
	reparent(get_tree().current_scene, true)

	var tween := create_tween()
	tween.tween_property(self, "volume_db", -40.0, 0.8)
	tween.tween_callback(stop)
	tween.tween_callback(queue_free)
