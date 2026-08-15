extends Node2D
class_name Figure

@onready var body_mesh: MeshInstance2D = $Body/MeshInstance2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var pop_particles: CPUParticles2D = $PopParticles
@onready var lifetime_timer: Timer = $LifetimeTimer

var global_params: Dictionary

@export var lifetime: float = 30.0
@export var lifetime_enabled: bool = true

@export var base_materials := {
	FigureEnums.Style.SOLID: preload("res://figures/shaders/SDFSolidMaterial.tres"),
	FigureEnums.Style.GRADIENT: preload("res://figures/shaders/SDFGradientMaterial.tres"),
	FigureEnums.Style.OUTLINE: preload("res://figures/shaders/SDFOutlineMaterial.tres"),
	FigureEnums.Style.OUTLINE_GRADIENT: preload("res://figures/shaders/SDFOutline_GradientMaterial.tres"),
}

@export var figure_personalities := {
	FigureEnums.PersonalityType.STATIC: preload("res://script/figures/personalities/personality_setup.gd"),
	FigureEnums.PersonalityType.BOUNCE: preload("res://script/figures/personalities/bounce.gd"),
	FigureEnums.PersonalityType.BLINK: preload("res://script/figures/personalities/blink.gd"),
	FigureEnums.PersonalityType.VIBRATION: preload("res://script/figures/personalities/vibration.gd"),
	FigureEnums.PersonalityType.COLOR_SHIFT: preload("res://script/figures/personalities/color_shift.gd"),
}

var shader_material: ShaderMaterial
var personality: FigurePersonality

## Blur is symmetric: as soft when Near as when Far — only Mid is sharp.
const DEPTH_VISUALS := {
	FigureEnums.Depth.NEAR: {"smoothness": 0.3,  "alpha": 1.0,  "scale_mult": 1.5, "z_index_range": Vector2i(17, 24), "energy_mult": 0.3, "mesh_mult": 1.6},
	FigureEnums.Depth.MID:  {"smoothness": 0.02, "alpha": 0.75, "scale_mult": 1.0, "z_index_range": Vector2i(9, 16), "energy_mult": 1.1, "mesh_mult": 1.0},
	FigureEnums.Depth.FAR:  {"smoothness": 0.3,  "alpha": 0.32, "scale_mult": 0.5, "z_index_range": Vector2i(1, 8),  "energy_mult": 0.6, "mesh_mult": 0.7},
}

## Baseline burst tuning, scaled per-figure in _configure_particles().
const PARTICLE_BASE_VELOCITY_MIN := 210.0
const PARTICLE_BASE_VELOCITY_MAX := 454.0
const PARTICLE_BASE_AMOUNT := 40.0
const PARTICLE_VELOCITY_SIZE_MULT_MAX := 2.2
const PARTICLE_VELOCITY_QUALITY_MULT_MAX := 1.3
const PARTICLE_AMOUNT_QUALITY_MULT_MAX := 1.4

## ⚠️ Rango de tamaño→integridad, propuesta sin confirmar.
const INTEGRIDAD_BASE := 60.0
const INTEGRIDAD_SIZE_MULT_MIN := 0.7
const INTEGRIDAD_SIZE_MULT_MAX := 1.3

## Poder ofensivo contra Vignette. 30/7 es el valor confirmado para Mid;
## Near y Far golpean menos por estar fuera de foco — multiplicadores ⚠️
## propuestos, sin confirmar.
const POWER_BASE := 30.0 / 7.0
const POWER_BY_DEPTH := {
	FigureEnums.Depth.NEAR: 0.5,
	FigureEnums.Depth.MID: 1.0,
	FigureEnums.Depth.FAR: 0.4,
}

## 5 ticks a 70bpm, convertidos a segundos porque Figure no corre su propio
## reloj de combate — solo recuerda cuánto hace que algo lo golpeó.
const REGEN_TIME_REQUIRED := 5.0 * (60.0 / 70.0)
const REGEN_RATE := 2.5  # /seg — menor que el daño recibido, según acordamos

## ⚠️ Límites de cuánto se encoge/oscurece por daño, sin confirmar. Nunca
## llegan a 0 — eso lo decide disappear_fast(), no este ajuste visual.
const DAMAGE_SCALE_MIN := 0.6
const DAMAGE_DIM_MIN := 0.35

var _padding := 1.65
var _base_color_a: Color
var _base_color_b: Color
var _size: float
var _max_size: float

var _depth_target: FigureEnums.Depth = FigureEnums.Depth.MID
var _current_depth: FigureEnums.Depth = FigureEnums.Depth.MID
var _depth_hold := 2.0
var _depth_drift_duration := 4.0
var _depth_timer := 0.0
var _has_drifted := false
var _has_appeared := false

## Estado de integridad y daño.
var integridad: float
var max_integridad: float
var _time_since_hit := 0.0
var _damage_ratio := 0.0  # 0 = integridad completa, 1 = a punto de desaparecer

