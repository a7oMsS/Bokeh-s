extends Node
class_name InvocationController

signal invoke(type: String, data: Dictionary)

func on_ritual_resolved(data: Dictionary) -> void:
	if data.get("result", "") != "success":
		return

	match data.get("type", ""):
		"condense":
			_invoke_condense(data)
		_:
			push_warning("InvocationController: tipo de ritual desconocido: %s" % data.get("type", ""))


func _invoke_condense(data: Dictionary) -> void:
	# data ya trae: position, elapsed, progress, quality (0-1, bonus por giro)
	emit_signal("invoke", "condense", data)
