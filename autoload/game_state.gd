extends Node
## GameState (autoload)
## Guarda o estado global e simples do protótipo: vida, fome e recursos coletados.
## Qualquer script pode acessar isso globalmente como "GameState.xxx".

signal health_changed(current: float, max_value: float)
signal hunger_changed(current: float, max_value: float)
signal resource_changed(resource_name: String, total: int)
signal player_died
signal player_damaged(amount: float)
signal recipe_crafted(recipe_id: String)

@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var hunger_drain_per_second: float = 1.0
@export var starve_damage_per_second: float = 3.0

var health: float = max_health
var hunger: float = max_hunger
var resources: Dictionary = {} # ex: {"comida": 3}
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

## Tenta remover `amount` unidades de um recurso. Retorna true e desconta se
## houver o suficiente; retorna false sem alterar nada caso contrário.
func remove_resource(resource_name: String, amount: int = 1) -> bool:
	var current: int = resources.get(resource_name, 0)
	if current < amount:
		return false
	resources[resource_name] = current - amount
	resource_changed.emit(resource_name, resources[resource_name])
	return true

## true se houver recursos suficientes para cobrir todos os custos de `costs`
## (ex: {"minerio": 3, "comida": 2}), sem alterar nada.
func can_afford(costs: Dictionary) -> bool:
	for resource_name in costs:
		if resources.get(resource_name, 0) < int(costs[resource_name]):
			return false
	return true

## Desconta todos os custos de uma vez (só se puder pagar tudo — atômico) e
## avisa quem quiser reagir ao craft (ex: o player aplicando um bônus).
func craft(recipe_id: String, costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for resource_name in costs:
		remove_resource(resource_name, int(costs[resource_name]))
	recipe_crafted.emit(recipe_id)
	return true

func reset() -> void:
	health = max_health
	hunger = max_hunger
	resources.clear()
	is_dead = false
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
