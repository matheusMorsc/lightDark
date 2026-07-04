class_name RunModifierDef
extends Resource
## Definição de um modificador de run (data-driven, .tres em
## res://world/dungeon/modifiers/). Um é sorteado por WorldLayers a cada
## `start_run()` e vale pra run inteira (todos os mapas até voltar pra
## base) — estilo "maldição do dia" de roguelite (Hades/Slay the Spire):
## cada tentativa fica mecanicamente diferente, sem precisar de arte nova.
##
## Todo multiplicador default = 1.0 (sem efeito); `elite_chance_bonus` é
## aditivo (soma direto na chance por mapa, default 0.0). Adicionar
## modificador novo = criar `.tres` novo; nenhum código muda.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export_group("Inimigos")
@export var enemy_speed_mult: float = 1.0
@export var enemy_damage_mult: float = 1.0
## Multiplica o power_scale do boss (afeta vida E dano dele — mesmo campo
## que o ciclo de profundidade já usa, ver boss.gd).
@export var boss_power_mult: float = 1.0
## Somado direto na chance de elite por sala (0.0 a 1.0), em cima do que o
## viés do portal já define (ver run_map.gd).
@export var elite_chance_bonus: float = 0.0

@export_group("Jogador")
## Multiplica o dano do ataque do jogador (normal e especial) só durante a
## run — não afeta a base nem GameState.attack_damage_mult (permanente).
@export var player_damage_mult: float = 1.0
## Multiplica quanto fome/vida a comida restaura, só durante a run.
@export var heal_effectiveness_mult: float = 1.0

@export_group("Recursos")
## Multiplica quantos nós de minério spawnam por sala.
@export var ore_yield_mult: float = 1.0
