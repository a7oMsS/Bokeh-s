extends Node2D
class_name CursorVisual

enum BaseVisibility { SHOWING, SCALING }
enum ScaleState { SCALE_IN, STEADY, SCALE_OUT }
enum EnergyState { HIDDEN, FADE_IN, HOLD, FADE_OUT }

const BASE_RADIUS := 45.0
const BASE_COLOR := Color(1.0, 1.0, 1.0, 0.552)
const BASE_WIDTH := 3.0

const SEGMENT_COUNT := 3
const ENERGY_RADIUS := 65.0
const ARC_WIDTH := 18.0
const ARC_TOTAL_SPAN := deg_to_rad(120.0)
const ARC_GAP := deg_to_rad(6.0)
const START_ANGLE := deg_to_rad(60.0)

const FADE_IN_TIME := 0.22
const HOLD_TIME := 2.5
const FADE_OUT_TIME := 0.48   

const SCALE_IN_TIME := 0.35
const SCALE_OUT_TIME := 0.22

const COLOR_LOW := Color(0.95, 0.82, 0.25)    # amarillo
const COLOR_MID := Color(0.25, 0.85, 0.9)     # cian
const COLOR_HIGH := Color(0.85, 0.35, 0.95)   # magenta

var _energy_gradient = Gradient.new()

var _base_visible := BaseVisibility.SHOWING
var _scale_timer := 0.0
var _scale_state := ScaleState.STEADY

var _energy_state := EnergyState.HIDDEN
var _energy_timer := 0.0
var _energy_alpha := 0.0
var _energy_ratio := 0.0

const SHAKE_STRENGTH := 16.0
const SHAKE_DECAY_RATE := 6.0
const DENIED_COLOR := Color(0.9, 0.25, 0.25)
const DENIED_FLASH_TIME := 0.12

var _deny_tween: Tween

var _shake_strength := 0.0
@onready var _rand := RandomNumberGenerator.new()

# -------------------------------------------------
# Cupo de Bokeh (activos/máximos) — se muestra y oculta EXACTAMENTE junto
# con el círculo base (mismo scale/modulate, sin timer propio como el
# anillo de energía).
# -------------------------------------------------

## Asignar desde main.gd: cursor_visual.figure_manager = figure_manager
var figure_manager: FigureManager

const BOKEH_RADIUS := 65.0
const BOKEH_ARC_CENTER_ANGLE := deg_to_rad(180.0)  # lado opuesto al anillo de energía
const BOKEH_ARC_SPAN := deg_to_rad(140.0)  # fijo -- compartido por puntos y relleno
const BOKEH_DISCRETE_CAP := 9

const BOKEH_DOT_MIN_RADIUS := 3.0
const BOKEH_DOT_MAX_RADIUS := 13.0
const BOKEH_DOT_FILL_FACTOR := 0.38  # fracción del espacio entre puntos que ocupa cada uno

const BOKEH_FILL_ARC_WIDTH := 4.0

const BOKEH_COLOR_LIT := Color(0.5, 0.95, 0.85, 0.95)   # menta, igual que el trazo del círculo base
const BOKEH_COLOR_UNLIT := Color(1.0, 1.0, 1.0, 0.12)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_process(true)

	_energy_gradient.offsets = PackedFloat32Array([0.3, 0.5, 0.7])
	_energy_gradient.colors = PackedColorArray([COLOR_LOW, COLOR_MID, COLOR_HIGH])

	_rand.randomize()

## Conectar: input_ritual_manager.condense_started.connect(cursor_visual.on_condense_started)
## El círculo base se apaga en cuanto arranca la carga — Condensation toma
## el protagonismo completo desde ahí.
func on_condense_started(_pos: Vector2) -> void:
	if Explorer.can_afford(RitualConstants.CONDENSE_ENERGY_COST):
		_base_visible = BaseVisibility.SCALING
		_scale_state = ScaleState.SCALE_OUT
	else:
		_trigger_insufficient_energy_feedback()


