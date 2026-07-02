extends CharacterBody2D
## Player: movimento top-down simples + ataque de área.
## "Bate e volta": sem defesa, sem itens, sem magia. Um botão de ataque
## que acerta tudo que tiver o método hit() dentro da AttackArea.

@export var speed: float = 200.0
@export var attack_damage: float = 10.0

@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _physics_process(_delta: float) -> void:
	velocity = _get_input_vector() * speed
	move_and_slide()

	if Input.is_action_just_pressed("ui_accept"):
		_attack()

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
