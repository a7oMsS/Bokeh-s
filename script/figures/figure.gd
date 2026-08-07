extends Node2D
class_name Figure

@onready var body_mesh: MeshInstance2D = $Body/MeshInstance2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var pop_particles: CPUParticles2D = $PopParticles
@onready var lifetime_timer: Timer = $LifetimeTimer

var global_params: Dictionary

@export var lifetime: float = 45.0
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
	FigureEnums.Depth.NEAR: {"smoothness": 0.3,  "alpha": 1.0,  "scale_mult": 2.0, "z_index": 20, "energy_mult": 0.3, "mesh_mult": 1.6},
	FigureEnums.Depth.MID:  {"smoothness": 0.02, "alpha": 0.75, "scale_mult": 1.0, "z_index": 10, "energy_mult": 1.1, "mesh_mult": 1.0},
	FigureEnums.Depth.FAR:  {"smoothness": 0.3,  "alpha": 0.32, "scale_mult": 0.5, "z_index": 1,  "energy_mult": 0.6, "mesh_mult": 0.7},
}

## Baseline burst tuning, scaled per-figure in _configure_particles().
## ⚠️ Verifica estos dos contra los valores reales de tu escena — no
## pude confirmarlos por la caída de la búsqueda del repo.
const PARTICLE_BASE_VELOCITY_MIN := 210.0
const PARTICLE_BASE_VELOCITY_MAX := 454.0
const PARTICLE_BASE_AMOUNT := 40.0
const PARTICLE_VELOCITY_SIZE_MULT_MAX := 2.2
const PARTICLE_VELOCITY_QUALITY_MULT_MAX := 1.3
const PARTICLE_AMOUNT_QUALITY_MULT_MAX := 1.4

var _padding := 1.65
var _base_color_a: Color
var _base_color_b: Color
var _size: float
var _max_size: float

var _depth_target: FigureEnums.Depth = FigureEnums.Depth.MID
var _depth_hold := 2.0
var _depth_drift_duration := 4.0
var _depth_timer := 0.0
var _has_drifted := false
var _has_appeared := false


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


func _ready() -> void:
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
func _apply_depth_visuals(depth: FigureEnums.Depth, duration: float) -> void:
	var v: Dictionary = DEPTH_VISUALS[depth]

	var normalized_size = _size / _max_size
	var energy = lerp(0.6, 0.8, normalized_size) * v.energy_mult

	var target_modulate := Color(energy, energy, energy, v.alpha)
	var target_light_color = _base_color_a * energy
	var target_scale = Vector2.ONE * v.scale_mult
	var target_mesh_size = Vector2.ONE * (_size * _padding * v.mesh_mult)

	z_index = v.z_index

	if duration <= 0.0:
		scale = target_scale
		modulate = target_modulate
		shader_material.set_shader_parameter("smoothness", v.smoothness)
		point_light.color = target_light_color
		body_mesh.mesh.size = target_mesh_size
		return

	var start_smoothness = shader_material.get_shader_parameter("smoothness")
	var start_light_color = point_light.color
	var start_mesh_size = body_mesh.mesh.size

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", target_modulate, duration) \
		.set_trans(Tween.TRANS_SINE)

	tween.tween_method(func(t: float):
		shader_material.set_shader_parameter("smoothness", lerp(start_smoothness, v.smoothness, t))
		point_light.color = start_light_color.lerp(target_light_color, t)
		body_mesh.mesh.size = start_mesh_size.lerp(target_mesh_size, t)
	, 0.0, 1.0, duration)


func _process(delta: float) -> void:
	if not _has_appeared or _has_drifted:
		return

	_depth_timer += delta
	if _depth_timer >= _depth_hold:
		_has_drifted = true
		if _depth_target == FigureEnums.Depth.MID:
			_play_settle_pulse()
		else:
			_apply_depth_visuals(_depth_target, _depth_drift_duration)


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
