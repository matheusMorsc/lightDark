extends CharacterBody2D
## Inimigo de run: 3 comportamentos no mesmo script, escolhidos por
## `behavior` — mesmo espírito data-driven do resto do jogo (o que muda vira
## export, não script novo). Visual vem dos 4 kits de personagem do
## craftpix_dungeon_kit (`kit_id` 1..4); o SpriteFrames é montado em runtime
## a partir das strips U/D/S (o kit não tem "left"/"right" dedicados — o
## lado é espelhado via flip_h, igual à convenção do próprio pack).
##
## Comportamentos:
## - melee: persegue e bate por proximidade (original).
## - ranged: mantém distância ideal e atira enemy_projectile.tscn.
## - explosive: persegue, "acende o pavio" ao chegar perto (pisca) e explode
##   em área — depois se autodestrói (sem loot, é um kamikaze).

const Y_FORESHORTEN: float = 0.8
const ENEMY_KIT_DIR := "res://assets/craftpix_dungeon_kit/enemies/"
const PROJECTILE := preload("res://entities/dungeon/enemy_projectile.tscn")

const HIT_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/hit_enemy_000.ogg"),
	preload("res://assets/audio/sfx/hit_enemy_001.ogg"),
	preload("res://assets/audio/sfx/hit_enemy_002.ogg"),
]

@export_group("Identidade")
@export_range(1, 4) var kit_id: int = 1
@export_enum("melee", "ranged", "explosive") var behavior: String = "melee"

@export_group("Corpo a corpo")
@export var speed: float = 80.0
@export var max_health: float = 30.0
@export var contact_damage: float = 10.0
@export var detection_radius: float = 160.0
@export var attack_radius: float = 36.0
@export var attack_interval: float = 1.0

@export_group("À distância (behavior = ranged)")
@export var ranged_ideal_range: float = 220.0
@export var ranged_min_range: float = 130.0
@export var projectile_speed: float = 260.0
@export var projectile_damage: float = 8.0
@export var shot_interval: float = 1.6

@export_group("Explosivo (behavior = explosive)")
@export var fuse_time: float = 0.8
@export var explosion_radius: float = 70.0
@export var explosion_damage: float = 26.0

## Setado de fora (run_map.gd) em inimigos "elite": o flash de dano volta
## pra essa cor em vez de branco puro, senão o tingimento se perde no
## primeiro hit.
var base_modulate: Color = Color.WHITE

## Afixos de elite (registrado jul/2026, ver run_map.gd::ELITE_AFFIXES) —
## setado de fora ANTES de entrar na árvore, então _ready() já pode aplicar
## o que for imediato (ex: "fast"). Vazio = inimigo comum, sem afixo.
var elite_affixes: Array[String] = []
const AFFIX_DISPLAY_NAMES := {
	"fast": "Rápido",
	"vampiric": "Vampírico",
	"shielded": "Blindado",
	"regenerating": "Regenerativo",
	"explosive": "Explosivo",
}
const FAST_SPEED_MULT := 1.4
const VAMPIRIC_HEAL_PCT := 0.5
const SHIELD_DAMAGE_REDUCTION := 0.35
const REGEN_PCT_PER_SECOND := 0.03
const EXPLOSIVE_DEATH_RADIUS := 70.0
const EXPLOSIVE_DEATH_DAMAGE := 20.0
const ELITE_LABEL_COLOR := Color(1.0, 0.65, 0.65)
var _affix_label: Label = null

## Atordoamento (registrado jul/2026, aplicado pelo Martelo da Forja — ver
## player.gd::_attack_hammer): enquanto >0, o inimigo não persegue, não
## ataca e não se move — só o knockback/física residual continua. Cor
## amarelada substitui o tingimento normal enquanto durar.
var _stun_time_left: float = 0.0
const STUN_TINT := Color(1.0, 0.95, 0.4)

var health: float
var _facing: String = "down"
var _anim_lock: float = 0.0
var _fusing: bool = false
var _fuse_left: float = 0.0
## Guarda contra reentrância: o explosivo pode chamar _die() de DENTRO do
## próprio _physics_process (via _explode()) — sem isso, o resto do frame
## ainda rodaria e a animação de morte seria sobrescrita na mesma tick por
## _update_animation() antes de set_physics_process(false) fazer efeito.
var _dead: bool = false

@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: AnimatedSprite2D = $Sprite2D
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
	attack_timer.wait_time = shot_interval if behavior == "ranged" else attack_interval
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	sprite.sprite_frames = _build_sprite_frames(kit_id)
	sprite.play("idle_" + _facing)
	if not elite_affixes.is_empty():
		if "fast" in elite_affixes:
			speed *= FAST_SPEED_MULT
		_spawn_affix_label()
	queue_redraw()

