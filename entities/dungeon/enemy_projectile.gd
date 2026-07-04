extends Area2D
## Projétil de inimigo à distância (usa Fireball.png do craftpix_dungeon_kit).
## Anda em linha reta; acerta o player por PROXIMIDADE — mesma convenção do
## resto do jogo (inimigos não colidem fisicamente com o player, dano é por
## distância; ver entities/enemy.gd e player.gd/take_damage). Some ao tocar
## parede, ao acertar ou ao expirar.

@export var speed: float = 260.0
@export var damage: float = 8.0
@export var lifetime: float = 2.5
@export var hit_radius: float = 20.0

## Direção normalizada; setada pelo inimigo que disparou logo após instanciar.
var direction: Vector2 = Vector2.RIGHT

var _life_left: float
var _player: Node2D
var _spent: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # só paredes (layer "world") — não mira em inimigos
	_life_left = lifetime
	_player = get_tree().get_first_node_in_group("player")
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	if _player and is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= hit_radius:
		_spent = true
		GameState.take_damage(damage)
		queue_free()

func _on_body_entered(_body: Node) -> void:
	if not _spent:
		queue_free()
