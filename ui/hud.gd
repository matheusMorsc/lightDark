extends CanvasLayer
## HUD: barras de vida/fome, grade de inventário (drag-and-drop) e painel
## de crafting.

@onready var health_bar: ProgressBar = $Control/VBoxContainer/HealthBar
@onready var hunger_bar: ProgressBar = $Control/VBoxContainer/HungerBar
## Número exato "atual / máximo" sobreposto na barra (registrado jul/2026,
## pedido do usuário pra facilitar ver o efeito do Amuleto Vital sem
## depender só da largura visual do preenchimento — 100→100 cheio e
## 150→150 cheio parecem IDÊNTICOS numa barra sem número).
@onready var health_value_label: Label = $Control/VBoxContainer/HealthBar/ValueLabel
@onready var hunger_value_label: Label = $Control/VBoxContainer/HungerBar/ValueLabel
@onready var slots_grid: GridContainer = $Control/InventoryPanel/VBox/SlotsGrid
@onready var tutorial_panel: PanelContainer = $Control/TutorialPanel
@onready var death_screen: Control = $Control/DeathScreen
@onready var crafting_panel: PanelContainer = $Control/CraftingPanel
@onready var crafting_title_label: Label = $Control/CraftingPanel/VBoxContainer/TitleLabel
@onready var crafting_status_label: Label = $Control/CraftingPanel/VBoxContainer/StatusLabel
@onready var crafting_recipes_vbox: VBoxContainer = $Control/CraftingPanel/VBoxContainer/Scroll/RecipesVBox
@onready var chest_panel: PanelContainer = $Control/ChestPanel
@onready var upgrades_panel: PanelContainer = $Control/UpgradesPanel

## Teclas de craft (o painel se monta sozinho a partir do RecipeDB): 1-9 e
## 0 = 10 dígitos, 10 receitas hoje (bateu certinho). Se uma 11ª receita
## entrar, tanto a linha do painel quanto o atalho de tecla pra ela somem
## (_build_recipe_rows e o loop abaixo cortam em RECIPE_KEYS.size()) — bug
## real que já aconteceu uma vez (jul/2026, ao passar de 9 pra 10 receitas
## o loop de tecla estourava o array; hoje os dois pontos usam o mesmo
## limite, então não trava mais, só "esconde" receitas excedentes).
const RECIPE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const HOTBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const STRUCTURES_DIR := "res://items/structures"
const CRAFT_STRUCTURE_SNAP := 8.0
const CRAFT_STRUCTURE_OFFSETS := [
	Vector2(0, 56), Vector2(48, 40), Vector2(-48, 40), Vector2(64, 8),
	Vector2(-64, 8), Vector2(64, -28), Vector2(-64, -28), Vector2(0, -60),
]

var _restart_key_was_pressed: bool = false
var _craft_menu_key_was_pressed: bool = false
var _craft_slot_key_was_pressed: Array[bool] = []
var _recipes: Array[RecipeDef] = []
var _structure_defs_by_id: Dictionary = {}  # String -> StructureDef
## "" = painel de craft mostra TUDO (aberto via C). Senão, id do grupo de
## uma estação (ex. "forja") — só mostra receitas daquela estação, aberto
## via E ao interagir com ela (ver station_interact.gd,
## open_station_crafting/close_station_crafting abaixo).
var _crafting_station_filter: String = ""
## Qual StaticBody2D (station_interact.gd) abriu o painel filtrado agora —
## precisa saber pra avisar ele de volta quando o painel fechar por outro
## caminho (ESC, abrir outro painel por cima...), senão a estação achava
## que ainda estava "aberta" e não respondia a um novo E.
var _crafting_station_source: Node = null
var _slot_nodes: Array = []
var _tool_label: Label
var _objectives_panel: PanelContainer
var _objective_labels: Dictionary = {}
var _objectives_key_was_pressed: bool = false
var _hotbar_key_was_pressed: Array[bool] = []
var _esc_was_pressed: bool = false
var _pause_root: Control
## Duas telas do menu de pause (ver _build_pause_menu): a de botões normal
## e a de controles (aberta pelo botão "Controles", volta com "Voltar").
var _pause_menu_box: VBoxContainer
var _pause_controls_box: VBoxContainer
var _volume_slider: HSlider
var _restart_button: Button
var _confirm_restart: bool = false

var _chest_slot_nodes: Array = []
var _open_chest: Node = null

var _upgrades_vbox: VBoxContainer
var _upgrades_key_was_pressed: bool = false

## Menu de cheat (F1), só existe em build de debug (editor ou export debug —
## nunca em export de release). Rudimentar de propósito: um botão por
## recurso pra farmar sem precisar rodar runs de verdade enquanto testa a
## progressão. Ver _build_debug_panel().
var _debug_panel: PanelContainer
var _debug_key_was_pressed: bool = false

## Painel do modo construção (B): lista TODAS as estruturas disponíveis
## agora, numeradas — antes disso o único feedback era o hint flutuante
## preso no ghost, que só muda de texto quando você já aperta um número.
## Com 9 estruturas (branch Construção) virou fácil não perceber que havia
## mais opções além das primeiras. Espelha o painel de craft.
var _build_panel: PanelContainer
var _build_vbox: VBoxContainer
var _build_was_active: bool = false

## Mapa simples (M alterna) — esquema de cima pra baixo da região ativa
## (jogador, bordas de região, estruturas construídas). Ver ui/map_view.gd.
var _map_panel: PanelContainer
var _map_key_was_pressed: bool = false

const BRANCH_NAMES := {
	UpgradeDef.Branch.COMBAT: "Combate",
	UpgradeDef.Branch.EXPLORATION: "Exploração",
	UpgradeDef.Branch.CONSTRUCTION: "Construção",
	UpgradeDef.Branch.MAGIC: "Magia",
}

