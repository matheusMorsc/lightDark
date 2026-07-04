extends CanvasLayer
## HUD: barras de vida/fome, grade de inventário (drag-and-drop) e painel
## de crafting.

@onready var health_bar: ProgressBar = $Control/VBoxContainer/HealthBar
@onready var hunger_bar: ProgressBar = $Control/VBoxContainer/HungerBar
@onready var slots_grid: GridContainer = $Control/InventoryPanel/VBox/SlotsGrid
@onready var tutorial_panel: PanelContainer = $Control/TutorialPanel
@onready var death_screen: Control = $Control/DeathScreen
@onready var crafting_panel: PanelContainer = $Control/CraftingPanel
@onready var crafting_status_label: Label = $Control/CraftingPanel/VBoxContainer/StatusLabel
@onready var chest_panel: PanelContainer = $Control/ChestPanel
@onready var upgrades_panel: PanelContainer = $Control/UpgradesPanel

@export var tutorial_duration: float = 6.0
@export var tutorial_fade_duration: float = 1.0

## Teclas de craft (o painel se monta sozinho a partir do RecipeDB).
const RECIPE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const HOTBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var _restart_key_was_pressed: bool = false
var _craft_menu_key_was_pressed: bool = false
var _craft_slot_key_was_pressed: Array[bool] = []
var _recipes: Array[RecipeDef] = []
var _slot_nodes: Array = []
var _tool_label: Label
var _objectives_panel: PanelContainer
var _objective_labels: Dictionary = {}
var _objectives_key_was_pressed: bool = false
var _hotbar_key_was_pressed: Array[bool] = []
var _esc_was_pressed: bool = false
var _pause_root: Control
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
	_build_recipe_rows()
	_setup_hotbar()
	_build_pause_menu()

	_on_health_changed(GameState.health, GameState.max_health)
	_on_hunger_changed(GameState.hunger, GameState.max_hunger)
	_update_inventory()

	get_tree().create_timer(tutorial_duration).timeout.connect(_hide_tutorial)

	# Indicador da ferramenta equipada (abaixo das barras de vida/fome).
	_tool_label = Label.new()
	$Control/VBoxContainer.add_child(_tool_label)
	GameState.tool_equipped.connect(_on_tool_equipped)
	GameState.inventory_changed.connect(func() -> void: GameState.get_equipped_tool())
	_on_tool_equipped(GameState.equipped_tool_id)

	_build_objectives_panel()
	ObjectiveTracker.progress_changed.connect(_on_objective_progress)
	ObjectiveTracker.biome_unlocked.connect(_on_biome_unlocked)

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
	if _pause_root.visible:
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
		crafting_panel.visible = false
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
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(280, 0)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "Pausado"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	var vol_row := HBoxContainer.new()
	vbox.add_child(vol_row)
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
	vbox.add_child(resume)
	_restart_button = Button.new()
	_restart_button.text = "Recomeçar do zero"
	_restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(_restart_button)
	var quit := Button.new()
	quit.text = "Salvar e sair"
	quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit)

func _open_pause() -> void:
	_confirm_restart = false
	_restart_button.text = "Recomeçar do zero"
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
		crafting_panel.visible = not crafting_panel.visible
		crafting_status_label.text = ""
		if crafting_panel.visible:
			upgrades_panel.visible = false
			if _debug_panel:
				_debug_panel.visible = false
			if _map_panel:
				_map_panel.visible = false
			if _open_chest:
				_open_chest.close()
	_craft_menu_key_was_pressed = c_pressed

	if not crafting_panel.visible:
		return

	for i in _recipes.size():
		var pressed := Input.is_key_pressed(RECIPE_KEYS[i])
		if pressed and not _craft_slot_key_was_pressed[i]:
			_try_craft(i)
		_craft_slot_key_was_pressed[i] = pressed

func _try_craft(index: int) -> void:
	var recipe: RecipeDef = _recipes[index]
	if GameState.craft(recipe.id, recipe.costs, recipe.result_id, recipe.result_count):
		if recipe.bonus_max_health > 0.0:
			GameState.max_health += recipe.bonus_max_health
		if recipe.heal_on_craft > 0.0:
			GameState.heal(recipe.heal_on_craft)
		crafting_status_label.text = "Craftado: %s!" % recipe.display_name
	else:
		crafting_status_label.text = "Recursos insuficientes para %s." % recipe.display_name

