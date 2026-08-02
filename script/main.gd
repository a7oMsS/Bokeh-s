extends Control

@onready var clic_area = $ClicArea

@onready var input_ritual_manager = $Managers/InputRitualManager
@onready var ritual_controller = $Managers/RitualController
@onready var invocation_controller = $Managers/InvocationControllerManager
@onready var figura_manager = $Managers/FiguraManager
@onready var camera = $Camera2D
@onready var luminance_manager = $Managers/LuminanceManager
@onready var progressBar = $hud/ProgressBar
@onready var progressLabel = $hud/Label
@onready var hud = $hud

func _ready():
	clic_area.gui_input.connect(input_ritual_manager.process_input)
	clic_area.gui_input.connect(camera.process_input)
	luminance_manager.luminance_changed.connect(progressBar.update_luminance)
	luminance_manager.condensation_triggered.connect(_on_condensation_triggered)

	# Input → Ritual
	input_ritual_manager.condense_started.connect(ritual_controller.start_condense)
	input_ritual_manager.condense_held.connect(ritual_controller.on_condense_held)
	input_ritual_manager.condense_pushed.connect(ritual_controller.on_condense_pushed)
	
	# Cancel
	input_ritual_manager.ritual_cancelled.connect(ritual_controller.on_ritual_cancelled)

	# Ritual → World
	ritual_controller.ritual_resolved.connect(invocation_controller.on_ritual_resolved)
	invocation_controller.invoke.connect(figura_manager.on_invoke)

func _on_condensation_triggered(level: int):
	camera.do_condensation_shake(level)
	progressBar.trigger_condensation_reset(level)