const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	# Continua processando mesmo com a árvore pausada (necessário pra tela de
	# morte funcionar e detectar a tecla de reiniciar).
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")

	GameState.health_changed.connect(_on_health_changed)
	GameState.hunger_changed.connect(_on_hunger_changed)
	GameState.inventory_changed.connect(_update_inventory)
	GameState.player_died.connect(_on_player_died)

	_slot_nodes = slots_grid.get_children()
	_chest_slot_nodes = chest_panel.get_node("VBox/SlotsGrid").get_children()
	_index_structure_defs()
	_build_recipe_rows()
	_setup_hotbar()
	_build_pause_menu()

	_on_health_changed(GameState.health, GameState.max_health)
	_on_hunger_changed(GameState.hunger, GameState.max_hunger)
	_update_inventory()

	# O painel de tutorial não aparece mais sozinho no boot (some depois de
	# uns segundos, fácil de perder) — agora só existe dentro do menu de
	# pause (ESC > Controles), sempre acessível. Ver _build_pause_menu().
	tutorial_panel.visible = false

	# Indicador da ferramenta equipada (abaixo das barras de vida/fome).
	# `custom_minimum_size`/`clip_text` fixos de propósito (jul/2026,
	# investigando report do usuário de a barra de vida "mudar de largura"
	# ao trocar de arma): esse Label é filho do MESMO VBoxContainer das
	# barras, e o texto muda de tamanho a cada troca de ferramenta ("—
	# selecione na hotbar" vs "Espada da Forja") — sem um tamanho travado,
	# corria o risco de influenciar o layout do container. Largura igual à
	# das barras (200px) pra ficar tudo alinhado.
	_tool_label = Label.new()
	_tool_label.custom_minimum_size = Vector2(200, 20)
	_tool_label.clip_text = true
	_tool_label.size_flags_horizontal = 0
	$Control/VBoxContainer.add_child(_tool_label)
	GameState.tool_equipped.connect(_on_tool_equipped)
	GameState.inventory_changed.connect(func() -> void: GameState.get_equipped_tool())
	_on_tool_equipped(GameState.equipped_tool_id)

	_build_objectives_panel()
	ObjectiveTracker.progress_changed.connect(_on_objective_progress)
	ObjectiveTracker.biome_unlocked.connect(_on_biome_unlocked)
	WorldLayers.run_modifier_rolled.connect(_on_run_modifier_rolled)
	GameState.potion_applied.connect(_on_potion_applied)
	GameState.potion_expired.connect(_on_potion_expired)
	GameState.passive_bonus_changed.connect(_on_passive_bonus_changed)

	_build_upgrades_panel()
	_build_build_panel()
	_build_map_panel()

	if OS.is_debug_build():
		_build_debug_panel()

func _process(_delta: float) -> void:
	# ESC tem prioridade em cadeia: fecha pause > fecha craft > sai do modo
	# construção (tratado pelo BuildMode) > abre o pause.
	var esc_pressed := Input.is_key_pressed(KEY_ESCAPE)
	if esc_pressed and not _esc_was_pressed:
		_handle_esc()
	_esc_was_pressed = esc_pressed

	if get_tree().paused:
		return

	_handle_crafting_input()
	_handle_upgrades_input()
	_handle_debug_input()
	_handle_map_input()
	_handle_hotbar_input()
	_update_build_panel()

	var o_pressed := Input.is_key_pressed(KEY_O)
	if o_pressed and not _objectives_key_was_pressed and _objectives_panel:
		_objectives_panel.visible = not _objectives_panel.visible
	_objectives_key_was_pressed = o_pressed

## Hotbar: numera os 10 slots, esconde os extras da cena e liga a seleção.
func _setup_hotbar() -> void:
	_hotbar_key_was_pressed.resize(HOTBAR_KEYS.size())
	for i in _slot_nodes.size():
		var node: Control = _slot_nodes[i]
		node.visible = i < GameState.INVENTORY_SIZE
		if i < GameState.INVENTORY_SIZE:
			var num := Label.new()
			num.text = str((i + 1) % 10)
			num.add_theme_font_size_override("font_size", 11)
			num.modulate = Color(1, 1, 1, 0.75)
			num.custom_minimum_size = Vector2(44, 0)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num.position = Vector2(0, 45)  # logo abaixo do slot (44px)
			node.get_node("Content").add_child(num)
	GameState.selected_slot_changed.connect(_update_hotbar_selection)
	_update_hotbar_selection(GameState.selected_slot)

## Teclas 1..0 selecionam o slot (fora do painel de craft e do modo B).
func _handle_hotbar_input() -> void:
	if crafting_panel.visible or upgrades_panel.visible or BuildMode.active:
		return
	if _debug_panel and _debug_panel.visible:
		return
	if _map_panel and _map_panel.visible:
		return
	for i in HOTBAR_KEYS.size():
		var pressed := Input.is_key_pressed(HOTBAR_KEYS[i])
		if pressed and not _hotbar_key_was_pressed[i]:
			GameState.select_slot(i)
		_hotbar_key_was_pressed[i] = pressed

## Scroll do mouse percorre a hotbar.
func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		GameState.select_slot((GameState.selected_slot + 1) % GameState.INVENTORY_SIZE)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		GameState.select_slot((GameState.selected_slot + GameState.INVENTORY_SIZE - 1) % GameState.INVENTORY_SIZE)

func _update_hotbar_selection(index: int) -> void:
	for i in _slot_nodes.size():
		_slot_nodes[i].modulate = Color(1.35, 1.3, 0.85) if i == index else Color.WHITE

