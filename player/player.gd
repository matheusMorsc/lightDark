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
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * speed
	move_and_slide()

	if Input.is_action_just_pressed("ui_accept"):
		_attack()

func _attack() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("hit"):
			body.hit(attack_damage)
