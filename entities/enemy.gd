extends CharacterBody2D
## Enemy simples: persegue o player dentro de um raio, ataca por proximidade
## (sem padrões, sem variáveis de combate), recebe dano via hit() e morre.

@export var speed: float = 80.0
@export var max_health: float = 30.0
@export var contact_damage: float = 10.0
@export var detection_radius: float = 160.0
@export var attack_radius: float = 36.0
@export var attack_interval: float = 1.0

## Mesmo fator de encurtamento vertical do player — inimigos se movem no
## mesmo "espaço inclinado", senão a perseguição fica assimétrica.
const Y_FORESHORTEN: float = 0.8

const HIT_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/hit_enemy_000.ogg"),
	preload("res://assets/audio/sfx/hit_enemy_001.ogg"),
	preload("res://assets/audio/sfx/hit_enemy_002.ogg"),
]

var health: float

@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_player: AudioStreamPlayer2D = $SfxPlayer

var _player: Node2D = null
var _flash_tween: Tween
var _knockback := Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player = get_tree().get_first_node_in_group("player")
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(delta: float) -> void:
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
		velocity.y *= Y_FORESHORTEN
		attack_timer.stop()
	else:
		velocity = Vector2.ZERO
		attack_timer.stop()

	# Empurrão de quando apanha (decai rápido).
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

func _on_attack_timer_timeout() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance <= attack_radius:
		GameState.take_damage(contact_damage)

func hit(amount: float) -> void:
	health -= amount
	if _player and is_instance_valid(_player):
		_knockback = (global_position - _player.global_position).normalized() * 170.0
	if health <= 0.0:
		_die()
		return
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = Color(1, 1, 1) * 2.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	_play_random(sfx_player, HIT_SOUNDS)

## Fica "morto" imediatamente (sem colisão nem sprite) mas só remove o nó
## depois do som de impacto tocar — se não fosse assim, o queue_free()
## cortaria o áudio no meio.
func _die() -> void:
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	sprite.hide()
	_play_random(sfx_player, HIT_SOUNDS)
	await get_tree().create_timer(0.4).timeout
	queue_free()

func _play_random(player: AudioStreamPlayer2D, sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	player.stream = sounds[randi() % sounds.size()]
	player.play()
