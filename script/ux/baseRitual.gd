extends Node2D
class_name BaseRitual

signal finished(data: Dictionary)

var ritual_type := ""
var elapsed := 0.0
var progress := 0.0   # intrínseco: qué tan avanzado está el ritual (cada subclase decide cómo crece)
var quality := 0.0    # extrínseco: feedback del gesto, alimentado desde fuera (input)

var _resolved := false


func begin(pos: Vector2) -> void:
	position = pos
	elapsed = 0.0
	progress = 0.0
	quality = 0.0
	_resolved = false


func _process(delta: float) -> void:
	elapsed += delta


## Retroalimentación externa del gesto (p. ej. cuánto se ha girado el mouse).
## El progreso NO llega por aquí: cada ritual decide cómo avanza el suyo,
## normalmente en su propio _process a partir de `elapsed`.
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
