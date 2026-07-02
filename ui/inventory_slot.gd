extends PanelContainer
## Um slot da grade de inventário: mostra ícone + contador do item (se
## houver) e implementa drag-and-drop nativo do Godot — arrastar um slot
## para outro chama GameState.swap_slots (empilha se for o mesmo item).

@export var index: int = -1

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
	return {"from_index": index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("from_index") and int(data["from_index"]) != index

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameState.swap_slots(int(data["from_index"]), index)
