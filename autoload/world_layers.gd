extends Node
## WorldLayers (autoload)
## Base persistente (região 1, sempre viva) + N regiões de superfície
## exploráveis (região 2+, instanciadas sob demanda e mantidas vivas pelo
## resto da sessão) + runs de mapas gerados (lado Hades).
##
## O talismã é uma estrutura construível na base (entities/structures/
## talisman.gd, StructureDef "talisma"): F nela chama start_run(). Dentro
## da run não há saída voluntária — só se volta ganhando (portal de saída
## pós-boss chama end_run(), ver run_portal.gd) ou morrendo
## (_on_player_died chama end_run()). Dentro da run não há andares — cada
## mapa termina em 2–3 portais e o jogador ESCOLHE o próximo mapa pelo tipo
## de recompensa (minério, combate, suprimentos), estilo Hades.
##
## Regiões (registrado jul/2026 — ver docs/plano-2-anos.md §2): a base
## (região 1, `world/biome_1.tscn`, a cena principal) nunca muda de lugar —
## "novo bioma" significa uma REGIÃO nova conectada por uma borda
## (entities/region_edge.gd), nunca uma base nova. Construção (B) e o
## talismã só funcionam na região 1 — ver BuildMode e talisman.gd.
## Limitação de v1: só a posição na base persiste entre sessões; se o save
## acontecer com o jogador numa região 2+, ele acorda na base ao recarregar
## (mesma regra da morte — "ainda não voltou" em vez de "perdeu o lugar").
##
## v1 do lado run (T1 do plano): a região ativa não é destruída ao entrar
## na run — é escondida e desabilitada, e o mapa da run é gerado num offset
## distante para colisores/luzes das camadas nunca interagirem. Só existe
## um mapa por vez; escolher um portal gera o próximo e libera o anterior.
##
## Morte na run é leve (pilar 3): volta pra base com metade da vida.
## A base nunca é afetada.

const MAP_SCENE := preload("res://world/dungeon/run_map.tscn")
const BASE_SAFE_RADIUS_MARKER_SCRIPT := preload("res://world/base_safe_radius_marker.gd")
const SURFACE_ENEMY := preload("res://entities/enemy.tscn")
const SURFACE_ENEMY_FAST := preload("res://entities/enemy_fast.tscn")
## Offset espacial da run: mantém os colisores da superfície (que continuam
## no espaço físico mesmo com o nó escondido) longe do player. Bem afastado
## de qualquer offset de região (ver REGIONS_DIR) pra nunca colidir.
const RUN_OFFSET := Vector2(0, 1000000)
const REGIONS_DIR := "res://world/regions"
const MODIFIERS_DIR := "res://world/dungeon/modifiers"

const DAY_NIGHT_CYCLE_SECONDS := 120.0
const DAY_END := 0.50
const DUSK_END := 0.65
const NIGHT_END := 0.90
const DAY_AMBIENT_SCALE := 1.12
const NIGHT_AMBIENT_SCALE := 0.32
const DUSK_AMBIENT_SCALE := 0.58
const NIGHT_SPAWN_INTERVAL := 4.0
const NIGHT_ENEMY_CAP := 12
const NIGHT_SPAWN_BATCH := 2
const NIGHT_SPAWN_MIN_DISTANCE := 260.0
const NIGHT_SPAWN_MAX_DISTANCE := 420.0
const BASE_SAFE_RADIUS := 420.0
const NIGHT_ENEMY_GROUP := "night_surface_enemy"
const BASE_SAFE_RADIUS_MARKER_NAME := "BaseSafeRadiusMarker"
const NIGHT_SCENE_POOL: Array[PackedScene] = [SURFACE_ENEMY, SURFACE_ENEMY_FAST]

## Emitido quando uma run começa com o modificador sorteado (ver
## RunModifierDef) — hud.gd escuta pra mostrar o toast de anúncio.
signal run_modifier_rolled(mod: RunModifierDef)
signal day_phase_changed(phase: String)
signal time_of_day_changed(time_ratio: float)

var in_run: bool = false
## Quantos mapas o jogador já entrou nesta run (1 = primeiro). Escala o risco.
var map_index: int = 0
## Seed da run — sorteada ao entrar; os mapas derivam dela.
var run_seed: int = 0

## Posição "de casa" na superfície, região 1 (respawn pós-morte e pós-load
## se o jogador tiver salvo numa região 2+ — ver limitação de v1 acima).
var home_position := Vector2.ZERO

## Id da região onde o jogador está agora (1 = base). Enquanto in_run,
## continua sendo a região de onde a run foi aberta (sempre 1 — só a base
## tem talismã).
var current_region_id: int = 1

