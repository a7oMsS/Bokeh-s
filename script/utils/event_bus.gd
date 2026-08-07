extends Node
class_name EventBus

# --- Señales globales del juego ---

# Progresión / desbloqueos
@warning_ignore("unused_signal")
signal level_up(level: int, unlock_name: String)
@warning_ignore("unused_signal")
signal item_unlocked(name: String, category: String)

# Estadísticas / puntuación
@warning_ignore("unused_signal")
signal score_changed(delta: float, total: float)
@warning_ignore("unused_signal")
signal stats_changed(stats: Dictionary)

# Figuras
@warning_ignore("unused_signal")
signal figure_spawned(fig: Node)

# Eventos de ritmo o timing
@warning_ignore("unused_signal")
signal timing_hit(kind: String) 
