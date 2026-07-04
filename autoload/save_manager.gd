extends Node
## SaveManager (autoload): persistência da BASE (pilar 1: a base é o porto
## seguro onde todo progresso permanente mora).
##
## O que salva: vida/fome/vida máxima, inventário, ferramenta equipada,
## posição do player na superfície, estruturas construídas e nós de recurso
## esgotados na superfície. Runs NÃO salvam nada — de propósito (roguelite).
##
## Formato: JSON versionado em user://save.json. Gatilhos: autosave
## periódico, entrar/sair de run, construir e fechar o jogo.

const SAVE_PATH := "user://save.json"
const VERSION := 1
const STRUCTURES_DIR := "res://items/structures"
const AUTOSAVE_SECONDS := 45.0

## Nomes (únicos) dos nós de recurso já esgotados na superfície.
var _depleted: Array = []
var _structure_defs: Dictionary = {}  # id -> StructureDef
var _loaded: bool = false

func _ready() -> void:
	_load_structure_defs()
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_SECONDS
	timer.autostart = true
	timer.timeout.connect(save_game)
	add_child(timer)
	# Espera a cena principal montar antes de aplicar o save.
	await get_tree().process_frame
	load_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _load_structure_defs() -> void:
	var dir := DirAccess.open(STRUCTURES_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(STRUCTURES_DIR + "/" + file) as StructureDef
		if def != null and def.id != "":
			_structure_defs[def.id] = def

## Chamado pelos nós de recurso da superfície ao esgotarem.
func mark_depleted(node: Node) -> void:
	if WorldLayers.in_run:
		return
	var n := String(node.name)
	if not _depleted.has(n):
		_depleted.append(n)

func save_game() -> void:
	if GameState.is_dead or not _loaded:
		return
	var inv: Array = []
	for slot in GameState.inventory:
		if slot == null:
			inv.append(null)
		else:
			inv.append({"item_id": slot.item_id, "count": slot.count})

	var structures: Array = []
	for n in get_tree().get_nodes_in_group("player_built"):
		if not (n is Node2D):
			continue
		var entry := {
			"id": String(n.get_meta("structure_id", "")),
			"x": n.global_position.x,
			"y": n.global_position.y,
		}
		# Baús carregam estado próprio (inventário) além de posição/id.
		if n.is_in_group("chests"):
			var chest_inv: Array = []
			for slot in n.inventory:
				if slot == null:
					chest_inv.append(null)
				else:
					chest_inv.append({"item_id": slot.item_id, "count": slot.count})
			entry["chest_inventory"] = chest_inv
		structures.append(entry)

	var pos := WorldLayers.surface_player_position()
	var data := {
		"version": VERSION,
		"health": GameState.health,
		"max_health": GameState.max_health,
		"hunger": GameState.hunger,
		"equipped_tool_id": GameState.equipped_tool_id,
		"inventory": inv,
		"player_pos": [pos.x, pos.y],
		"structures": structures,
		"depleted": _depleted,
		"objectives": ObjectiveTracker.to_dict(),
		"upgrades": UpgradeTracker.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: não consegui gravar " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func load_game() -> void:
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary) or int(data.get("version", 0)) != VERSION:
		push_warning("SaveManager: save incompatível, ignorando.")
		return

	# --- GameState ---
	GameState.max_health = float(data.get("max_health", GameState.max_health))
	GameState.health = clampf(float(data.get("health", GameState.max_health)), 1.0, GameState.max_health)
	GameState.hunger = clampf(float(data.get("hunger", GameState.max_hunger)), 0.0, GameState.max_hunger)
	var inv: Array = data.get("inventory", [])
	GameState.inventory = []
	GameState.inventory.resize(GameState.INVENTORY_SIZE)
	for i in mini(inv.size(), GameState.INVENTORY_SIZE):
		var slot: Variant = inv[i]
		if slot is Dictionary and ItemDB.has(String(slot.get("item_id", ""))):
			GameState.inventory[i] = {"item_id": String(slot["item_id"]), "count": int(slot["count"])}
	GameState.health_changed.emit(GameState.health, GameState.max_health)
	GameState.hunger_changed.emit(GameState.hunger, GameState.max_hunger)
	GameState.inventory_changed.emit()
	ObjectiveTracker.from_dict(data.get("objectives", {}))
	UpgradeTracker.from_dict(data.get("upgrades", {}))
	var tool_id := String(data.get("equipped_tool_id", ""))
	if tool_id != "":
		GameState.equip_tool(tool_id)

	# --- Superfície: nós esgotados somem, estruturas voltam ---
	var surface := WorldLayers.surface_root()
	if surface == null:
		return
	var entities := surface.get_node_or_null("Entities")
	_depleted = data.get("depleted", [])
	if entities:
		for n: Variant in _depleted:
			var node := entities.get_node_or_null(String(n))
			if node:
				node.queue_free()
		for s: Variant in data.get("structures", []):
			if not (s is Dictionary):
				continue
			var def: StructureDef = _structure_defs.get(String(s.get("id", "")), null)
			if def == null or def.scene == null:
				continue
			var node: Node2D = def.scene.instantiate()
			entities.add_child(node)
			node.global_position = Vector2(float(s["x"]), float(s["y"]))
			node.set_meta("structure_id", def.id)
			node.add_to_group("player_built")
			if node.is_in_group("chests"):
				var saved_inv: Array = s.get("chest_inventory", [])
				var chest_inv: Array = []
				chest_inv.resize(node.inventory.size())
				for i in mini(saved_inv.size(), chest_inv.size()):
					var slot: Variant = saved_inv[i]
					if slot is Dictionary and ItemDB.has(String(slot.get("item_id", ""))):
						chest_inv[i] = {"item_id": String(slot["item_id"]), "count": int(slot["count"])}
				node.inventory = chest_inv

	# --- Player ---
	var pp: Array = data.get("player_pos", [])
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and pp.size() == 2:
		player.global_position = Vector2(float(pp[0]), float(pp[1]))

## Apaga o save (usado no restart pós-morte na superfície).
func wipe() -> void:
	ObjectiveTracker.reset()
	UpgradeTracker.reset()
	_depleted.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
