extends Area2D
## Borda de região: encostar nela (sem tecla, sem F) troca de região — é o
## "andar até a beira do mapa" que liga a base a novas áreas exploráveis
## (pilar: mundo único, o mapa vai "aumentando" em vez de trocar de base —
## ver docs/plano-2-anos.md §2 e WorldLayers.goto_region()). Toda região
## que tiver uma borda precisa da borda espelhada do lado de lá, senão o
## jogador não consegue voltar.

## Id da RegionDef de destino (ver world/regions/*.tres).
@export var target_region_id: int = 1
## Posição LOCAL dentro da região de destino onde o jogador aparece —
## alguns passos longe da borda espelhada de lá, senão ele reentra na hora.
@export var spawn_position: Vector2 = Vector2.ZERO

## Trava a borda por um instante depois de qualquer troca — evita
## ida-e-volta instantânea se o ponto de chegada nascer perto demais dela.
var _cooldown: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("region_edge")

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0.0 or GameState.is_dead or WorldLayers.in_run:
		return
	if not body.is_in_group("player"):
		return
	_cooldown = 1.5
	WorldLayers.goto_region(target_region_id, spawn_position)
