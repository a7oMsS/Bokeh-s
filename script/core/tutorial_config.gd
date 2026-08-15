extends Resource
class_name WorldConfig

@export var world_id: String = "world_1"

@export_group("Luminancia")
@export var energia_total: float = 1500.0

@export_group("Sombra")
@export var vignette_limit: int = 16
@export var spawn_interval: float = 4.0
@export var initial_count: int = 8