## Conectar: ritual_controller.ritual_resolved.connect(cursor_visual.on_ritual_resolved)
## Se llama tanto en éxito como en cancelación (BaseRitual siempre resuelve
## con un "result"). El círculo base vuelve en cualquier caso — el anillo
## de energía solo si de verdad hubo un ritual exitoso.
func on_ritual_resolved(data: Dictionary) -> void:
	_base_visible = BaseVisibility.SCALING
	_scale_state = ScaleState.SCALE_IN
	_scale_timer = 0.0

	if data.get("result", "") == RitualConstants.RESULT_SUCCESS:
		_energy_ratio = Explorer.energy_ratio()
		_energy_state = EnergyState.FADE_IN
		_energy_timer = 0.0


func _process(delta: float) -> void:
	## CanvasLayer "hud" ya es espacio de pantalla — sin compensar cámara.
	global_position = get_viewport().get_mouse_position()

	if _energy_state != EnergyState.HIDDEN:
		## Lectura en vivo, no snapshot — si la energía regenera mientras
		## el anillo está visible, se refleja frame a frame.
		_energy_ratio = Explorer.energy_ratio()
		_update_energy_fade(delta)

	if _base_visible == BaseVisibility.SCALING:
		_update_scale_trans(delta)

	if _shake_strength > 0.0:
		_update_shake_cursor(delta)

	queue_redraw()


func _update_shake_cursor(delta: float) -> void:
	var base_pos = get_viewport().get_mouse_position()
	base_pos += Vector2(_rand.randf_range(-_shake_strength, _shake_strength), _rand.randf_range(-_shake_strength, _shake_strength))
	_shake_strength = lerp(_shake_strength, 0.0, SHAKE_DECAY_RATE * delta)
	global_position = base_pos


func _trigger_insufficient_energy_feedback() -> void:
	_shake_strength = SHAKE_STRENGTH

	if _deny_tween and _deny_tween.is_valid():
		_deny_tween.kill()
	_deny_tween = create_tween()

	_deny_tween.tween_property(self, "modulate:r", DENIED_COLOR.r, DENIED_FLASH_TIME)
	_deny_tween.parallel().tween_property(self, "modulate:g", DENIED_COLOR.g, DENIED_FLASH_TIME)
	_deny_tween.parallel().tween_property(self, "modulate:b", DENIED_COLOR.b, DENIED_FLASH_TIME)
	_deny_tween.tween_interval(0.35)
	_deny_tween.tween_property(self, "modulate:r", 1.0, DENIED_FLASH_TIME)
	_deny_tween.parallel().tween_property(self, "modulate:g", 1.0, DENIED_FLASH_TIME)
	_deny_tween.parallel().tween_property(self, "modulate:b", 1.0, DENIED_FLASH_TIME)


func _update_energy_fade(delta: float) -> void:
	_energy_timer += delta
	match _energy_state:
		EnergyState.FADE_IN:
			_energy_alpha = clamp(_energy_timer / FADE_IN_TIME, 0.0, 1.0)
			if _energy_timer >= FADE_IN_TIME:
				_energy_state = EnergyState.HOLD
				_energy_timer = 0.0
		EnergyState.HOLD:
			_energy_alpha = 1.0
			if _energy_timer >= HOLD_TIME:
				_energy_state = EnergyState.FADE_OUT
				_energy_timer = 0.0
		EnergyState.FADE_OUT:
			_energy_alpha = 1.0 - clamp(_energy_timer / FADE_OUT_TIME, 0.0, 1.0)
			if _energy_timer >= FADE_OUT_TIME:
				_energy_state = EnergyState.HIDDEN
				_energy_alpha = 0.0


func _update_scale_trans(delta: float) -> void:
	_scale_timer += delta
	match _scale_state:
		ScaleState.SCALE_IN:
			scale = Vector2.ONE * clamp(_scale_timer / SCALE_IN_TIME, 0.0, 1.0)
			modulate.a = clamp(_scale_timer / SCALE_IN_TIME, 0.0, 1.0)
			if _scale_timer >= SCALE_IN_TIME:
				_scale_state = ScaleState.STEADY
				_scale_timer = 0.0
		ScaleState.STEADY:
			_base_visible = BaseVisibility.SHOWING
			_scale_timer = 0.0
		ScaleState.SCALE_OUT:
			scale = Vector2.ONE - (Vector2.ONE * clamp(_scale_timer / SCALE_OUT_TIME, 0.0, 1.0))
			modulate.a = 1 - clamp(_scale_timer / SCALE_IN_TIME, 0.0, 1.0)
			if _scale_timer >= SCALE_OUT_TIME:
				_scale_state = ScaleState.STEADY
				_scale_timer = 0.0