## Label flutuante listando os afixos (graybox: sem ícone, só texto) —
## mesma ideia do "Requer X" dos nós de recurso, mas sempre visível
## enquanto o elite estiver vivo, não só ao passar o mouse.
func _spawn_affix_label() -> void:
	_affix_label = Label.new()
	var names: Array = []
	for tag in elite_affixes:
		names.append(AFFIX_DISPLAY_NAMES.get(tag, tag))
	_affix_label.text = " / ".join(names)
	_affix_label.add_theme_font_size_override("font_size", 13)
	_affix_label.add_theme_color_override("font_color", ELITE_LABEL_COLOR)
	_affix_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_affix_label.add_theme_constant_override("outline_size", 4)
	_affix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_affix_label.position = Vector2(-60, -58)
	_affix_label.custom_minimum_size = Vector2(120, 0)
	add_child(_affix_label)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if "regenerating" in elite_affixes and health < max_health:
		health = minf(max_health, health + max_health * REGEN_PCT_PER_SECOND * delta)
		queue_redraw()
	if _player == null or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _stun_time_left > 0.0:
		_stun_time_left = maxf(0.0, _stun_time_left - delta)
		attack_timer.stop()
		velocity = Vector2.ZERO
		if _stun_time_left <= 0.0:
			sprite.modulate = base_modulate
	else:
		match behavior:
			"ranged":
				_process_ranged()
			"explosive":
				_process_explosive(delta)
			_:
				_process_melee()

	# Empurrão de quando apanha (decai rápido) — continua valendo mesmo
	# atordoado, senão um golpe de martelo nunca empurra ninguém.
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	_update_animation(velocity.length() > 4.0, delta)

## Atordoa por `duration` segundos (ver var _stun_time_left acima).
## Chamado de fora (player.gd::_attack_hammer) — mesma interface simples
## de hit(), só que opcional: quem ataca confere has_method("stun") antes
## de chamar, então nem todo alvo precisa suportar isso (ex.: nós de
## recurso e o Boss não têm esse método, ficam imunes de graça).
func stun(duration: float) -> void:
	if _dead:
		return
	_stun_time_left = maxf(_stun_time_left, duration)
	sprite.modulate = STUN_TINT

func _process_melee() -> void:
	var distance := global_position.distance_to(_player.global_position)
	if distance <= attack_radius:
		velocity = Vector2.ZERO
		if attack_timer.is_stopped():
			attack_timer.start()
	elif distance <= detection_radius:
		_move_toward_player(speed)
		attack_timer.stop()
	else:
		velocity = Vector2.ZERO
		attack_timer.stop()

## Kiting: foge se o player chegar perto demais, aproxima se estiver longe
## demais da faixa ideal, senão para e atira (attack_timer cuida do tiro).
func _process_ranged() -> void:
	var distance := global_position.distance_to(_player.global_position)
	if distance > detection_radius:
		velocity = Vector2.ZERO
		attack_timer.stop()
		return
	if distance < ranged_min_range:
		_move_away_from_player(speed)
	elif distance > ranged_ideal_range:
		_move_toward_player(speed)
	else:
		velocity = Vector2.ZERO
	if attack_timer.is_stopped():
		attack_timer.start()

func _process_explosive(delta: float) -> void:
	if _fusing:
		velocity = Vector2.ZERO
		_fuse_left -= delta
		var pulse := int(_fuse_left * 12.0) % 2 == 0
		sprite.modulate = Color(1.6, 0.7, 0.55) if pulse else base_modulate
		if _fuse_left <= 0.0:
			_explode()
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance <= attack_radius:
		velocity = Vector2.ZERO
		_fusing = true
		_fuse_left = fuse_time
	elif distance <= detection_radius:
		_move_toward_player(speed * 1.15)
	else:
		velocity = Vector2.ZERO

func _move_toward_player(spd: float) -> void:
	velocity = (_player.global_position - global_position).normalized() * spd
	velocity.y *= Y_FORESHORTEN
	_update_facing(velocity)

func _move_away_from_player(spd: float) -> void:
	velocity = (global_position - _player.global_position).normalized() * spd
	velocity.y *= Y_FORESHORTEN
	_update_facing(-velocity)

func _on_attack_timer_timeout() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if behavior == "ranged":
		_shoot()
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance <= attack_radius:
		GameState.take_damage(contact_damage)
		_apply_vampiric_heal(contact_damage)
		_play_attack_anim()

## Afixo "vampiric": cura uma fração do dano causado ao jogador. Só cobre
## dano de contato (melee) e explosão (ver _explode) — projétil não cura
## em v1, o dano dele acontece dentro de enemy_projectile.gd, fora daqui.
func _apply_vampiric_heal(damage_dealt: float) -> void:
	if "vampiric" in elite_affixes and not _dead:
		health = minf(max_health, health + damage_dealt * VAMPIRIC_HEAL_PCT)
		queue_redraw()

func _shoot() -> void:
	var distance := global_position.distance_to(_player.global_position)
	if distance > detection_radius:
		return
	var dir := (_player.global_position - global_position).normalized()
	var p: Node2D = PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position
	p.direction = dir
	p.speed = projectile_speed
	p.damage = projectile_damage
	_play_attack_anim()

func _explode() -> void:
	_fusing = false
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= explosion_radius:
		GameState.take_damage(explosion_damage)
	_spawn_explosion_fx()
	_play_random(sfx_player, HIT_SOUNDS)
	_die()

