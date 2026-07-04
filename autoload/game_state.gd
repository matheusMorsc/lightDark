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
## Emitido quando a soma de bônus passivos (ver `_recompute_passive_bonuses`)
## muda — HUD mostra um toast "Vida aumentada/reduzida em X" (mesmo padrão
## do toast de poção). delta > 0 = ganhou item passivo, < 0 = perdeu.
signal passive_bonus_changed(delta: float)

const INVENTORY_SIZE: int = 10
## Vida máxima SEM nenhum item passivo — a vida máxima "de verdade"
## (`max_health`) é sempre BASE_MAX_HEALTH + passive_bonus_max_health (ver
## `_recompute_passive_bonuses`), nunca editada diretamente por fora disso
## (registrado jul/2026: o usuário queria a ESCALA da barra de vida
## previsível — antes `hud.gd` somava `RecipeDef.bonus_max_health` direto em
## `max_health` no craft, sem ligação nenhuma com o inventário; se o item
## sumisse o bônus continuava lá pra sempre).
const BASE_MAX_HEALTH: float = 100.0

@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
## Soma atual de `ItemDef.passive_bonus_max_health` de tudo que está no
## inventário — ver `_recompute_passive_bonuses`.
var passive_bonus_max_health: float = 0.0
## Ligado só pelo SaveManager durante o load (ver save_manager.gd::
## load_game): recalcula o bônus (matemática normal) mas NÃO dispara o
## toast de "vida aumentada" — sem isso, carregar um save com um Amuleto
## Vital guardado mostrava a mensagem toda vez, como se o item tivesse
## acabado de ser ganho.
var _silent_passive_recompute: bool = false
## Reduzido de 0.3 pra 0.15 (jul/2026, pedido do usuário — fome descia rápido
## demais): de ~5.5min até zerar pra ~11min com fome cheia.
@export var hunger_drain_per_second: float = 0.15
@export var starve_damage_per_second: float = 3.0

var health: float = max_health
var hunger: float = max_hunger
var is_dead: bool = false

## I-frames genéricas (hoje só o dash do player usa): enquanto true,
## take_damage() não faz nada. Qualquer sistema pode ligar/desligar.
var invulnerable: bool = false

## Multiplicadores/bônus permanentes da árvore de progressão (ver
## UpgradeTracker) — 1.0/0.0 = sem bônus nenhum. Quem lê: player.gd (dano,
## dash, velocidade, lanterna) e resource_node.gd (coleta). Comprar um
## upgrade soma/multiplica aqui na hora; carregar o save reaplica do zero
## a partir da lista de upgrades comprados (esses valores não são salvos
## diretamente).
var attack_damage_mult: float = 1.0
var dash_cooldown_mult: float = 1.0
var speed_mult: float = 1.0
var lantern_range_mult: float = 1.0
var resource_yield_bonus_pct: float = 0.0

## Buffs TEMPORÁRIOS da Mesa de Alquimia (registrado jul/2026, ver
## "RecipeDef.potion_*" e hud.gd::_try_craft — craftar uma poção é bebê-la
## na hora, sem item passando pelo inventário; diferente do Amuleto Vital,
## que virou item PASSIVO de verdade — ver _recompute_passive_bonuses
## abaixo). Multiplicam POR CIMA dos multiplicadores permanentes
## acima (ex.: dano final = base * attack_damage_mult * potion_attack_mult),
## nunca substituem. Só existem 3 canais de propósito (velocidade, ataque,
## defesa) — igual ao design "poucos afixos fixos" já usado no elite das
## runs; se precisar de mais no futuro, adicionar mais um par mult/timer.
## Beber uma poção de canal já ativo RENOVA a duração com o novo valor (não
## empilha, não builda "deus-mode" tomando 3 poções de força seguidas).
var potion_speed_mult: float = 1.0
var potion_attack_mult: float = 1.0
## Multiplica o DANO RECEBIDO (0.6 = 40% de redução) — ver take_damage().
var potion_defense_mult: float = 1.0

var _potion_speed_time_left: float = 0.0
var _potion_attack_time_left: float = 0.0
var _potion_defense_time_left: float = 0.0

## Emitido quando uma poção é bebida (toast no HUD) e quando o efeito
## expira sozinho (aviso "acabou") — ver hud.gd.
signal potion_applied(display_name: String, duration: float)
signal potion_expired(channel: String)

## Ferramenta atualmente equipada ("" = mãos livres). Validada contra o
## inventário em get_equipped_tool() — sumiu do inventário, desequipa.
var equipped_tool_id: String = ""

## Slot selecionado na hotbar (1..0 ou scroll). Selecionar uma ferramenta
## equipa na hora; selecionar qualquer outra coisa (comida, recurso, slot
## vazio) desequipa — ver select_slot(). Comida selecionada é a que o
## botão direito do mouse consome (ver player.gd::_eat).
var selected_slot: int = 0

## Array de tamanho fixo INVENTORY_SIZE. Cada slot é null (vazio) ou
## {"item_id": String, "count": int}.
var inventory: Array = []

func _ready() -> void:
	# Conectado ANTES do reset() de propósito: reset() termina emitindo
	# inventory_changed, e essa primeira chamada já precisa recalcular o
	# bônus passivo (fica em 0, inventário vazio) pra deixar tudo
	# consistente desde o boot.
	inventory_changed.connect(_recompute_passive_bonuses)
	reset()

func _process(delta: float) -> void:
	if is_dead:
		return

	hunger = max(0.0, hunger - hunger_drain_per_second * delta)
	hunger_changed.emit(hunger, max_hunger)

	if hunger <= 0.0:
		take_damage(starve_damage_per_second * delta)

	_update_potion_timer("speed", delta)
	_update_potion_timer("attack", delta)
	_update_potion_timer("defense", delta)

