extends Node
## GameState (autoload)
## Guarda o estado global do protótipo: vida, fome e o inventário do
## jogador. O inventário é uma grade real de slots (não mais um Dictionary
## de contadores) — cada slot guarda {"item_id": String, "count": int} ou
## null se vazio. Empilha automaticamente até o máximo de cada item
## (ver ItemDB) e serve tanto de "mochila" quanto de "estoque global": não
## existe baú físico, os recursos coletados vão direto pra essa grade.

signal health_changed(current: float, max_value: float)
signal hunger_changed(current: float, max_value: float)
signal resource_changed(resource_name: String, total: int)
signal inventory_changed
signal player_died
signal player_damaged(amount: float)
signal recipe_crafted(recipe_id: String)
signal tool_equipped(item_id: String)
signal selected_slot_changed(index: int)

const INVENTORY_SIZE: int = 10

@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var hunger_drain_per_second: float = 0.3
@export var starve_damage_per_second: float = 3.0

var health: float = max_health
var hunger: float = max_hunger
var is_dead: bool = false

## Ferramenta atualmente equipada ("" = mãos livres). Validada contra o
## inventário em get_equipped_tool() — sumiu do inventário, desequipa.
var equipped_tool_id: String = ""

## Slot selecionado na hotbar (1..0 ou scroll). Selecionar uma ferramenta
## equipa na hora; comida selecionada é a que o E consome primeiro.
var selected_slot: int = 0

## Array de tamanho fixo INVENTORY_SIZE. Cada slot é null (vazio) ou
## {"item_id": String, "count": int}.
var inventory: Array = []

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

## Soma unidades de um item ao inventário: preenche pilhas existentes desse
## item primeiro, depois usa slots vazios. Se não houver espaço nenhum, o
## excedente é perdido (retorna quanto de fato coube).
func add_resource(item_id: String, amount: int = 1) -> int:
	var max_stack: int = ItemDB.get_max_stack(item_id)
	var remaining: int = amount

	for i in inventory.size():
		if remaining <= 0:
			break
		var slot = inventory[i]
		if slot != null and slot.item_id == item_id and slot.count < max_stack:
			var space: int = max_stack - slot.count
			var add_amount: int = min(space, remaining)
			slot.count += add_amount
			remaining -= add_amount

	for i in inventory.size():
		if remaining <= 0:
			break
		if inventory[i] == null:
			var add_amount: int = min(max_stack, remaining)
			inventory[i] = {"item_id": item_id, "count": add_amount}
			remaining -= add_amount

	var added: int = amount - remaining
	if added > 0:
		resource_changed.emit(item_id, get_total(item_id))
		inventory_changed.emit()
		ObjectiveTracker.notify_collected(item_id, added)
	return added

## Tenta remover `amount` unidades de um item. Retorna true e desconta
## (varrendo slots até zerar a quantia) se houver o suficiente no total;
## retorna false sem alterar nada caso contrário (atômico).
func remove_resource(item_id: String, amount: int = 1) -> bool:
	if get_total(item_id) < amount:
		return false

	var remaining: int = amount
	for i in inventory.size():
		if remaining <= 0:
			break
		var slot = inventory[i]
		if slot != null and slot.item_id == item_id:
			var take: int = min(slot.count, remaining)
			slot.count -= take
			remaining -= take
			if slot.count <= 0:
				inventory[i] = null

	resource_changed.emit(item_id, get_total(item_id))
	inventory_changed.emit()
	return true

## Soma quantas unidades de um item existem no inventário inteiro.
func get_total(item_id: String) -> int:
	var total := 0
	for slot in inventory:
		if slot != null and slot.item_id == item_id:
			total += slot.count
	return total

## Troca o conteúdo de dois slots (drag-and-drop na UI). Se os dois slots
## tiverem o mesmo item, empilha em vez de trocar (até o máximo, sobra fica
## no slot de origem) — comportamento padrão de inventário de grade.
func swap_slots(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= inventory.size() or b >= inventory.size():
		return
	var slot_a = inventory[a]
	var slot_b = inventory[b]

	if slot_a != null and slot_b != null and slot_a.item_id == slot_b.item_id:
		var max_stack: int = ItemDB.get_max_stack(slot_b.item_id)
		var space: int = max_stack - slot_b.count
		if space > 0:
			var moved: int = min(space, slot_a.count)
			slot_b.count += moved
			slot_a.count -= moved
			if slot_a.count <= 0:
				inventory[a] = null
			inventory_changed.emit()
			return

	inventory[a] = slot_b
	inventory[b] = slot_a
	inventory_changed.emit()

## true se houver itens suficientes para cobrir todos os custos de `costs`
## (ex: {"minerio": 3, "comida": 2}), sem alterar nada.
func can_afford(costs: Dictionary) -> bool:
	for item_id in costs:
		if get_total(item_id) < int(costs[item_id]):
			return false
	return true

## Desconta todos os custos de uma vez (só se puder pagar tudo — atômico),
## entrega o item resultante (se houver) e avisa quem quiser reagir.
## Ferramentas craftadas são equipadas na hora.
func craft(recipe_id: String, costs: Dictionary, result_id: String = "", result_count: int = 1) -> bool:
	if not can_afford(costs):
		return false
	for item_id in costs:
		remove_resource(item_id, int(costs[item_id]))
	if result_id != "":
		add_resource(result_id, result_count)
		var def: ItemDef = ItemDB.get_def(result_id)
		if def and def.category == ItemDef.Category.TOOL:
			equip_tool(result_id)
	recipe_crafted.emit(recipe_id)
	return true

func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, INVENTORY_SIZE - 1)
	var slot: Variant = inventory[selected_slot] if selected_slot < inventory.size() else null
	if slot != null:
		var def: ItemDef = ItemDB.get_def(slot.item_id)
		if def and def.category == ItemDef.Category.TOOL:
			equip_tool(slot.item_id)
	selected_slot_changed.emit(selected_slot)

## Equipa uma ferramenta que esteja no inventário.
func equip_tool(item_id: String) -> bool:
	var def: ItemDef = ItemDB.get_def(item_id)
	if def == null or def.category != ItemDef.Category.TOOL or get_total(item_id) <= 0:
		return false
	equipped_tool_id = item_id
	tool_equipped.emit(item_id)
	return true

## Ferramenta equipada (ou null). Se ela não está mais no inventário,
## desequipa automaticamente.
func get_equipped_tool() -> ItemDef:
	if equipped_tool_id == "":
		return null
	if get_total(equipped_tool_id) <= 0:
		equipped_tool_id = ""
		tool_equipped.emit("")
		return null
	return ItemDB.get_def(equipped_tool_id)

## true se a ferramenta equipada cobre o requisito (tipo + tier mínimo).
## Requisito de tipo vazio = coleta à mão, sempre passa.
func has_tool(tool_type: String, tier: int) -> bool:
	if tool_type == "":
		return true
	var def := get_equipped_tool()
	return def != null and def.tool_type == tool_type and def.tool_tier >= tier

func reset() -> void:
	health = max_health
	hunger = max_hunger
	is_dead = false
	equipped_tool_id = ""
	tool_equipped.emit("")
	inventory = []
	inventory.resize(INVENTORY_SIZE)
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
	inventory_changed.emit()
