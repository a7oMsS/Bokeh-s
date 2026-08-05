extends Node

# ======== Control de figuras ========

@onready var FiguraESN = preload("res://escenas/obj/Figura.tscn")

var figuras_vivas: Array = []
var limite_figuras = 60
signal figure_spawned(fig: Node)


# ======== Listas completas ========
var todas_formas = ["circulo","cuadrado","triangulo","estrella5","estrella4","hexagono","rombo","corazon"]
var todos_estilos = ["solido","gradiente","outline","outline_gradiente"]
var todos_tamanos = ["Pequeños","Medianos","Grandes"]
var todas_personalidades = ["estatico","rebote","parpadeo","vibracion","cambioColor"]

# ======== Listas desbloqueadas (inicialmente básicas) ========
var formas = ["circulo"]
var estilos = ["solido"]          
var tamanos = ["Grandes"]
var personalidades = ["rebote"]

# ======== Bonus por calidad del gesto (spin_ratio, 0-1) ========
const QUALITY_SIZE_BONUS_MAX := 0.35     # hasta +35% de tamaño con gesto perfecto
const QUALITY_BRIGHTEN_MAX := 0.25       # hasta +25% de luminosidad de color

# ======== Profundidad dinámica ========
# Toda figura nace enfocada (Mid) y luego deriva hacia Near o Far.
const DEPTH_FOCUS_CHANCE_MIN := 0.33     # sin giro: 33% quedarse enfocada, 33/33 Near/Far
const DEPTH_FOCUS_CHANCE_MAX := 0.66     # con giro: 66%
const DEPTH_HOLD_MIN := 1.5              # segundos mínimos enfocada antes de derivar
const DEPTH_HOLD_MAX := 4.0              # segundos máximos (más con mejor quality)
const DEPTH_DRIFT_MIN := 3.0             # duración mínima de la transición Mid → target
const DEPTH_DRIFT_MAX := 6.0             # duración máxima


# ---------------- Métodos de desbloqueo ----------------
func enable_forma(nombre: String) -> void:
	if todas_formas.has(nombre) and not formas.has(nombre):
		formas.append(nombre)

func enable_style(nombre: String) -> void:
	if todos_estilos.has(nombre) and not estilos.has(nombre):
		estilos.append(nombre)

func enable_personality(nombre: String) -> void:
	if todas_personalidades.has(nombre) and not personalidades.has(nombre):
		personalidades.append(nombre)

func enable_size(nombre: String) -> void:
	if todos_tamanos.has(nombre) and not tamanos.has(nombre):
		tamanos.append(nombre)

# ---------------- Getters (usan lo desbloqueado) ----------------
func get_forma_aleatoria() -> String:
	return formas[randi() % formas.size()]

func get_estilo_aleatoria() -> String:
	return estilos[randi() % estilos.size()]

func get_personalidad_aleatoria() -> String:
	return personalidades[randi() % personalidades.size()]

func get_figuras_disponibles() -> Array:
	return formas

func get_estilos_disponibles() -> Array:
	return estilos

func get_tamanos_disponibles() -> Array:
	return tamanos

func get_personalidades_disp() -> Array:
	return personalidades

func get_color_aleatorio() -> Color:
	# Armonía triádica real: 3 hues a 120° exactos entre sí.
	# 60° = amarillo/dorado, 180° = cian puro, 300° = magenta puro
	# (son los 3 colores secundarios del círculo HSV — de ahí que caigan
	# perfectamente equidistantes sin necesidad de calcular complementos).
	var hue_dorado := 60.0 / 360.0
	var hue_cian := 180.0 / 360.0
	var hue_magenta := 300.0 / 360.0

	var roll = randf()
	var hue: float
	if roll < 0.6:
		hue = hue_dorado      # 60%
	elif roll < 0.9:
		hue = hue_cian        # 30%
	else:
		hue = hue_magenta     # 10%

	var saturation = randf_range(0.5, 0.9)
	var value = randf_range(0.5, 1.0)

	return Color.from_hsv(hue, saturation, value)

func get_color_similar(base_color: Color) -> Color:
	var h = base_color.h
	var s = base_color.s
	var v = base_color.v
	h = wrapf(h + randf_range(-0.1, 0.1), 0, 2.0)
	s = clamp(s + randf_range(-0.1, 0.1), 0.05, 2.0)
	v = clamp(v + randf_range(-0.4, 0.4), 0.05, 1.2)
	return Color.from_hsv(h, s, v, base_color.a)

