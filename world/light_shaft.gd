extends Node2D
## Feixes de luz sutis que "cortam" a escuridão a partir de uma fonte de luz
## (tocha). Puramente estético: balança devagar e pisca de leve, reforçando
## a sensação de profundidade sem depender de um shader de god-rays de verdade.

@export var sway_speed: float = 0.6
@export var flicker_speed: float = 3.0
@export var base_alpha: float = 0.28

@onready var _beams: Array[Sprite2D] = [$Beam1, $Beam2]

var _base_rotations: Array[float] = []
var _time: float = 0.0

func _ready() -> void:
	for beam in _beams:
		_base_rotations.append(beam.rotation)

func _process(delta: float) -> void:
	_time += delta
	for i in _beams.size():
		var beam := _beams[i]
		var phase := i * 2.4
		beam.rotation = _base_rotations[i] + sin(_time * sway_speed + phase) * 0.05
		var flicker := 0.85 + 0.15 * sin(_time * flicker_speed + phase * 1.7)
		beam.modulate.a = base_alpha * flicker