## Línea base que pone la profundidad, separada del ajuste por daño — nunca
## se pisan entre sí, siempre se combinan en _update_combined_visuals().
var _depth_scale_mult := 1.0
var _depth_modulate := Color.WHITE
var _depth_light_color := Color.WHITE


## Stores incoming spawn data only. Runs before this node enters the tree
## (FigureManager calls it before add_child), so it must not touch any
## child node here — all node setup happens in _ready().
func init(params: Dictionary) -> void:
	global_params = params
	_base_color_a = params.color_a
	_base_color_b = params.color_b
	_size = params.size
	_max_size = params.max_size
	_depth_target = params.get("depth_target", FigureEnums.Depth.MID)
	_depth_hold = params.get("depth_hold", 2.0)
	_depth_drift_duration = params.get("depth_drift_duration", 4.0)

	var size_mult = lerp(INTEGRIDAD_SIZE_MULT_MIN, INTEGRIDAD_SIZE_MULT_MAX, _size / _max_size)
	max_integridad = INTEGRIDAD_BASE * size_mult
	integridad = max_integridad


func _ready() -> void:
	add_to_group("bokeh")

	_setup_shader(global_params)
	_apply_depth_visuals(global_params.get("depth", FigureEnums.Depth.MID), 0.0)
	position = global_params.position

	if lifetime > 0:
		lifetime_timer.start(lifetime)
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)

	appear()
	_set_personality(global_params.personality)


## Shape/material/mesh setup. Identity color is set ONCE here and never
## touched again — depth transitions only ever affect modulate from here on.
func _setup_shader(params: Dictionary) -> void:
	var style: FigureEnums.Style = params.style
	if not base_materials.has(style):
		push_warning("Unknown style: %s" % style)
		return

	shader_material = base_materials[style].duplicate(true)
	body_mesh.material = shader_material
	body_mesh.mesh = QuadMesh.new()

	shader_material.set_shader_parameter("shape", params.shape)
	shader_material.set_shader_parameter("padding", _padding)
	shader_material.set_shader_parameter("size", _size / _max_size)
	shader_material.set_shader_parameter("color_a", _base_color_a)
	shader_material.set_shader_parameter("color_b", _base_color_b)


func _on_lifetime_timer_timeout() -> void:
	if lifetime_enabled:
		disappear()


func disable_lifetime() -> void:
	lifetime_enabled = false
	lifetime_timer.stop()


## Applies the visuals for one depth state — brightness/alpha (modulate),
## blur, scale, mesh size and light color. Never color_a/color_b.
## duration = 0.0  → instant (used at birth)
## duration > 0.0  → animates toward that state (used when drifting)
##
## A diferencia de la versión anterior, esto ya NO escribe scale/modulate/
## point_light.color directamente — guarda la línea base de profundidad y
## deja que _update_combined_visuals() la mezcle con el daño actual.
func _apply_depth_visuals(depth: FigureEnums.Depth, duration: float) -> void:
	var v: Dictionary = DEPTH_VISUALS[depth]
	_current_depth = depth

	var normalized_size = _size / _max_size
	var energy = lerp(0.6, 0.8, normalized_size) * v.energy_mult

	var target_modulate := Color(energy, energy, energy, v.alpha)
	var target_light_color = _base_color_a * energy
	var target_scale_mult: float = v.scale_mult
	var target_mesh_size = Vector2.ONE * (_size * _padding * v.mesh_mult)

	z_index = randi_range(v.z_index_range.x, v.z_index_range.y)

	if duration <= 0.0:
		_depth_scale_mult = target_scale_mult
		_depth_modulate = target_modulate
		_depth_light_color = target_light_color
		shader_material.set_shader_parameter("smoothness", v.smoothness)
		body_mesh.mesh.size = target_mesh_size
		_update_combined_visuals()
		return

	var start_smoothness = shader_material.get_shader_parameter("smoothness")
	var start_scale_mult = _depth_scale_mult
	var start_modulate = _depth_modulate
	var start_light_color = _depth_light_color
	var start_mesh_size = body_mesh.mesh.size

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(t: float):
		_depth_scale_mult = lerp(start_scale_mult, target_scale_mult, t)
		_depth_modulate = start_modulate.lerp(target_modulate, t)
		_update_combined_visuals()
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_method(func(t: float):
		shader_material.set_shader_parameter("smoothness", lerp(start_smoothness, v.smoothness, t))
		_depth_light_color = start_light_color.lerp(target_light_color, t)
		body_mesh.mesh.size = start_mesh_size.lerp(target_mesh_size, t)
		_update_combined_visuals()
	, 0.0, 1.0, duration)


## Único punto que de verdad escribe scale/modulate/point_light.color —
## combina la línea base de profundidad con el ajuste por daño, para que
## ninguno de los dos sistemas pise al otro.
func _update_combined_visuals() -> void:
	var damage_scale = lerp(1.0, DAMAGE_SCALE_MIN, _damage_ratio)
	scale = Vector2.ONE * _depth_scale_mult * damage_scale

	var damage_dim = lerp(1.0, DAMAGE_DIM_MIN, _damage_ratio)
	modulate = Color(
		_depth_modulate.r * damage_dim,
		_depth_modulate.g * damage_dim,
		_depth_modulate.b * damage_dim,
		_depth_modulate.a
	)
	

	point_light.color = _depth_light_color * damage_dim


