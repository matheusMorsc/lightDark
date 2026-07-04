extends CharacterBody2D
## Boss graybox (fim de run) — cápsula grande com dois ataques telegrafados.
## GRAYBOX de propósito: a arte final substitui só o nó Body (Polygon2D);
## moveset, hitboxes e timings ficam.
##
## Ataques:
## 1) INVESTIDA — para, pisca e mostra uma linha na direção do player, depois
##    dá um dash; acerta uma vez se passar perto.
## 2) PANCADA (AoE) — para e desenha um anel crescendo até o raio real; quem
##    estiver dentro quando fecha, toma dano.

signal defeated

enum State { CHASE, TELEGRAPH, CHARGE, RECOVER, DEAD }

const Y_FORESHORTEN := 0.8
const SLAM_RADIUS := 90.0
const CHARGE_SPEED := 340.0
const TELEGRAPH_TIME := 0.7
const BODY_COLOR := Color(0.75, 0.3, 0.45)

const HIT_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/hit_enemy_000.ogg"),
	preload("res://assets/audio/sfx/hit_enemy_001.ogg"),
	preload("res://assets/audio/sfx/hit_enemy_002.ogg"),
]

@export var max_health: float = 150.0
@export var speed: float = 55.0
@export var contact_damage: float = 12.0
@export var charge_damage: float = 22.0
@export var slam_damage: float = 18.0
## Multiplicador de força (ciclos de boss mais fundos escalam via run_map).
@export var power_scale: float = 1.0

var health: float
var _state: State = State.CHASE
var _state_time: float = 0.0
var _next_attack_in: float = 3.0
var _attack_kind: int = 0  # 0 = investida, 1 = pancada
var _charge_dir := Vector2.ZERO
var _charge_hit := false
var _contact_cooldown: float = 0.0
var _telegraph_progress: float = 0.0
var _player: Node2D
var _flash_tween: Tween

@onready var body: Polygon2D = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_player: AudioStreamPlayer2D = $SfxPlayer

func _ready() -> void:
	add_to_group("enemies")
	max_health *= power_scale
	contact_damage *= power_scale
	charge_damage *= power_scale
	slam_damage *= power_scale
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	if _player == null or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	_state_time -= delta
	match _state:
		State.CHASE:
			_chase(delta)
		State.TELEGRAPH:
			_telegraph()
		State.CHARGE:
			_charge()
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_time <= 0.0:
				_state = State.CHASE
	move_and_slide()
	queue_redraw()

func _chase(delta: float) -> void:
	var to_player := _player.global_position - global_position
	velocity = to_player.normalized() * speed
	velocity.y *= Y_FORESHORTEN
	if to_player.length() < 34.0 and _contact_cooldown <= 0.0:
		GameState.take_damage(contact_damage)
		_contact_cooldown = 1.0
	_next_attack_in -= delta
	if _next_attack_in <= 0.0:
		# Longe = investida garantida; perto = 50/50.
		_attack_kind = 0 if to_player.length() > 110.0 else randi() % 2
		_state = State.TELEGRAPH
		_state_time = TELEGRAPH_TIME
		_telegraph_progress = 0.0
		velocity = Vector2.ZERO

func _telegraph() -> void:
	velocity = Vector2.ZERO
	_telegraph_progress = 1.0 - maxf(_state_time, 0.0) / TELEGRAPH_TIME
	# pisca em vermelho enquanto anuncia
	body.color = Color(0.95, 0.4, 0.35) if int(_state_time * 10.0) % 2 == 0 else BODY_COLOR
	if _state_time <= 0.0:
		body.color = BODY_COLOR
		if _attack_kind == 0:
			_charge_dir = (_player.global_position - global_position).normalized()
			_charge_hit = false
			_state = State.CHARGE
			_state_time = 0.45
		else:
			_do_slam()

func _charge() -> void:
	velocity = _charge_dir * CHARGE_SPEED
	velocity.y *= Y_FORESHORTEN
	if not _charge_hit and global_position.distance_to(_player.global_position) < 30.0:
		_charge_hit = true
		GameState.take_damage(charge_damage)
	if _state_time <= 0.0:
		_recover()

func _do_slam() -> void:
	if global_position.distance_to(_player.global_position) <= SLAM_RADIUS:
		GameState.take_damage(slam_damage)
	_recover()

func _recover() -> void:
	_state = State.RECOVER
	_state_time = 0.8
	_next_attack_in = randf_range(2.2, 3.6)

func hit(amount: float) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	DamageNumbers.spawn(get_parent(), global_position, amount)
	_play_random(HIT_SOUNDS)
	if _flash_tween:
		_flash_tween.kill()
	body.modulate = Color(1.7, 1.7, 1.7)
	_flash_tween = create_tween()
	_flash_tween.tween_property(body, "modulate", Color.WHITE, 0.15)
	queue_redraw()
	if health <= 0.0:
		_die()

func _die() -> void:
	_state = State.DEAD
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	defeated.emit()
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if _state == State.DEAD:
		return
	# Barra de vida flutuante.
	var w := 64.0
	draw_rect(Rect2(-w / 2.0, -78.0, w, 7.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2.0 + 1.0, -77.0, (w - 2.0) * clampf(health / max_health, 0.0, 1.0), 5.0), Color(0.9, 0.25, 0.25))
	# Telegraphs.
	if _state == State.TELEGRAPH:
		if _attack_kind == 1:
			draw_arc(Vector2.ZERO, SLAM_RADIUS * _telegraph_progress, 0.0, TAU, 40, Color(1, 0.4, 0.3, 0.8), 3.0)
			draw_arc(Vector2.ZERO, SLAM_RADIUS, 0.0, TAU, 40, Color(1, 0.4, 0.3, 0.35), 2.0)
		elif is_instance_valid(_player):
			var dir := (_player.global_position - global_position).normalized()
			draw_line(Vector2.ZERO, dir * 90.0 * _telegraph_progress, Color(1, 0.5, 0.3, 0.8), 4.0)

func _play_random(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	sfx_player.stream = sounds[randi() % sounds.size()]
	sfx_player.play()
