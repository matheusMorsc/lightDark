extends Node
## RecipeDB (autoload): carrega as receitas (RecipeDef, .tres) de
## res://items/recipes no boot, ordenadas por sort_order.

const RECIPES_DIR := "res://items/recipes"

var _recipes: Array[RecipeDef] = []

func _ready() -> void:
	var dir := DirAccess.open(RECIPES_DIR)
	if dir == null:
		push_error("RecipeDB: pasta de receitas não encontrada: " + RECIPES_DIR)
		return
	for file in dir.get_files():
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var r: RecipeDef = load(RECIPES_DIR + "/" + file) as RecipeDef
		if r != null and r.id != "":
			_recipes.append(r)
	_recipes.sort_custom(func(a: RecipeDef, b: RecipeDef) -> bool: return a.sort_order < b.sort_order)

func get_all() -> Array[RecipeDef]:
	return _recipes
