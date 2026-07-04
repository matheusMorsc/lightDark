extends Node
## BuildMode (autoload): modo de construção — só funciona na região 1 (a
## base; ver WorldLayers §Regiões). B alterna; 1..N escolhe a estrutura; o
## ghost segue o mouse com snap de 8px e fica verde/vermelho conforme a
## validade (custo + alcance + espaço livre + Workbench por perto quando
## exigido); clique esquerdo constrói e desconta os recursos.
## Estruturas são StructureDef (.tres) em res://items/structures — adicionar
## uma nova = criar um .tres + uma cena, nenhum código muda. Estruturas com
## `required_upgrade_id` só entram na lista numerada depois de compradas na
## árvore de progressão (ver UpgradeTracker) — a lista completa fica em
## `_all_defs`, a disponível (o que o jogador realmente vê) em `_defs`.

const STRUCTURES_DIR := "res://items/structures"
const PLACE_RANGE := 130.0
const SNAP := 8.0
## Raio pra "perto da Workbench" — estruturas com requires_workbench_nearby
## só podem ser erguidas dentro dessa distância de uma Workbench já construída.
const WORKBENCH_RANGE := 200.0

## Teclas 1-9 e 0 = 10 dígitos (mesmo padrão de RECIPE_KEYS/HOTBAR_KEYS em
## hud.gd). Registrado jul/2026: antes disso o código somava `KEY_1 + i`
## direto, que só é válido pra i=0..8 — pra i=9 (10º item) o resultado NÃO
## é KEY_0 (os codes não são sequenciais nessa direção), e a partir de 11
## itens (hoje, com Baú Grande/Poste de Luz) não existe tecla nenhuma pro
## 11º. Fix: array explícito + `mini()` no loop, e scroll do mouse cobre
## qualquer quantidade de estruturas além das 10 teclas físicas (ver
## _unhandled_input abaixo).
const BUILD_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var active: bool = false
## Frame em que o modo foi fechado (o ESC que fecha não deve abrir o pause).
var last_exit_frame := -1

var _all_defs: Array[StructureDef] = []
## Subconjunto de _all_defs realmente disponível agora (desbloqueados) —
## é o que aparece numerado no modo construção. Recalculada ao abrir o modo
## e sempre que um upgrade é comprado.
var _defs: Array[StructureDef] = []
var _index: int = 0
var _ghost: Node2D = null
var _hint: Label = null
var _valid: bool = false
var _invalid_reason: String = ""
var _b_was := false
var _click_was := false
var _num_was: Array[bool] = []

func _ready() -> void:
	var dir := DirAccess.open(STRUCTURES_DIR)
	if dir == null:
		push_error("BuildMode: pasta de estruturas não encontrada.")
		return
	var files := Array(dir.get_files())
	files.sort()
	for file: String in files:
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(STRUCTURES_DIR + "/" + file) as StructureDef
		# Fica como aviso permanente (não print de debug): um StructureDef
		# que falha ao carregar não trava o jogo, só desaparece em silêncio
		# da lista do modo B — já aconteceu (ver PROJECT_STATUS.md, "Color()
		# com 3 argumentos não é aceito no parser de recurso .tscn/.tres,
		# só na expressão GDScript — precisa sempre dos 4 componentes).
		if def == null:
			push_warning("BuildMode: falha ao carregar ", file, " (load() retornou null ou não é StructureDef).")
			continue
		if def.scene == null:
			push_warning("BuildMode: ", file, " carregou mas def.scene é null (cena referenciada não resolveu).")
			continue
		_all_defs.append(def)
	# Diagnóstico permanente em build de debug (jul/2026, mesmo espírito do
	# aviso de load acima): reportado pelo usuário que Baú Grande/Poste de
	# Luz não aparecem no modo B mesmo com o upgrade "constr_workbench"
	# comprado — nada no código explica isso à leitura, então em vez de
	# adivinhar de novo, listar aqui o que REALMENTE carregou.
	if OS.is_debug_build():
		var ids: Array = []
		for d in _all_defs:
			ids.append("%s (upgrade=%s)" % [d.id, d.required_upgrade_id if d.required_upgrade_id != "" else "-"])
		print("BuildMode: estruturas carregadas de %s: %s" % [STRUCTURES_DIR, ids])
	_refresh_available()
	UpgradeTracker.purchased.connect(func(_def: UpgradeDef) -> void: _refresh_available())

