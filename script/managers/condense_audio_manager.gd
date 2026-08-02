extends Node
class_name AudioManager

@export var max_condense_voices := 4
var active_players: Array[AudioStreamPlayerCondense] = []

var melody_index := 0
var melody_up := true


func play_condense_audio(data: Dictionary) -> void:
	if active_players.size() >= max_condense_voices:
		active_players.pop_back()

	var player := AudioStreamPlayerCondense.new()
	player.pitch_scale = data.get("pitch_seed", 1.0)

	add_child(player)
	active_players.append(player)

	_update_melody_index()
	player.index = melody_index
	player.play_condense_audio()

	player.stopped.connect(func():
		active_players.erase(player)
		player.queue_free()
	)

func soltar_condensado(_data := {}) -> void:
	if active_players.is_empty():
		return
	active_players.back().soltar_condensado()

func play_success_ritual(_data := {}) -> void:
	if active_players.is_empty():
		return
	active_players.back().play_success_ritual()


func _update_melody_index() -> void:
	if melody_up:
		melody_index += 1
		if melody_index > 5:
			melody_up = false
	else:
		melody_index -= 1
		if melody_index < 1:
			melody_up = true