func _process(delta: float) -> void:
	_time_since_hit += delta
	if _time_since_hit >= REGEN_TIME_REQUIRED and integridad < max_integridad:
		integridad = min(max_integridad, integridad + REGEN_RATE * delta)
		_damage_ratio = 1.0 - (integridad / max_integridad)
		_update_combined_visuals()

	if not _has_appeared or _has_drifted:
		return

	_depth_timer += delta
	if _depth_timer >= _depth_hold:
		_has_drifted = true
		if _depth_target == FigureEnums.Depth.MID:
			_play_settle_pulse()
		else:
			_apply_depth_visuals(_depth_target, _depth_drift_duration)


## Llamado por Vignette.gd — ver nota de arquitectura en vignette.gd:
## Vignette resuelve el combate, Figure solo recibe y reacciona.
func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	integridad -= amount
	_time_since_hit = 0.0
	_damage_ratio = clamp(1.0 - (integridad / max_integridad), 0.0, 1.0)
	_update_combined_visuals()
	if integridad <= 0.0:
		disappear_fast()


## Poder actual contra Vignette — depende de la profundidad en la que este
## Bokeh está ahora mismo, no de su tamaño ni personalidad.
func get_power() -> float:
	return POWER_BASE * POWER_BY_DEPTH.get(_current_depth, 1.0)


func _play_settle_pulse() -> void:
	var base_scale = scale
	var base_light_energy = point_light.energy

	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", base_scale * 1.1, 0.25) \
		.set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(self, "scale", base_scale, 0.3) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)

	var light_tween := create_tween()
	light_tween.tween_property(point_light, "energy", base_light_energy * 1.7, 0.25)
	light_tween.tween_property(point_light, "energy", base_light_energy, 0.3)


## Entrance animation. _has_appeared only flips once this finishes, which
## gates when the depth-drift clock in _process() is allowed to start —
## otherwise a figure could drift to Near/Far while still scaling in.
func appear() -> void:
	scale = Vector2.ZERO
	modulate.a = 0.0
	rotation = -PI / 2

	var mid: Dictionary = DEPTH_VISUALS[FigureEnums.Depth.MID]
	var target_scale = Vector2.ONE * mid.scale_mult

	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", mid.alpha, 0.1)
	tween.parallel().tween_property(self, "rotation", rotation + PI / 2, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): _has_appeared = true)

	await get_tree().create_timer(0.05).timeout
	_configure_particles()
	pop_particles.restart()
	pop_particles.emitting = true


## Velocity scales with figure size so the burst can outrun the mesh
## while it's still growing — otherwise large figures swallow their own
## particles before they clear the body. Quality adds extra punch on top.
func _configure_particles() -> void:
	var normalized_size = _size / _max_size
	var quality = global_params.get("quality", 0.0)

	var velocity_mult = lerp(1.0, PARTICLE_VELOCITY_SIZE_MULT_MAX, normalized_size)
	velocity_mult *= lerp(1.0, PARTICLE_VELOCITY_QUALITY_MULT_MAX, quality)

	pop_particles.initial_velocity_min = PARTICLE_BASE_VELOCITY_MIN * velocity_mult
	pop_particles.initial_velocity_max = PARTICLE_BASE_VELOCITY_MAX * velocity_mult
	pop_particles.amount = int(lerp(PARTICLE_BASE_AMOUNT, PARTICLE_BASE_AMOUNT * PARTICLE_AMOUNT_QUALITY_MULT_MAX, quality))

	pop_particles.modulate = Color(_base_color_a.r, _base_color_a.g, _base_color_a.b, 0.6)
	pop_particles.scale_amount_min = normalized_size/10
	pop_particles.scale_amount_max = normalized_size/3
	pop_particles.scale = (Vector2.ONE * remap(_size, 50.0, 120.0, 0.5, 1.0))

func _set_personality(personality_type: FigureEnums.PersonalityType) -> void:
	if not figure_personalities.has(personality_type):
		push_warning("Unknown personality: %s" % personality_type)
		return
	set_personality(figure_personalities[personality_type])


func set_personality(script: Script) -> void:
	if personality:
		personality.queue_free()
	personality = script.new()
	add_child(personality)
	personality.setup(self)


func disappear() -> void:
	if personality:
		personality.queue_free()

	$FallTrail.set_process(true)

	var tween := create_tween()
	tween.tween_property(self, "position", position + Vector2(0, get_viewport_rect().size.y), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), 0.5)
	tween.tween_callback(queue_free)


func disappear_fast() -> void:
	var tween := create_tween()
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.6)
	tween.tween_callback(queue_free).set_delay(0.6)
