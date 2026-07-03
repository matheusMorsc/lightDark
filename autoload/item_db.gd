extends Node
## ItemDB (autoload): carrega toda definição de item (ItemDef, .tres) de
## res://items/defs no boot. Puramente dados; quem manipula o inventário
## de verdade é o GameState.

const DEFS_DIR := "res://items/defs"

var _defs: Dictionary = {}

func _ready() -> void:
	var dir := DirAccess.open(DEFS_DIR)
	if dir == null:
		push_error("ItemDB: pasta de definições não encontrada: " + DEFS_DIR)
		return
	for file in dir.get_files():
		# Em builds exportadas os .tres viram .tres.remap.
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def: ItemDef = load(DEFS_DIR + "/" + file) as ItemDef
		if def != null and def.id != "":
			_defs[def.id] = def
	if _defs.is_empty():
		push_error("ItemDB: nenhuma definição de item carregada.")

func has(id: String) -> bool:
	return _defs.has(id)

func get_def(id: String) -> ItemDef:
	return _defs.get(id, null)

func get_display_name(id: String) -> String:
	var d: ItemDef = get_def(id)
	return d.display_name if d else id

func get_icon(id: String) -> Texture2D:
	var d: ItemDef = get_def(id)
	return d.icon if d else null

func get_max_stack(id: String) -> int:
	var d: ItemDef = get_def(id)
	return d.max_stack if d else 99
