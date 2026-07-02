extends StaticBody2D
## Nó de recurso colhível. Recebe golpes via hit() (mesma interface do Enemy)
## e soma ao contador global em GameState até esgotar.

@export var resource_id: String = "comida"
@export var hits_to_deplete: int = 3
@export var amount_per_hit: int = 1

@onready var sprite: Sprite2D = $Sprite2D

var _hits_remaining: int
var _flash_tween: Tween

func _ready() -> void:
	_hits_remaining = hits_to_deplete

func hit(_amount: float) -> void:
	_hits_remaining -= 1
	GameState.add_resource(resource_id, amount_per_hit)
	if _hits_remaining <= 0:
		queue_free()
		return
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = Color(1, 1, 1) * 2.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
