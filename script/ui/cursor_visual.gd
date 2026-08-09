extends Node2D
class_name CursorVisual

## Reemplaza el cursor de sistema operativo por uno dibujado en Godot.
## Motivo: un cursor de SO se dibuja fuera del bucle de Godot, con latencia
## cero respecto al hardware — ningún nodo del motor puede igualar eso.
## Dibujando el círculo base y el anillo de energía en el mismo nodo, en
## el mismo _process()/_draw(), quedan sincronizados entre sí sin excepción.
##
## Reemplaza el Input.set_custom_mouse_cursor() que vivía en ClicArea —
## quita esa línea de ahí, ya no hace nada útil una vez que el cursor de
## SO está oculto.

# -------------------------------------------------
# Círculo base (estado "reposo")
# -------------------------------------------------
const BASE_RADIUS := 45.0
const BASE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const BASE_WIDTH := 3.0

# -------------------------------------------------
# Anillo de energía (estado "post-ritual")
# -------------------------------------------------
const SEGMENT_COUNT := 3
const ENERGY_RADIUS := 65.0
const ARC_WIDTH := 18.0
const ARC_TOTAL_SPAN := deg_to_rad(120.0)
const ARC_GAP := deg_to_rad(6.0)
const START_ANGLE := deg_to_rad(60.0)

const FADE_IN_TIME := 0.22
const HOLD_TIME := 2.0
const FADE_OUT_TIME := 0.48   # ~1.5s total

const SCALE_IN_TIME := 0.35
const SCALE_OUT_TIME := 0.22

const COLOR_LOW := Color(0.95, 0.82, 0.25)    # amarillo
const COLOR_MID := Color(0.25, 0.85, 0.9)     # cian
const COLOR_HIGH := Color(0.85, 0.35, 0.95)   # magenta

var _energy_gradient = Gradient.new()

var _base_visible := "showing"  # showing | scaling |
var _scale_timer := 0.0
var _scale_state := "steady" 

var _energy_state := "hidden"   # hidden | fade_in | hold | fade_out
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
		_base_visible = "scaling"
		_scale_state = "scale_out"
	else:
		_trigger_insufficient_energy_feedback()
		

## Conectar: ritual_controller.ritual_resolved.connect(cursor_visual.on_ritual_resolved)
## Se llama tanto en éxito como en cancelación (BaseRitual siempre resuelve
## con un "result"). El círculo base vuelve en cualquier caso — el anillo
## de energía solo si de verdad hubo un ritual exitoso.
func on_ritual_resolved(data: Dictionary) -> void:
	_base_visible = "scaling"
	_scale_state = "scale_in"
	_scale_timer = 0.0
	
	if data.get("result", "") == RitualConstants.RESULT_SUCCESS:
		_energy_ratio = Explorer.energy_ratio()
		_energy_state = "fade_in"
		_energy_timer = 0.0



func _process(delta: float) -> void:
	## CanvasLayer "hud" ya es espacio de pantalla — sin compensar cámara.
	global_position = get_viewport().get_mouse_position()

	if _energy_state != "hidden":
		## Lectura en vivo, no snapshot — si la energía regenera mientras
		## el anillo está visible, se refleja frame a frame.
		_energy_ratio = Explorer.energy_ratio()
		_update_energy_fade(delta)
		
	if _base_visible == "scaling":
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
		"fade_in":
			_energy_alpha = clamp(_energy_timer / FADE_IN_TIME, 0.0, 1.0)
			if _energy_timer >= FADE_IN_TIME:
				_energy_state = "hold"
				_energy_timer = 0.0
		"hold":
			_energy_alpha = 1.0
			if _energy_timer >= HOLD_TIME:
				_energy_state = "fade_out"
				_energy_timer = 0.0
		"fade_out":
			_energy_alpha = 1.0 - clamp(_energy_timer / FADE_OUT_TIME, 0.0, 1.0)
			if _energy_timer >= FADE_OUT_TIME:
				_energy_state = "hidden"
				_energy_alpha = 0.0

func _update_scale_trans(delta: float) -> void:
	_scale_timer += delta
	match _scale_state:
		"scale_in":
			scale = Vector2.ONE * clamp(_scale_timer / SCALE_IN_TIME, 0.0, 1.0)
			modulate.a = clamp(_scale_timer / SCALE_IN_TIME, 0.0, 1.0)
			if _scale_timer >= SCALE_IN_TIME:
				_scale_state = "steady"
				_scale_timer = 0.0
		"steady":
			_base_visible = "showing"
			scale = scale
			modulate.a = modulate.a
			_scale_timer = 0.0
		"scale_out":
			scale = Vector2.ONE - (Vector2.ONE * clamp(_scale_timer / SCALE_OUT_TIME, 0.0, 1.0))
			modulate.a = 1 - clamp(_scale_timer / SCALE_IN_TIME, 0.0, 1.0)
			if _scale_timer >= SCALE_OUT_TIME:
				_scale_state = "steady"
				_scale_timer = 0.0
	

func _draw() -> void:
	draw_arc(Vector2.ZERO, BASE_RADIUS, 0.0, TAU, 32, BASE_COLOR, BASE_WIDTH, true)

	if _energy_state != "hidden":
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
