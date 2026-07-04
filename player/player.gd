extends CharacterBody2D
## Player: movimento top-down simples + ataque de área.
## "Bate e volta": sem defesa, sem itens, sem magia. Um botão de ataque
## que acerta tudo que tiver o método hit() dentro da AttackArea.

@export var speed: float = 200.0
@export var attack_damage: float = 10.0
@export var eat_hunger_restore: float = 25.0
@export var footstep_interval_px: float = 42.0

@export_group("Dash")
## Impulso instantâneo (sem telegraph, diferente da investida do boss):
## Shift dispara, dura pouco, dá i-frames enquanto dura, cooldown separado.
@export var dash_speed: float = 420.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.7

## Encurtamento vertical: no mundo "inclinado" estilo Don't Starve, um passo
## pra cima/baixo cobre menos tela que um passo lateral.
const Y_FORESHORTEN: float = 0.8
## Offset da AttackArea a partir dos pés, na direção do facing.
const ATTACK_REACH: float = 24.0
## Alcance máximo de interação/golpe, medido no "espaço do mundo"
## (compensa o achatamento vertical da perspectiva).
const ATTACK_MAX_DIST: float = 64.0

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
@onready var torch: Node2D = $Torch
@onready var light_shafts: Node2D = $Torch/LightShafts
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer

var _flash_tween: Tween
var _eat_key_was_pressed: bool = false
var _tool_key_was_pressed: bool = false
var _attack_mouse_was_pressed: bool = false
var _footstep_distance: float = 0.0
var _facing: String = "down"
var _attack_anim_timer: float = 0.0

var _dash_key_was_pressed: bool = false
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	GameState.player_damaged.connect(_on_player_damaged)
	GameState.player_died.connect(_on_player_died)
	GameState.inventory_changed.connect(_update_lantern)
	# Comprar "Lanterna Encantada" no meio do jogo precisa refletir na hora,
	# não só na próxima vez que o inventário mudar.
	UpgradeTracker.purchased.connect(func(_def: UpgradeDef) -> void: _update_lantern())
	_update_lantern()
	_update_attack_area_position()

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
	if GameState.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input_vector := _get_input_vector()

	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	var dash_key_pressed := Input.is_key_pressed(KEY_SHIFT)
	if dash_key_pressed and not _dash_key_was_pressed and _dash_time_left <= 0.0 \
			and _dash_cooldown_left <= 0.0 and _attack_anim_timer <= 0.0 and not BuildMode.active:
		_start_dash(input_vector)
	_dash_key_was_pressed = dash_key_pressed

	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
		velocity = _dash_dir * dash_speed
		velocity.y *= Y_FORESHORTEN
		if _dash_time_left <= 0.0:
			_end_dash()
	else:
		velocity = input_vector * speed * GameState.speed_mult
		velocity.y *= Y_FORESHORTEN
	move_and_slide()
	_update_footsteps(delta)
	_update_facing(input_vector)

	# Ataque/coleta: Espaço OU clique esquerdo do mouse (o cursor já mostra
	# espada/picareta via CursorManager quando tem algo alcançável embaixo).
	# Bloqueado durante o dash — os dois estados não se misturam.
	var attack_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var attack_pressed := Input.is_action_just_pressed("ui_accept") \
		or (attack_mouse_pressed and not _attack_mouse_was_pressed)
	if attack_pressed and not BuildMode.active and _dash_time_left <= 0.0:
		_attack()
	_attack_mouse_was_pressed = attack_mouse_pressed

	# "Just pressed" manual pra E, pelo mesmo motivo do _get_input_vector():
	# não depender do Input Map do projeto.
	var eat_key_pressed := Input.is_key_pressed(KEY_E)
	if eat_key_pressed and not _eat_key_was_pressed:
		_eat()
	_eat_key_was_pressed = eat_key_pressed

	# Q alterna entre as ferramentas presentes no inventário.
	var tool_key_pressed := Input.is_key_pressed(KEY_Q)
	if tool_key_pressed and not _tool_key_was_pressed:
		_cycle_tool()
	_tool_key_was_pressed = tool_key_pressed

	_update_animation(input_vector.length() > 0.0 or _dash_time_left > 0.0, delta)

## Vira o personagem (down/up/left/right) conforme o eixo dominante do
## movimento. Só atualiza enquanto se move — parado, mantém a última direção.
func _update_facing(input_vector: Vector2) -> void:
	if input_vector.length() == 0.0:
		return
	if abs(input_vector.x) > abs(input_vector.y):
		_facing = "right" if input_vector.x > 0.0 else "left"
	else:
		_facing = "down" if input_vector.y > 0.0 else "up"
	_update_attack_area_position()

