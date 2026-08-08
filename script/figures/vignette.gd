extends Node2D
class_name Vignette

## Vignette resuelve el combate, no Bokeh. Cada Vignette, en su propio tick,
## busca los Bokeh dentro de combat_radius, les inflige su poder, y por
## separado suma el poder de esos mismos Bokeh contra sí mismo. Si varios
## Vignette están cerca del mismo Bokeh, el daño se acumula solo porque cada
## uno corre este cálculo por su cuenta -- no hace falta coordinarlos entre
## sí. Figure.gd solo necesita exponer take_damage(amount) y get_power().
##
## Estado básico para pruebas: solo personalidad Static. Nada de Drifting
## todavía -- ni el campo lo sugiere como activo.

@onready var body_mesh: MeshInstance2D = $Body/MeshInstance2D

var global_params: Dictionary

@export var base_material: ShaderMaterial
@export var combat_radius := 350.0  # mismo valor que el aura de purificación de Bokeh
@export var tick_interval := 60.0 / 70.0  # 70bpm

## ⚠️ Multiplicadores de dureza sin confirmar contigo -- primera propuesta.
@export var base_densidad := 30.0
@export var hardness_multipliers := {
	VignetteEnums.Hardness.SOFT: 0.7,
	VignetteEnums.Hardness.NORMAL: 1.0,
	VignetteEnums.Hardness.DENSE: 1.4,
}

@export var power := 1.5  # daño infligido a Bokeh, por tick, dentro de rango
@export var regen_ticks_required := 6
@export var regen_rate := 1.5  # /seg -- menor que el daño recibido, según acordamos
@export var base_mesh_size := 140.0  # ⚠️ orden de magnitud a ojo, ajústalo viéndolo en pantalla

var densidad: float
var max_densidad: float
var hardness: VignetteEnums.Hardness

var _ticks_since_hit := 0
var _tick_timer := 0.0
var _base_scale := Vector2.ONE
var _shader_material: ShaderMaterial
var _dispersed := false


## Solo guarda datos, no toca nodos hijos -- ShadowManager llama esto antes
## de add_child(), igual que Figure.init().
func init(params: Dictionary) -> void:
	global_params = params
	hardness = params.get("hardness", VignetteEnums.Hardness.NORMAL)
	position = params.position
	z_index = 10
	max_densidad = base_densidad * hardness_multipliers.get(hardness, 1.0)
	densidad = max_densidad
	_base_scale = Vector2.ONE * params.get("size", 1.0)


func _ready() -> void:
	add_to_group("vignette")

	body_mesh.mesh = QuadMesh.new()
	body_mesh.mesh.size = Vector2.ONE * base_mesh_size  # ⚠️ tamaño en pixeles, propuesta sin confirmar

	if base_material:
		_shader_material = base_material.duplicate(true)
		body_mesh.material = _shader_material

	scale = Vector2.ZERO
	modulate.a = 0.0
	appear()


func _process(delta: float) -> void:
	if _dispersed:
		return

	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer -= tick_interval
		var hit_this_tick := _resolve_combat_tick()
		if not hit_this_tick:
			_ticks_since_hit += 1

	if _ticks_since_hit >= regen_ticks_required and densidad < max_densidad:
		densidad = min(max_densidad, densidad + regen_rate * delta)
		_update_visual()


## Devuelve true si este Vignette recibió daño en este tick (para que
## _process sepa si debe reiniciar o incrementar el contador de regeneración).
func _resolve_combat_tick() -> bool:
	var nearby_bokeh: Array = []
	for node in get_tree().get_nodes_in_group("bokeh"):
		if is_instance_valid(node) and global_position.distance_to(node.global_position) <= combat_radius:
			nearby_bokeh.append(node)

	if nearby_bokeh.is_empty():
		return false

	var incoming := 0.0
	for bokeh in nearby_bokeh:
		if bokeh.has_method("take_damage"):
			bokeh.take_damage(power)
		if bokeh.has_method("get_power"):
			incoming += bokeh.get_power()

	if incoming > 0.0:
		take_damage(incoming)
		return true
	return false


func take_damage(amount: float) -> void:
	if amount <= 0.0 or _dispersed:
		return
	densidad -= amount
	_ticks_since_hit = 0
	_update_visual()
	if densidad <= 0.0:
		disperse()


func get_power() -> float:
	return power


## Único punto de reacción visual al daño: el uniform damage_ratio del
## shader. Nada de escala ni modulate -- solo color, según acordamos.
func _update_visual() -> void:
	if _shader_material == null:
		return
	var ratio = clamp(densidad / max_densidad, 0.0, 1.0)
	_shader_material.set_shader_parameter("damage_ratio", 1.0 - ratio)


func appear() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.4)


func disperse() -> void:
	_dispersed = true
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
