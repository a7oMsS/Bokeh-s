extends Node2D
class_name BaseRitual

signal finished(data: Dictionary)

var ritual_type := ""
var elapsed := 0.0
var progress := 0.0
var quality := 0.0

var _resolved := false


func begin(pos: Vector2) -> void:
	position = pos
	elapsed = 0.0
	progress = 0.0
	quality = 0.0
	_resolved = false


func _process(delta: float) -> void:
	elapsed += delta


## External gesture feedback (e.g. how much the mouse has spun). Progress
## does NOT arrive here — each ritual decides how its own advances,
## usually inside its own _process() from elapsed.
func update(new_quality: float) -> void:
	quality = new_quality


func resolve(final_quality: float = 0.0) -> void:
	quality = final_quality


func cancel() -> void:
	pass


func _finish(result: String, extra: Dictionary = {}) -> void:
	if _resolved:
		return
	_resolved = true
	var data := {
		"type": ritual_type,
		"result": result,
		"position": position,
		"elapsed": elapsed,
		"progress": progress,
		"quality": quality,
	}
	for key in extra.keys():
		data[key] = extra[key]
	emit_signal("finished", data)