## Recalcula quais estruturas o jogador já pode construir (sem upgrade
## exigido, ou upgrade já comprado). Chamada na abertura do modo e sempre
## que UpgradeTracker avisa uma compra nova.
func _refresh_available() -> void:
	_defs = _all_defs.filter(func(d: StructureDef) -> bool:
		return d.required_upgrade_id == "" or UpgradeTracker.is_purchased(d.required_upgrade_id)
	)
	if OS.is_debug_build():
		for d in _all_defs:
			if d.required_upgrade_id != "" and not (d in _defs):
				print("BuildMode: '%s' escondida — upgrade '%s' comprado? %s" % [
					d.id, d.required_upgrade_id, UpgradeTracker.is_purchased(d.required_upgrade_id)
				])
	_num_was.resize(_defs.size())
	_num_was.fill(false)
	_index = clampi(_index, 0, maxi(0, _defs.size() - 1))

func _process(_delta: float) -> void:
	var b_pressed := Input.is_key_pressed(KEY_B)
	if b_pressed and not _b_was:
		_toggle()
	_b_was = b_pressed

	if not active:
		return
	if WorldLayers.in_run or GameState.is_dead or WorldLayers.current_region_id != 1:
		_exit()
		return

	for i in mini(_defs.size(), BUILD_KEYS.size()):
		var pressed := Input.is_key_pressed(BUILD_KEYS[i])
		if pressed and not _num_was[i] and i != _index:
			_index = i
			_refresh_ghost()
		_num_was[i] = pressed

	_update_ghost()

	# Sem o guard de UI, clicar num botão do painel clicável (ver hud.gd
	# _refresh_build_panel, registrado jul/2026) também tentaria construir
	# embaixo dele — mesma classe de bug já resolvida no ataque do player
	# (ver player.gd e "Convenções" no PROJECT_STATUS).
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var click := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not over_ui
	if click and not _click_was:
		_try_place()
	_click_was = click

## Scroll do mouse percorre a lista de estruturas (mesmo padrão da hotbar em
## hud.gd) — cobre qualquer quantidade de estruturas, não só as 10 primeiras
## que cabem em teclas físicas.
func _unhandled_input(event: InputEvent) -> void:
	if not active or _defs.is_empty() or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_index = (_index + 1) % _defs.size()
		_refresh_ghost()
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_index = (_index + _defs.size() - 1) % _defs.size()
		_refresh_ghost()

func _toggle() -> void:
	if active:
		_exit()
	elif not WorldLayers.in_run and not GameState.is_dead and WorldLayers.current_region_id == 1:
		_refresh_available()
		if _defs.is_empty():
			return
		active = true
		_refresh_ghost()

func _exit() -> void:
	active = false
	last_exit_frame = Engine.get_process_frames()
	if _ghost:
		_ghost.queue_free()
		_ghost = null

## Recria o ghost com a estrutura selecionada (transparente, sem colisão).
func _refresh_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	var world := _world_entities()
	if world == null:
		_exit()
		return
	var def := _defs[_index]
	_ghost = def.scene.instantiate()
	_disable_collisions(_ghost)
	world.add_child(_ghost)

	_hint = Label.new()
	_hint.custom_minimum_size = Vector2(200, 0)
	_hint.position = Vector2(-100, -72)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ghost.add_child(_hint)

func _disable_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_collisions(child)

