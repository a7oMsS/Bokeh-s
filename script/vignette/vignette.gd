extends Node2D
class_name Vignette

## Vignette resolves combat, not Bokeh. Each Vignette, on its own tick,
## looks for Bokeh within combat_radius, deals its power to them, and
## separately adds up those same Bokeh's power against itself. If several
## Vignette are near the same Bokeh, damage stacks simply because each one
## runs this calculation independently — no need to coordinate between
## them. Figure.gd only needs to expose take_damage(amount) and get_power().
##
## Basic state for testing: Static personality only. No Drifting yet —
## nothing in this file suggests it's active either.

@onready var body_mesh: MeshInstance2D = $Body/MeshInstance2D

var global_params: Dictionary

@export var elite_density := 110.0
@export var elite_power_multiplier := 2.5   # same factor already used for the Elite's passive drain
@export var elite_scale_mult := 2.0          # ⚠️ proposed, to make it read as noticeably bigger
@export var elite_color: Color = Color(0.222, 0.174, 0.294, 1.0)
@export var elite_color_bleed: Color = Color(0.092, 0.885, 0.885, 1.0)

@export var seek_speed := 40.0            # ⚠️ proposed, unconfirmed
@export var seek_stop_distance := 60.0    # stops closing in once within combat range

var _seek_target: Node = null

var is_elite: bool = false

const DEPTH_VISUALS := {
	FigureEnums.Depth.NEAR: {"scale_mult": 1.5, "alpha": 0.85, "z_index_range": Vector2i(17, 24), "edge_softness_mult": 2.2},
	FigureEnums.Depth.MID:  {"scale_mult": 1.0, "alpha": 1.0, "z_index_range": Vector2i(9, 16), "edge_softness_mult": 1.0},
	FigureEnums.Depth.FAR:  {"scale_mult": 0.6, "alpha": 0.7,  "z_index_range": Vector2i(1, 8),  "edge_softness_mult": 1.8},
}

@export var base_edge_softness := 0.12  # the shader's own previous default

var _depth: FigureEnums.Depth

@export var base_material: ShaderMaterial
@export var combat_radius := 300.0  # same value as Bokeh's own purification aura
@export var tick_interval := 60.0 / 48.0  # 70bpm

## ⚠️ Hardness multipliers unconfirmed — first proposal.
@export var base_density := 30.0
@export var hardness_multipliers := {
	VignetteEnums.Hardness.SOFT: 0.7,
	VignetteEnums.Hardness.NORMAL: 1.0,
	VignetteEnums.Hardness.DENSE: 1.4,
}

@export var base_power := 1.5
var power: float
@export var regen_ticks_required := 6
@export var regen_rate := 1.5  # /sec — lower than incoming damage, as agreed
@export var base_mesh_size := 180.0  # ⚠️ order of magnitude eyeballed, tune it on screen

var density: float
var max_density: float
var noise_seed: int
var hardness: VignetteEnums.Hardness

var _ticks_since_hit := 0
var _tick_timer := 0.0
var _base_scale := Vector2.ONE
var _shader_material: ShaderMaterial
var _dispersed := false


## Only stores data, doesn't touch child nodes -- ShadowManager calls this
## before add_child(), same as Figure.init().
func init(params: Dictionary) -> void:
	global_params = params
	hardness = params.get("hardness", VignetteEnums.Hardness.NORMAL)
	is_elite = params.get("is_elite", false)
	position = params.position

	if is_elite:
		max_density = elite_density
		power = base_power * elite_power_multiplier
	else:
		max_density = base_density * hardness_multipliers.get(hardness, 1.0)
		power = base_power

	density = max_density
	_base_scale = Vector2.ONE * params.get("size", 1.0) * (elite_scale_mult if is_elite else 1.0)
	noise_seed = params.get("noise_seed", 1.0)
	_depth = params.get("depth", FigureEnums.Depth.MID)


func _ready() -> void:
	add_to_group("vignette")

	body_mesh.mesh = QuadMesh.new()
	body_mesh.mesh.size = Vector2.ONE * base_mesh_size  # ⚠️ size in pixels, proposed, unconfirmed

	var dv: Dictionary = DEPTH_VISUALS[_depth]
	z_index = randi_range(dv.z_index_range.x, dv.z_index_range.y)
	scale = _base_scale * dv.scale_mult  # once only, doesn't drift over time

	if base_material:
		_shader_material = base_material.duplicate(true)
		body_mesh.material = _shader_material
		_shader_material.set_shader_parameter("edge_softness", base_edge_softness * dv.edge_softness_mult)

		if is_elite:
			_shader_material.set_shader_parameter("color_dark", elite_color)
			_shader_material.set_shader_parameter("color_bleed", elite_color_bleed)
	else:
		push_warning("material not found: %s" % base_material)
		return

	var noise_tex = _shader_material.get_shader_parameter("noise_tex")
	if noise_tex is NoiseTexture2D:
		if noise_tex.noise:
			noise_tex.noise.seed = noise_seed

	scale = Vector2.ZERO
	modulate.a = 0.0
	appear()


func _process(delta: float) -> void:
	if _dispersed:
		return

	if _seek_target != null:
		if not is_instance_valid(_seek_target):
			_seek_target = null  # target died -- the Vignette "won", goes back to idle
		else:
			var to_target = _seek_target.global_position - global_position
			if to_target.length() > seek_stop_distance:
				position += to_target.normalized() * seek_speed * delta

	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer -= tick_interval
		var hit_this_tick := _resolve_combat_tick()
		if not hit_this_tick:
			_ticks_since_hit += 1

	if _ticks_since_hit >= regen_ticks_required and density < max_density:
		density = min(max_density, density + regen_rate * delta)
		_update_visual()


## Returns true if this Vignette took damage this tick (so _process knows
## whether to reset or increment the regen counter).
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
		if _seek_target == null:
			_seek_target = _pick_closest(nearby_bokeh)
		return true
	return false


func _pick_closest(candidates: Array) -> Node:
	var closest: Node = null
	var closest_dist := INF
	for b in candidates:
		var d = global_position.distance_to(b.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = b
	return closest


func take_damage(amount: float) -> void:
	if amount <= 0.0 or _dispersed:
		return
	density -= amount
	_ticks_since_hit = 0
	_update_visual()
	if density <= 0.0:
		disperse()


func get_power() -> float:
	return power


## Only point of visual reaction to damage: the shader's damage_ratio
## uniform. No scale or modulate change -- color only, as agreed.
func _update_visual() -> void:
	if _shader_material == null:
		return
	var ratio = clamp(density / max_density, 0.0, 1.0)
	_shader_material.set_shader_parameter("damage_ratio", 1.0 - ratio)


func appear() -> void:
	var dv: Dictionary = DEPTH_VISUALS[_depth]

	if is_elite:
		dv = DEPTH_VISUALS[FigureEnums.Depth.MID]
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * dv.scale_mult, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", dv.alpha, 0.4)


func disperse() -> void:
	_dispersed = true
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
