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
## "Ataque rápido": golpe normal (Espaço/clique) disparado durante o dash OU
## numa janela curta logo depois dele — alcance bem maior, pra facilitar
## acertar algo que você já passou correndo. Reaproveita a mesma AttackArea
## (agora com CollisionShape2D maior, ver player.tscn) e só filtra por uma
## distância diferente (ver _pick_target); não é um golpe em área — ainda
## acerta um alvo só, só que com bem mais margem pra conectar.
const QUICK_ATTACK_MAX_DIST: float = 110.0
const DASH_ATTACK_GRACE: float = 0.15
## Ataque especial (Q) — golpe em área, ver _special_attack().
const SPECIAL_ATTACK_RADIUS: float = 100.0
const SPECIAL_ATTACK_COOLDOWN: float = 2.5
const SPECIAL_RING_DURATION: float = 0.35

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
var _eat_mouse_was_pressed: bool = false
var _attack_mouse_was_pressed: bool = false
var _footstep_distance: float = 0.0
var _facing: String = "down"
var _attack_anim_timer: float = 0.0

var _dash_key_was_pressed: bool = false
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
## Janela de "ataque rápido" que sobrevive um pouco além do fim do dash.
var _dash_grace_left: float = 0.0

var _special_key_was_pressed: bool = false
var _special_cooldown_left: float = 0.0
## >0 enquanto o anel do ataque especial ainda está se expandindo (só
## visual — o dano já foi aplicado no frame em que _special_attack rodou).
var _special_ring_timer: float = 0.0

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

## Anel do ataque especial (Q) — mesmo visual do "Pancada" do Boss
## (boss.gd::_draw), só que aqui toca DEPOIS do dano (puramente cosmético):
## cresce de 0 até SPECIAL_ATTACK_RADIUS ao longo de SPECIAL_RING_DURATION.
func _draw() -> void:
	if _special_ring_timer <= 0.0:
		return
	var t := 1.0 - _special_ring_timer / SPECIAL_RING_DURATION
	var r := SPECIAL_ATTACK_RADIUS * clampf(t, 0.0, 1.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1, 0.4, 0.3, 0.8), 3.0)
	draw_arc(Vector2.ZERO, SPECIAL_ATTACK_RADIUS, 0.0, TAU, 40, Color(1, 0.4, 0.3, 0.35), 2.0)

func _physics_process(delta: float) -> void:
	if GameState.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input_vector := _get_input_vector()

	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_dash_grace_left = maxf(0.0, _dash_grace_left - delta)
	_special_cooldown_left = maxf(0.0, _special_cooldown_left - delta)
	if _special_ring_timer > 0.0:
		_special_ring_timer = maxf(0.0, _special_ring_timer - delta)
		queue_redraw()
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
	# Clique tem que estar fora de qualquer Control (HUD, hotbar etc.) —
	# senão clicar num slot da hotbar pra trocar de ferramenta também
	# "atacaria" (raw Input.is_mouse_button_pressed não é filtrado pela UI
	# como um evento _gui_input seria).
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var attack_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not over_ui
	var attack_pressed := Input.is_action_just_pressed("ui_accept") \
		or (attack_mouse_pressed and not _attack_mouse_was_pressed)
	# "Ataque rápido": diferente de antes, o golpe normal NÃO é mais
	# bloqueado durante o dash — dá pra cancelar o dash com um ataque
	# (ver _attack, que detecta a janela e usa alcance maior).
	if attack_pressed and not BuildMode.active:
		_attack()
	_attack_mouse_was_pressed = attack_mouse_pressed

	# Ataque especial (Q): golpe em área, só fora do dash (ver _special_attack).
	var special_key_pressed := Input.is_key_pressed(KEY_Q)
	if special_key_pressed and not _special_key_was_pressed and not BuildMode.active \
			and _dash_time_left <= 0.0:
		_special_attack()
	_special_key_was_pressed = special_key_pressed

	# Comer: botão direito do mouse, com a comida selecionada na hotbar
	# (mudou jul/2026 — antes E comia automaticamente a primeira comida do
	# inventário; agora precisa selecionar o slot primeiro, igual equipar
	# ferramenta). Mesmo filtro de UI do ataque, mesmo motivo.
	var eat_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not over_ui
	if eat_mouse_pressed and not _eat_mouse_was_pressed and not BuildMode.active:
		_eat()
	_eat_mouse_was_pressed = eat_mouse_pressed

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
	# Durante o dash ou na janela curta logo depois, o golpe normal vira
	# "ataque rápido": mesmo alvo único, mas alcance bem maior (a
	# AttackArea física já é grande o bastante — ver player.tscn — só muda
	# o filtro de distância).
	var quick := _dash_time_left > 0.0 or _dash_grace_left > 0.0
	var target := _pick_target(QUICK_ATTACK_MAX_DIST if quick else ATTACK_MAX_DIST)
	if target:
		target.hit((attack_damage + _equipped_weapon_bonus()) * GameState.attack_damage_mult)
		_spawn_hit_fx(target.global_position + Vector2(0, -12))
		_hit_stop()

