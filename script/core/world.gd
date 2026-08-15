extends Control

## Nombre del mundo para SaveManager — placeholder hasta que exista
## WorldConfig; cuando llegue, esta línea pasa a world_config.world_id
## y nada más cambia.
@export var world_config: WorldConfig

@onready var input_capture = $InputCapture 

@onready var input_ritual_manager = $Managers/InputRitualManager
@onready var ritual_controller = $Managers/RitualController
@onready var invocation_controller = $Managers/InvocationControllerManager
@onready var figure_manager = $Managers/FigureManager
@onready var shadow_manager = $Managers/ShadowManager
@onready var score_manager = $Managers/ScoreManager
@onready var audio_manager = $Managers/AudioManager
@onready var luminance_manager = $Managers/LuminanceManager

@onready var container = $GameWorld/FiguresLayer
@onready var world_awakening = $GameWorld/Atmosphere  

@onready var camera = $Camera2D
@onready var hud = $HUD

func _ready():
	luminance_manager.setup(figure_manager, shadow_manager)
	luminance_manager.energia_total = world_config.energia_total
	luminance_manager.emit_signal("luminance_changed", luminance_manager.current_luminance, luminance_manager.energia_total)

	shadow_manager.vignette_limit = world_config.vignette_limit
	shadow_manager.spawn_interval = world_config.spawn_interval
	shadow_manager.initial_count = world_config.initial_count

	hud.setup(figure_manager)
	container.z_index = ZLayers.GAMEPLAY

	SaveManager.set_current_world(world_config.world_id)
	if SaveManager.has_save():
		SaveManager.load_game()

	input_capture.gui_input.connect(input_ritual_manager.process_input)
	input_capture.gui_input.connect(camera.process_input)
	luminance_manager.luminance_changed.connect(hud.update_luminance)

	# Input → Ritual
	input_ritual_manager.condense_started.connect(hud.on_condense_started)
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
	ritual_controller.ritual_resolved.connect(hud.on_ritual_resolved)

	score_manager.score_updated.connect(hud.update_score)
	score_manager.combo_updated.connect(hud.update_combo)
	invocation_controller.invoke.connect(figure_manager.on_invoke)

	shadow_manager.start_world(figure_manager, container)
	luminance_manager.luminance_changed.connect(world_awakening.on_luminance_changed)

	EventBusAuto.level_up.connect(func(_level, _name): SaveManager.save_game())
	EventBusAuto.item_unlocked.connect(func(_item): SaveManager.save_game())
	luminance_manager.world_purified.connect(func(): SaveManager.save_game())

func _on_condensation_triggered(level: int):
	camera.do_condensation_shake(level)
	hud.trigger_condensation_reset(level)
