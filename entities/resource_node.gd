extends StaticBody2D
## Nó de recurso colhível. Recebe golpes via hit() (mesma interface do Enemy)
## e soma ao contador global em GameState até esgotar.

@export var resource_id: String = "comida"
@export var hits_to_deplete: int = 3
@export var amount_per_hit: int = 1

const MINE_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/mine_000.ogg"),
	preload("res://assets/audio/sfx/mine_001.ogg"),
	preload("res://assets/audio/sfx/mine_002.ogg"),
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_player: AudioStreamPlayer2D = $SfxPlayer

var _hits_remaining: int
var _flash_tween: Tween

func _ready() -> void:
	_hits_remaining = hits_to_deplete

func hit(_amount: float) -> void:
	_hits_remaining -= 1
	GameState.add_resource(resource_id, amount_per_hit)
	if _hits_remaining <= 0:
		_deplete()
		return
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = Color(1, 1, 1) * 2.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	_play_random(MINE_SOUNDS)

## Igual ao Enemy: esconde/desativa na hora, mas só remove o nó depois do
## som de impacto tocar por completo.
func _deplete() -> void:
	collision_shape.set_deferred("disabled", true)
	sprite.hide()
	_play_random(MINE_SOUNDS)
	await get_tree().create_timer(0.4).timeout
	queue_free()

func _play_random(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	sfx_player.stream = sounds[randi() % sounds.size()]
	sfx_player.play()