## Reposiciona a AttackArea na frente do personagem conforme o facing.
func _update_attack_area_position() -> void:
	var dir := Vector2.ZERO
	match _facing:
		"right": dir = Vector2.RIGHT
		"left": dir = Vector2.LEFT
		"up": dir = Vector2(0.0, -Y_FORESHORTEN)
		"down": dir = Vector2(0.0, Y_FORESHORTEN)
	attack_area.position = dir * ATTACK_REACH

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
	var target := _pick_target()
	if target:
		target.hit(attack_damage * GameState.attack_damage_mult)
		_spawn_hit_fx(target.global_position + Vector2(0, -12))
		_hit_stop()

## Escolhe UM alvo por golpe (nada de acertar tudo ao redor): pontua os
## candidatos por proximidade + alinhamento com a direção encarada, com
## leve prioridade pra inimigos (combate > coleta em situação mista).
func _pick_target() -> Node2D:
	var facing_dir := _facing_vector()
	var best: Node2D = null
	var best_score := INF
	for body in attack_area.get_overlapping_bodies():
		if body == self or not body.has_method("hit"):
			continue
		var to: Vector2 = body.global_position - global_position
		# distância no espaço "real" do mundo (desfaz o achatamento em Y)
		var dist := Vector2(to.x, to.y / Y_FORESHORTEN).length()
		if dist > ATTACK_MAX_DIST:
			continue
		var alignment := facing_dir.dot(to.normalized()) if to.length() > 1.0 else 1.0
		var score := dist - alignment * 28.0
		if body.is_in_group("enemies"):
			score -= 8.0
		if score < best_score:
			best_score = score
			best = body
	return best

func _facing_vector() -> Vector2:
	match _facing:
		"right": return Vector2.RIGHT
		"left": return Vector2.LEFT
		"up": return Vector2.UP
		_: return Vector2.DOWN

## Lanterna craftável (progressão de luz): sem ela, a luz pessoal é só um
## brilho fraco — suficiente na superfície, apertado nas runs.
func _update_lantern() -> void:
	var has_lantern := GameState.get_total("lanterna") > 0
	var range_mult := GameState.lantern_range_mult if has_lantern else 1.0
	torch.set("energy", 1.3 if has_lantern else 0.6)
	torch.set("range", (180.0 if has_lantern else 110.0) * range_mult)
	light_shafts.visible = has_lantern

## Equipa a próxima ferramenta do inventário (ordem dos slots).
func _cycle_tool() -> void:
	var tools: Array[String] = []
	for slot in GameState.inventory:
		if slot != null:
			var def: ItemDef = ItemDB.get_def(slot.item_id)
			if def and def.category == ItemDef.Category.TOOL and not tools.has(slot.item_id):
				tools.append(slot.item_id)
	if tools.is_empty():
		return
	var idx := tools.find(GameState.equipped_tool_id)
	GameState.equip_tool(tools[(idx + 1) % tools.size()])

## Dispara o dash: direção = input atual (se estiver se movendo) ou o
## facing atual (se parado) — sempre um impulso, nunca precisa mirar antes.
## Concede i-frames (GameState.invulnerable) pelo tempo do impulso.
func _start_dash(input_vector: Vector2) -> void:
	var dir := input_vector if input_vector.length() > 0.0 else _facing_vector()
	_dash_dir = dir.normalized()
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown * GameState.dash_cooldown_mult
	GameState.invulnerable = true
	_spawn_dash_fx()

func _end_dash() -> void:
	_dash_time_left = 0.0
	GameState.invulnerable = false

## Rajada de partículas na saída do dash — pista visual rápida já que não
## existe animação de dash nos SpriteFrames (só idle/walk/attack/death).
func _spawn_dash_fx() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.direction = Vector2(-_dash_dir.x, -_dash_dir.y)
	p.spread = 16.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(0.78, 0.9, 1.0, 0.85)
	p.z_index = 40
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -10)
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)

## Congela o jogo por um instante no impacto (hit-stop) — vende o peso
## do golpe. O timer ignora o time_scale pra sempre voltar ao normal.
func _hit_stop() -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0

## Fagulhas de acerto (graybox: CPUParticles2D efêmero).
func _spawn_hit_fx(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 240)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(1, 0.9, 0.6)
	p.z_index = 50
	get_parent().add_child(p)
	p.global_position = pos
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

## Come o primeiro item de comida do inventário (ordem dos slots —
## reorganize os slots pra escolher o que comer primeiro).
func _eat() -> void:
	# Prioriza o slot selecionado na hotbar; senão, a primeira comida.
	var order: Array = [GameState.selected_slot]
	for i in GameState.inventory.size():
		if i != GameState.selected_slot:
			order.append(i)
	for i: int in order:
		var slot: Variant = GameState.inventory[i]
		if slot == null:
			continue
		var def: ItemDef = ItemDB.get_def(slot.item_id)
		if def == null or def.category != ItemDef.Category.FOOD:
			continue
		if GameState.remove_resource(slot.item_id, 1):
			GameState.eat(def.hunger_restore if def.hunger_restore > 0.0 else eat_hunger_restore)
			if def.heal_amount > 0.0:
				GameState.heal(def.heal_amount)
			_play_random(sfx_player, EAT_SOUNDS)
		return
