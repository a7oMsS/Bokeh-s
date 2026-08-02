extends Node

# ======== Control de figuras ========

@onready var FiguraESN = preload("res://escenas/obj/Figura.tscn")

var figuras_vivas: Array = []
var limite_figuras = 40
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
var personalidades = ["parpadeo","vibracion"]

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
	var base_hue := 45.0 / 360.0 
	var split_ofset := 25.0 / 360.0
	var comp_hue = fmod((base_hue + 0.5), 1.0)
	var split_a = fmod((comp_hue - split_ofset + 1.0), 1.0)
	var split_b = fmod((comp_hue + split_ofset), 1.0)
	
	var roll = randf()
	var hue: float
	
	if roll < 0.7:
		hue = base_hue
	elif  roll < 0.85:
		hue = split_a
	else:
		hue = split_b
		
	var saturation = randf_range(0.6, 0.85)
	var value = randf_range(0.6, 1.0)
	
	return Color.from_hsv(hue, saturation, value)

func get_color_similar(base_color: Color) -> Color:
	var h = base_color.h
	var s = base_color.s
	var v = base_color.v
	# Pequeñas variaciones aleatorias
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
			
func get_random_depth():
	var depth := randf()
	
	if depth < 0.33:
		return "Near"
	elif depth < 0.66:
		return "Mid"
	else:
		return "Far"

func generar_parametros(config: Dictionary) -> Dictionary:
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
	
	var personalidad = config.personalidad
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
			
	return {
		"forma": forma,
		"estilo": estilo,
		"color_a": color_a,
		"color_b": color_b,
		"tamano": tamano,
		"personalidad": personalidad,
		"tamanoMaximo": get_tamano_maximo(),
		"depth": get_random_depth(),
		"posicion": config.posicion
	}
	

var figuresContainer

func _ready():
	figuresContainer = $"../../ClicArea/FiguresLayer"

func on_invoke(type: String, data: Dictionary):
	match type:
		"condense":
			spawn_random(data.position)

func spawn_random(position) -> Node:
	# Limita figuras en pantalla
	if figuras_vivas.size() < limite_figuras:
		var fig = FiguraESN.instantiate()
		var params = generar_parametros(Utils.defaultConfig(position))
		
		fig.init(params)
		
		figuresContainer.add_child(fig)
			
		figuras_vivas.append(fig)
		
		emit_signal("figure_spawned", fig)
		EventBusAuto.emit_signal("figure_spawned", fig)
		return
	else:
		return
	

		
