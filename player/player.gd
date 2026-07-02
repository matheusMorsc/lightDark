extends CharacterBody2D
## Player: movimento top-down simples + ataque de área.
## "Bate e volta": sem defesa, sem itens, sem magia. Um botão de ataque
## que acerta tudo que tiver o método hit() dentro da AttackArea.

@export var speed: float = 200.0
@export var attack_damage: float = 10.0
@export var eat_hunger_restore: float = 25.0

@onready var attack_area: Area2D = $AttackArea
@onready var sprite: Sprite2D = $Sprite2D

var _flash_tween: Tween
var _eat_key_was_pressed: bool = false

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	GameState.player_damaged.connect(_on_player_damaged)

func _on_player_damaged(_amount: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = Color(1, 0.35, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _physics_process(_delta: float) -> void:
	velocity = _get_input_vector() * speed
	move_and_slide()

	if Input.is_action_just_pressed("ui_accept"):
		_attack()

	# "Just pressed" manual pra E, pelo mesmo motivo do _get_input_vector():
	# não depender do Input Map do projeto.
	var eat_key_pressed := Input.is_key_pressed(KEY_E)
	if eat_key_pressed and not _eat_key_was_pressed:
		_eat()
	_eat_key_was_pressed = eat_key_pressed

## Lê o teclado diretamente (setas OU WASD), sem depender do Input Map do
## projeto — assim funciona de imediato em qualquer configuração.
func _get_input_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		x += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		y += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		y -= 1.0
	var v := Vector2(x, y)
	return v.normalized() if v.length() > 0.0 else v

func _attack() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("hit"):
			body.hit(attack_damage)

## Consome 1 unidade de "comida" (se houver) e recupera fome.
func _eat() -> void:
	if GameState.remove_resource("comida", 1):
		GameState.eat(eat_hunger_restore)