var _region_defs: Dictionary = {}  # int -> RegionDef
## Raízes já instanciadas (id 1 é sempre a cena principal; as demais só
## existem depois da primeira visita, e continuam vivas escondidas — ver
## docs no topo do arquivo).
var _region_roots: Dictionary = {}  # int -> Node2D

## Modificador ativo da run atual (null = nenhum, ou fora de uma run).
## Sorteado uma vez em _do_start_run() e vale pra todos os mapas até voltar
## pra base — "maldição do dia" estilo roguelite, ver RunModifierDef.
var active_modifier: RunModifierDef = null
var _modifier_pool: Array[RunModifierDef] = []
var _time_of_day_ratio: float = 0.22
var _day_phase: String = "dia"
var _night_spawn_cooldown: float = NIGHT_SPAWN_INTERVAL

var _map: Node2D = null
var _return_position := Vector2.ZERO
var _fade_rect: ColorRect
var _fading := false

func _ready() -> void:
	GameState.player_died.connect(_on_player_died)
	_load_region_defs()
	_load_modifier_defs()
	call_deferred("_capture_home")
	# Véu preto pra transição de camadas (CanvasLayer acima de tudo).
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_base_safe_radius_marker()
	_apply_surface_cycle_to_root(_base_root())

func _process(delta: float) -> void:
	if in_run:
		return
	_advance_day_night(delta)
	_update_surface_night_pressure(delta)

func _load_region_defs() -> void:
	var dir := DirAccess.open(REGIONS_DIR)
	if dir == null:
		push_error("WorldLayers: pasta de regiões não encontrada.")
		return
	for file in dir.get_files():
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(REGIONS_DIR + "/" + file) as RegionDef
		if def != null:
			_region_defs[def.id] = def

func _load_modifier_defs() -> void:
	var dir := DirAccess.open(MODIFIERS_DIR)
	if dir == null:
		push_error("WorldLayers: pasta de modificadores não encontrada.")
		return
	for file in dir.get_files():
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(MODIFIERS_DIR + "/" + file) as RunModifierDef
		if def != null:
			_modifier_pool.append(def)

## Getters com fallback neutro (1.0 multiplicativo / 0.0 aditivo) — quem
## chama não precisa checar `active_modifier == null` toda vez.
func get_enemy_speed_mult() -> float:
	return active_modifier.enemy_speed_mult if active_modifier else 1.0

func get_enemy_damage_mult() -> float:
	return active_modifier.enemy_damage_mult if active_modifier else 1.0

func get_boss_power_mult() -> float:
	return active_modifier.boss_power_mult if active_modifier else 1.0

func get_elite_chance_bonus() -> float:
	return active_modifier.elite_chance_bonus if active_modifier else 0.0

func get_player_damage_mult() -> float:
	return active_modifier.player_damage_mult if active_modifier else 1.0

func get_heal_effectiveness_mult() -> float:
	return active_modifier.heal_effectiveness_mult if active_modifier else 1.0

func get_ore_yield_mult() -> float:
	return active_modifier.ore_yield_mult if active_modifier else 1.0

func get_time_of_day_ratio() -> float:
	return _time_of_day_ratio

func set_time_of_day_ratio(value: float) -> void:
	_time_of_day_ratio = wrapf(value, 0.0, 1.0)
	_update_day_phase(true)
	_apply_surface_cycle_to_root(_active_root())
	_apply_surface_cycle_to_root(_base_root())

func get_day_phase() -> String:
	return _day_phase

func is_night_phase() -> bool:
	return _day_phase == "noite"

func _capture_home() -> void:
	var p := _get_player()
	if p:
		home_position = p.global_position
		_update_base_safe_radius_marker()

## Fade preto rápido cobrindo a troca de camada (esconde o teleporte,
## o reparent e o snap da câmera).
func _transition(action: Callable) -> void:
	_fading = true
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.15)
	await tw.finished
	action.call()
	var tw_out := create_tween()
	tw_out.tween_property(_fade_rect, "color:a", 0.0, 0.25)
	await tw_out.finished
	_fading = false

## Raiz da região 1 (base) — sempre resolve pra `current_scene` se ainda não
## tiver sido capturada (mesma resiliência de antes: sobrevive a
## reload_current_scene, que não re-executa _ready() dos autoloads).
func _base_root() -> Node2D:
	if _region_roots.has(1):
		return _region_roots[1]
	return get_tree().current_scene as Node2D

## Raiz da região ATIVA agora (a que está visível/habilitada).
func _active_root() -> Node2D:
	if _region_roots.has(current_region_id):
		return _region_roots[current_region_id]
	return _base_root() if current_region_id == 1 else null

