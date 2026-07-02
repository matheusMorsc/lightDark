extends Node
## ItemDB (autoload): metadados de cada tipo de item que pode existir no
## inventário — nome de exibição, ícone (pro grid da UI) e tamanho máximo
## de pilha. Puramente dados; quem manipula o inventário de verdade é o
## GameState.

class ItemDef:
	var id: String
	var display_name: String
	var icon: Texture2D
	var max_stack: int

	func _init(p_id: String, p_display_name: String, p_icon: Texture2D, p_max_stack: int) -> void:
		id = p_id
		display_name = p_display_name
		icon = p_icon
		max_stack = p_max_stack

var _defs: Dictionary = {}

func _ready() -> void:
	_register("comida", "Cogumelo", preload("res://assets/kenney_pixel_platformer/Tiles/tile_0030_transparent.png"), 99)
	_register("minerio", "Minério", preload("res://assets/kenney_roguelike_caves/gem_ore.png"), 99)
	_register("pedra", "Pedra", preload("res://assets/ui/icons/pedra_icon.png"), 99)

func _register(id: String, display_name: String, icon: Texture2D, max_stack: int) -> void:
	_defs[id] = ItemDef.new(id, display_name, icon, max_stack)

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
