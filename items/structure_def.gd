class_name StructureDef
extends Resource
## Definição de uma estrutura construível (data-driven, .tres em
## res://items/structures). Estrutura nova = um .tres novo + uma cena.

@export var id: String = ""
@export var display_name: String = ""
## Cena instanciada ao construir (e usada como ghost de preview).
@export var scene: PackedScene
## Custos em recursos: {"item_id": quantidade}
@export var costs: Dictionary = {}
