extends AudioStreamPlayer2D
class_name CondenseChargeAudio

@export var base_pitch_range := Vector2(0.85, 1.05)
@onready var _bus_index := AudioServer.get_bus_index("Condense")
@onready var _filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_bus_index, 0)

var _pitch_seed := 1.0


func iniciar() -> void:
	_pitch_seed = randf_range(base_pitch_range.x, base_pitch_range.y)
	pitch_scale = _pitch_seed
	volume_db = -15.0
	bus = "Condense"
	play()

func actualizar(progress: float, quality: float) -> void:
	if not playing:
		return
	# progress mueve el "cuerpo" del sonido — mismo dato que hace crecer al core.
	volume_db = lerp(-15.0,-9.0, progress)
	_filter.cutoff_hz = lerp(400.0, 12000.0, progress)
	# quality añade un brillo extra encima — el mismo bono que COLOR_BONUS.
	pitch_scale = _pitch_seed + (quality * 0.25)

func detener() -> void:
	reparent(get_tree().current_scene, true)

	var tween = create_tween()
	tween.tween_property(self, "volume_db", -40.0, 0.8)
	tween.tween_callback(stop)
	tween.tween_callback(queue_free) 
