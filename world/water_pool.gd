extends StaticBody2D
## Poça/lago decorativo feito de ladrilhos de água com borda de pedra.
## Gera o tilemap proceduralmente a partir de width/height (em tiles) e
## ajusta a colisão pra bloquear a passagem (não dá pra nadar ainda).

const TILE_SIZE := 16
const TOP_LEFT := Vector2i(0, 0)
const TOP := Vector2i(1, 0)
const TOP_RIGHT := Vector2i(2, 0)
const LEFT := Vector2i(0, 1)
const CENTER := Vector2i(1, 1)
const RIGHT := Vector2i(2, 1)
const BOTTOM_LEFT := Vector2i(0, 2)
const BOTTOM := Vector2i(1, 2)
const BOTTOM_RIGHT := Vector2i(2, 2)

@export var width: int = 5
@export var height: int = 4

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var w: int = max(2, width)
	var h: int = max(2, height)
	tile_map.clear()
	for y in h:
		for x in w:
			var atlas := CENTER
			if y == 0 and x == 0:
				atlas = TOP_LEFT
			elif y == 0 and x == w - 1:
				atlas = TOP_RIGHT
			elif y == h - 1 and x == 0:
				atlas = BOTTOM_LEFT
			elif y == h - 1 and x == w - 1:
				atlas = BOTTOM_RIGHT
			elif y == 0:
				atlas = TOP
			elif y == h - 1:
				atlas = BOTTOM
			elif x == 0:
				atlas = LEFT
			elif x == w - 1:
				atlas = RIGHT
			tile_map.set_cell(Vector2i(x, y), 0, atlas)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w * TILE_SIZE, h * TILE_SIZE)
	collision_shape.shape = shape
	collision_shape.position = Vector2(w * TILE_SIZE / 2.0, h * TILE_SIZE / 2.0)
