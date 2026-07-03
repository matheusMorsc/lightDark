extends Node2D
## Mapa de run gerado proceduralmente (v1 — T1 do plano).
## Algoritmo: "drunkard walk" numa grade de slots de sala → sala retangular
## por slot → corredores em L pelas arestas → paredes com colisão via tiles.
## O mapa termina na sala mais distante com 2–3 PORTAIS DE ESCOLHA (estilo
## Hades): cada um anuncia o viés de recompensa do próximo mapa.
## reward_bias (escolhido no portal anterior) altera o conteúdo DESTE mapa.
## Determinístico por rng_seed (setado pelo WorldLayers antes do add_child).

## A cada N mapas, a sala final vira arena de boss (fim do ciclo da run).
const BOSS_EVERY := 3

const SLOT_W := 16   # tamanho do slot de sala, em tiles
const SLOT_H := 12

const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
]
const RARE_FLOOR := Vector2i(9, 3)
## Tiles claros da "trilha" que guia o jogador do spawn até a sala final.
const ROAD_TILES: Array[Vector2i] = [
	Vector2i(15, 6), Vector2i(16, 6), Vector2i(17, 6), Vector2i(16, 7),
]
const WALL_TILE := Vector2i(16, 2)

const ENEMY := preload("res://entities/enemy.tscn")
const ENEMY_FAST := preload("res://entities/enemy_fast.tscn")
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

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var entities: Node2D = $Entities

func _ready() -> void:
	_generate()

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# 1. Passeio aleatório na grade de slots: quais salas existem e quem é
	#    vizinho de quem (as arestas garantem conectividade total).
	var order: Array[Vector2i] = [Vector2i.ZERO]
	var edges: Array = []
	var occupied := {Vector2i.ZERO: true}
	var cur := Vector2i.ZERO
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var target: int = clampi(5 + map_index, 6, 11)
	var guard := 0
	while order.size() < target and guard < 500:
		guard += 1
		var next: Vector2i = cur + dirs[rng.randi() % 4]
		if not occupied.has(next):
			occupied[next] = true
			order.append(next)
			edges.append([cur, next])
		cur = next

	# 2. Uma sala retangular por slot.
	var floor_cells := {}
	var centers := {}
	var rects := {}
	for slot: Vector2i in order:
		var w := rng.randi_range(8, SLOT_W - 4)
		var h := rng.randi_range(6, SLOT_H - 4)
		var ox := slot.x * SLOT_W + (SLOT_W - w) / 2
		var oy := slot.y * SLOT_H + (SLOT_H - h) / 2
		for x in range(ox, ox + w):
			for y in range(oy, oy + h):
				floor_cells[Vector2i(x, y)] = true
		centers[slot] = Vector2i(ox + w / 2, oy + h / 2)
		rects[slot] = Rect2i(ox, oy, w, h)

	# 3. Corredores em L (3 tiles de largura) entre salas conectadas,
	#    lembrando quais células pertencem a cada corredor (p/ a trilha).
	var corridor_cells := {}
	for e in edges:
		var a: Vector2i = centers[e[0]]
		var b: Vector2i = centers[e[1]]
		var cells: Array = []
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for off in range(-1, 2):
				var c := Vector2i(x, a.y + off)
				floor_cells[c] = true
				cells.append(c)
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for off in range(-1, 2):
				var c := Vector2i(b.x + off, y)
				floor_cells[c] = true
				cells.append(c)
		corridor_cells[_edge_key(e[0], e[1])] = cells

	# 4. Pinta o chão e levanta parede em toda célula vazia encostada nele.
	for c: Vector2i in floor_cells:
		var atlas: Vector2i
		if rng.randf() < 0.08:
			atlas = RARE_FLOOR
		else:
			atlas = FLOOR_TILES[rng.randi() % FLOOR_TILES.size()]
		floor_layer.set_cell(c, 0, atlas)
	for c: Vector2i in floor_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dy)
				if not floor_cells.has(n) and wall_layer.get_cell_source_id(n) == -1:
					wall_layer.set_cell(n, 0, WALL_TILE)

	# 4b. Trilha: as arestas do passeio formam uma árvore, então o caminho
	#     spawn → sala final é único. Pinta os corredores dele com tiles
	#     claros — a "estrada" que o jogador segue até os portais/boss.
	var parent := {}
	for e in edges:
		parent[e[1]] = e[0]
	var walk: Vector2i = order[order.size() - 1]
	while parent.has(walk):
		var key := _edge_key(parent[walk], walk)
		for c: Vector2i in corridor_cells.get(key, []):
			floor_layer.set_cell(c, 0, ROAD_TILES[rng.randi() % ROAD_TILES.size()])
		walk = parent[walk]

	# 5. Multiplicadores do viés de recompensa deste mapa.
	var ore_min := 1
	var ore_max := 2
	var prop_min := 1
	var prop_max := 3
	var extra_enemies := 0
	var elite_chance := 0.0
	match reward_bias:
		"minerio":
			ore_min = 3; ore_max = 4
		"combate":
			extra_enemies = 2; elite_chance = 0.35; prop_max = 4
		"suprimentos":
			prop_min = 4; prop_max = 6

	# 6. Conteúdo: spawn na sala inicial, portais de escolha na mais distante,
	#    inimigos/props/minério nas demais (risco cresce com map_index).
	var start: Vector2i = order[0]
	var far: Vector2i = order[order.size() - 1]
	spawn_position = _cell_pos(centers[start]) + Vector2(0, 24)
	var boss_map := map_index % BOSS_EVERY == 0
	if boss_map:
		_spawn_boss(centers[far])
	else:
		_spawn_portals(rng, centers[far])

	for i in range(1, order.size()):
		var slot: Vector2i = order[i]
		var r: Rect2i = rects[slot]
		var n_enemies := rng.randi_range(1, 1 + mini(map_index, 3))
		if slot == far:
			if boss_map:
				continue  # arena do boss fica limpa: só o duelo
			n_enemies = maxi(1, n_enemies - 1)  # sala dos portais mais leve
		else:
			n_enemies += extra_enemies if rng.randf() < 0.6 else 0
		for j in n_enemies:
			_spawn_enemy(rng, r, rng.randf() < elite_chance)
		for j in rng.randi_range(prop_min, prop_max):
			_spawn(PROPS[rng.randi() % PROPS.size()], _rand_cell(rng, r))
		for j in rng.randi_range(ore_min, ore_max):
			_spawn(ORE, _rand_cell(rng, r))
		if rng.randf() < 0.6:
			_spawn(TORCH, _cell_pos(Vector2i(r.position.x + 1, r.position.y + 1)))

