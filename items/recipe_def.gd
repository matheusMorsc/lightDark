class_name RecipeDef
extends Resource
## Definição de uma receita de craft (data-driven, .tres em res://items/recipes).
## Adicionar receita nova = criar um .tres novo; o painel do HUD se monta sozinho.

@export var id: String = ""
@export var display_name: String = ""
## Custos: {"item_id": quantidade}
@export var costs: Dictionary = {}
## Item entregue ao craftar ("" = receita só de efeito, ex.: refeição).
@export var result_id: String = ""
@export var result_count: int = 1
## Ícone do painel (se vazio, usa o ícone do item resultante).
@export var icon: Texture2D
## Ordem no painel de craft.
@export var sort_order: int = 0
## "" = craftável em qualquer lugar. Senão, id do grupo de uma estação
## construída que precisa estar perto (ver hud.gd::_near_station) — ex.
## "forja" pras receitas de Tier II e armas.
@export var required_station: String = ""
## Nome de exibição da estação (só pra UI — "Forja", "Mesa de Alquimia"...).
## Evita ter que inferir o texto a partir do id do grupo.
@export var required_station_name: String = ""

@export_group("Efeitos ao craftar")
@export var bonus_max_health: float = 0.0
@export var heal_on_craft: float = 0.0
