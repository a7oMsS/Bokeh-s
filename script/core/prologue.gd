extends Control
class_name Prologue

@onready var practice_world = $PracticeWorld
@onready var ljossteinn_dialogue: Control = $LjossteinnDialogue  # reservado, sin contenido — Onboarding decide qué dice y cuándo

# TODO (Onboarding): secuencia de diálogo, cuándo termina el prólogo,
# y cómo queda marcado que ya se completó (para que StartScreen no vuelva
# a mandar acá en la próxima partida).

func _ready() -> void:
	pass
