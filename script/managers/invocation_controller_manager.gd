extends Node
class_name InvocationController

signal invoke(type: String, data: Dictionary)

func on_ritual_resolved(data: Dictionary):
	match data.type:
		"condense":
			if data.result == "success":
				_invoke_bokeh_condense(data)
		_:
			pass
		

func _invoke_bokeh_condense(data: Dictionary):
	emit_signal("invoke","condense",data)
