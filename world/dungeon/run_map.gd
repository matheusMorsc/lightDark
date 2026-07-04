extends Node2D
## Mapa de run em formato de SALA de combate (inspirado no loop de Hades):
## uma arena única por mapa, sem corredores. Em mapas normais, o encontro
## começa com uma leva de 3–5 inimigos e segue em novas levas até totalizar
## 25–30 eliminados; só então os portais de escolha aparecem.
## reward_bias (escolhido no portal anterior) afeta a composição/perigo da
## sala atual. Determinístico por rng_seed (setado pelo WorldLayers).

## A cada N mapas, a sala final vira arena de boss (fim do ciclo da run).
const BOSS_EVERY := 3

const ARENA_W := 42  # largura interna da arena, em tiles
const ARENA_H := 28  # altura interna da arena, em tiles
const WAVE_MIN := 3
const WAVE_MAX := 5
const ENCOUNTER_TOTAL_MIN := 25
const ENCOUNTER_TOTAL_MAX := 30
const WAVE_DELAY := 0.85
const SAFE_RADIUS_FROM_SPAWN := 190.0

const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
]
const RARE_FLOOR := Vector2i(9, 3)
const WALL_TILE := Vector2i(16, 2)

const ENEMY := preload("res://entities/enemy.tscn")
const ENEMY_FAST := preload("res://entities/enemy_fast.tscn")
const ENEMY_RANGED := preload("res://entities/enemy_ranged.tscn")
const ENEMY_EXPLOSIVE := preload("res://entities/enemy_explosive.tscn")
const ORE := preload("res://entities/ore_node.tscn")
const PORTAL := preload("res://entities/dungeon/run_portal.tscn")
const BOSS := preload("res://entities/dungeon/boss.tscn")
const TORCH := preload("res://entities/dungeon/wall_torch.tscn")
const PROPS: Array[PackedScene] = [
	preload("res://entities/dungeon/crate_a.tscn"),
	preload("res://entities/dungeon/crate_b.tscn"),
	preload("res://entities/dungeon/barrel.tscn"),
	preload("res://entities/dungeon/pot.tscn"),
	preload("res://entities/dungeon/rocks_a.tscn"),
	preload("res://entities/dungeon/sack.tscn"),
]

var map_index: int = 1
var rng_seed: int = 0
## Viés escolhido no portal do mapa anterior ("nenhum" no primeiro).
var reward_bias: String = "nenhum"
## Posição global onde o player aparece (calculada na geração).
var spawn_position: Vector2
var _rng := RandomNumberGenerator.new()
var _arena_rect := Rect2i()
var _portal_center := Vector2i.ZERO
var _encounter_target := 0
var _encounter_spawned := 0
var _encounter_alive := 0
var _encounter_active := false
var _elite_chance := 0.0

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var entities: Node2D = $Entities

func _ready() -> void:
	_generate()

