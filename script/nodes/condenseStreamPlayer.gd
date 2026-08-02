extends AudioStreamPlayer
class_name AudioStreamPlayerCondense

signal stopped

@export var audio_success: Array[AudioStream] = [preload("res://assets/sonidos/success4.wav"), preload("res://assets/sonidos/success5.wav"), preload("res://assets/sonidos/success6.wav"), preload("res://assets/sonidos/success7.wav"), preload("res://assets/sonidos/success1.wav"), preload("res://assets/sonidos/success2.wav"), preload("res://assets/sonidos/success3.wav")]

var charge := 0.0
var max_charge := 2.0
var charging := false
var exploding := false
var base_pitch := 1.0
var index := 0

func _process(delta):
	if exploding: return

	if charging:
		charge = min(charge + delta, max_charge)
		_update_sound()
	else:
		charge = max(charge - delta * 2.0, 0.0)
		_update_sound()
		if charge <= 0.0:
			emit_signal("stopped")

func play_condense_audio():
	base_pitch = pitch_scale
	charging = true
	exploding = false
	charge = 0.0
	play()

func soltar_condensado():
	charging = false

func play_success_ritual():
	exploding = true
	charging = false
	pitch_scale = 1.0
	volume_db = 0.0

	if index < audio_success.size():
		stream = audio_success[index]
		play()

func _update_sound():
	var t := charge / max_charge
	volume_db = lerp(-40.0, -10.0, t)
	pitch_scale = lerp(base_pitch, base_pitch + 0.4, t)
