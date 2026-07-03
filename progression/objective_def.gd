class_name ObjectiveDef
extends Resource
## Definição de um objetivo de bioma (data-driven, .tres em
## res://progression/objectives). O "contrato" do bioma: cumprir todos os
## objetivos de um bioma desbloqueia o seguinte.

enum Kind { KILL_BOSS, COLLECT_ITEM, BUILD_STRUCTURE }

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.KILL_BOSS
## Alvo: item_id para coleta, structure_id para construção ("" = qualquer).
@export var target_id: String = ""
@export var required: int = 1
## Bioma dono deste objetivo (cumprir todos libera o bioma+1).
@export var biome: int = 1
@export var sort_order: int = 0
