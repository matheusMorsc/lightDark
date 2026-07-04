class_name UpgradeDef
extends Resource
## Um nó da árvore de progressão permanente (data-driven, .tres em
## res://progression/upgrades). Comprado com essência via UpgradeTracker —
## upgrade novo = só criar um .tres, nenhum código muda.
##
## `requires` (opcional) é o id de outro UpgradeDef que precisa estar
## comprado antes — cada branch vira uma cadeia linear, sem precisar de UI
## de árvore/grafo visual (a lista já mostra bloqueado/disponível/comprado).

enum Branch { COMBAT, EXPLORATION, CONSTRUCTION, MAGIC }

## O que `value` faz depende do efeito — ver UpgradeTracker._apply_effect().
enum Effect {
	ATTACK_DAMAGE_MULT,
	DASH_COOLDOWN_MULT,
	MOVE_SPEED_MULT,
	LANTERN_RANGE_MULT,
	RESOURCE_YIELD_CHANCE,
	## Não muta GameState — é só um marcador. Quem checa o desbloqueio é o
	## StructureDef correspondente, via `required_upgrade_id` apontando pro
	## id DESTE upgrade (ver BuildMode._refresh_available()).
	UNLOCKS_STRUCTURE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var branch: Branch = Branch.COMBAT
@export var icon: Texture2D
@export var cost_essencia: int = 3
## Id de outro UpgradeDef que precisa estar comprado antes ("" = raiz da branch).
@export var requires: String = ""
@export var effect: Effect = Effect.ATTACK_DAMAGE_MULT
@export var value: float = 0.1
@export var sort_order: int = 0
