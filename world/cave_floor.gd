extends TileMapLayer
## Preenche uma area retangular com tiles de chao de caverna, variando
## aleatoriamente entre algumas variantes pra nao ficar repetitivo.
## Isso substitui o retangulo verde de placeholder por um chao de verdade.

@export var width_tiles: int = 130
@export var height_tiles: int = 130

## Coordenadas (na atlas) dos tiles de chao disponiveis. A maioria e pedra
## (mais comum), com uma variante de terra mais rara pra dar textura.
@export var stone_variants: Array[Vector2i] = [
	Vector2i(16, 14),
	Vector2i(17, 14),
	Vector2i(18, 14),
	Vector2i(19, 14),
]
@export var dirt_variants: Array[Vector2i] = [
	Vector2i(17, 12),
	Vector2i(18, 12),
]
@export var dirt_chance: float = 0.12

func _ready() -> void:
	_generate_floor()

func _generate_floor() -> void:
	var half_w: int = width_tiles / 2
	var half_h: int = height_tiles / 2
	for x in range(-half_w, half_w):
		for y in range(-half_h, half_h):
			var coords: Vector2i
			if randf() < dirt_chance:
				coords = dirt_variants[randi() % dirt_variants.size()]
			else:
				coords = stone_variants[randi() % stone_variants.size()]
			set_cell(Vector2i(x, y), 0, coords)
