extends Node2D

@onready var pop_particles = $PopParticles
@onready var anim_player = $AnimationPlayer
@onready var point_light
var paramsGlobal

@export var lifetime: float = 40.0
@export var lifetime_enabled: bool = true
@onready var lifetime_timer: Timer = $LifetimeTimer

@export var materiales_base := {
	"solido": preload("res://figuras/shaders/SDFSolidMaterial.tres"),
	"gradiente": preload("res://figuras/shaders/SDFGradientMaterial.tres"),
	"outline": preload("res://figuras/shaders/SDFOutlineMaterial.tres"),
	"outline_gradiente": preload("res://figuras/shaders/SDFOutline_GradientMaterial.tres")
}

@export var personalidades_figuras := {
	"estatico": preload("res://script/figuras/personalities/personalidadSetUp.gd"),
	"rebote": preload("res://script/figuras/personalities/rebote.gd"),
	"parpadeo": preload("res://script/figuras/personalities/parpadeo.gd"),
	"vibracion": preload("res://script/figuras/personalities/vibracion.gd"),
	"cambioColor": preload("res://script/figuras/personalities/cambioColor.gd")
}

@onready var body_mesh: MeshInstance2D

var body_material : ShaderMaterial
var shader_material : ShaderMaterial
var personality: FiguraPersonality

# ======== Profundidad dinámica ========
# El desenfoque es simétrico: tan borroso al acercarse (Near) como al
# perderse de vista (Far). Solo Mid está nítido.
const DEPTH_VISUALS := {
	"Near": {"smoothness": 0.3,  "alpha": 1.0,  "scale_mult": 2.0, "z_index": 20, "energy_mult": 0.3, "mesh_mult": 1.6},
	"Mid":  {"smoothness": 0.02, "alpha": 0.75, "scale_mult": 1.0, "z_index": 10, "energy_mult": 1.1, "mesh_mult": 1.0},
	"Far":  {"smoothness": 0.3,  "alpha": 0.32, "scale_mult": 0.5, "z_index": 1,  "energy_mult": 0.6, "mesh_mult": 0.7},
}

var _padding := 1.65
var _base_color_a: Color
var _base_color_b: Color
var _tamano: float
var _tamano_maximo: float

# Estado de la deriva de profundidad
var _depth_target := "Mid"
var _depth_hold := 2.0
var _depth_drift_duration := 4.0
var _depth_timer := 0.0
var _has_drifted := false


func _ready():
	body_mesh = $Body/MeshInstance2D
	if not body_mesh:
		push_error("MeshInstance2D no encontrado")

	pop_particles.set("initial_color", Color(1.0, 1.0, 1.0, 1.0))
	pop_particles.modulate = Color(2.0, 2.0, 2.0, 1.0)

	aparecer()

	if lifetime > 0:
		lifetime_timer.start(lifetime)

	lifetime_timer.timeout.connect(_on_LifetimeTimer_timeout)


func _on_LifetimeTimer_timeout():
	if lifetime_enabled:
		desaparecer()


func disable_lifetime():
	lifetime_enabled = false
	lifetime_timer.stop()


func init(params: Dictionary) -> void:
	if not body_mesh:
		body_mesh = $Body/MeshInstance2D
		if not body_mesh:
			push_error("❌ No se encontró MeshInstance2D")
			return

	paramsGlobal = params

	# 2) Asignar shader según estilo
	var estilo = params.estilo
	if materiales_base.has(estilo):
		shader_material = materiales_base[estilo].duplicate(true)
		body_mesh.material = shader_material
	else:
		push_warning("Estilo desconocido: %s" % estilo)

	# 3) Forma
	var forma_index = 0
	match params.forma:
		"circulo": forma_index = 0
		"cuadrado": forma_index = 1
		"triangulo": forma_index = 2
		"estrella5": forma_index = 3
		"estrella4": forma_index = 4
		"hexagono": forma_index = 5
		"rombo": forma_index = 6
		"corazon": forma_index = 7
		_: forma_index = 0
	shader_material.set_shader_parameter("forma", forma_index)

	point_light = $PointLight2D

	# --- Datos base para poder recalcular en cualquier momento de la deriva ---
	_base_color_a = params.color_a
	_base_color_b = params.color_b
	_tamano = params.tamano
	_tamano_maximo = params.tamanoMaximo

	_depth_target = params.get("depth_target", "Mid")
	_depth_hold = params.get("depth_hold", 2.0)
	_depth_drift_duration = params.get("depth_drift_duration", 4.0)
	_depth_timer = 0.0
	_has_drifted = false

	# Mesh base — se crea antes de aplicar visuales de profundidad,
	# que necesitan poder escribir su tamaño.
	var qm = QuadMesh.new()
	body_mesh.mesh = qm
	shader_material.set_shader_parameter("padding", _padding)
	shader_material.set_shader_parameter("size", (_tamano / _tamano_maximo))

	# Aplica de una vez el estado de nacimiento (normalmente "Mid")
	_apply_depth_visuals(params.get("depth", "Mid"), 0.0)

	# 6) Posición
	position = params.posicion

	# 7) personalidad
	var personalidad = params.personalidad
	if personalidades_figuras.has(personalidad):
		set_personality(personalidades_figuras[personalidad])
	else:
		push_warning("Personalidad desconocida: %s" % personalidad)


