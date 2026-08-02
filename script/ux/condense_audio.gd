extends Node2D

@onready var audio_player = $"."

var carga : float = 0.0
var maxima_carga : float = 2.2 # Tiempo hasta explotar
var esta_cargando : bool = false
var explotando : bool = false
var pitch : float = 1.0

# Referencia al bus y al efecto
@onready var bus_index = AudioServer.get_bus_index("Condense")
@onready var filter_effect : AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus_index, 0)

@export var audio_success = preload("res://assets/sonidos/condense_success.wav")

func _process(delta):
	if !explotando:
		if esta_cargando:
			carga = min(carga + delta, maxima_carga)
			actualizar_audio_dinamico()
			
		else:
			disipar(delta)

func actualizar_audio_dinamico():
	var progreso = carga / maxima_carga # De 0.0 a 1.0
	
	# 1. Volumen: Sube de -40dB (casi silencio) a 0dB (fuerte)
	audio_player.volume_db = lerp(-10.0, 0.0, progreso)
	
	audio_player.pitch_scale = lerp(pitch, pitch+0.4, carga / maxima_carga)
	
	filter_effect.cutoff_hz = lerp(500.0, 20000.0, progreso)

func disipar(delta):
	if carga > 0:
		carga = max(carga - delta * 2.0, 0.0) # Se disipa el doble de rápido
		actualizar_audio_dinamico()
		if carga <= 0:
			audio_player.stop()

func iniciar_condensado():
	esta_cargando = true
	pitch = randf_range(0.8,1.1)
	audio_player.pitch_scale = pitch 
	audio_player.play()

func soltar_condensado():
	esta_cargando = false
	
func explotar():
	explotando = true
	audio_player.stream = audio_success
	audio_player.pitch = 1.0
	audio_player.volume_db = 0.0
	audio_player.play()
