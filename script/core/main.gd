extends Control

@onready var clic_area = $ClicArea

@onready var input_ritual_manager = $Managers/InputRitualManager
@onready var ritual_controller = $Managers/RitualController
@onready var invocation_controller = $Managers/InvocationControllerManager
@onready var figure_manager = $Managers/FigureManager
@onready var shadow_manager = $Managers/ShadowManager
@onready var score_manager = $Managers/ScoreManager
@onready var audio_manager = $Managers/AudioManager
@onready var luminance_manager = $Managers/LuminanceManager
@onready var container = $ClicArea/FiguresLayer
@onready var world_awakening = $ClicArea/WorldAwakening
@onready var camera = $Camera2D
@onready var cursor_visual = $hud/CursorVisual
@onready var progressBar = $hud/ProgressBar
@onready var progressLabel = $hud/Luminalbl
@onready var hud = $hud

func _ready():
	cursor_visual.figure_manager = figure_manager
	clic_area.gui_input.connect(input_ritual_manager.process_input)
	clic_area.gui_input.connect(camera.process_input)
	luminance_manager.luminance_changed.connect(progressBar.update_luminance)

	# Input → Ritual
	input_ritual_manager.condense_started.connect(cursor_visual.on_condense_started)
	input_ritual_manager.condense_started.connect(ritual_controller.start_condense)
	input_ritual_manager.condense_held.connect(ritual_controller.on_condense_held)
	input_ritual_manager.condense_resolved.connect(ritual_controller.on_condense_resolved)
	
	# Cancel
	input_ritual_manager.ritual_cancelled.connect(ritual_controller.on_ritual_cancelled)

	# Ritual → World
	ritual_controller.ritual_resolved.connect(invocation_controller.on_ritual_resolved)
	ritual_controller.ritual_resolved.connect(score_manager.on_ritual_resolved)
	ritual_controller.ritual_resolved.connect(func(data):
		if data.get("result", "") == RitualConstants.RESULT_SUCCESS:
			audio_manager.play_success(data.get("quality", 0.0))
	)
	
	ritual_controller.ritual_resolved.connect(cursor_visual.on_ritual_resolved)
	
	score_manager.score_updated.connect(hud.update_score)
	score_manager.combo_updated.connect(hud.update_combo)
	invocation_controller.invoke.connect(figure_manager.on_invoke)
	
	shadow_manager.start_world(figure_manager, container)
	luminance_manager.luminance_changed.connect(world_awakening.on_luminance_changed)

func _on_condensation_triggered(level: int):
	camera.do_condensation_shake(level)
	progressBar.trigger_condensation_reset(level)