func _update_ghost() -> void:
	if _ghost == null:
		return
	var mouse := _ghost.get_global_mouse_position()
	var pos := Vector2(snappedf(mouse.x, SNAP), snappedf(mouse.y, SNAP))
	_ghost.global_position = pos

	var def := _defs[_index]
	var player := _player()
	var near := player != null and player.global_position.distance_to(pos) <= PLACE_RANGE
	var has_workbench := not def.requires_workbench_nearby or _workbench_nearby(pos)
	var affordable := GameState.can_afford(def.costs)
	var space := _space_free(pos)
	_valid = affordable and near and space and has_workbench
	_ghost.modulate = Color(0.5, 1.0, 0.5, 0.65) if _valid else Color(1.0, 0.4, 0.4, 0.5)

	_invalid_reason = ""
	if not affordable:
		_invalid_reason = "faltam recursos"
	elif not near:
		_invalid_reason = "longe demais do personagem"
	elif not has_workbench:
		_invalid_reason = "precisa estar perto de uma Workbench"
	elif not space:
		_invalid_reason = "sem espaço livre aqui"
	if _hint:
		var status := (" — %s" % _invalid_reason) if _invalid_reason != "" else ""
		var key_hint := "[1..%d]" % mini(_defs.size(), BUILD_KEYS.size())
		_hint.text = "%s — %s%s\n%s ou scroll troca | clique: construir | B: sair" % [
			def.display_name, _cost_text(def), status, key_hint
		]

## true se existir alguma Workbench construída dentro de WORKBENCH_RANGE.
func _workbench_nearby(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("workbench"):
		if n is Node2D and (n as Node2D).global_position.distance_to(pos) <= WORKBENCH_RANGE:
			return true
	return false

## Espaço livre = nenhum corpo físico na pegada da estrutura.
func _space_free(pos: Vector2) -> bool:
	var space := _ghost.get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	params.shape = shape
	params.transform = Transform2D(0.0, pos + Vector2(0, -4))
	params.collide_with_bodies = true
	return space.intersect_shape(params, 1).is_empty()

func _try_place() -> void:
	if not _valid or _ghost == null:
		return
	var def := _defs[_index]
	if not GameState.can_afford(def.costs):
		return
	for item_id in def.costs:
		GameState.remove_resource(item_id, int(def.costs[item_id]))
	var world := _world_entities()
	if world == null:
		return
	var node: Node2D = def.scene.instantiate()
	world.add_child(node)
	node.global_position = _ghost.global_position
	# Persistência: SaveManager varre este grupo/meta ao salvar.
	node.set_meta("structure_id", def.id)
	node.add_to_group("player_built")
	ObjectiveTracker.notify_built(def.id)
	SaveManager.save_game()

func _cost_text(def: StructureDef) -> String:
	var parts: PackedStringArray = []
	for item_id in def.costs:
		parts.append("%d %s" % [int(def.costs[item_id]), ItemDB.get_display_name(item_id)])
	return ", ".join(parts)

func _world_entities() -> Node2D:
	var cs := get_tree().current_scene
	return cs.get_node_or_null("Entities") as Node2D if cs else null

func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D

## Lista das estruturas disponíveis agora (já desbloqueadas) — usado pelo
## painel do HUD que lista as opções numeradas (ver hud.gd::_refresh_build_panel).
## Sem isso o jogador só descobria estruturas novas apertando números às
## cegas, sem saber quantas existem ou quais teclas usar.
func get_available() -> Array[StructureDef]:
	return _defs

## Índice selecionado agora (pra destacar a linha correspondente na lista).
func get_selected_index() -> int:
	return _index

## Seleciona a estrutura pelo índice diretamente — chamado pelo painel
## clicável do HUD (registrado jul/2026, ver "Convenções": teclas 1..0 e
## scroll continuam funcionando também, isso só dá uma terceira forma sem
## limite de quantidade de estruturas).
func select_index(i: int) -> void:
	if i < 0 or i >= _defs.size() or i == _index:
		return
	_index = i
	_refresh_ghost()

func get_cost_text(def: StructureDef) -> String:
	return _cost_text(def)

## Quantas das estruturas disponíveis têm tecla física (1..0) — usado pelo
## painel do HUD pra saber a partir de qual linha mostrar "[scroll]" em vez
## de um número (ver hud.gd::_refresh_build_panel).
func get_key_count() -> int:
	return BUILD_KEYS.size()
