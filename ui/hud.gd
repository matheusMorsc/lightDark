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

@export var tutorial_duration: float = 6.0
@export var tutorial_fade_duration: float = 1.0

const RECIPES := [
	{"id": "ferramenta", "name": "Ferramenta Reforçada", "costs": {"minerio": 3, "comida": 2}},
	{"id": "refeicao", "name": "Refeição Reforçada", "costs": {"comida": 5}},
	{"id": "fortificacao", "name": "Fortificação", "costs": {"pedra": 4}},
]
const RECIPE_KEYS := [KEY_1, KEY_2, KEY_3]

var _restart_key_was_pressed: bool = false
var _craft_menu_key_was_pressed: bool = false
var _craft_slot_key_was_pressed: Array[bool] = [false, false, false]
var _slot_nodes: Array = []

func _ready() -> void:
	# Continua processando mesmo com a árvore pausada (necessário pra tela de
	# morte funcionar e detectar a tecla de reiniciar).
	process_mode = Node.PROCESS_MODE_ALWAYS

	GameState.health_changed.connect(_on_health_changed)
	GameState.hunger_changed.connect(_on_hunger_changed)
	GameState.inventory_changed.connect(_update_inventory)
	GameState.player_died.connect(_on_player_died)

	_slot_nodes = slots_grid.get_children()

	_on_health_changed(GameState.health, GameState.max_health)
	_on_hunger_changed(GameState.hunger, GameState.max_hunger)
	_update_inventory()

	get_tree().create_timer(tutorial_duration).timeout.connect(_hide_tutorial)

func _process(_delta: float) -> void:
	if death_screen.visible:
		var restart_pressed := Input.is_key_pressed(KEY_R)
		if restart_pressed and not _restart_key_was_pressed:
			_restart()
		_restart_key_was_pressed = restart_pressed
		return

	_handle_crafting_input()

func _restart() -> void:
	GameState.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _handle_crafting_input() -> void:
	var c_pressed := Input.is_key_pressed(KEY_C)
	if c_pressed and not _craft_menu_key_was_pressed:
		crafting_panel.visible = not crafting_panel.visible
		crafting_status_label.text = ""
	_craft_menu_key_was_pressed = c_pressed

	if not crafting_panel.visible:
		return

	for i in RECIPES.size():
		var pressed := Input.is_key_pressed(RECIPE_KEYS[i])
		if pressed and not _craft_slot_key_was_pressed[i]:
			_try_craft(i)
		_craft_slot_key_was_pressed[i] = pressed

func _try_craft(index: int) -> void:
	var recipe: Dictionary = RECIPES[index]
	if GameState.craft(recipe.id, recipe.costs):
		if recipe.id == "refeicao":
			GameState.max_health += 20.0
			GameState.heal(20.0)
		elif recipe.id == "fortificacao":
			GameState.max_health += 15.0
		crafting_status_label.text = "Craftado: %s!" % recipe.name
	else:
		crafting_status_label.text = "Recursos insuficientes para %s." % recipe.name

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

## Redesenha a grade inteira a partir de GameState.inventory — chamado toda
## vez que qualquer slot muda (coleta, craft, comer, arrastar).
func _update_inventory() -> void:
	for i in _slot_nodes.size():
		if i >= GameState.inventory.size():
			break
		_slot_nodes[i].set_slot_data(GameState.inventory[i])

func _on_player_died() -> void:
	death_screen.visible = true
	get_tree().paused = true
