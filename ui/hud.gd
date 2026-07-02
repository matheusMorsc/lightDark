extends CanvasLayer
## HUD simples: barra de vida, barra de fome e contador de recursos.

@onready var health_bar: ProgressBar = $Control/VBoxContainer/HealthBar
@onready var hunger_bar: ProgressBar = $Control/VBoxContainer/HungerBar
@onready var resources_label: Label = $Control/VBoxContainer/ResourcesLabel

func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.hunger_changed.connect(_on_hunger_changed)
	GameState.resource_changed.connect(_on_resource_changed)
	GameState.player_died.connect(_on_player_died)

	_on_health_changed(GameState.health, GameState.max_health)
	_on_hunger_changed(GameState.hunger, GameState.max_hunger)
	_update_resources_label()

func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current

func _on_hunger_changed(current: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = current

func _on_resource_changed(_resource_name: String, _total: int) -> void:
	_update_resources_label()

func _update_resources_label() -> void:
	if GameState.resources.is_empty():
		resources_label.text = "Recursos: -"
		return
	var parts: PackedStringArray = []
	for key in GameState.resources.keys():
		parts.append("%s: %d" % [key, GameState.resources[key]])
	resources_label.text = "Recursos: " + ", ".join(parts)

func _on_player_died() -> void:
	resources_label.text += "\nVocê morreu! (reinicie a cena com F5 / botão de play)"
