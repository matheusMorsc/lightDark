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
	var def := WorldLayers.get_region_def(target_region_id)
	if def != null and def.required_biome_unlock > 0 and not ObjectiveTracker.is_biome_unlocked(def.required_biome_unlock):
		_show_locked_hint()
		return  # sem cooldown aqui — o jogador pode tentar de novo assim que desbloquear
	_cooldown = 1.5
	WorldLayers.goto_region(target_region_id, spawn_position)

## Aviso flutuante quando a borda ainda está travada (mesmo padrão visual
## do "Requer X" de resource_node.gd::_show_hint).
func _show_locked_hint() -> void:
	var label := Label.new()
	label.text = "Ainda não desbloqueado"
	label.top_level = true
	label.z_index = 200
	label.z_as_relative = false
	label.custom_minimum_size = Vector2(160, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.global_position = global_position + Vector2(-80, -60)
	var tween := create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 16.0, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)