## Ataque especial em área (Q) — golpe giratório da espada. Só funciona com
## uma arma equipada (weapon_damage_bonus > 0 — ver ItemDef "Arma"): reforça
## a troca real entre colher (machado/picareta) e lutar melhor (espada) que
## a Forja introduziu; com picareta/machado equipados, Q não faz nada.
## Dano é INSTANTÂNEO (aplicado no frame em que Q é apertado) e acerta TODOS
## os alvos no raio — ao contrário do golpe normal (_pick_target), que
## escolhe um alvo só. Visual copiado do ataque "Pancada" do Boss da
## dungeon (boss.gd::_do_slam/_draw): mesmo anel se expandindo, mas aqui é
## puramente cosmético — o dano já aconteceu antes do anel começar a crescer.
func _special_attack() -> void:
	if _special_cooldown_left > 0.0:
		return
	if _equipped_weapon_bonus() <= 0.0:
		return
	_special_cooldown_left = SPECIAL_ATTACK_COOLDOWN
	sprite.play("attack_" + _facing)
	_attack_anim_timer = ATTACK_ANIM_DURATION
	_special_ring_timer = SPECIAL_RING_DURATION
	var dmg := (attack_damage + _equipped_weapon_bonus()) * GameState.attack_damage_mult
	var hit_any := false
	for target in _query_hittable_in_radius(SPECIAL_ATTACK_RADIUS):
		target.hit(dmg)
		_spawn_hit_fx(target.global_position + Vector2(0, -12))
		hit_any = true
	if hit_any:
		_hit_stop()
	queue_redraw()

## Busca física direta (não depende do overlap "cacheado" da AttackArea, que
## só atualiza uma vez por passo de física) — necessária porque o raio do
## golpe especial é maior e centrado no jogador (360°), diferente do
## retângulo direcional da AttackArea normal. Mesma collision_mask da
## AttackArea, pra enxergar os mesmos tipos de alvo (inimigos, recursos,
## props quebráveis).
func _query_hittable_in_radius(radius: float) -> Array[Node2D]:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = attack_area.collision_mask
	params.exclude = [get_rid()]
	var out: Array[Node2D] = []
	for result in get_world_2d().direct_space_state.intersect_shape(params, 32):
		var collider = result.get("collider")
		if collider is Node2D and collider != self and collider.has_method("hit"):
			out.append(collider)
	return out

## Bônus de dano da arma equipada agora (0 se a ferramenta atual não for
## uma arma — ver ItemDef.weapon_damage_bonus). Reaproveita o mesmo "uma
## ferramenta ativa por vez" do ciclo Q: equipar a Espada da Forja pra
## lutar melhor custa não poder colher com machado/picareta ao mesmo tempo.
func _equipped_weapon_bonus() -> float:
	var def: ItemDef = ItemDB.get_def(GameState.equipped_tool_id)
	return def.weapon_damage_bonus if def else 0.0

## Escolhe UM alvo por golpe (nada de acertar tudo ao redor): pontua os
## candidatos por proximidade + alinhamento com a direção encarada, com
## leve prioridade pra inimigos (combate > coleta em situação mista).
## `max_dist` maior = "ataque rápido" (ver _attack) — mesma lógica de
## alvo único, só com mais margem pra conectar.
func _pick_target(max_dist: float = ATTACK_MAX_DIST) -> Node2D:
	var facing_dir := _facing_vector()
	var best: Node2D = null
	var best_score := INF
	for body in attack_area.get_overlapping_bodies():
		if body == self or not body.has_method("hit"):
			continue
		var to: Vector2 = body.global_position - global_position
		# distância no espaço "real" do mundo (desfaz o achatamento em Y)
		var dist := Vector2(to.x, to.y / Y_FORESHORTEN).length()
		if dist > max_dist:
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
	_dash_grace_left = DASH_ATTACK_GRACE

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

## Come o item de comida do slot SELECIONADO na hotbar — nada de "primeira
## comida do inventário" (mudou jul/2026): se o slot atual não for comida,
## o clique direito simplesmente não faz nada. Mesma lógica de "selecionar
## pra usar" do equipar ferramenta (ver GameState.select_slot).
func _eat() -> void:
	var slot: Variant = GameState.inventory[GameState.selected_slot] \
		if GameState.selected_slot < GameState.inventory.size() else null
	if slot == null:
		return
	var def: ItemDef = ItemDB.get_def(slot.item_id)
	if def == null or def.category != ItemDef.Category.FOOD:
		return
	if GameState.remove_resource(slot.item_id, 1):
		GameState.eat(def.hunger_restore if def.hunger_restore > 0.0 else eat_hunger_restore)
		if def.heal_amount > 0.0:
			GameState.heal(def.heal_amount)
		_play_random(sfx_player, EAT_SOUNDS)