## Republica os globals de ambiente (lit_ambient_color/energy) do
## LitCanvasModulate de dentro de `root`. Necessário sempre que uma raiz
## VOLTA a ficar ativa só com show() (sem re-entrar na árvore) — nesse caso
## _enter_tree() não dispara de novo, e "o último a entrar vence" continua
## sendo a região que a gente acabou de esconder. Seguro chamar sempre,
## mesmo em raiz recém-instanciada (só reafirma o valor já correto).
func _reapply_ambient(root: Node2D) -> void:
	_apply_surface_cycle_to_root(root)

func _advance_day_night(delta: float) -> void:
	_time_of_day_ratio = wrapf(_time_of_day_ratio + delta / DAY_NIGHT_CYCLE_SECONDS, 0.0, 1.0)
	_update_day_phase()
	_apply_surface_cycle_to_root(_active_root())
	_apply_surface_cycle_to_root(_base_root())
	time_of_day_changed.emit(_time_of_day_ratio)

func _update_day_phase(force_emit: bool = false) -> void:
	var previous := _day_phase
	if _time_of_day_ratio < DAY_END:
		_day_phase = "dia"
	elif _time_of_day_ratio < DUSK_END:
		_day_phase = "entardecer"
	elif _time_of_day_ratio < NIGHT_END:
		_day_phase = "noite"
	else:
		_day_phase = "amanhecer"
	if force_emit or _day_phase != previous:
		if previous == "noite" and _day_phase != "noite":
			_clear_night_surface_enemies()
		day_phase_changed.emit(_day_phase)

func _apply_surface_cycle_to_root(root: Node2D) -> void:
	if root == null:
		return
	var canvas_modulate := root.get_node_or_null("LitCanvasModulate")
	if canvas_modulate == null:
		return
	var base_color: Color = canvas_modulate.get_meta("day_cycle_base_color", Color(0, 0, 0, 0))
	if base_color.a == 0.0:
		base_color = canvas_modulate.get("color")
		canvas_modulate.set_meta("day_cycle_base_color", base_color)
	var scale := _current_ambient_scale()
	var applied := Color(base_color.r * scale, base_color.g * scale, base_color.b * scale, base_color.a)
	canvas_modulate.set("color", applied)

func _current_ambient_scale() -> float:
	if _time_of_day_ratio < DAY_END:
		return DAY_AMBIENT_SCALE
	if _time_of_day_ratio < DUSK_END:
		var dusk_t := inverse_lerp(DAY_END, DUSK_END, _time_of_day_ratio)
		return lerpf(DAY_AMBIENT_SCALE, DUSK_AMBIENT_SCALE, dusk_t)
	if _time_of_day_ratio < NIGHT_END:
		var night_t := inverse_lerp(DUSK_END, NIGHT_END, _time_of_day_ratio)
		return lerpf(DUSK_AMBIENT_SCALE, NIGHT_AMBIENT_SCALE, night_t)
	var dawn_t := inverse_lerp(NIGHT_END, 1.0, _time_of_day_ratio)
	return lerpf(NIGHT_AMBIENT_SCALE, DAY_AMBIENT_SCALE, dawn_t)

func _update_surface_night_pressure(delta: float) -> void:
	if _day_phase != "noite":
		_night_spawn_cooldown = NIGHT_SPAWN_INTERVAL
		return
	var root := _active_root()
	var player := _get_player()
	if root == null or player == null:
		return
	if current_region_id == 1 and player.global_position.distance_to(home_position) <= BASE_SAFE_RADIUS:
		_night_spawn_cooldown = NIGHT_SPAWN_INTERVAL
		return
	if _count_night_surface_enemies(root) >= NIGHT_ENEMY_CAP:
		return
	_night_spawn_cooldown -= delta
	if _night_spawn_cooldown > 0.0:
		return
	_night_spawn_cooldown = NIGHT_SPAWN_INTERVAL
	for _i in range(NIGHT_SPAWN_BATCH):
		if _count_night_surface_enemies(root) >= NIGHT_ENEMY_CAP:
			break
		_spawn_night_surface_enemy(root, player.global_position)

func _count_night_surface_enemies(root: Node2D) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group(NIGHT_ENEMY_GROUP):
		if root.is_ancestor_of(enemy):
			count += 1
	return count

