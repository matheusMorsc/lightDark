class_name HeightSprite
extends Node
## Canal de altura VISUAL separado da posição lógica no chão.
## Nunca mova o Y do corpo para pulos/knockback — isso muda a posição no
## plano e quebra Y-sort e colisão. Este nó desloca só o sprite pra cima
## e encolhe a sombra, simulando o objeto no ar.
##
## Uso: adicione como filho da entidade, aponte sprite_path/shadow_path,
## e chame hop() no knockback, drop de item, etc.

@export var sprite_path: NodePath
@export var shadow_path: NodePath
@export var gravity: float = 600.0

var height: float = 0.0:
	set(value):
		height = maxf(0.0, value)
		_apply()

var velocity_h: float = 0.0

var _sprite: Node2D
var _shadow: Node2D
var _base_sprite_pos: Vector2
var _base_shadow_scale: Vector2
var _base_shadow_alpha: float

func _ready() -> void:
	_sprite = get_node_or_null(sprite_path)
	_shadow = get_node_or_null(shadow_path)
	if _sprite:
		_base_sprite_pos = _sprite.position
	if _shadow:
		_base_shadow_scale = _shadow.scale
		_base_shadow_alpha = _shadow.modulate.a
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	velocity_h -= gravity * delta
	height += velocity_h * delta
	if height <= 0.0 and velocity_h <= 0.0:
		height = 0.0
		velocity_h = 0.0
		set_physics_process(false)

## Impulso vertical (px/s). 120–200 fica bom pra knockback e drops.
func hop(strength: float = 180.0) -> void:
	velocity_h = strength
	set_physics_process(true)

func _apply() -> void:
	if _sprite:
		_sprite.position.y = _base_sprite_pos.y - height
	if _shadow:
		_shadow.scale = _base_shadow_scale * clampf(1.0 - height / 80.0, 0.4, 1.0)
		_shadow.modulate.a = _base_shadow_alpha * clampf(1.0 - height / 120.0, 0.3, 1.0)
