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
## "" = sempre disponível. Senão, id de um UpgradeDef que precisa estar
## comprado (UpgradeTracker.is_purchased) pra essa estrutura aparecer no
## modo construção — ver BuildMode._refresh_available().
@export var required_upgrade_id: String = ""
## Estações avançadas (Forge, Alchemy Table, Research Table) só podem ser
## construídas perto de uma Workbench já erguida — ver
## BuildMode._workbench_nearby() e o grupo "workbench".
@export var requires_workbench_nearby: bool = false
