extends Node
class_name WorldAwakening

## Sistema dark → awakening: interpola el estado ambiental de la escena
## según el progreso de Luminancia. Escucha luminance_changed directo
## (mismo patrón que progressBar.update_luminance) — LuminanceManager se
## queda puramente como economía, esto es presentación.
##
## _process(), no Tween: luminance_changed se dispara casi cada frame (el
## drenaje pasivo corre en el _process() de LuminanceManager) — crear un
## Tween nuevo en cada señal competiría contra sí mismo sin parar.

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var world_particles: GPUParticles2D = $WorldParticles
@onready var fog_material: ShaderMaterial = $BG/FogLayer.material

# ---- Dark (t=0) — iguales a los valores actuales de la escena, así que
# nada cambia visualmente en el estado de partida hasta el primer avance.
## Subido de 0.039 -- a ese nivel, CanvasModulate topaba a ~4% de brillo
## cualquier cosa sin brillo HDR (niebla, partículas, el cuerpo de un
## Vignette), sin importar qué tan claro fuera su color de origen. Sigue
## siendo casi total oscuridad, pero deja algo de margen real.
const DARK_MODULATE := Color(0.2, 0.2, 0.2, 1.0)
const DARK_BRIGHTNESS := 0.87
const DARK_CONTRAST := 0.98
const DARK_SATURATION := 1.15
const DARK_GLOW := 0.5
const DARK_PARTICLE_RATIO := 0.25
const DARK_FOG_INTENSITY := 2.0
## fog_intensity solo controla el alpha de esta capa aditiva -- este color
## es el techo real de cuánto puede aportar, sin importar el intensity.
## 0.044 (el valor original) es invisible después del multiply de
## CanvasModulate + el overlay del Vignette de esquina.
const DARK_FOG_COLOR := Color(0.20, 0.20, 0.22, 1.0)

# ---- Awakened (t=1) — punto de partida, es decisión de arte tuya. Ajusta
# estos valores a ojo, todo lo demás sigue funcionando igual.
const AWAKE_MODULATE := Color(0.42, 0.38, 0.5, 1.0)
const AWAKE_BRIGHTNESS := 1.05
const AWAKE_CONTRAST := 1.05
const AWAKE_SATURATION := 1.35
const AWAKE_GLOW := 0.95
const AWAKE_PARTICLE_RATIO := 1.0
const AWAKE_FOG_INTENSITY := 0.4
const AWAKE_FOG_COLOR := Color(0.357, 0.334, 0.405, 1.0)

## Qué tan rápido _current_t persigue a _target_t — más alto reacciona más
## rápido a un salto repentino de luminancia (invocar, dispersar un Vignette).
const SMOOTHING_SPEED := 2.0

var _target_t := 0.0
var _current_t := 0.0


func _ready() -> void:
	set_process(false)


## Conectar: luminance_manager.luminance_changed.connect(world_awakening.on_luminance_changed)
func on_luminance_changed(current: float, max_value: float) -> void:
	_target_t = clamp(current / max_value, 0.0, 1.0)
	set_process(true)


func _process(delta: float) -> void:
	_current_t = lerp(_current_t, _target_t, 1.0 - exp(-SMOOTHING_SPEED * delta))

	canvas_modulate.color = DARK_MODULATE.lerp(AWAKE_MODULATE, _current_t)

	var env := world_environment.environment
	env.adjustment_brightness = lerp(DARK_BRIGHTNESS, AWAKE_BRIGHTNESS, _current_t)
	env.adjustment_contrast = lerp(DARK_CONTRAST, AWAKE_CONTRAST, _current_t)
	env.adjustment_saturation = lerp(DARK_SATURATION, AWAKE_SATURATION, _current_t)
	env.glow_intensity = lerp(DARK_GLOW, AWAKE_GLOW, _current_t)

	world_particles.amount_ratio = lerp(DARK_PARTICLE_RATIO, AWAKE_PARTICLE_RATIO, _current_t)
	fog_material.set_shader_parameter("fog_intensity", lerp(DARK_FOG_INTENSITY, AWAKE_FOG_INTENSITY, _current_t))
	fog_material.set_shader_parameter("fog_color", DARK_FOG_COLOR.lerp(AWAKE_FOG_COLOR, _current_t))

	## Se apaga solo cuando ya alcanzó el objetivo — no gasta ciclos cuando
	## la luminancia está estable.
	if abs(_current_t - _target_t) < 0.001:
		set_process(false)
