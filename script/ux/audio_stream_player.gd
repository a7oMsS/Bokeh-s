extends AudioStreamPlayer
class_name AudioStreamPlayerCondense

@export var success_base: AudioStream = preload("res://assets/sounds/condense_success.wav")

## pitch_scale ratios for the 7 major-scale degrees (0,2,4,5,7,9,11
## semitones above the root), applied to a single base sample.
const MAJOR_SCALE_RATIOS := [0.85, 0.9541, 1.0709, 1.1346, 1.2736, 1.4295, 1.6046]

var index := 0


func play_success(quality: float = 0.0) -> void:
	stream = success_base
	pitch_scale = MAJOR_SCALE_RATIOS[clamp(index, 0, MAJOR_SCALE_RATIOS.size() - 1)]
	volume_db = lerp(-6.0, 0.0, quality)
	play()
