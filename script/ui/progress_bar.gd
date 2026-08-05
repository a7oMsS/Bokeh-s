extends Control
class_name LuminanceBar

@onready var label: Label = $"../Label"
@onready var particles: GPUParticles2D = $GPUParticles2D

# Colores de la barra
var start_color := Color(0.703, 0.74, 0.0, 1.0)      # amarillo cálido
var end_color   := Color(0.0, 0.505, 0.463, 1.0)     # blanco-azulado (cerca del umbral)
# Colores de la barra
var start_color_glow := Color(0.95, 0.855, 0.0, 0.298)      # amarillo cálido
var end_color_glow   := Color(0.047, 0.553, 0.94, 0.38)     # blanco-azulado (cerca del umbral)

var tween: Tween

func _ready():
	# Configuración inicial
	self.max_value = 100.0
	get_window().size_changed.connect(_on_window_resize)
	
	_on_window_resize()
	particles.amount_ratio = 0
	
func _on_window_resize():
	particles.process_material.emission_box_extents = Vector3(self.size.x/5*3, self.size.y*1.7,1.0)
	particles.position = Vector2(self.size.x/2, self.size.y/4)

func update_luminance(current: float, max_val: float):
	
	self.max_value = max_val
	self.value = current
	
	# Evolución de color
	var t = clamp(current / max_val, 0.0, 1.0)
	var fill_color = start_color.lerp(end_color, t)
	var glow_color = start_color_glow.lerp(end_color_glow, t)
	
	var style = self.get_theme_stylebox("fill") as StyleBoxFlat
	style.bg_color = fill_color
	style.shadow_color = glow_color
		
	# Cantidad de partículas según el llenado
	var target_ratio = lerp(0.15, 1.0, t)          # mínimo 15% → máximo 100%
	particles.amount_ratio = target_ratio

	# Posición de emisión (teniendo en cuenta el skew de la barra)
	var skew_offset_x = self.size.x * t * 0.05      # compensación por skew.x = 0.2
	var skew_offset_y = self.size.y * t * 0.2     # compensación por skew.y = 0.05

	particles.position = Vector2(
		self.size.x * t*0.5 + skew_offset_x,
		self.size.y * 0.5 - skew_offset_y
	)

	# Extensión del rectángulo de emisión (más ancho cuando está más lleno)
	particles.process_material.emission_box_extents = Vector3(
		self.size.x * t * 0.5, 
		self.size.y * 0.5,
		1.0
	)

	# Color dinámico (más blanco-azulado cerca del final)
	particles.modulate = fill_color*2

	# Pequeño burst extra cuando está muy lleno
	if t > 0.85:
		particles.amount_ratio = int(target_ratio * 1.6)
	

# ====================== ANIMACIÓN DE CONDENSACIÓN ======================
func trigger_condensation_reset(level: int):
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# 2. Barra baja con overshoo
	tween.tween_property(self, "value", 0.0, 0.48) \
		 .set_trans(Tween.TRANS_BACK) \
		 .set_ease(Tween.EASE_OUT)
	
	# 3. Pequeño pop de escala
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1) \
		 .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35) \
		 .set_delay(0.1)
	
	# 4. Flash final de brillo
	tween.tween_property(self, "modulate", Color(1.8, 1.8, 2.0), 0.08)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.4) \
		 .set_delay(0.1)
