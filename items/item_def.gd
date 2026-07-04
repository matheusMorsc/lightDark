class_name ItemDef
extends Resource
## Definição de um tipo de item (data-driven, .tres em res://items/defs).
## Adicionar um item novo = criar um .tres novo; nenhum código muda.

enum Category { RESOURCE, TOOL, FOOD, STRUCTURE, PASSIVE }

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var category: Category = Category.RESOURCE

@export_group("Ferramenta")
## Tipo de ferramenta ("machado", "picareta"...). Nós de recurso exigem
## tipo + tier mínimo pra serem coletados. "" pra uma arma pura (ver grupo
## "Arma" abaixo) — participa da categoria TOOL e do equipar-por-seleção
## normalmente (ver GameState.select_slot), só não serve pra colher nada.
@export var tool_type: String = ""
@export var tool_tier: int = 0

@export_group("Arma")
## Somado a `player.attack_damage` (antes do multiplicador de upgrades)
## enquanto este item estiver EQUIPADO como ferramenta atual — mesmo
## sistema de "uma ferramenta ativa por vez" de sempre: selecionar o slot
## dela na hotbar equipa (ver GameState.select_slot). Faz craftar uma arma
## na Forja ser uma troca real: equipar pra lutar melhor custa não poder
## colher com machado/picareta ao mesmo tempo.
@export var weapon_damage_bonus: float = 0.0
## Moveset do golpe normal quando esta arma está equipada (registrado
## jul/2026, ver player.gd::_attack). "" ou "espada" = alvo único, alcance
## normal (comportamento de sempre). "lanca" = alcance maior, perfura
## (acerta todos numa linha, não só o mais próximo). "martelo" = hitbox
## bem maior, mais lento entre golpes, atordoa o alvo.
## Sem @export_enum de propósito — ele rejeita "" como opção (erro de
## parse), e "" é justamente o valor default de toda ferramenta que não é
## arma. Continua um texto livre; valores válidos: "", "espada", "lanca",
## "martelo" (ver player.gd::_attack).
@export var weapon_type: String = ""

@export_group("Comida")
@export var hunger_restore: float = 0.0
@export var heal_amount: float = 0.0

@export_group("Passivo")
## Categoria PASSIVE (registrado jul/2026, ver Amuleto Vital): o bônus se
## aplica sozinho enquanto o item existir em QUALQUER slot do inventário
## principal (hotbar) — não precisa estar selecionado/equipado como
## ferramenta. Sair do inventário (chest, drop) remove o bônus na hora.
## Ver GameState._recompute_passive_bonuses().
@export var passive_bonus_max_health: float = 0.0
