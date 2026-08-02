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

func _ready():
	body_mesh = $Body/MeshInstance2D
	if not body_mesh:
		push_error("MeshInstance2D no encontrado")
	
	# Ajustar el color inicial y modulate de las partículas para que brillen
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
		"circulo":
			forma_index = 0
		"cuadrado":
			forma_index = 1
		"triangulo":
			forma_index = 2
		"estrella5":
			forma_index = 3
		"estrella4":
			forma_index = 4
		"hexagono":
			forma_index = 5
		"rombo":
			forma_index = 6
		"corazon":
			forma_index = 7
		_:
			forma_index = 0

	shader_material.set_shader_parameter("forma", forma_index)
	
	var depth_value = 0.0 # 0 = Lejos, 0.5 = Medio (Foco), 1 = Cerca
	match params.depth:
		"Far": depth_value = 0.0
		"Mid": depth_value = 0.5
		"Near": depth_value = 1.0

	# Calculamos la "distancia al foco" (0 = en foco, 0.5 = máximo desenfoque)
	var focus_dist = abs(depth_value - 0.5)
	# --- Ajuste de Suavizado (Smoothstep) ---
	# En foco: 0.02 (nítido). En los extremos: 0.45 (borroso)
	var smoothness = lerp(0.02, 0.3, focus_dist * 2.0)
	shader_material.set_shader_parameter("smoothness", smoothness)	
	# --- Ajuste de Opacidad ---
	# Queremos que las figuras en foco sean más sólidas
	self.modulate.a = lerp(0.8, 0.3, focus_dist * 2.0)
	
	# === BRILLO SEGÚN TAMAÑO ===
	var normalized_size = params.tamano / params.tamanoMaximo;
	var energy = lerp(0.6, 0.8, normalized_size);
	
	if params.depth == "Near":
		energy *= 0.3
		self.modulate.a = 1.0          # ← más ghosting (más transparente)
		self.scale *= 2.0         # ← más grande pero más etéreo
		self.z_index = 20
	elif params.depth == "Mid":
		energy *= 1.1
		self.modulate.a = 0.75
		self.z_index = 10
	else: # Far
		energy *= 0.6
		self.modulate.a = 0.32         # más oscuro y pequeño
		self.scale *= 0.5

	shader_material.set_shader_parameter("color_a", params.color_a * energy)
	shader_material.set_shader_parameter("color_b", params.color_b * energy)
	shader_material.set_shader_parameter("smoothness", smoothness)
	
	point_light = $PointLight2D
	point_light.color = params.color_a * energy
	
	# 5) Tamaño con margen extra para el glow
	var padding = 1.65   # ← prueba entre 1.5 y 1.8 (1.65 suele ser ideal)

	var qm = QuadMesh.new()
	qm.size = Vector2(params.tamano * padding, params.tamano * padding)
	body_mesh.mesh = qm
	
	if params.depth == "Near":   # ← más ghosting (más transparente)
		qm.size*=1.6  
	elif params.depth == "Mid":
		qm.size*=1.0  
	else: # Far    # más oscuro y pequeño
		qm.size*=0.7  

	# Guardamos el padding para usarlo en el shader
	shader_material.set_shader_parameter("padding", padding)
	shader_material.set_shader_parameter("size", (params.tamano/params.tamanoMaximo))

	# 6) Posición
	position = params.posicion
	
		# 7) personalidad
	var personalidad = params.personalidad
	if personalidades_figuras.has(personalidad):
		set_personality(personalidades_figuras[personalidad])
	else:
		push_warning("Personalidad desconocida: %s" % personalidad)

func aparecer():
	self.scale = Vector2(0, 0)
	self.modulate.a = 0.0
	self.rotation = -PI / 2
	
	var tween = create_tween()
   # Animar la escala
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Animar la opacidad
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(self, "rotation",  self.rotation + PI / 2, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Primera rotación: de 0 a 90 grados (PI/2) en 0.4 segundos
	
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

func _process(delta):
	if personality:
		personality._process(delta)
	
func desaparecer():
	personality.queue_free()
	
	$Line2D.set_process(true)
	
	var tween = create_tween()

	# Animación de caída
	tween.tween_property(self, "position", position + Vector2(0, get_viewport_rect().size.y), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Desvanecimiento
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)

	# Escala disminuye
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), 0.5)

	# Al terminar, eliminar figura
	tween.tween_callback(Callable(self, "queue_free"))

func desaparecer_rapido():
	var tween = create_tween()
	
	 # Escala disminuye
	tween.parallel().tween_property(self, "scale", Vector2(0.0, 0.0), 0.6)
	
	tween.tween_callback(Callable(self, "queue_free")).set_delay(0.6)
