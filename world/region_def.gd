class_name RegionDef
extends Resource
## Definição de uma região da superfície (data-driven, .tres em
## res://world/regions). Região nova = um .tres novo + uma cena — nenhum
## código muda (mesmo padrão de StructureDef/UpgradeDef/ItemDef).
##
## A região 1 é sempre a BASE (pilar: "mundo único, base persistente" — ver
## docs/plano-2-anos.md §2): não tem `scene` própria porque ELA é a cena
## principal do jogo (world/biome_1.tscn, run/main_scene no project.godot),
## já viva desde o boot. Regiões novas (2+) têm `scene` e são instanciadas
## sob demanda por WorldLayers.goto_region() na primeira vez que o jogador
## entra nelas — e continuam vivas (só escondidas) depois disso, pelo
## resto da sessão.

@export var id: int = 1
@export var display_name: String = ""
## null pra região 1 (é a cena principal, não precisa instanciar nada).
@export var scene: PackedScene
@export var is_base: bool = false
## Deslocamento espacial fixo onde o conteúdo desta região vive de verdade
## (mesmo truque do offset das runs — mantém regiões fisicamente separadas
## pra colisores/luzes nunca se misturarem). Região 1 fica na origem.
@export var offset: Vector2 = Vector2.ZERO
## 0 = sem gate, qualquer um cruza a borda a qualquer momento. Senão, o id
## de um bioma que precisa estar desbloqueado (`ObjectiveTracker.
## is_biome_unlocked`) antes da borda deixar passar — ver
## `entities/region_edge.gd`.
@export var required_biome_unlock: int = 0
