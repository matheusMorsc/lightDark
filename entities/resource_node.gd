extends StaticBody2D
## Nó de recurso colhível. Recebe golpes via hit() (mesma interface do Enemy)
## e soma ao contador global em GameState até esgotar.

@export var resource_id: String = "madeira"
@export var hits_to_deplete: int = 3
@export var amount_per_hit: int = 1

var _hits_remaining: int

func _ready() -> void:
	_hits_remaining = hits_to_deplete

func hit(_amount: float) -> void:
	_hits_remaining -= 1
	GameState.add_resource(resource_id, amount_per_hit)
	if _hits_remaining <= 0:
		queue_free()