func _generate() -> void:
	_rng.seed = rng_seed

	# 1) Sala única (arena): chão interno + anel de parede ao redor.
	_arena_rect = Rect2i(-ARENA_W / 2, -ARENA_H / 2, ARENA_W, ARENA_H)
	for x in range(_arena_rect.position.x, _arena_rect.end.x):
		for y in range(_arena_rect.position.y, _arena_rect.end.y):
			var c := Vector2i(x, y)
			var atlas := RARE_FLOOR if _rng.randf() < 0.08 else FLOOR_TILES[_rng.randi() % FLOOR_TILES.size()]
			floor_layer.set_cell(c, 0, atlas)
	for x in range(_arena_rect.position.x - 1, _arena_rect.end.x + 1):
		wall_layer.set_cell(Vector2i(x, _arena_rect.position.y - 1), 0, WALL_TILE)
		wall_layer.set_cell(Vector2i(x, _arena_rect.end.y), 0, WALL_TILE)
	for y in range(_arena_rect.position.y - 1, _arena_rect.end.y + 1):
		wall_layer.set_cell(Vector2i(_arena_rect.position.x - 1, y), 0, WALL_TILE)
		wall_layer.set_cell(Vector2i(_arena_rect.end.x, y), 0, WALL_TILE)

	# 2) Spawn do player na base da sala; centro guarda o ponto de portais.
	var center := Vector2i.ZERO
	_portal_center = center
	spawn_position = _cell_pos(Vector2i(center.x, _arena_rect.end.y - 4)) + Vector2(0, 18)

	# 3) Viés do mapa atual (o portal escolhido no mapa anterior) + modificador.
	var ore_min := 1
	var ore_max := 2
	var prop_min := 2
	var prop_max := 4
	var elite_base := 0.08
	match reward_bias:
		"minerio":
			ore_min = 4
			ore_max = 6
		"combate":
			elite_base = 0.22
			prop_max = 5
		"suprimentos":
			prop_min = 5
			prop_max = 7
	_elite_chance = clampf(elite_base + WorldLayers.get_elite_chance_bonus(), 0.0, 0.9)
	var ore_mult := WorldLayers.get_ore_yield_mult()
	if ore_mult != 1.0:
		ore_min = maxi(1, ceili(ore_min * ore_mult))
		ore_max = maxi(ore_min, ceili(ore_max * ore_mult))

	# 4) Decoração/recurso da sala (mantém leitura de reward_bias sem quebrar
	#    o foco em combate por ondas).
	for _i in _rng.randi_range(prop_min, prop_max):
		_spawn(PROPS[_rng.randi() % PROPS.size()], _rand_cell(_rng, _arena_rect))
	for _i in _rng.randi_range(ore_min, ore_max):
		_spawn(ORE, _rand_cell(_rng, _arena_rect))
	_spawn(TORCH, _cell_pos(Vector2i(_arena_rect.position.x + 2, _arena_rect.position.y + 2)))
	_spawn(TORCH, _cell_pos(Vector2i(_arena_rect.end.x - 3, _arena_rect.position.y + 2)))

	# 5) Encontro: mapa de boss segue no ciclo, mapa comum usa levas até 25–30.
	var boss_map := map_index % BOSS_EVERY == 0
	if boss_map:
		_spawn_boss(center)
		return
	_encounter_target = _rng.randi_range(ENCOUNTER_TOTAL_MIN, ENCOUNTER_TOTAL_MAX)
	_encounter_spawned = 0
	_encounter_alive = 0
	_encounter_active = true
	_spawn_next_wave()

## Arena de boss: spawna o boss escalado pelo ciclo; ao vencer, recompensa
## em essência + portal de saída no lugar da queda.
func _spawn_boss(cell: Vector2i) -> void:
	var b := BOSS.instantiate()
	b.power_scale = (1.0 + 0.4 * float(map_index / BOSS_EVERY - 1)) * WorldLayers.get_boss_power_mult()
	b.defeated.connect(_on_boss_defeated.bind(cell))
	entities.add_child(b)
	b.global_position = _cell_pos(cell)

func _on_boss_defeated(cell: Vector2i) -> void:
	ObjectiveTracker.notify_boss_defeated()
	var cycle := maxi(1, map_index / BOSS_EVERY)
	GameState.add_resource("essencia", 2 + cycle)
	var p := PORTAL.instantiate()
	p.is_exit = true
	entities.add_child(p)
	p.global_position = _cell_pos(cell)

## Encontro de sala normal: spawna uma leva (3–5) e repete até bater a meta
## total (25–30). Portais só aparecem ao limpar a última leva.
func _spawn_next_wave() -> void:
	if not _encounter_active:
		return
	var remaining := _encounter_target - _encounter_spawned
	if remaining <= 0:
		return
	var wave_size := mini(_rng.randi_range(WAVE_MIN, WAVE_MAX), remaining)
	var spawned_now := 0
	var attempts := 0
	while spawned_now < wave_size and attempts < 60:
		attempts += 1
		if _spawn_enemy(_rng, _arena_rect, _rng.randf() < _elite_chance):
			spawned_now += 1
			_encounter_spawned += 1
			_encounter_alive += 1
	if _encounter_alive <= 0 and _encounter_spawned >= _encounter_target:
		_encounter_active = false
		_spawn_portals(_rng, _portal_center)

func _on_wave_enemy_exited() -> void:
	if not _encounter_active:
		return
	_encounter_alive = maxi(0, _encounter_alive - 1)
	if _encounter_alive > 0:
		return
	if _encounter_spawned >= _encounter_target:
		_encounter_active = false
		_spawn_portals(_rng, _portal_center)
		return
	await get_tree().create_timer(WAVE_DELAY).timeout
	if not is_inside_tree() or not _encounter_active:
		return
	_spawn_next_wave()

