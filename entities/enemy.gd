extends CharacterBody2D
## Enemy simples: persegue o player dentro de um raio, ataca por proximidade
## (sem padrões, sem variáveis de combate), recebe dano via hit() e morre.

@export var speed: float = 80.0
@export var max_health: float = 30.0
@export var contact_damage: float = 10.0
@export var detection_radius: float = 160.0
@export var attack_radius: float = 36.0
@export var attack_interval: float = 1.0

var health: float

@onready var attack_timer: Timer = $AttackTimer

var _player: Node2D = null

func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player = get_tree().get_first_node_in_group("player")
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance := global_position.distance_to(_player.global_position)

	if distance <= attack_radius:
		velocity = Vector2.ZERO
		if attack_timer.is_stopped():
			attack_timer.start()
	elif distance <= detection_radius:
		velocity = (_player.global_position - global_position).normalized() * speed
		attack_timer.stop()
	else:
		velocity = Vector2.ZERO
		attack_timer.stop()

	move_and_slide()

func _on_attack_timer_timeout() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance <= attack_radius:
		GameState.take_damage(contact_damage)

func hit(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()
