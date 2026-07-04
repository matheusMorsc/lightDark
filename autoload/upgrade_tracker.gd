extends Node
## UpgradeTracker (autoload): árvore de progressão permanente comprada com
## essência (o gancho de longo prazo pro "matar boss → ganhar essência" —
## ver docs/plano-2-anos.md). Data-driven: cada UpgradeDef (.tres em
## res://progression/upgrades) pertence a uma branch (Combate, Exploração,
## Construção, Magia) e pode exigir outro upgrade já comprado.
##
## Comprar aplica o efeito na hora em GameState (multiplicadores/bônus) e
## persiste só a LISTA de ids comprados — ao carregar o save, os efeitos
## são reaplicados do zero a partir dessa lista (ver from_dict).

signal purchased(def: UpgradeDef)

const UPGRADES_DIR := "res://progression/upgrades"

var _defs: Array[UpgradeDef] = []
var _purchased: Array[String] = []

func _ready() -> void:
	var dir := DirAccess.open(UPGRADES_DIR)
	if dir == null:
		push_error("UpgradeTracker: pasta de upgrades não encontrada.")
		return
	for file in dir.get_files():
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(UPGRADES_DIR + "/" + file) as UpgradeDef
		if def != null and def.id != "":
			_defs.append(def)
	_defs.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool: return a.sort_order < b.sort_order)

func get_all() -> Array[UpgradeDef]:
	return _defs

func get_branch(branch: UpgradeDef.Branch) -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for def in _defs:
		if def.branch == branch:
			out.append(def)
	return out

func is_purchased(id: String) -> bool:
	return _purchased.has(id)

## true se puder comprar agora: ainda não comprado, pré-requisito cumprido
## (se houver) e essência suficiente.
func can_purchase(def: UpgradeDef) -> bool:
	if def == null or is_purchased(def.id):
		return false
	if def.requires != "" and not is_purchased(def.requires):
		return false
	return GameState.get_total("essencia") >= def.cost_essencia

func purchase(def: UpgradeDef) -> bool:
	if not can_purchase(def):
		return false
	if not GameState.remove_resource("essencia", def.cost_essencia):
		return false
	_purchased.append(def.id)
	_apply_effect(def)
	purchased.emit(def)
	SaveManager.save_game()
	return true

## Único lugar que sabe "o que cada Effect faz" — upgrade novo com um
## Effect já existente não toca aqui, só cria o .tres.
func _apply_effect(def: UpgradeDef) -> void:
	match def.effect:
		UpgradeDef.Effect.ATTACK_DAMAGE_MULT:
			GameState.attack_damage_mult += def.value
		UpgradeDef.Effect.DASH_COOLDOWN_MULT:
			GameState.dash_cooldown_mult *= maxf(0.1, 1.0 - def.value)
		UpgradeDef.Effect.MOVE_SPEED_MULT:
			GameState.speed_mult += def.value
		UpgradeDef.Effect.LANTERN_RANGE_MULT:
			GameState.lantern_range_mult += def.value
		UpgradeDef.Effect.RESOURCE_YIELD_CHANCE:
			GameState.resource_yield_bonus_pct += def.value
		UpgradeDef.Effect.UNLOCKS_STRUCTURE:
			pass  # o desbloqueio é a própria compra estar em `_purchased`;
			# StructureDef.required_upgrade_id aponta pro id deste upgrade e
			# BuildMode checa UpgradeTracker.is_purchased() na hora de montar
			# a lista de estruturas disponíveis.

func _find(id: String) -> UpgradeDef:
	for def in _defs:
		if def.id == id:
			return def
	return null

## Zera todos os multiplicadores de GameState pros valores neutros —
## chamado antes de reaplicar (from_dict) ou num reset total (reset).
func _reset_effects() -> void:
	GameState.attack_damage_mult = 1.0
	GameState.dash_cooldown_mult = 1.0
	GameState.speed_mult = 1.0
	GameState.lantern_range_mult = 1.0
	GameState.resource_yield_bonus_pct = 0.0

func to_dict() -> Dictionary:
	return {"purchased": _purchased.duplicate()}

func from_dict(data: Dictionary) -> void:
	_purchased.clear()
	_reset_effects()
	for id: Variant in data.get("purchased", []):
		var sid := String(id)
		var def := _find(sid)
		if def != null:
			_purchased.append(sid)
			_apply_effect(def)
			# Sem isso, quem só se atualiza reagindo ao sinal `purchased`
			# (BuildMode._refresh_available, HUD._refresh_upgrades_panel,
			# player._update_lantern) ficava com o estado de ANTES do save
			# até a próxima compra ao vivo — ex.: estruturas já desbloqueadas
			# não apareciam na lista do modo construção logo após carregar.
			# Os listeners são idempotentes (só recalculam), então reemitir
			# aqui no load é seguro.
			purchased.emit(def)

## Usado pelo "Recomeçar do zero" — apaga a progressão comprada junto.
func reset() -> void:
	_purchased.clear()
	_reset_effects()
