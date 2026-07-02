extends CharacterBody2D
## Player: movimento top-down simples + ataque de área.
## "Bate e volta": sem defesa, sem itens, sem magia. Um botão de ataque
## que acerta tudo que tiver o método hit() dentro da AttackArea.

@export var speed: float = 200.0
@export var attack_damage: float = 10.0
@export var eat_hunger_restore: float = 25.0
@export var footstep_interval_px: float = 42.0

const DAMAGE_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/hit_player_000.ogg"),
	preload("res://assets/audio/sfx/hit_player_001.ogg"),
	preload("res://assets/audio/sfx/hit_player_002.ogg"),
]
const EAT_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/eat_000.ogg"),
	preload("res://assets/audio/sfx/eat_001.ogg"),
	preload("res://assets/audio/sfx/eat_002.ogg"),
]
const FOOTSTEP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/footsteps/footstep_00.ogg"),
	preload("res://assets/audio/footsteps/footstep_01.ogg"),
	preload("res://assets/audio/footsteps/footstep_02.ogg"),
	preload("res://assets/audio/footsteps/footstep_03.ogg"),
	preload("res://assets/audio/footsteps/footstep_04.ogg"),
	preload("res://assets/audio/footsteps/footstep_05.ogg"),
]

## Duração da animação de ataque (8 frames a 18 fps) — enquanto ela toca,
## a animação de idle/walk não sobrescreve o sprite.
const ATTACK_ANIM_DURATION: float = 8.0 / 18.0

@onready var attack_area: Area2D = $AttackArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer

var _flash_tween: Tween
var _eat_key_was_pressed: bool = false
var _attack_mouse_was_pressed: bool = false
var _footstep_distance: float = 0.0
var _facing: String = "down"
var _attack_anim_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	GameState.player_damaged.connect(_on_player_damaged)
	GameState.recipe_crafted.connect(_on_recipe_crafted)
	GameState.player_died.connect(_on_player_died)

func _on_recipe_crafted(recipe_id: String) -> void:
	if recipe_id == "ferramenta":
		attack_damage += 5.0

func _on_player_damaged(_amount: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = Color(1, 0.35, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	_play_random(sfx_player, DAMAGE_SOUNDS)

func _on_player_died() -> void:
	sprite.play("death_" + _facing)

func _physics_process(delta: float) -> void:
	var input_vector := _get_input_vector()
	velocity = input_vector * speed
	move_and_slide()
	_update_footsteps(delta)
	_update_facing(input_vector)

	# Ataque/coleta: Espaço OU clique esquerdo do mouse (o cursor já mostra
	# espada/picareta via CursorManager quando tem algo alcançável embaixo).
	var attack_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var attack_pressed := Input.is_action_just_pressed("ui_accept") \
		or (attack_mouse_pressed and not _attack_mouse_was_pressed)
	if attack_pressed:
		_attack()
	_attack_mouse_was_pressed = attack_mouse_pressed

	# "Just pressed" manual pra E, pelo mesmo motivo do _get_input_vector():
	# não depender do Input Map do projeto.
	var eat_key_pressed := Input.is_key_pressed(KEY_E)
	if eat_key_pressed and not _eat_key_was_pressed:
		_eat()
	_eat_key_was_pressed = eat_key_pressed

	_update_animation(input_vector.length() > 0.0, delta)

## Vira o personagem (down/up/left/right) conforme o eixo dominante do
## movimento. Só atualiza enquanto se move — parado, mantém a última direção.
func _update_facing(input_vector: Vector2) -> void:
	if input_vector.length() == 0.0:
		return
	if abs(input_vector.x) > abs(input_vector.y):
		_facing = "right" if input_vector.x > 0.0 else "left"
	else:
		_facing = "down" if input_vector.y > 0.0 else "up"

## Escolhe idle/walk conforme movimento e direção — a não ser que uma
## animação de ataque esteja tocando, que tem prioridade até terminar.
func _update_animation(is_moving: bool, delta: float) -> void:
	if _attack_anim_timer > 0.0:
		_attack_anim_timer = max(0.0, _attack_anim_timer - delta)
		return
	var anim_name := ("walk_" if is_moving else "idle_") + _facing
	if sprite.animation != anim_name:
		sprite.play(anim_name)

## Toca um passo a cada footstep_interval_px de distância percorrida.
func _update_footsteps(delta: float) -> void:
	if velocity.length() < 1.0:
		return
	_footstep_distance += velocity.length() * delta
	if _footstep_distance >= footstep_interval_px:
		_footstep_distance = 0.0
		_play_random(footstep_player, FOOTSTEP_SOUNDS)

func _play_random(player: AudioStreamPlayer, sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	player.stream = sounds[randi() % sounds.size()]
	player.play()

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
	sprite.play("attack_" + _facing)
	_attack_anim_timer = ATTACK_ANIM_DURATION
	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("hit"):
			body.hit(attack_damage)

## Consome 1 unidade de "comida" (se houver) e recupera fome.
func _eat() -> void:
	if GameState.remove_resource("comida", 1):
		GameState.eat(eat_hunger_restore)
		_play_random(sfx_player, EAT_SOUNDS)