# Aplica los valores visuales de un nivel de profundidad.
# duration = 0.0  → instantáneo (usado al nacer)
# duration > 0.0  → anima hacia ese estado (usado al derivar)
func _apply_depth_visuals(depth_name: String, duration: float) -> void:
	var v: Dictionary = DEPTH_VISUALS[depth_name]

	var normalized_size = _tamano / _tamano_maximo
	var energy = lerp(0.6, 0.8, normalized_size) * v.energy_mult

	var target_color_a = _base_color_a * energy
	var target_color_b = _base_color_b * energy
	var target_scale = Vector2.ONE * v.scale_mult
	var target_mesh_size = Vector2.ONE * (_tamano * _padding * v.mesh_mult)

	# El z_index es de por sí un salto discreto (orden de dibujo), no algo
	# que se pueda animar con naturalidad — se aplica al iniciar la deriva.
	self.z_index = v.z_index

	if duration <= 0.0:
		self.scale = target_scale
		self.modulate.a = v.alpha
		shader_material.set_shader_parameter("smoothness", v.smoothness)
		shader_material.set_shader_parameter("color_a", target_color_a)
		shader_material.set_shader_parameter("color_b", target_color_b)
		if point_light:
			point_light.color = target_color_a
		if body_mesh.mesh:
			body_mesh.mesh.size = target_mesh_size
		return

	var start_smoothness = shader_material.get_shader_parameter("smoothness")
	var start_color_a = shader_material.get_shader_parameter("color_a")
	var start_color_b = shader_material.get_shader_parameter("color_b")
	var start_light_color = point_light.color if point_light else Color.WHITE
	var start_mesh_size = body_mesh.mesh.size if body_mesh.mesh else target_mesh_size

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", v.alpha, duration) \
		.set_trans(Tween.TRANS_SINE)

	# Shader, luz y mesh no son propiedades simples del nodo, así que las
	# interpolamos a mano con un solo método — más robusto que confiar en
	# que el path "shader_parameter/x" sea tweenable directamente.
	tween.tween_method(func(t: float):
		shader_material.set_shader_parameter("smoothness", lerp(start_smoothness, v.smoothness, t))
		shader_material.set_shader_parameter("color_a", start_color_a.lerp(target_color_a, t))
		shader_material.set_shader_parameter("color_b", start_color_b.lerp(target_color_b, t))
		if point_light:
			point_light.color = start_light_color.lerp(target_color_a, t)
		if body_mesh.mesh:
			body_mesh.mesh.size = start_mesh_size.lerp(target_mesh_size, t)
	, 0.0, 1.0, duration)


func _process(delta):
	if personality:
		personality._process(delta)

	if not _has_drifted:
		_depth_timer += delta
		if _depth_timer >= _depth_hold:
			_has_drifted = true
			if _depth_target == "Mid":
				# Gesto exitoso: se queda enfocada. Un pequeño pulso confirma
				# que "quedó anclada" en vez de que sea indistinguible de
				# una figura que aún no decidió su destino.
				_play_settle_pulse()
			else:
				_apply_depth_visuals(_depth_target, _depth_drift_duration)


func _play_settle_pulse() -> void:
	var base_scale = self.scale
	var base_light_energy = point_light.energy if point_light else 0.0

	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", base_scale * 1.1, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", base_scale, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if point_light:
		var light_tween = create_tween()
		light_tween.tween_property(point_light, "energy", base_light_energy * 1.7, 0.16)
		light_tween.tween_property(point_light, "energy", base_light_energy, 0.3)


func aparecer():
	self.scale = Vector2(0, 0)
	self.modulate.a = 0.0
	self.rotation = -PI / 2

	# Antes se animaba hacia valores fijos (1,1 / 1.0) sin importar la
	# profundidad de nacimiento. Ahora respeta el estado real de Mid.
	var mid_visuals: Dictionary = DEPTH_VISUALS["Mid"]
	var target_scale = Vector2.ONE * mid_visuals.scale_mult
	var target_alpha = mid_visuals.alpha

	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", target_alpha, 0.1)
	tween.parallel().tween_property(self, "rotation",  self.rotation + PI / 2, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await get_tree().create_timer(0.05).timeout

	pop_particles.modulate = Color(paramsGlobal.color_a.r, paramsGlobal.color_a.g, paramsGlobal.color_a.b, 0.6)
	pop_particles.scale_amount_min = paramsGlobal.tamano/paramsGlobal.tamanoMaximo
	var scale_factor = remap(paramsGlobal.tamano, 50.0, 120.0, 0.5, 1.0)
	pop_particles.scale = Vector2(scale_factor, scale_factor)
	pop_particles.restart()
	pop_particles.emitting = true


func set_personality(script: Script):
	if personality:
		personality.queue_free()
	personality = script.new()
	add_child(personality)
	personality.setup(self)


func desaparecer():
	if personality:
		personality.queue_free()

	$Line2D.set_process(true)

	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(0, get_viewport_rect().size.y), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), 0.5)
	tween.tween_callback(Callable(self, "queue_free"))


func desaparecer_rapido():
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(0.0, 0.0), 0.6)
	tween.tween_callback(Callable(self, "queue_free")).set_delay(0.6)