## Conta regressiva de UM canal de poção — ao chegar em 0, o multiplicador
## volta pra 1.0 (efeito neutro) sozinho e avisa quem estiver de olho
## (ver potion_expired, usado pelo toast do HUD).
func _update_potion_timer(channel: String, delta: float) -> void:
	var time_left := _get_potion_time_left(channel)
	if time_left <= 0.0:
		return
	time_left = maxf(0.0, time_left - delta)
	_set_potion_time_left(channel, time_left)
	if time_left <= 0.0:
		_set_potion_mult(channel, 1.0)
		potion_expired.emit(channel)

func _get_potion_time_left(channel: String) -> float:
	match channel:
		"speed": return _potion_speed_time_left
		"attack": return _potion_attack_time_left
		"defense": return _potion_defense_time_left
		_: return 0.0

func _set_potion_time_left(channel: String, value: float) -> void:
	match channel:
		"speed": _potion_speed_time_left = value
		"attack": _potion_attack_time_left = value
		"defense": _potion_defense_time_left = value

func _set_potion_mult(channel: String, value: float) -> void:
	match channel:
		"speed": potion_speed_mult = value
		"attack": potion_attack_mult = value
		"defense": potion_defense_mult = value

## Bebe uma poção (chamado por hud.gd::_try_craft ao craftar uma receita
## com `potion_channel` setado — ver recipe_def.gd). Renova a duração em
## vez de empilhar: beber a mesma poção de novo só estica o tempo restante
## com o novo valor, nunca soma multiplicador em cima de multiplicador.
func apply_potion(channel: String, mult: float, duration: float, display_name: String) -> void:
	_set_potion_mult(channel, mult)
	_set_potion_time_left(channel, duration)
	potion_applied.emit(display_name, duration)

## Recalcula o bônus de vida máxima vindo de itens PASSIVOS (Amuleto Vital/
## II — ver ItemDef.Category.PASSIVE) presentes em QUALQUER slot do
## inventário — basta existir, não precisa estar selecionado (diferente de
## ferramenta/arma). Conectado em `inventory_changed` (ver _ready()), roda
## de novo toda vez que o inventário muda — perder o item (chest, drop)
## remove o bônus na hora, ganhar aplica sozinho.
## `max_health` nunca é mais editado diretamente por fora daqui (registrado
## jul/2026 — antes hud.gd::_try_craft somava RecipeDef.bonus_max_health
## direto em max_health no craft, sem ligação com o inventário: a vida
## máxima só crescia, nunca voltava, e a "escala" da barra virava
## imprevisível). Ganhar bônus (delta > 0) também cura o mesmo tanto (mesma
## sensação do heal_on_craft antigo); perder só reduz o teto, sem dano.
func _recompute_passive_bonuses() -> void:
	var total := 0.0
	for slot in inventory:
		if slot == null:
			continue
		var def: ItemDef = ItemDB.get_def(slot.item_id)
		if def != null and def.category == ItemDef.Category.PASSIVE:
			total += def.passive_bonus_max_health * slot.count
	if is_equal_approx(total, passive_bonus_max_health):
		return
	var delta := total - passive_bonus_max_health
	passive_bonus_max_health = total
	max_health = BASE_MAX_HEALTH + passive_bonus_max_health
	health = clampf(health + maxf(delta, 0.0), 0.0, max_health)
	health_changed.emit(health, max_health)
	if not _silent_passive_recompute:
		passive_bonus_changed.emit(delta)

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0 or invulnerable:
		return
	var mitigated := amount * potion_defense_mult
	health = max(0.0, health - mitigated)
	health_changed.emit(health, max_health)
	player_damaged.emit(mitigated)
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

## Selecionar um slot com ferramenta/arma equipa na hora; selecionar
## QUALQUER outra coisa (comida, recurso, slot vazio) desequipa — sem isso,
## o item equipado ficava "grudado" ao trocar de slot (bug real: dava pra
## usar o ataque especial em área, que exige arma, mesmo com a espada há
## muito fora do slot selecionado, só porque ela tinha sido equipada antes
## e nunca foi explicitamente trocada por outra ferramenta).
func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, INVENTORY_SIZE - 1)
	var slot: Variant = inventory[selected_slot] if selected_slot < inventory.size() else null
	var def: ItemDef = ItemDB.get_def(slot.item_id) if slot != null else null
	if def and def.category == ItemDef.Category.TOOL:
		equip_tool(slot.item_id)
	elif equipped_tool_id != "":
		equipped_tool_id = ""
		tool_equipped.emit("")
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
	passive_bonus_max_health = 0.0
	max_health = BASE_MAX_HEALTH
	health = max_health
	hunger = max_hunger
	is_dead = false
	invulnerable = false
	attack_damage_mult = 1.0
	dash_cooldown_mult = 1.0
	speed_mult = 1.0
	lantern_range_mult = 1.0
	resource_yield_bonus_pct = 0.0
	potion_speed_mult = 1.0
	potion_attack_mult = 1.0
	potion_defense_mult = 1.0
	_potion_speed_time_left = 0.0
	_potion_attack_time_left = 0.0
	_potion_defense_time_left = 0.0
	equipped_tool_id = ""
	tool_equipped.emit("")
	inventory = []
	inventory.resize(INVENTORY_SIZE)
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
	# Emite por último: inventário vazio -> _recompute_passive_bonuses (ver
	# _ready()) confirma bônus 0, sem reemitir health_changed de novo (delta
	# já é 0, is_equal_approx sai cedo).
	inventory_changed.emit()
