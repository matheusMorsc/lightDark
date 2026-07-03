extends Node
## WorldLayers (autoload)
## Superfície fixa/persistente (bioma) + runs de mapas gerados (lado Hades).
##
## O player carrega um "talismã" permanente (não ocupa inventário): a tecla T
## teleporta pra dentro de uma run a partir da superfície, e de volta pra
## base de dentro da run (encerrando-a). Dentro da run não há andares —
## cada mapa termina em 2–3 portais e o jogador ESCOLHE o próximo mapa
## pelo tipo de recompensa (minério, combate, suprimentos), estilo Hades.
##
## v1 (T1 do plano): a superfície não é destruída ao entrar na run — ela é
## escondida e desabilitada, e o mapa da run é gerado num offset distante
## para colisores/luzes das duas camadas nunca interagirem. Só existe um
## mapa por vez; escolher um portal gera o próximo e libera o anterior.
##
## Morte na run é leve (pilar 3): volta pra base com metade da vida.
## A base nunca é afetada.

const MAP_SCENE := preload("res://world/dungeon/run_map.tscn")
## Offset espacial da run: mantém os colisores da superfície (que continuam
## no espaço físico mesmo com o nó escondido) longe do player.
const RUN_OFFSET := Vector2(0, 100000)

var in_run: bool = false
## Quantos mapas o jogador já entrou nesta run (1 = primeiro). Escala o risco.
var map_index: int = 0
## Seed da run — sorteada ao entrar; os mapas derivam dela.
var run_seed: int = 0

## Posição "de casa" na superfície (respawn pós-morte).
var home_position := Vector2.ZERO

var _surface: Node2D = null
var _map: Node2D = null
var _return_position := Vector2.ZERO
var _t_was_pressed := false
var _fade_rect: ColorRect
var _fading := false

func _ready() -> void:
	GameState.player_died.connect(_on_player_died)
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

func _capture_home() -> void:
	var p := _get_player()
	if p:
		home_position = p.global_position

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

## Talismã: T alterna entre entrar na run e voltar pra base.
func _process(_delta: float) -> void:
	var t_pressed := Input.is_key_pressed(KEY_T)
	if t_pressed and not _t_was_pressed and not GameState.is_dead and not _fading:
		if in_run:
			end_run()
		else:
			start_run()
	_t_was_pressed = t_pressed

## Inicia uma run nova a partir da superfície (com fade).
func start_run() -> void:
	if in_run or _fading or _get_player() == null:
		return
	_transition(_do_start_run)

func _do_start_run() -> void:
	var player := _get_player()
	run_seed = randi()
	_surface = get_tree().current_scene
	_return_position = player.global_position
	in_run = true
	map_index = 0
	SaveManager.save_game()
	_goto_map("nenhum")

## Chamado pelos portais: gera o próximo mapa com o viés escolhido.
func enter_next_map(reward: String) -> void:
	if in_run and not _fading:
		_transition(_goto_map.bind(reward))

## Volta pra base (talismã ou pós-morte) e encerra a run (com fade).
func end_run() -> void:
	if _get_player() == null or _surface == null or not in_run or _fading:
		return
	_transition(_do_end_run)

func _do_end_run() -> void:
	var player := _get_player()
	in_run = false
	map_index = 0
	_surface.show()
	_surface.process_mode = Node.PROCESS_MODE_INHERIT
	# O LitCanvasModulate da run sobrescreveu os shader globals de ambiente
	# ("o último a entrar vence"). Reaplica o da superfície ao voltar.
	for m in get_tree().get_nodes_in_group("lit_canvas_modulate"):
		if _surface.is_ancestor_of(m):
			m.color = m.color  # o setter republica os globals
			break
	player.reparent(_surface.get_node("Entities"))
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
	elif _surface:
		_surface.hide()
		_surface.process_mode = Node.PROCESS_MODE_DISABLED

	player.reparent(_map.get_node("Entities"))
	player.global_position = _map.spawn_position
	player.velocity = Vector2.ZERO

## Morte unificada (pilar 3: morrer atrasa, nunca pune de verdade):
## na run OU na superfície, acorda na base com metade da vida. A fome
## também é reposta ao mínimo de 50% — senão morte por fome vira loop.
func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	GameState.is_dead = false
	GameState.health = GameState.max_health * 0.5
	GameState.hunger = maxf(GameState.hunger, GameState.max_hunger * 0.5)
	GameState.health_changed.emit(GameState.health, GameState.max_health)
	GameState.hunger_changed.emit(GameState.hunger, GameState.max_hunger)
	if in_run:
		end_run()
	else:
		var player := _get_player()
		if player:
			player.global_position = home_position
		SaveManager.save_game()

## Reset completo do mundo (usado pelo "Recomeçar do zero" do pause).
func reset_world() -> void:
	in_run = false
	map_index = 0
	_fading = false
	_fade_rect.color.a = 0.0
	if _map:
		_map.queue_free()
		_map = null
	_surface = null

## Nó da superfície (mesmo durante uma run).
func surface_root() -> Node2D:
	if in_run and _surface:
		return _surface
	return get_tree().current_scene as Node2D

## Posição do player na superfície (ponto de retorno, se estiver em run).
func surface_player_position() -> Vector2:
	if in_run:
		return _return_position
	var p := _get_player()
	return p.global_position if p else Vector2.ZERO

func _get_player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D