func _handle_esc() -> void:
	if _pause_root.visible and _pause_controls_box.visible:
		_hide_pause_controls()  # ESC na tela de controles só volta um nível
	elif _pause_root.visible:
		_close_pause()
	elif _debug_panel and _debug_panel.visible:
		_debug_panel.visible = false
	elif _map_panel and _map_panel.visible:
		_map_panel.visible = false
	elif chest_panel.visible:
		if _open_chest:
			_open_chest.close()
		else:
			chest_panel.visible = false
	elif upgrades_panel.visible:
		upgrades_panel.visible = false
	elif crafting_panel.visible:
		_close_crafting_panel()
	elif BuildMode.active or Engine.get_process_frames() == BuildMode.last_exit_frame:
		pass  # este ESC pertence ao modo construção
	else:
		_open_pause()

## Menu de pause: volume (persistido), continuar, recomeçar, sair.
func _build_pause_menu() -> void:
	_pause_root = Control.new()
	_pause_root.visible = false
	$Control.add_child(_pause_root)
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	_pause_root.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_pause_root.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)

	# Duas "telas" dentro do mesmo painel — menu principal e controles —
	# alternadas por visibilidade (só uma some por vez, nunca duas juntas).
	var outer := VBoxContainer.new()
	panel.add_child(outer)

	_pause_menu_box = VBoxContainer.new()
	_pause_menu_box.custom_minimum_size = Vector2(280, 0)
	_pause_menu_box.add_theme_constant_override("separation", 10)
	outer.add_child(_pause_menu_box)

	var title := Label.new()
	title.text = "Pausado"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	_pause_menu_box.add_child(title)
	var vol_row := HBoxContainer.new()
	_pause_menu_box.add_child(vol_row)
	var vol_label := Label.new()
	vol_label.text = "Volume "
	vol_row.add_child(vol_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.value = _load_volume()
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_volume_slider)
	var resume := Button.new()
	resume.text = "Continuar"
	resume.pressed.connect(_close_pause)
	_pause_menu_box.add_child(resume)
	var controls_btn := Button.new()
	controls_btn.text = "Controles"
	controls_btn.pressed.connect(_show_pause_controls)
	_pause_menu_box.add_child(controls_btn)
	_restart_button = Button.new()
	_restart_button.text = "Recomeçar do zero"
	_restart_button.pressed.connect(_on_restart_pressed)
	_pause_menu_box.add_child(_restart_button)
	var quit := Button.new()
	quit.text = "Salvar e sair"
	quit.pressed.connect(_on_quit_pressed)
	_pause_menu_box.add_child(quit)

	# Tela de controles: mesmo texto do tutorial inicial (uma fonte só,
	# lida do próprio TutorialLabel — sem duplicar a string em dois lugares).
	_pause_controls_box = VBoxContainer.new()
	_pause_controls_box.visible = false
	_pause_controls_box.custom_minimum_size = Vector2(280, 0)
	_pause_controls_box.add_theme_constant_override("separation", 10)
	outer.add_child(_pause_controls_box)
	var controls_title := Label.new()
	controls_title.text = "Controles"
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_title.add_theme_font_size_override("font_size", 24)
	_pause_controls_box.add_child(controls_title)
	var controls_label := Label.new()
	controls_label.text = tutorial_panel.get_node("TutorialLabel").text
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_controls_box.add_child(controls_label)
	var back_btn := Button.new()
	back_btn.text = "Voltar"
	back_btn.pressed.connect(_hide_pause_controls)
	_pause_controls_box.add_child(back_btn)

func _show_pause_controls() -> void:
	_pause_menu_box.visible = false
	_pause_controls_box.visible = true

func _hide_pause_controls() -> void:
	_pause_controls_box.visible = false
	_pause_menu_box.visible = true

func _open_pause() -> void:
	_confirm_restart = false
	_restart_button.text = "Recomeçar do zero"
	_hide_pause_controls()
	_pause_root.visible = true
	get_tree().paused = true
	SaveManager.save_game()

func _close_pause() -> void:
	_pause_root.visible = false
	get_tree().paused = false

## Recomeço total exige confirmação (apaga o save inteiro).
func _on_restart_pressed() -> void:
	if not _confirm_restart:
		_confirm_restart = true
		_restart_button.text = "Tem certeza? Clique de novo"
		return
	hide_chest_panel()
	WorldLayers.reset_world()
	SaveManager.wipe()
	GameState.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	SaveManager.save_game()
	get_tree().quit()

# ---- volume persistido em user://settings.cfg ----

func _load_volume() -> float:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var v: float = float(cfg.get_value("audio", "master", 0.8))
	_apply_volume(v)
	return v

func _on_volume_changed(v: float) -> void:
	_apply_volume(v)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master", v)
	cfg.save(SETTINGS_PATH)