func _draw() -> void:
	draw_arc(Vector2.ZERO, BASE_RADIUS, 0.0, TAU, 32, BASE_COLOR, BASE_WIDTH, true)
	_draw_bokeh_count()

	if _energy_state != EnergyState.HIDDEN:
		_draw_energy_ring()


func _draw_energy_ring() -> void:
	var segment_span = (ARC_TOTAL_SPAN - ARC_GAP * (SEGMENT_COUNT - 1)) / float(SEGMENT_COUNT)

	var fill_color = _energy_gradient.sample(_energy_ratio)
	fill_color.a *= _energy_alpha
	var track_color = Color(1, 1, 1, 0.07 * _energy_alpha)

	for i in range(SEGMENT_COUNT):
		var seg_start = START_ANGLE - i * (segment_span + ARC_GAP)
		var seg_end = seg_start - segment_span

		var seg_low = float(i) / SEGMENT_COUNT
		var seg_high = float(i + 1) / SEGMENT_COUNT
		var seg_fill = clamp((_energy_ratio - seg_low) / (seg_high - seg_low), 0.0, 1.0)

		draw_arc(Vector2.ZERO, ENERGY_RADIUS, seg_start, seg_end, 12, track_color, ARC_WIDTH, true)

		if seg_fill > 0.0:
			var filled_end = seg_start - segment_span * seg_fill
			draw_arc(Vector2.ZERO, ENERGY_RADIUS, seg_start, filled_end, 12, fill_color, ARC_WIDTH, true)


func _draw_bokeh_count() -> void:
	if figure_manager == null:
		return

	var limit = figure_manager.figure_limit
	var active = figure_manager.active_figures.size()

	if limit <= BOKEH_DISCRETE_CAP:
		_draw_bokeh_dots(active, limit)
	else:
		_draw_bokeh_fill_arc(active, limit)


func _draw_bokeh_dots(active: int, limit: int) -> void:
	if limit <= 0:
		return

	var start_angle = BOKEH_ARC_CENTER_ANGLE - BOKEH_ARC_SPAN * 0.5
	var spacing = BOKEH_ARC_SPAN / float(limit + 1) if limit > 1 else 0.0

	var dot_radius: float
	if limit > 1:
		var chord = 2.0 * BOKEH_RADIUS * sin(spacing * 0.5)
		dot_radius = clamp(chord * BOKEH_DOT_FILL_FACTOR, BOKEH_DOT_MIN_RADIUS, BOKEH_DOT_MAX_RADIUS)
	else:
		dot_radius = BOKEH_DOT_MAX_RADIUS

	for i in range(limit):
		var angle = start_angle + (i + 1) * spacing
		var pos = Vector2(cos(angle), sin(angle)) * BOKEH_RADIUS
		var lit = i < active
		draw_circle(pos, dot_radius, BOKEH_COLOR_LIT if lit else BOKEH_COLOR_UNLIT)
		if not lit:
			draw_arc(pos, dot_radius, 0.0, TAU, 10, Color(BOKEH_COLOR_LIT, 0.3), 1.0, true)


func _draw_bokeh_fill_arc(active: int, limit: int) -> void:
	var fill_ratio = clamp(float(active) / float(limit), 0.0, 1.0)
	var start_angle = BOKEH_ARC_CENTER_ANGLE - BOKEH_ARC_SPAN * 0.5
	var end_angle = BOKEH_ARC_CENTER_ANGLE + BOKEH_ARC_SPAN * 0.5

	draw_arc(Vector2.ZERO, BOKEH_RADIUS, start_angle, end_angle, 24, BOKEH_COLOR_UNLIT, BOKEH_FILL_ARC_WIDTH, true)

	if fill_ratio > 0.0:
		var filled_end = start_angle + BOKEH_ARC_SPAN * fill_ratio
		draw_arc(Vector2.ZERO, BOKEH_RADIUS, start_angle, filled_end, 24, BOKEH_COLOR_LIT, BOKEH_FILL_ARC_WIDTH, true)