func get_tamano_aleatorio():
	var probability = randi_range(0,99)
	if probability < 10:
		return get_tamano_por_categoria("Grandes")
	elif probability < 65:
		return get_tamano_por_categoria("Medianos")
	else:
		return get_tamano_por_categoria("Pequeños")
	

func get_tamano_maximo():
	var pantalla = 	DisplayServer.window_get_size()
	var referencia = min(pantalla.x, pantalla.y)
	return referencia * 0.35

func get_tamano_por_categoria(categoria: String) -> float:
	var pantalla = 	DisplayServer.window_get_size()
	var referencia = min(pantalla.x, pantalla.y)

	match categoria:
		"Pequeños":
			return randf_range(referencia * 0.075, referencia * 0.10)
		"Medianos":
			return randf_range(referencia * 0.14, referencia * 0.18)
		"Grandes":
			return randf_range(referencia * 0.25, referencia * 0.35)
		_:
			return get_tamano_aleatorio()

# ---------------- Profundidad dinámica ----------------

# Decide hacia dónde va a derivar la figura una vez pase su tiempo enfocada.
# Mayor quality → más probable que se acerque (Near, protagonismo).
# Menor quality → más probable que se pierda en el fondo (Far).
func get_depth_target(quality: float) -> String:
	var focus_chance = lerp(DEPTH_FOCUS_CHANCE_MIN, DEPTH_FOCUS_CHANCE_MAX, quality)
	if randf() < focus_chance:
		return "Mid"
	return "Near" if randf() < 0.5 else "Far"


func generar_parametros(config: Dictionary, quality: float = 0.0) -> Dictionary:
	var forma = config.forma
	if forma == "aleatorio":
		forma = get_forma_aleatoria()

	var estilo = config.estilo
	if estilo == "aleatorio":
		estilo = get_estilo_aleatoria()

	var tamano = config.tamano
	if tamano == "aleatorio":
		tamano = get_tamano_aleatorio()
	else:
		tamano = get_tamano_por_categoria(config.tamano)

	# Bono de tamaño por calidad del gesto (no cambia de categoría, solo escala dentro de ella)
	tamano *= 1.0 + (quality * QUALITY_SIZE_BONUS_MAX)
	
	var personalidad = config.personalidad
	if personalidad == "aleatorio":
		personalidad = get_personalidad_aleatoria()

	var color_a = config.color_a
	var color_b = config.color_b

	if config.usar_paleta:
		if config.color_b_relacionado:
			color_b = get_color_similar(color_a)
			color_a = get_color_similar(color_a)
		else:
			color_a = get_color_similar(color_a)
			color_b = get_color_aleatorio()
	else:
		if config.color_b_relacionado:
			color_a = get_color_aleatorio()
			color_b = get_color_similar(color_a)
		else:
			color_a = get_color_aleatorio()
			color_b = get_color_aleatorio()

	# Bono de brillo por calidad del gesto
	color_a = color_a.lightened(quality * QUALITY_BRIGHTEN_MAX)
	color_b = color_b.lightened(quality * QUALITY_BRIGHTEN_MAX)

	# Profundidad: siempre nace enfocada, deriva según la calidad del gesto
	var depth_target = get_depth_target(quality)
	var depth_hold = lerp(DEPTH_HOLD_MIN, DEPTH_HOLD_MAX, quality)
	var depth_drift_duration = randf_range(DEPTH_DRIFT_MIN, DEPTH_DRIFT_MAX)

	return {
		"forma": forma,
		"estilo": estilo,
		"color_a": color_a,
		"color_b": color_b,
		"tamano": tamano,
		"personalidad": personalidad,
		"tamanoMaximo": get_tamano_maximo(),
		"depth": "Mid",
		"depth_target": depth_target,
		"depth_hold": depth_hold,
		"depth_drift_duration": depth_drift_duration,
		"quality": quality,
		"posicion": config.posicion
	}
	

var figuresContainer

func _ready():
	figuresContainer = $"../../ClicArea/FiguresLayer"

func on_invoke(type: String, data: Dictionary):
	match type:
		"condense":
			spawn_random(data.position, data.get("quality", 0.0))

func spawn_random(position: Vector2, quality: float = 0.0) -> Node:
	if figuras_vivas.size() >= limite_figuras:
		return null

	var fig = FiguraESN.instantiate()
	var params = generar_parametros(Utils.defaultConfig(position), quality)
	
	fig.init(params)
	figuresContainer.add_child(fig)
	figuras_vivas.append(fig)
	
	emit_signal("figure_spawned", fig)
	EventBusAuto.emit_signal("figure_spawned", fig)
	return fig