func _apply_volume(v: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(bus, v <= 0.001)

func _handle_crafting_input() -> void:
	var c_pressed := Input.is_key_pressed(KEY_C)
	if c_pressed and not _craft_menu_key_was_pressed:
		if crafting_panel.visible:
			_close_crafting_panel()
		else:
			crafting_status_label.text = ""
			# C sempre abre a visão GERAL (todas as receitas), mesmo que a
			# última vez tenha sido fechada no meio de um E filtrado por
			# estação — reseta o filtro pra garantir.
			_crafting_station_filter = ""
			_crafting_station_source = null
			crafting_title_label.text = "Crafting (C para fechar)"
			crafting_panel.visible = true
			upgrades_panel.visible = false
			if _debug_panel:
				_debug_panel.visible = false
			if _map_panel:
				_map_panel.visible = false
			if _open_chest:
				_open_chest.close()
			_build_recipe_rows()
	_craft_menu_key_was_pressed = c_pressed

	if not crafting_panel.visible:
		return

	# Teclas só cobrem as primeiras RECIPE_KEYS.size() receitas (10 hoje) —
	# a partir daí só dá pra craftar clicando no botão da linha (ver
	# _build_recipe_rows). Mesmo limite usado no resize de
	# _craft_slot_key_was_pressed.
	for i in mini(_recipes.size(), RECIPE_KEYS.size()):
		var pressed := Input.is_key_pressed(RECIPE_KEYS[i])
		if pressed and not _craft_slot_key_was_pressed[i]:
			_try_craft(i)
		_craft_slot_key_was_pressed[i] = pressed

func _try_craft(index: int) -> void:
	var recipe: RecipeDef = _recipes[index]
	if recipe.required_station != "" and not _near_station(recipe.required_station):
		crafting_status_label.text = "Precisa estar perto da %s." % recipe.required_station_name
		return
	var place_result := {}
	if recipe.build_structure_id != "":
		place_result = _find_craft_structure_spot(recipe.build_structure_id)
		if not bool(place_result.get("ok", false)):
			crafting_status_label.text = String(place_result.get("reason", "Não foi possível construir agora."))
			return
	if GameState.craft(recipe.id, recipe.costs, recipe.result_id, recipe.result_count):
		# bonus_max_health/heal_on_craft: caminho antigo, sem receita nenhuma
		# usando mais (Amuleto Vital/II viraram itens PASSIVE reais em
		# jul/2026 — ver ItemDef.Category.PASSIVE e GameState.
		# _recompute_passive_bonuses). Deixado aqui só de propósito genérico,
		# caso uma receita futura precise de um efeito instantâneo puro sem
		# virar item físico.
		if recipe.bonus_max_health > 0.0:
			GameState.max_health += recipe.bonus_max_health
		if recipe.heal_on_craft > 0.0:
			GameState.heal(recipe.heal_on_craft)
		if recipe.potion_channel != "":
			GameState.apply_potion(recipe.potion_channel, recipe.potion_mult, recipe.potion_duration, recipe.display_name)
		if recipe.build_structure_id != "":
			_spawn_crafted_structure(place_result.get("def") as StructureDef, place_result.get("pos", Vector2.ZERO))
			crafting_status_label.text = "Construído: %s!" % recipe.display_name
		else:
			crafting_status_label.text = "Craftado: %s!" % recipe.display_name
	else:
		crafting_status_label.text = "Recursos insuficientes para %s." % recipe.display_name

## true se existir uma estrutura do grupo `group` (ex. "forja") construída
## dentro do alcance do jogador — mesmo raio e mesma ideia de
## BuildMode._workbench_nearby, mas medido a partir da posição do jogador
## (aqui é sobre CRAFTAR, não sobre construir).
const STATION_RANGE := 200.0
func _near_station(group: String) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	for n in get_tree().get_nodes_in_group(group):
		if n is Node2D and (n as Node2D).global_position.distance_to(player.global_position) <= STATION_RANGE:
			return true
	return false

## Abre o painel de craft filtrado por UMA estação (chamado por
## station_interact.gd via call_group("hud", ...) ao apertar E perto dela)
## — registrado jul/2026. Mostra só as receitas com `required_station ==
## group`; para `group == "workbench"`, mostra as estruturas movidas para o
## fluxo de interação E da bancada (Baú Grande, Poste de Luz), já com ação
## de construir.
func open_station_crafting(group: String, display_name: String, source: Node) -> void:
	crafting_status_label.text = ""
	crafting_panel.visible = true
	upgrades_panel.visible = false
	if _debug_panel:
		_debug_panel.visible = false
	if _map_panel:
		_map_panel.visible = false
	if _open_chest:
		_open_chest.close()
	_crafting_station_filter = group
	_crafting_station_source = source
	crafting_title_label.text = "%s (E fecha)" % display_name
	if group == "workbench":
		BuildMode.force_refresh_available()
	_build_recipe_rows()

## Fecha o painel de craft filtrado, mas SÓ se quem pediu pra fechar foi
## quem abriu (evita uma estação fechar o painel de outra por engano, caso
## dois E's se atropelem de algum jeito).
func close_station_crafting(source: Node) -> void:
	if _crafting_station_source != source:
		return
	_close_crafting_panel()

## Fecha o painel de craft e limpa o estado de filtro por estação, se
## houver. Usado pelo ESC e por qualquer painel que force fechar o craft
## ao abrir por cima (upgrades, build, mapa, baú...) — sem isso, fechar o
## craft filtrado por um caminho que não seja o próprio E/C deixava a
## estação (`station_interact.gd::is_open`) sem saber que fechou, e ela só
## reagiria ao PRÓXIMO E como se fosse fechar algo que já estava fechado.
func _close_crafting_panel() -> void:
	crafting_panel.visible = false
	if _crafting_station_source != null and is_instance_valid(_crafting_station_source):
		_crafting_station_source.is_open = false
	_crafting_station_filter = ""
	_crafting_station_source = null

## Monta as linhas do painel de craft a partir do RecipeDB (data-driven).
## Virou clicável/scrollável (registrado jul/2026, mesmo estilo do painel de
## progressão — tecla U, e do painel de construção — tecla B): antes as
## linhas eram só ícone+texto (sem clique) e cortavam em RECIPE_KEYS.size()
## (10) — qualquer receita além disso ficava invisível e impossível de
## craftar (ia acontecer de novo ao adicionar as receitas da Mesa de
## Pesquisa, que levam o total a 12). Agora a lista mostra TODAS as
## receitas (ou só as da estação, se `_crafting_station_filter` estiver
## setado — ver open_station_crafting), clicar crafta na hora; tecla 1..0
## continua funcionando pras 10 primeiras da lista GERAL (ver
## _handle_crafting_input), só não tem mais limite de visibilidade.
func _build_recipe_rows() -> void:
	for child in crafting_recipes_vbox.get_children():
		child.queue_free()
	_recipes = RecipeDB.get_all()
	_craft_slot_key_was_pressed.resize(mini(_recipes.size(), RECIPE_KEYS.size()))
	var shown := 0
	for i in _recipes.size():
		var r := _recipes[i]
		# Bug real (jul/2026, achado pelo usuário via screenshot): a condição
		# antiga só escondia receita de OUTRA estação quando já estava numa
		# visão FILTRADA (E numa estação) — a visão GERAL (C, filter == "")
		# nunca escondia nada, só mostrava o hint "(perto de X)" e deixava
		# craftar clicando mesmo longe da estação (barrado só na hora do
		# craft, em _try_craft). Resultado: Amuleto Vital, Lanterna Avançada
		# etc. continuavam aparecendo no C geral depois de ganharem
		# required_station. Comparação direta (r.required_station ==
		# _crafting_station_filter) resolve os dois casos de uma vez: geral
		# (filter == "") só mostra receita sem estação; filtrado só mostra a
		# da própria estação.
		if r.required_station != _crafting_station_filter:
			continue
		crafting_recipes_vbox.add_child(_build_recipe_row(i, r))
		shown += 1
	if _crafting_station_filter == "workbench":
		for def in BuildMode.get_workbench_e_available():
			crafting_recipes_vbox.add_child(_build_workbench_build_row(def))
			shown += 1
	if shown == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Nada disponível aqui ainda."
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		crafting_recipes_vbox.add_child(empty_lbl)

func _build_recipe_row(index: int, r: RecipeDef) -> Control:
	var row := HBoxContainer.new()
	row.name = "Recipe%d" % index
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if r.icon:
		icon_rect.texture = r.icon
	elif r.potion_channel != "":
		icon_rect.texture = PlaceholderIcons.potion_icon(r.potion_channel)
	else:
		icon_rect.texture = ItemDB.get_icon(r.result_id)
	row.add_child(icon_rect)
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Hint "(perto da X)" removido (jul/2026): agora que _build_recipe_rows
	# escova por `required_station == _crafting_station_filter`, uma receita
	# com estação só aparece OU na visão filtrada dessa estação (E) OU nunca
	# na geral (C) — o caso "geral mostrando receita de estação" que pedia
	# o hint não existe mais.
	var tag := "[%d]" % (index + 1) if index < RECIPE_KEYS.size() else "[clique]"
	btn.text = "%s %s — %s" % [tag, r.display_name, _costs_text(r.costs)]
	btn.pressed.connect(func() -> void: _try_craft(index))
	row.add_child(btn)
	return row

func _build_workbench_build_row(def: StructureDef) -> Control:
	var row := HBoxContainer.new()
	row.name = "Build_%s" % def.id
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var maybe_icon := ItemDB.get_icon(def.id)
	if maybe_icon:
		icon_rect.texture = maybe_icon
	row.add_child(icon_rect)
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "[construir] %s — %s" % [def.display_name, BuildMode.get_cost_text(def)]
	btn.pressed.connect(func() -> void: _try_workbench_build(def.id))
	row.add_child(btn)
	return row

func _try_workbench_build(def_id: String) -> void:
	if BuildMode.begin_from_workbench(def_id):
		_close_crafting_panel()
	else:
		crafting_status_label.text = "Não foi possível iniciar construção agora."

func _index_structure_defs() -> void:
	_structure_defs_by_id.clear()
	var dir := DirAccess.open(STRUCTURES_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(STRUCTURES_DIR + "/" + file) as StructureDef
		if def != null and def.id != "":
			_structure_defs_by_id[def.id] = def

func _find_craft_structure_spot(def_id: String) -> Dictionary:
	var def := _structure_defs_by_id.get(def_id, null) as StructureDef
	if def == null or def.scene == null:
		return {"ok": false, "reason": "Estrutura não encontrada para esta receita."}
	if WorldLayers.in_run or WorldLayers.current_region_id != 1:
		return {"ok": false, "reason": "Só dá para construir isso na base."}
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return {"ok": false, "reason": "Jogador não encontrado."}
	for offset: Vector2 in CRAFT_STRUCTURE_OFFSETS:
		var raw_pos := player.global_position + offset
		var pos := Vector2(snappedf(raw_pos.x, CRAFT_STRUCTURE_SNAP), snappedf(raw_pos.y, CRAFT_STRUCTURE_SNAP))
		if def.requires_workbench_nearby and not _craft_workbench_nearby(pos):
			continue
		if _craft_space_free(pos):
			return {"ok": true, "def": def, "pos": pos}
	if def.requires_workbench_nearby:
		return {"ok": false, "reason": "Sem espaço livre perto de uma Workbench."}
	return {"ok": false, "reason": "Sem espaço livre para construir por perto."}

func _craft_workbench_nearby(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("workbench"):
		if n is Node2D and (n as Node2D).global_position.distance_to(pos) <= STATION_RANGE:
			return true
	return false

func _craft_space_free(pos: Vector2) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var space := player.get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	params.shape = shape
	params.transform = Transform2D(0.0, pos + Vector2(0, -4))
	params.collide_with_bodies = true
	return space.intersect_shape(params, 1).is_empty()

func _spawn_crafted_structure(def: StructureDef, pos: Vector2) -> void:
	if def == null or def.scene == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var entities := player.get_parent() as Node2D
	if entities == null:
		return
	var node: Node2D = def.scene.instantiate()
	entities.add_child(node)
	node.global_position = pos
	node.set_meta("structure_id", def.id)
	node.add_to_group("player_built")
	ObjectiveTracker.notify_built(def.id)
	SaveManager.save_game()

func _costs_text(costs: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item_id in costs:
		parts.append("%d %s" % [int(costs[item_id]), ItemDB.get_display_name(item_id)])
	return ", ".join(parts)

## Painel de progressão permanente (U alterna): uma lista por branch, sem
## grafo visual — "requires" só vira texto "bloqueado até X" (ver
## UpgradeDef). Reconstrói inteiro a cada compra, é barato o bastante pra
## não precisar de diffing.
func _handle_upgrades_input() -> void:
	var u_pressed := Input.is_key_pressed(KEY_U)
	if u_pressed and not _upgrades_key_was_pressed:
		upgrades_panel.visible = not upgrades_panel.visible
		if upgrades_panel.visible:
			_close_crafting_panel()
			if _debug_panel:
				_debug_panel.visible = false
			if _map_panel:
				_map_panel.visible = false
			if _open_chest:
				_open_chest.close()
			_refresh_upgrades_panel()
	_upgrades_key_was_pressed = u_pressed

func _build_upgrades_panel() -> void:
	_upgrades_vbox = upgrades_panel.get_node("Scroll/VBox")
	UpgradeTracker.purchased.connect(func(_def: UpgradeDef) -> void: _refresh_upgrades_panel())

func _refresh_upgrades_panel() -> void:
	for child in _upgrades_vbox.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Progressão — essência: %d  (U fecha)" % GameState.get_total("essencia")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	_upgrades_vbox.add_child(title)
	for branch: UpgradeDef.Branch in BRANCH_NAMES:
		var defs := UpgradeTracker.get_branch(branch)
		if defs.is_empty():
			continue
		var branch_label := Label.new()
		branch_label.text = BRANCH_NAMES[branch]
		branch_label.add_theme_font_size_override("font_size", 15)
		_upgrades_vbox.add_child(branch_label)
		for def in defs:
			_upgrades_vbox.add_child(_build_upgrade_row(def))

func _build_upgrade_row(def: UpgradeDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(300, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var purchased := UpgradeTracker.is_purchased(def.id)
	var locked := def.requires != "" and not UpgradeTracker.is_purchased(def.requires)
	if purchased:
		lbl.text = "✓ %s — %s" % [def.display_name, def.description]
		lbl.modulate = Color(0.6, 1.0, 0.6)
	elif locked:
		var req_name := def.requires
		var req_def := UpgradeTracker.get_all().filter(func(d: UpgradeDef) -> bool: return d.id == def.requires)
		if not req_def.is_empty():
			req_name = req_def[0].display_name
		lbl.text = "🔒 %s — requer \"%s\"" % [def.display_name, req_name]
		lbl.modulate = Color(0.55, 0.55, 0.55)
	else:
		lbl.text = "%s — %s (%d essência)" % [def.display_name, def.description, def.cost_essencia]
	row.add_child(lbl)

	if not purchased and not locked:
		var btn := Button.new()
		btn.text = "Comprar"
		btn.disabled = not UpgradeTracker.can_purchase(def)
		btn.pressed.connect(func() -> void:
			if UpgradeTracker.purchase(def):
				_refresh_upgrades_panel()
				if crafting_panel.visible and _crafting_station_filter == "workbench":
					_build_recipe_rows()
		)
		row.add_child(btn)
	return row

## Menu de cheat (F1, só build de debug): um botão "+10" por item de
## categoria RESOURCE OU FOOD (data-driven via ItemDB.get_all() — item novo
## aparece sozinho, nada aqui precisa mudar; FOOD entrou jul/2026 pra
## Cogumelo/Refeição Reforçada aparecerem também, antes só recurso) + cura/
## saciedade cheia. Existe só pra testar a progressão sem precisar farmar em
## runs de verdade.
## Painel ancorado no TOPO-ESQUERDA (jul/2026, era CENTER_LEFT) + lista
## dentro de um ScrollContainer com altura máxima: a lista de botões cresceu
## (Lanterna Avançada, Resíduo Sombrio, agora Cogumelo/Refeição...) e o
## painel centralizado verticalmente passou a cortar no canto inferior
## esquerdo da tela em resoluções menores — mesmo padrão de scroll já usado
## no painel de craft/construção.
func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	$Control.add_child(_debug_panel)
	_debug_panel.visible = false
	_debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	var outer_vbox := VBoxContainer.new()
	_debug_panel.add_child(outer_vbox)
	var title := Label.new()
	title.text = "CHEAT (F1 fecha) — só em build de debug"
	title.add_theme_font_size_override("font_size", 16)
	outer_vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	for def in ItemDB.get_all():
		if def.category != ItemDef.Category.RESOURCE and def.category != ItemDef.Category.FOOD:
			continue
		var btn := Button.new()
		btn.text = "+10 %s" % def.display_name
		btn.pressed.connect(func() -> void: GameState.add_resource(def.id, 10))
		vbox.add_child(btn)
	var heal_btn := Button.new()
	heal_btn.text = "Curar + saciar tudo"
	heal_btn.pressed.connect(func() -> void:
		GameState.heal(GameState.max_health)
		GameState.eat(GameState.max_hunger)
	)
	vbox.add_child(heal_btn)

func _handle_debug_input() -> void:
	if _debug_panel == null:
		return
	var f1_pressed := Input.is_key_pressed(KEY_F1)
	if f1_pressed and not _debug_key_was_pressed:
		_debug_panel.visible = not _debug_panel.visible
		if _debug_panel.visible:
			_close_crafting_panel()
			upgrades_panel.visible = false
			if _map_panel:
				_map_panel.visible = false
			if _open_chest:
				_open_chest.close()
	_debug_key_was_pressed = f1_pressed

## Painel do modo construção (centro-esquerda, mesmo canto do cheat — os
## dois raramente coexistem e um fecha o outro ao abrir, ver abaixo). Só
## visível enquanto BuildMode.active; reconstrói a lista toda vez que o
## modo abre (estruturas desbloqueadas podem ter mudado desde a última vez).
## Virou clicável/scrollável (registrado jul/2026, mesmo estilo do painel de
## progressão — tecla U): antes era só texto (Label) numerado, e com 11
## estruturas (Baú Grande/Poste de Luz) já não cabiam mais 1 tecla por
## item — clicar na linha sempre funciona, não importa quantas estruturas
## existam. Tecla 1..0 e scroll do mouse continuam funcionando também (ver
## BuildMode._process/_unhandled_input) — o clique é só mais uma forma.
func _build_build_panel() -> void:
	_build_panel = PanelContainer.new()
	$Control.add_child(_build_panel)
	_build_panel.visible = false
	_build_panel.add_theme_stylebox_override("panel", crafting_panel.get_theme_stylebox("panel"))
	# CENTER_LEFT como o painel de cheat (F1) — os dois raramente abrem ao
	# mesmo tempo; evita qualquer risco de colidir com hotbar/objetivos.
	# Fica na borda esquerda (não centralizado como o de progressão) de
	# propósito: o jogador precisa continuar vendo o ghost seguindo o mouse
	# no resto da tela pra posicionar a construção depois de escolher.
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	_build_panel.custom_minimum_size = Vector2(340, 420)
	var scroll := ScrollContainer.new()
	_build_panel.add_child(scroll)
	_build_vbox = VBoxContainer.new()
	_build_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_build_vbox)

func _update_build_panel() -> void:
	if _build_panel == null:
		return
	if BuildMode.active and not _build_was_active:
		_refresh_build_panel()
		_close_crafting_panel()
		upgrades_panel.visible = false
		if _debug_panel:
			_debug_panel.visible = false
		if _map_panel:
			_map_panel.visible = false
		if _open_chest:
			_open_chest.close()
	_build_panel.visible = BuildMode.active
	_build_was_active = BuildMode.active
	if BuildMode.active:
		_highlight_build_selection()

## As teclas 1..0 só cobrem 10 estruturas (ver BuildMode.BUILD_KEYS); a
## partir da 11ª (jul/2026, com Baú Grande/Poste de Luz) a linha mostra
## "[scroll]" em vez de um número que não existe — clicar na linha sempre
## funciona independente disso (ver _build_row abaixo).
func _refresh_build_panel() -> void:
	for child in _build_vbox.get_children():
		child.queue_free()
	var key_count := BuildMode.get_key_count()
	var title := Label.new()
	title.text = "Construção — clique escolhe (ou [1..%d]/scroll) | B: sai" % mini(BuildMode.get_available().size(), key_count)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_size_override("font_size", 15)
	_build_vbox.add_child(title)
	for i in BuildMode.get_available().size():
		var def: StructureDef = BuildMode.get_available()[i]
		var tag := "[%d]" % (i + 1) if i < key_count else "[scroll]"
		_build_vbox.add_child(_build_row(i, def, tag))
	_highlight_build_selection()

## Uma linha do painel de construção: botão inteiro clicável (mesmo padrão
## do "Comprar" da progressão) que seleciona a estrutura direto — não
## depende de saber qual tecla apertar. `BuildMode.select_index` já ignora
## cliques repetidos no item já selecionado.
func _build_row(index: int, def: StructureDef, tag: String) -> Button:
	var btn := Button.new()
	btn.name = "Row%d" % index
	btn.text = "%s %s — %s" % [tag, def.display_name, BuildMode.get_cost_text(def)]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(func() -> void:
		BuildMode.select_index(index)
		_highlight_build_selection()
	)
	return btn

## Destaca o botão da estrutura selecionada agora (mesmo padrão da hotbar).
func _highlight_build_selection() -> void:
	var sel := BuildMode.get_selected_index()
	for i in _build_vbox.get_child_count() - 1:
		var row := _build_vbox.get_child(i + 1)  # +1 pula o título
		if row is Button:
			row.modulate = Color(1.35, 1.3, 0.85) if i == sel else Color.WHITE

## Mapa simples (M alterna): esquema de cima pra baixo da região ativa —
## jogador, bordas de região e estruturas construídas (ver ui/map_view.gd,
## que faz todo o desenho via _draw()). Centralizado na tela (painel maior,
## precisa de espaço) — fecha objetivos/craft/progressão/cheat/baú ao abrir.
func _build_map_panel() -> void:
	_map_panel = PanelContainer.new()
	$Control.add_child(_map_panel)
	_map_panel.visible = false
	_map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 10)
	var vbox := VBoxContainer.new()
	_map_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Mapa (M fecha)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	var view := MapView.new()
	view.custom_minimum_size = Vector2(260, 260)
	vbox.add_child(view)

func _handle_map_input() -> void:
	if _map_panel == null:
		return
	var m_pressed := Input.is_key_pressed(KEY_M)
	if m_pressed and not _map_key_was_pressed:
		_map_panel.visible = not _map_panel.visible
		if _map_panel.visible:
			_close_crafting_panel()
			upgrades_panel.visible = false
			if _debug_panel:
				_debug_panel.visible = false
			if _objectives_panel:
				_objectives_panel.visible = false
			if _open_chest:
				_open_chest.close()
	_map_key_was_pressed = m_pressed

## Painel de objetivos do bioma (canto superior direito; O alterna).
func _build_objectives_panel() -> void:
	_objectives_panel = PanelContainer.new()
	$Control.add_child(_objectives_panel)
	_objectives_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	# Ancorado à direita, o painel precisa crescer pra ESQUERDA (senão
	# expande pra fora da tela e os textos ficam cortados).
	_objectives_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objectives_panel.grow_vertical = Control.GROW_DIRECTION_END
	var vbox := VBoxContainer.new()
	_objectives_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Objetivos — Bioma 1  (O oculta)"
	vbox.add_child(title)
	for def in ObjectiveTracker.get_objectives(1):
		var lbl := Label.new()
		vbox.add_child(lbl)
		_objective_labels[def.id] = lbl
		_refresh_objective(def, ObjectiveTracker.get_progress(def.id))

func _refresh_objective(def: ObjectiveDef, current: int) -> void:
	var lbl: Label = _objective_labels.get(def.id)
	if lbl == null:
		return
	var done := current >= def.required
	lbl.text = "%s %s  %d/%d" % ["✓" if done else "•", def.display_name, current, def.required]
	lbl.modulate = Color(0.6, 1.0, 0.6) if done else Color.WHITE

func _on_objective_progress(def: ObjectiveDef, current: int) -> void:
	_refresh_objective(def, current)

## Toast central genérico (desbloqueios, queda na run...).
func _show_toast(text: String, font_size: int = 34) -> void:
	var toast := Label.new()
	toast.text = text
	toast.add_theme_font_size_override("font_size", font_size)
	toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	toast.add_theme_constant_override("outline_size", 6)
	$Control.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.position.y -= 80.0
	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.8)
	tween.tween_callback(toast.queue_free)

func _on_biome_unlocked(biome: int) -> void:
	_show_toast("Bioma %d desbloqueado!" % biome)

## Anúncio do modificador da run (ver RunModifierDef/WorldLayers.
## active_modifier) — dispara uma vez ao entrar no talismã, vale pra todos
## os mapas até voltar pra base.
func _on_run_modifier_rolled(mod: RunModifierDef) -> void:
	_show_toast("Modificador da run: %s\n%s" % [mod.display_name, mod.description], 26)

## Poções da Mesa de Alquimia (registrado jul/2026, ver GameState.
## apply_potion): toast ao beber e ao expirar, mesmo padrão do aviso de
## bioma desbloqueado — feedback claro de "o buff começou/acabou" sem
## precisar de uma barra de status dedicada ainda.
const _POTION_CHANNEL_NAMES := {
	"speed": "Velocidade",
	"attack": "Força",
	"defense": "Proteção",
}

func _on_potion_applied(display_name: String, duration: float) -> void:
	_show_toast("%s (%ds)" % [display_name, int(duration)], 24)

func _on_potion_expired(channel: String) -> void:
	var name: String = _POTION_CHANNEL_NAMES.get(channel, channel)
	_show_toast("Efeito de %s acabou." % name, 20)

## Itens PASSIVOS (Amuleto Vital/II — ver GameState._recompute_passive_
## bonuses): toast ao ganhar OU perder o bônus de vida máxima, mesmo
## padrão de feedback dos toasts de poção. Ganhar (craftar, tirar de um
## baú) e perder (dropar, guardar num baú) disparam os dois.
func _on_passive_bonus_changed(delta: float) -> void:
	if delta > 0.0:
		_show_toast("Vida máxima aumentada em %d" % int(delta), 24)
	else:
		_show_toast("Vida máxima reduzida em %d" % int(-delta), 24)

func _on_tool_equipped(item_id: String) -> void:
	if item_id == "":
		_tool_label.text = "Ferramenta: — (selecione na hotbar)"
	else:
		_tool_label.text = "Ferramenta: %s" % ItemDB.get_display_name(item_id)

func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
	health_value_label.text = "%d / %d" % [int(round(current)), int(round(max_value))]

func _on_hunger_changed(current: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = current
	hunger_value_label.text = "%d / %d" % [int(round(current)), int(round(max_value))]

## Abre o painel do baú (chamado por chest.gd via call_group("hud", ...)):
## liga cada slot da grade ao inventário DESSE baú e desenha o conteúdo.
func show_chest_panel(chest: Node) -> void:
	_close_crafting_panel()
	upgrades_panel.visible = false
	if _debug_panel:
		_debug_panel.visible = false
	if _open_chest and _open_chest != chest and _open_chest.inventory_changed.is_connected(_update_chest_panel):
		_open_chest.inventory_changed.disconnect(_update_chest_panel)
	_open_chest = chest
	if not chest.inventory_changed.is_connected(_update_chest_panel):
		chest.inventory_changed.connect(_update_chest_panel)
	for slot in _chest_slot_nodes:
		slot.container = chest
	chest_panel.visible = true
	_update_chest_panel()

## Fecha o painel do baú. `chest` opcional evita fechar por engano se outro
## baú (que não o aberto) chamar close() por qualquer motivo.
func hide_chest_panel(chest: Node = null) -> void:
	if chest != null and chest != _open_chest:
		return
	if _open_chest and _open_chest.inventory_changed.is_connected(_update_chest_panel):
		_open_chest.inventory_changed.disconnect(_update_chest_panel)
	_open_chest = null
	chest_panel.visible = false

## A grade tem 40 nós fixos (pra caber o Baú Grande, ver chest.gd
## slot_count) mas um baú normal só usa os 20 primeiros — os excedentes
## precisam ficar ESCONDIDOS (não só "sem dado"), senão um baú pequeno
## mostraria 20 slots fantasmas vazios (ou, pior, com lixo de uma sessão
## anterior de Baú Grande) no fim da grade.
func _update_chest_panel() -> void:
	if _open_chest == null:
		return
	var capacity: int = _open_chest.inventory.size()
	for i in _chest_slot_nodes.size():
		var slot_node = _chest_slot_nodes[i]
		slot_node.visible = i < capacity
		if i < capacity:
			slot_node.set_slot_data(_open_chest.inventory[i])

## Redesenha a grade inteira a partir de GameState.inventory — chamado toda
## vez que qualquer slot muda (coleta, craft, comer, arrastar).
func _update_inventory() -> void:
	for i in _slot_nodes.size():
		if i >= GameState.inventory.size():
			break
		_slot_nodes[i].set_slot_data(GameState.inventory[i])

func _on_player_died() -> void:
	# Morte unificada: nunca pausa nem apaga o save — o WorldLayers
	# revive na base em 2s (pilar 3). Recomeço total vira opção de menu.
	hide_chest_panel()
	if WorldLayers.in_run:
		_show_toast("Você caiu... o talismã te puxa de volta.", 20)
	else:
		_show_toast("Você desmaiou... e acorda em casa.", 20)