func _spawn_night_surface_enemy(root: Node2D, around: Vector2) -> void:
	var entities := root.get_node_or_null("Entities") as Node2D
	if entities == null:
		return
	for _attempt in range(12):
		var angle := randf() * TAU
		var distance := randf_range(NIGHT_SPAWN_MIN_DISTANCE, NIGHT_SPAWN_MAX_DISTANCE)
		var pos := around + Vector2.RIGHT.rotated(angle) * distance
		if current_region_id == 1 and pos.distance_to(home_position) <= BASE_SAFE_RADIUS:
			continue
		var enemy = NIGHT_SCENE_POOL[randi() % NIGHT_SCENE_POOL.size()].instantiate()
		enemy.global_position = pos
		enemy.set("speed", float(enemy.get("speed")) * 1.35)
		enemy.set("max_health", float(enemy.get("max_health")) * 1.4)
		enemy.set("contact_damage", float(enemy.get("contact_damage")) * 1.3)
		enemy.set("detection_radius", float(enemy.get("detection_radius")) * 1.3)
		enemy.set("base_modulate", Color(0.78, 0.84, 1.0, 1.0))
		entities.add_child(enemy)
		enemy.add_to_group(NIGHT_ENEMY_GROUP)
		return

func _clear_night_surface_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group(NIGHT_ENEMY_GROUP):
		enemy.queue_free()

func _ensure_base_safe_radius_marker() -> void:
	var base := _base_root()
	if base == null or base.get_node_or_null(BASE_SAFE_RADIUS_MARKER_NAME) != null:
		return
	var marker := Node2D.new()
	marker.name = BASE_SAFE_RADIUS_MARKER_NAME
	marker.set_script(BASE_SAFE_RADIUS_MARKER_SCRIPT)
	marker.set("radius", BASE_SAFE_RADIUS)
	base.add_child(marker)
	_update_base_safe_radius_marker()

func _update_base_safe_radius_marker() -> void:
	var base := _base_root()
	if base == null:
		return
	var marker := base.get_node_or_null(BASE_SAFE_RADIUS_MARKER_NAME) as Node2D
	if marker:
		marker.global_position = home_position

## Inicia uma run nova a partir da base (com fade). Chamado pelo talismã
## (entities/structures/talisman.gd) — não existe mais tecla global pra
## isso, e não existe saída voluntária depois de entrar. Só funciona na
## região 1 (o talismã, como estrutura construível, só existe lá).
func start_run() -> void:
	if in_run or _fading or current_region_id != 1 or _get_player() == null:
		return
	_transition(_do_start_run)

func _do_start_run() -> void:
	var player := _get_player()
	run_seed = randi()
	_region_roots[1] = get_tree().current_scene
	_return_position = player.global_position
	in_run = true
	map_index = 0
	active_modifier = _modifier_pool[randi() % _modifier_pool.size()] if not _modifier_pool.is_empty() else null
	if active_modifier:
		run_modifier_rolled.emit(active_modifier)
	SaveManager.save_game()
	_goto_map("nenhum")

## Chamado pelos portais: gera o próximo mapa com o viés escolhido.
func enter_next_map(reward: String) -> void:
	if in_run and not _fading:
		_transition(_goto_map.bind(reward))

## Volta pra base e encerra a run (com fade). Só dois chamadores: o portal
## de saída pós-boss (vitória, run_portal.gd) e _on_player_died (morte) —
## não existe saída voluntária no meio de uma run.
func end_run() -> void:
	var base := _base_root()
	if _get_player() == null or base == null or not in_run or _fading:
		return
	_transition(_do_end_run)

func _do_end_run() -> void:
	var player := _get_player()
	var base := _base_root()
	in_run = false
	map_index = 0
	active_modifier = null
	base.show()
	base.process_mode = Node.PROCESS_MODE_INHERIT
	_reapply_ambient(base)
	player.reparent(base.get_node("Entities"))
	player.global_position = _return_position
	player.velocity = Vector2.ZERO
	if _map:
		_map.queue_free()
		_map = null
	SaveManager.save_game()

func _goto_map(reward: String) -> void:
	var player := _get_player()
	if player == null:
		return
	map_index += 1

	var old := _map
	_map = MAP_SCENE.instantiate()
	_map.map_index = map_index
	_map.rng_seed = run_seed + map_index * 7919
	_map.reward_bias = reward
	_map.position = RUN_OFFSET
	get_tree().root.add_child(_map)

	if old:
		old.queue_free()
	else:
		var base := _base_root()
		if base:
			base.hide()
			base.process_mode = Node.PROCESS_MODE_DISABLED

	player.reparent(_map.get_node("Entities"))
	player.global_position = _map.spawn_position
	player.velocity = Vector2.ZERO

