class_name ItemDef
extends Resource
## Definição de um tipo de item (data-driven, .tres em res://items/defs).
## Adicionar um item novo = criar um .tres novo; nenhum código muda.

enum Category { RESOURCE, TOOL, FOOD, STRUCTURE }

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var category: Category = Category.RESOURCE

@export_group("Ferramenta")
## Tipo de ferramenta ("machado", "picareta"...). Nós de recurso exigem
## tipo + tier mínimo pra serem coletados.
@export var tool_type: String = ""
@export var tool_tier: int = 0

@export_group("Comida")
@export var hunger_restore: float = 0.0
@export var heal_amount: float = 0.0
