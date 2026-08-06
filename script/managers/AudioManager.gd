extends Node
class_name AudioManager

@export var pool_size := 4
var _pool: Array[AudioStreamPlayerCondense] = []
var _next_steal_index := 0

var melody_index := 0
var melody_up := true


func _ready() -> void:
	for i in range(pool_size):
		var player := AudioStreamPlayerCondense.new()
		add_child(player)
		_pool.append(player)


func play_success(quality: float = 0.0) -> void:
	var player := _get_free_player()
	_update_melody_index()
	player.index = melody_index
	player.play_success(quality)


func _get_free_player() -> AudioStreamPlayerCondense:
	for p in _pool:
		if not p.playing:
			return p
	# Pool lleno: roba la voz más vieja, pero DETENIÉNDOLA primero
	# (el bug original era descartarla sin frenarla).
	var oldest = _pool[_next_steal_index]
	oldest.stop()
	_next_steal_index = (_next_steal_index + 1) % _pool.size()
	return oldest


func _update_melody_index() -> void:
	if melody_up:
		melody_index += 1
		if melody_index > 6:
			melody_index = 5
			melody_up = false
	else:
		melody_index -= 1
		if melody_index < 0:
			melody_index = 1 
			melody_up = true
