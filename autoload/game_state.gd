extends Node
## GameState (autoload)
## Guarda o estado global e simples do protótipo: vida, fome e recursos coletados.
## Qualquer script pode acessar isso globalmente como "GameState.xxx".

signal health_changed(current: float, max_value: float)
signal hunger_changed(current: float, max_value: float)
signal resource_changed(resource_name: String, total: int)
signal player_died
signal player_damaged(amount: float)

@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var hunger_drain_per_second: float = 1.0
@export var starve_damage_per_second: float = 3.0

var health: float = max_health
var hunger: float = max_hunger
var resources: Dictionary = {} # ex: {"madeira": 3}
var is_dead: bool = false

func _ready() -> void:
	reset()

func _process(delta: float) -> void:
	if is_dead:
		return

	hunger = max(0.0, hunger - hunger_drain_per_second * delta)
	hunger_changed.emit(hunger, max_hunger)

	if hunger <= 0.0:
		take_damage(starve_damage_per_second * delta)

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	player_damaged.emit(amount)
	if health <= 0.0:
		is_dead = true
		player_died.emit()

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)

func eat(amount: float) -> void:
	hunger = min(max_hunger, hunger + amount)
	hunger_changed.emit(hunger, max_hunger)

func add_resource(resource_name: String, amount: int = 1) -> void:
	resources[resource_name] = resources.get(resource_name, 0) + amount
	resource_changed.emit(resource_name, resources[resource_name])

func reset() -> void:
	health = max_health
	hunger = max_hunger
	resources.clear()
	is_dead = false
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
