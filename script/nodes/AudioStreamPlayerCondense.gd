extends AudioStreamPlayer
class_name AudioStreamPlayerCondense

@export var success_base: AudioStream = preload("res://assets/sonidos/ES_User Interface, Alert, Select, Soft Warm Tone, Delay 01 - Epidemic Sound - 0000-2873.wav")

# Ratios de pitch_scale para los 7 grados de la escala mayor (0,2,4,5,7,9,11
# semitonos sobre la raíz). Un solo sample, pitcheado — así el charge y el
# success comparten exactamente el mismo material sonoro, garantizado.
const MAJOR_SCALE_RATIOS := [0.85, 0.9541, 1.0709, 1.1346, 1.2736, 1.4295, 1.6046]

var index := 0


func play_success(quality: float = 0.0) -> void:
	stream = success_base
	pitch_scale = MAJOR_SCALE_RATIOS[clamp(index, 0, MAJOR_SCALE_RATIOS.size() - 1)] + (1.0 * quality)
	# Un gesto Perfecto suena un poco más lleno — mismo lenguaje que el
	# flash magenta visual y el bono de audio del charge.
	volume_db = lerp(-8.0, -5.0, quality)
	play()