## Arena de boss: spawna o boss escalado pelo ciclo; ao vencer, recompensa
## em essência + portal de saída no lugar da queda.
func _spawn_boss(cell: Vector2i) -> void:
	var b := BOSS.instantiate()
	b.power_scale = 1.0 + 0.4 * float(map_index / BOSS_EVERY - 1)
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

func _edge_key(a: Vector2i, b: Vector2i) -> String:
	return "%s|%s" % [a, b]

func _spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	var n: Node2D = scene.instantiate()
	entities.add_child(n)
	n.global_position = pos
	return n

## Inimigos mais fortes quanto mais fundo na run; elites são versões
## reforçadas e avermelhadas (placeholder graybox de "miniboss").
func _spawn_enemy(rng: RandomNumberGenerator, r: Rect2i, elite: bool) -> void:
	var pos := _rand_cell(rng, r)
	if pos.distance_to(spawn_position) < 190.0:
		return  # zona segura: ninguém spawna colado na entrada do mapa
	var scene := ENEMY_FAST if rng.randf() < 0.3 else ENEMY
	var e := scene.instantiate()
	var f := 1.0 + 0.2 * (map_index - 1)
	if elite:
		f *= 1.8
	e.max_health *= f
	e.contact_damage *= f
	e.speed *= 1.0 + 0.05 * (map_index - 1)
	entities.add_child(e)
	if elite:
		var spr: Node = e.get_node_or_null("Sprite2D")
		if spr:
			spr.modulate = Color(1.0, 0.55, 0.55)
			spr.scale *= 1.25
	e.global_position = pos

func _rand_cell(rng: RandomNumberGenerator, r: Rect2i) -> Vector2:
	var c := Vector2i(
		rng.randi_range(r.position.x + 1, r.end.x - 2),
		rng.randi_range(r.position.y + 1, r.end.y - 2)
	)
	return _cell_pos(c)

func _cell_pos(c: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(c))