## Troca a região ativa (com fade) — chamado por entities/region_edge.gd ao
## encostar numa borda. `local_pos` é a posição DENTRO da região de
## destino, sem o offset dela (goto_region soma sozinho via to_global).
## Não funciona durante uma run (não existe "sair pra outra região" no meio
## de uma run, mesma regra do talismã).
func goto_region(id: int, local_pos: Vector2) -> void:
	if in_run or _fading or id == current_region_id or _get_player() == null:
		return
	if not _region_defs.has(id):
		push_warning("WorldLayers: região %d não cadastrada em %s." % [id, REGIONS_DIR])
		return
	_transition(_do_goto_region.bind(id, local_pos))

func _do_goto_region(id: int, local_pos: Vector2) -> void:
	var player := _get_player()
	if player == null:
		return
	var new_root := _get_or_create_region_root(id)
	if new_root == null:
		return
	var old_root := _active_root()
	if old_root and old_root != new_root:
		old_root.hide()
		old_root.process_mode = Node.PROCESS_MODE_DISABLED
	new_root.show()
	new_root.process_mode = Node.PROCESS_MODE_INHERIT
	_reapply_ambient(new_root)
	current_region_id = id
	player.reparent(new_root.get_node("Entities"))
	player.global_position = new_root.to_global(local_pos)
	player.velocity = Vector2.ZERO
	SaveManager.save_game()

## Pega a raiz já viva de uma região ou instancia (primeira visita — fica
## viva escondida depois disso, pelo resto da sessão; ver docs no topo).
func _get_or_create_region_root(id: int) -> Node2D:
	if id == 1:
		return _base_root()
	if _region_roots.has(id):
		return _region_roots[id]
	var def: RegionDef = _region_defs.get(id)
	if def == null or def.scene == null:
		return null
	var root: Node2D = def.scene.instantiate()
	root.position = def.offset
	get_tree().root.add_child(root)
	_region_roots[id] = root
	return root

## Morte unificada (pilar 3: morrer atrasa, nunca pune de verdade):
## em qualquer lugar, acorda na base com metade da vida. A fome também é
## reposta ao mínimo de 50% — senão morte por fome vira loop.
func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	GameState.is_dead = false
	GameState.health = GameState.max_health * 0.5
	GameState.hunger = maxf(GameState.hunger, GameState.max_hunger * 0.5)
	GameState.health_changed.emit(GameState.health, GameState.max_health)
	GameState.hunger_changed.emit(GameState.hunger, GameState.max_hunger)
	if in_run:
		end_run()
	elif current_region_id != 1:
		goto_region(1, home_position)
	else:
		var player := _get_player()
		if player:
			player.global_position = home_position
		SaveManager.save_game()

## Reset completo do mundo (usado pelo "Recomeçar do zero" do pause).
## Regiões extras (id != 1) foram adicionadas como irmãs de current_scene
## (get_tree().root.add_child), então sobrevivem a reload_current_scene()
## se não forem liberadas na mão — igual já valia pro mapa de run.
func reset_world() -> void:
	in_run = false
	map_index = 0
	current_region_id = 1
	_fading = false
	_fade_rect.color.a = 0.0
	if _map:
		_map.queue_free()
		_map = null
	for id: int in _region_roots.keys():
		if id != 1:
			var root: Node2D = _region_roots[id]
			if root:
				root.queue_free()
	_region_roots.clear()

## Nó da base (região 1) — mesmo durante uma run ou numa região 2+. Usado
## por SaveManager/BuildMode, que só lidam com a base (só ela tem
## estruturas construíveis — ver docs/plano-2-anos.md §2).
func surface_root() -> Node2D:
	return _base_root()

## Posição do player na base (ponto de retorno, se estiver em run ou numa
## região 2+ — ver limitação de v1 no topo do arquivo).
func surface_player_position() -> Vector2:
	if in_run:
		return _return_position
	if current_region_id != 1:
		return home_position
	var p := _get_player()
	return p.global_position if p else Vector2.ZERO

func _get_player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D

## Raiz da região ativa agora — exposta pra quem precisa desenhar/consultar
## a região atual sem duplicar a lógica de _active_root() (ver ui/map_view.gd).
func active_root() -> Node2D:
	return _active_root()

## Nome de exibição de uma região cadastrada (ou "?" se o id não existir) —
## usado pelo mapa simples (M) pra rotular bordas de região.
func get_region_name(id: int) -> String:
	var def: RegionDef = _region_defs.get(id)
	return def.display_name if def else "?"

## RegionDef cru de uma região cadastrada (ou null) — usado por
## entities/region_edge.gd pra checar `required_biome_unlock` antes de
## deixar cruzar a borda.
func get_region_def(id: int) -> RegionDef:
	return _region_defs.get(id)
