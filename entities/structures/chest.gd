extends StaticBody2D
## Baú: estrutura construível na base com inventário próprio (20 slots).
## F abre/fecha a UI de transferência quando este é o baú mais próximo ao
## alcance do jogador (mesmo padrão "só o mais próximo responde" usado nos
## portais de run — ver entities/dungeon/run_portal.gd). O conteúdo é
## persistido pelo SaveManager (grupo "chests"), à parte da posição/id que
## já é coberta pelo grupo "player_built".

signal inventory_changed

const SLOT_COUNT: int = 20

## Texturas do sprite fechado/aberto (feedback visual ao abrir a UI).
@export var closed_texture: Texture2D
@export var open_texture: Texture2D

## Array de tamanho fixo SLOT_COUNT: cada slot é null ou
## {"item_id": String, "count": int} — mesmo formato do GameState.inventory.
var inventory: Array = []
var is_open: bool = false

@onready var area: Area2D = $Area2D
@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

var _player_inside: bool = false
var _f_was_pressed: bool = true  # true evita disparo no frame em que spawna

func _ready() -> void:
	add_to_group("chests")
	inventory.resize(SLOT_COUNT)
	label.text = "F — Abrir baú"
	label.hide()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		label.hide()
		if is_open:
			close()

## Com vários baús ao alcance, só o mais próximo "possui" o player (uma
## label na tela, um F por vez) — mesma regra dos portais de run.
func _is_nearest() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var my_dist := global_position.distance_squared_to(player.global_position)
	for other in get_tree().get_nodes_in_group("chests"):
		if other != self and other.global_position.distance_squared_to(player.global_position) < my_dist:
			return false
	return true

func _process(_delta: float) -> void:
	var active := _player_inside and _is_nearest()
	label.visible = active and not is_open
	var f_pressed := Input.is_key_pressed(KEY_F)
	if active and f_pressed and not _f_was_pressed and not GameState.is_dead and not BuildMode.active:
		toggle()
	_f_was_pressed = f_pressed

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	label.hide()
	if open_texture:
		sprite.texture = open_texture
	get_tree().call_group("hud", "show_chest_panel", self)

func close() -> void:
	is_open = false
	if closed_texture:
		sprite.texture = closed_texture
	get_tree().call_group("hud", "hide_chest_panel", self)

## Troca o conteúdo de dois slots do baú (drag-and-drop na UI). Mesma regra
## de empilhamento do GameState.swap_slots.
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
