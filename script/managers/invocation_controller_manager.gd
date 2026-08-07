extends Node
class_name InvocationController

signal invoke(type: String, data: Dictionary)

func on_ritual_resolved(data: Dictionary) -> void:
	if data.get("result", "") != RitualConstants.RESULT_SUCCESS:
		return

	match data.get("type", ""):
		RitualConstants.TYPE_CONDENSE:
			_invoke_condense(data)
		_:
			push_warning("InvocationController: unknown ritual type: %s" % data.get("type", ""))


func _invoke_condense(data: Dictionary) -> void:
	emit_signal("invoke", RitualConstants.TYPE_CONDENSE, data)
