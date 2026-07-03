extends Node
## BuildMode (autoload): modo de construção da base (só na superfície).
## B alterna; 1..N escolhe a estrutura; o ghost segue o mouse com snap de
## 8px e fica verde/vermelho conforme a validade (custo + alcance + espaço
## livre); clique esquerdo constrói e desconta os recursos.
## Estruturas são StructureDef (.tres) em res://items/structures — adicionar
## uma nova = criar um .tres + uma cena, nenhum código muda.

const STRUCTURES_DIR := "res://items/structures"
const PLACE_RANGE := 130.0
const SNAP := 8.0

var active: bool = false
## Frame em que o modo foi fechado (o ESC que fecha não deve abrir o pause).
var last_exit_frame := -1

var _defs: Array[StructureDef] = []
var _index: int = 0
var _ghost: Node2D = null
var _hint: Label = null
var _valid: bool = false
var _b_was := false
var _click_was := false
var _num_was: Array[bool] = []

func _ready() -> void:
	var dir := DirAccess.open(STRUCTURES_DIR)
	if dir == null:
		push_error("BuildMode: pasta de estruturas não encontrada.")
		return
	var files := Array(dir.get_files())
	files.sort()
	for file: String in files:
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def := load(STRUCTURES_DIR + "/" + file) as StructureDef
		if def != null and def.scene != null:
			_defs.append(def)
	_num_was.resize(_defs.size())
	_num_was.fill(false)

func _process(_delta: float) -> void:
	var b_pressed := Input.is_key_pressed(KEY_B)
	if b_pressed and not _b_was:
		_toggle()
	_b_was = b_pressed

	if not active:
		return
	if WorldLayers.in_run or GameState.is_dead:
		_exit()
		return

	for i in _defs.size():
		var pressed := Input.is_key_pressed(KEY_1 + i)
		if pressed and not _num_was[i] and i != _index:
			_index = i
			_refresh_ghost()
		_num_was[i] = pressed

	_update_ghost()

	var click := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if click and not _click_was:
		_try_place()
	_click_was = click

func _toggle() -> void:
	if active:
		_exit()
	elif not WorldLayers.in_run and not GameState.is_dead and not _defs.is_empty():
		active = true
		_refresh_ghost()

func _exit() -> void:
	active = false
	last_exit_frame = Engine.get_process_frames()
	if _ghost:
		_ghost.queue_free()
		_ghost = null

## Recria o ghost com a estrutura selecionada (transparente, sem colisão).
func _refresh_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	var world := _world_entities()
	if world == null:
		_exit()
		return
	var def := _defs[_index]
	_ghost = def.scene.instantiate()
	_disable_collisions(_ghost)
	world.add_child(_ghost)

	_hint = Label.new()
	_hint.custom_minimum_size = Vector2(200, 0)
	_hint.position = Vector2(-100, -72)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "%s — %s\n[1..%d] troca | clique: construir | B: sair" % [
		def.display_name, _cost_text(def), _defs.size()
	]
	_ghost.add_child(_hint)

func _disable_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_collisions(child)

func _update_ghost() -> void:
	if _ghost == null:
		return
	var mouse := _ghost.get_global_mouse_position()
	var pos := Vector2(snappedf(mouse.x, SNAP), snappedf(mouse.y, SNAP))
	_ghost.global_position = pos

	var def := _defs[_index]
	var player := _player()
	var near := player != null and player.global_position.distance_to(pos) <= PLACE_RANGE
	_valid = GameState.can_afford(def.costs) and near and _space_free(pos)
	_ghost.modulate = Color(0.5, 1.0, 0.5, 0.65) if _valid else Color(1.0, 0.4, 0.4, 0.5)

## Espaço livre = nenhum corpo físico na pegada da estrutura.
func _space_free(pos: Vector2) -> bool:
	var space := _ghost.get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	params.shape = shape
	params.transform = Transform2D(0.0, pos + Vector2(0, -4))
	params.collide_with_bodies = true
	return space.intersect_shape(params, 1).is_empty()

func _try_place() -> void:
	if not _valid or _ghost == null:
		return
	var def := _defs[_index]
	if not GameState.can_afford(def.costs):
		return
	for item_id in def.costs:
		GameState.remove_resource(item_id, int(def.costs[item_id]))
	var world := _world_entities()
	if world == null:
		return
	var node: Node2D = def.scene.instantiate()
	world.add_child(node)
	node.global_position = _ghost.global_position
	# Persistência: SaveManager varre este grupo/meta ao salvar.
	node.set_meta("structure_id", def.id)
	node.add_to_group("player_built")
	ObjectiveTracker.notify_built(def.id)
	SaveManager.save_game()

func _cost_text(def: StructureDef) -> String:
	var parts: PackedStringArray = []
	for item_id in def.costs:
		parts.append("%d %s" % [int(def.costs[item_id]), ItemDB.get_display_name(item_id)])
	return ", ".join(parts)

func _world_entities() -> Node2D:
	var cs := get_tree().current_scene
	return cs.get_node_or_null("Entities") as Node2D if cs else null

func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D