## Monta as linhas do painel de craft a partir do RecipeDB (data-driven):
## remove as linhas estáticas da cena e gera uma por receita carregada.
func _build_recipe_rows() -> void:
	var vbox := crafting_status_label.get_parent()
	for n in ["Recipe1Row", "Recipe2Row", "Recipe3Row"]:
		var row := vbox.get_node_or_null(n)
		if row:
			row.queue_free()
	_recipes = RecipeDB.get_all()
	_craft_slot_key_was_pressed.resize(mini(_recipes.size(), RECIPE_KEYS.size()))
	for i in mini(_recipes.size(), RECIPE_KEYS.size()):
		var r: RecipeDef = _recipes[i]
		var row := HBoxContainer.new()
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = r.icon if r.icon else ItemDB.get_icon(r.result_id)
		row.add_child(icon_rect)
		var lbl := Label.new()
		lbl.text = "[%d] %s — %s" % [i + 1, r.display_name, _costs_text(r.costs)]
		row.add_child(lbl)
		vbox.add_child(row)
	vbox.move_child(crafting_status_label, -1)

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
			crafting_panel.visible = false
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
		)
		row.add_child(btn)
	return row

## Menu de cheat (F1, só build de debug): um botão "+10" por item de
## categoria RESOURCE (data-driven via ItemDB.get_all() — item novo aparece
## sozinho, nada aqui precisa mudar) + cura/saciedade cheia. Existe só pra
## testar a progressão sem precisar farmar em runs de verdade.
func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	$Control.add_child(_debug_panel)
	_debug_panel.visible = false
	_debug_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	var vbox := VBoxContainer.new()
	_debug_panel.add_child(vbox)
	var title := Label.new()
	title.text = "CHEAT (F1 fecha) — só em build de debug"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	for def in ItemDB.get_all():
		if def.category != ItemDef.Category.RESOURCE:
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
			crafting_panel.visible = false
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
func _build_build_panel() -> void:
	_build_panel = PanelContainer.new()
	$Control.add_child(_build_panel)
	_build_panel.visible = false
	# CENTER_LEFT como o painel de cheat (F1) — os dois raramente abrem ao
	# mesmo tempo; evita qualquer risco de colidir com hotbar/objetivos.
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	_build_vbox = VBoxContainer.new()
	_build_panel.add_child(_build_vbox)

func _update_build_panel() -> void:
	if _build_panel == null:
		return
	if BuildMode.active and not _build_was_active:
		_refresh_build_panel()
		crafting_panel.visible = false
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

func _refresh_build_panel() -> void:
	for child in _build_vbox.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Construção — [1..%d] escolhe | clique: constrói | B: sai" % BuildMode.get_available().size()
	title.add_theme_font_size_override("font_size", 14)
	_build_vbox.add_child(title)
	for i in BuildMode.get_available().size():
		var def: StructureDef = BuildMode.get_available()[i]
		var lbl := Label.new()
		lbl.name = "Row%d" % i
		lbl.text = "[%d] %s — %s" % [i + 1, def.display_name, BuildMode.get_cost_text(def)]
		_build_vbox.add_child(lbl)
	_highlight_build_selection()

## Destaca a linha da estrutura selecionada agora (mesmo padrão do hotbar).
func _highlight_build_selection() -> void:
	var sel := BuildMode.get_selected_index()
	for i in _build_vbox.get_child_count() - 1:
		var row := _build_vbox.get_child(i + 1)  # +1 pula o título
		if row is Label:
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
			crafting_panel.visible = false
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

func _on_tool_equipped(item_id: String) -> void:
	if item_id == "":
		_tool_label.text = "Ferramenta: — (Q alterna)"
	else:
		_tool_label.text = "Ferramenta: %s" % ItemDB.get_display_name(item_id)

func _hide_tutorial() -> void:
	var tween := create_tween()
	tween.tween_property(tutorial_panel, "modulate:a", 0.0, tutorial_fade_duration)
	tween.tween_callback(tutorial_panel.hide)

func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current

func _on_hunger_changed(current: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = current

## Abre o painel do baú (chamado por chest.gd via call_group("hud", ...)):
## liga cada slot da grade ao inventário DESSE baú e desenha o conteúdo.
func show_chest_panel(chest: Node) -> void:
	crafting_panel.visible = false
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

func _update_chest_panel() -> void:
	if _open_chest == null:
		return
	for i in _chest_slot_nodes.size():
		if i >= _open_chest.inventory.size():
			break
		_chest_slot_nodes[i].set_slot_data(_open_chest.inventory[i])

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