## 2–3 portais lado a lado, cada um com um viés diferente (escolha do jogador).
func _spawn_portals(rng: RandomNumberGenerator, center: Vector2i) -> void:
	var kinds := ["minerio", "combate", "suprimentos"]
	# Fisher-Yates com o rng da seed (shuffle() usaria o RNG global e
	# quebraria o determinismo do mapa).
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	var count := 2 if map_index < 2 else 3
	var spacing := 5  # tiles entre portais (longe o bastante pra não sobrepor)
	for i in count:
		var offset_x := int(round((i - (count - 1) / 2.0) * spacing))
		var cell := center + Vector2i(offset_x, 0)
		var p := PORTAL.instantiate()
		p.reward = kinds[i]
		entities.add_child(p)
		p.global_position = _cell_pos(cell)

func _spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	var n: Node2D = scene.instantiate()
	entities.add_child(n)
	n.global_position = pos
	return n

## Mistura de tipo por viés: "combate" traz mais variedade (e mais risco —
## à distância e explosivos exigem mais atenção que o melee puro); os
## demais viéses mantêm a run majoritariamente melee, com uma pitada de
## variedade pra não ficar repetitivo.
func _pick_enemy_scene(rng: RandomNumberGenerator) -> PackedScene:
	var pool: Array[PackedScene] = [ENEMY, ENEMY_FAST, ENEMY_RANGED, ENEMY_EXPLOSIVE]
	var weights: Array[float] = [0.55, 0.25, 0.15, 0.05]
	if reward_bias == "combate":
		weights = [0.35, 0.20, 0.25, 0.20]
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if roll <= acc:
			return pool[i]
	return pool[pool.size() - 1]

## Afixos de elite disponíveis (ver entities/enemy.gd pra efeito de cada
## um) — cada elite sorteia 2 distintos, no lugar do antigo multiplicador
## burro (registrado jul/2026, parte do sistema de Run Modifiers).
const ELITE_AFFIXES: Array[String] = ["fast", "vampiric", "shielded", "regenerating", "explosive"]
const ELITE_TINT := Color(1.0, 0.55, 0.55)

## Inimigos mais fortes quanto mais fundo na run; elites são versões
## reforçadas com 2 afixos reais sorteados (não é mais só stat x1.8).
func _spawn_enemy(rng: RandomNumberGenerator, r: Rect2i, elite: bool) -> bool:
	var pos := _rand_cell(rng, r)
	if pos.distance_to(spawn_position) < SAFE_RADIUS_FROM_SPAWN:
		return false  # zona segura: ninguém spawna colado na entrada do mapa
	var scene := _pick_enemy_scene(rng)
	var e := scene.instantiate()
	var health_mult := 1.0 + 0.2 * (map_index - 1)
	if elite:
		health_mult *= 1.3  # bump menor que antes — o resto do perigo vem dos afixos
	var dmg_mult := health_mult * WorldLayers.get_enemy_damage_mult()
	e.max_health *= health_mult
	e.contact_damage *= dmg_mult
	e.projectile_damage *= dmg_mult
	e.explosion_damage *= dmg_mult
	e.speed *= (1.0 + 0.05 * (map_index - 1)) * WorldLayers.get_enemy_speed_mult()
	if elite:
		e.base_modulate = ELITE_TINT
		e.elite_affixes = _pick_elite_affixes(rng)
	entities.add_child(e)
	if elite:
		var spr: Node = e.get_node_or_null("Sprite2D")
		if spr:
			spr.modulate = ELITE_TINT
			spr.scale *= 1.25
	e.global_position = pos
	if _encounter_active:
		e.tree_exited.connect(_on_wave_enemy_exited, CONNECT_ONE_SHOT)
	return true

## Sorteia 2 afixos distintos de ELITE_AFFIXES (Fisher-Yates parcial com o
## rng da seed, mesmo motivo do shuffle manual em _spawn_portals).
func _pick_elite_affixes(rng: RandomNumberGenerator) -> Array[String]:
	var pool := ELITE_AFFIXES.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return [pool[0], pool[1]]

func _rand_cell(rng: RandomNumberGenerator, r: Rect2i) -> Vector2:
	var c := Vector2i(
		rng.randi_range(r.position.x + 1, r.end.x - 2),
		rng.randi_range(r.position.y + 1, r.end.y - 2)
	)
	return _cell_pos(c)

func _cell_pos(c: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(c))