## Fagulhas alaranjadas da explosão — mesma receita do breakable_prop.gd,
## cores diferentes e raio maior.
func _spawn_explosion_fx() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 18
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 200.0
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.55, 0.2)
	p.z_index = 50
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -10)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

func _update_facing(vel: Vector2) -> void:
	if vel.length() < 1.0:
		return
	if absf(vel.x) > absf(vel.y):
		_facing = "side"
		sprite.flip_h = vel.x < 0.0
	else:
		_facing = "down" if vel.y > 0.0 else "up"

func _update_animation(is_moving: bool, delta: float) -> void:
	if _fusing:
		return
	if _anim_lock > 0.0:
		_anim_lock = maxf(0.0, _anim_lock - delta)
		return
	var anim_name := ("walk_" if is_moving else "idle_") + _facing
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _play_attack_anim() -> void:
	var anim_name := "attack_" + _facing
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		_anim_lock = 0.3

func hit(amount: float) -> void:
	if "shielded" in elite_affixes:
		amount *= (1.0 - SHIELD_DAMAGE_REDUCTION)
	health -= amount
	DamageNumbers.spawn(get_parent(), global_position, amount)
	queue_redraw()
	if _player and is_instance_valid(_player):
		_knockback = (global_position - _player.global_position).normalized() * 170.0
	if health <= 0.0:
		_die()
		return
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = Color(1.6, 1.6, 1.6)
	_flash_tween = create_tween()
	# Se ainda estiver atordoado depois do flash, volta pro amarelo do
	# stun em vez da cor normal — senão um segundo golpe durante o stun
	# "cancelaria" a cor visualmente antes do efeito acabar de verdade.
	_flash_tween.tween_property(sprite, "modulate", STUN_TINT if _stun_time_left > 0.0 else base_modulate, 0.2)
	_play_random(sfx_player, HIT_SOUNDS)

## Barra de vida flutuante (registrado jul/2026, pedido do usuário — mesma
## receita já usada pelo Boss em boss.gd::_draw(), só menor). Redesenhada
## sempre que `health` muda (hit, regen do afixo, cura vampírica) via
## queue_redraw() nesses pontos.
func _draw() -> void:
	if _dead:
		return
	var w := 36.0
	draw_rect(Rect2(-w / 2.0, -50.0, w, 5.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2.0 + 1.0, -49.0, (w - 2.0) * clampf(health / max_health, 0.0, 1.0), 3.0), Color(0.9, 0.25, 0.25))

## Fica "morto" imediatamente (sem colisão) mas só remove o nó depois da
## animação/som de morte — senão corta tudo no meio.
func _die() -> void:
	_dead = true
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	if _affix_label:
		_affix_label.hide()
	if "explosive" in elite_affixes:
		_explosive_death()
	var death_anim := "death_" + _facing
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(death_anim):
		sprite.play(death_anim)
	else:
		sprite.hide()
	_play_random(sfx_player, HIT_SOUNDS)
	await get_tree().create_timer(0.4).timeout
	queue_free()

## Afixo "explosive": ao morrer, dá um último susto em área (não confundir
## com behavior == "explosive", que é o kamikaze inteiro — este é só o
## estouro final de qualquer elite que tenha sorteado o afixo).
func _explosive_death() -> void:
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= EXPLOSIVE_DEATH_RADIUS:
		GameState.take_damage(EXPLOSIVE_DEATH_DAMAGE)
	_spawn_explosion_fx()

func _play_random(player: AudioStreamPlayer2D, sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	player.stream = sounds[randi() % sounds.size()]
	player.play()

## Monta um SpriteFrames a partir das strips U/D/S do craftpix_dungeon_kit:
## frames quadrados (largura do frame = altura da imagem), então não
## precisa de slicing manual por pixel — funciona pra qualquer um dos 4 kits.
func _build_sprite_frames(kit: int) -> SpriteFrames:
	var dir := ENEMY_KIT_DIR + str(kit) + "/"
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var specs := [
		["idle_down", "D_Idle.png", 6.0, true],
		["idle_up", "U_Idle.png", 6.0, true],
		["idle_side", "S_Idle.png", 6.0, true],
		["walk_down", "D_Walk.png", 9.0, true],
		["walk_up", "U_Walk.png", 9.0, true],
		["walk_side", "S_Walk.png", 9.0, true],
		["attack_down", "D_Attack.png", 10.0, false],
		["attack_up", "U_Attack.png", 10.0, false],
		["attack_side", "S_Attack.png", 10.0, false],
		["death_down", "D_Death.png", 8.0, false],
		["death_up", "U_Death.png", 8.0, false],
		["death_side", "S_Death.png", 8.0, false],
	]
	for spec: Array in specs:
		var tex: Texture2D = load(dir + String(spec[1]))
		if tex == null:
			continue
		var frame_h := tex.get_height()
		if frame_h <= 0:
			continue
		var frame_count := maxi(1, int(round(tex.get_width() / float(frame_h))))
		var anim_name: String = spec[0]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, spec[2])
		frames.set_animation_loop(anim_name, spec[3])
		for i in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * frame_h, 0, frame_h, frame_h)
			frames.add_frame(anim_name, atlas)
	return frames
