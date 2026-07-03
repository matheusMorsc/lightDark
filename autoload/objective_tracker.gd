extends Node
## ObjectiveTracker (autoload): progresso dos objetivos de bioma.
## Data-driven (ObjectiveDef .tres em res://progression/objectives).
## O progresso de coleta é CUMULATIVO — gastar essência no craft não desfaz
## a coleta. Persistido pelo SaveManager. Quando todos os objetivos de um
## bioma completam, emite biome_unlocked (v1: mensagem; depois: portal novo).

signal progress_changed(def: ObjectiveDef, current: int)
signal biome_unlocked(biome: int)

const OBJECTIVES_DIR := "res://progression/objectives"

var _defs: Array[ObjectiveDef] = []
var _progress: Dictionary = {}   # id -> int (limitado a required)
var _unlocked: Array = [1]

func _ready() -> void:
	var dir := DirAccess.open(OBJECTIVES_DIR)
	if dir == null:
		push_error("ObjectiveTracker: pasta de objetivos não encontrada.")
		return
	for file in dir.get_files():
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(OBJECTIVES_DIR + "/" + file) as ObjectiveDef
		if def != null and def.id != "":
			_defs.append(def)
	_defs.sort_custom(func(a: ObjectiveDef, b: ObjectiveDef) -> bool: return a.sort_order < b.sort_order)

func get_objectives(biome: int = 1) -> Array[ObjectiveDef]:
	var out: Array[ObjectiveDef] = []
	for def in _defs:
		if def.biome == biome:
			out.append(def)
	return out

func get_progress(id: String) -> int:
	return int(_progress.get(id, 0))

func is_complete(def: ObjectiveDef) -> bool:
	return get_progress(def.id) >= def.required

func is_biome_unlocked(biome: int) -> bool:
	return _unlocked.has(biome)

# ---- eventos do jogo ----

func notify_boss_defeated() -> void:
	_bump(ObjectiveDef.Kind.KILL_BOSS, "", 1)

func notify_collected(item_id: String, amount: int) -> void:
	_bump(ObjectiveDef.Kind.COLLECT_ITEM, item_id, amount)

func notify_built(structure_id: String) -> void:
	_bump(ObjectiveDef.Kind.BUILD_STRUCTURE, structure_id, 1)

func _bump(kind: ObjectiveDef.Kind, target: String, amount: int) -> void:
	var changed := false
	for def in _defs:
		if def.kind != kind:
			continue
		if def.target_id != "" and def.target_id != target:
			continue
		var cur := get_progress(def.id)
		if cur >= def.required:
			continue
		var next := mini(def.required, cur + amount)
		_progress[def.id] = next
		progress_changed.emit(def, next)
		changed = true
	if changed:
		_check_unlocks()

func _check_unlocks() -> void:
	var biomes := {}
	for def in _defs:
		biomes[def.biome] = true
	for biome: int in biomes:
		if _unlocked.has(biome + 1):
			continue
		var all_done := true
		for def in get_objectives(biome):
			if not is_complete(def):
				all_done = false
				break
		if all_done:
			_unlocked.append(biome + 1)
			biome_unlocked.emit(biome + 1)
			SaveManager.save_game()

# ---- persistência (chamado pelo SaveManager) ----

func to_dict() -> Dictionary:
	return {"progress": _progress.duplicate(), "unlocked": _unlocked.duplicate()}

func from_dict(data: Dictionary) -> void:
	_progress = {}
	for k: Variant in data.get("progress", {}):
		_progress[String(k)] = int(data["progress"][k])
	_unlocked = data.get("unlocked", [1]).map(func(v: Variant) -> int: return int(v))
	if _unlocked.is_empty():
		_unlocked = [1]
	for def in _defs:
		progress_changed.emit(def, get_progress(def.id))

func reset() -> void:
	_progress.clear()
	_unlocked = [1]
	for def in _defs:
		progress_changed.emit(def, 0)
