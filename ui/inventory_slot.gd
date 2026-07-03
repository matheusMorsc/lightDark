extends PanelContainer
## Um slot da grade de inventário: mostra ícone + contador do item (se
## houver) e implementa drag-and-drop nativo do Godot — arrastar um slot
## para outro chama swap_slots do "dono" do slot (empilha se for o mesmo
## item). `container` é o dono deste slot: null = inventário do jogador
## (GameState); caso contrário, qualquer objeto com a mesma API (Array
## `inventory`, método `swap_slots(a, b)` e sinal `inventory_changed`) —
## hoje só o baú (chest.gd). Arrastar entre containers diferentes transfere
## o item em vez de trocar posições dentro do mesmo array.

@export var index: int = -1
var container: Object = null

@onready var icon_rect: TextureRect = $Content/Icon
@onready var count_label: Label = $Content/CountLabel

var _item_id: String = ""
var _count: int = 0

## `data` é null (slot vazio) ou {"item_id": String, "count": int}.
func set_slot_data(data) -> void:
	if data == null:
		_item_id = ""
		_count = 0
		icon_rect.texture = null
		icon_rect.visible = false
		count_label.visible = false
		return
	_item_id = data.item_id
	_count = data.count
	icon_rect.texture = ItemDB.get_icon(_item_id)
	icon_rect.visible = true
	count_label.text = "x%d" % _count
	count_label.visible = _count > 1
	tooltip_text = "%s (x%d)" % [ItemDB.get_display_name(_item_id), _count]

func _owner_inventory() -> Object:
	return container if container != null else GameState

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _item_id == "":
		return null
	var preview := TextureRect.new()
	preview.texture = icon_rect.texture
	preview.custom_minimum_size = Vector2(28, 28)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"from_index": index, "from_owner": _owner_inventory()}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("from_index"):
		return false
	var from_owner: Object = data.get("from_owner", GameState)
	return from_owner != _owner_inventory() or int(data["from_index"]) != index

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_index: int = int(data["from_index"])
	var from_owner: Object = data.get("from_owner", GameState)
	var to_owner: Object = _owner_inventory()
	if from_owner == to_owner:
		to_owner.swap_slots(from_index, index)
	else:
		_transfer(from_owner, from_index, to_owner, index)

## Move um item entre dois inventários distintos (jogador <-> baú): empilha
## se os itens baterem (respeitando o máximo), senão troca as posições —
## mesma regra do swap_slots dentro de um único inventário.
func _transfer(from_owner: Object, from_index: int, to_owner: Object, to_index: int) -> void:
	var from_slot = from_owner.inventory[from_index]
	if from_slot == null:
		return
	var to_slot = to_owner.inventory[to_index]

	if to_slot != null and to_slot.item_id == from_slot.item_id:
		var max_stack: int = ItemDB.get_max_stack(to_slot.item_id)
		var space: int = max_stack - to_slot.count
		if space > 0:
			var moved: int = min(space, from_slot.count)
			to_slot.count += moved
			from_slot.count -= moved
			if from_slot.count <= 0:
				from_owner.inventory[from_index] = null
			from_owner.inventory_changed.emit()
			to_owner.inventory_changed.emit()
			return

	from_owner.inventory[from_index] = to_slot
	to_owner.inventory[to_index] = from_slot
	from_owner.inventory_changed.emit()
	to_owner.inventory_changed.emit()
