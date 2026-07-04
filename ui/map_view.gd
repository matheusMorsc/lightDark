class_name MapView
extends Control
## Mapa simples (M alterna, painel no HUD — ver hud.gd::_build_map_panel).
## v1 propositalmente rudimentar: um esquema de cima pra baixo só da REGIÃO
## ATIVA agora (jogador, bordas de região, estruturas construídas). Não
## tenta mostrar todas as regiões juntas na mesma escala — elas vivem em
## offsets gigantes (ver WorldLayers) só pra colisores/luzes nunca se
## misturarem, então "a mesma régua" entre regiões não faz sentido. Sem
## tiles, sem fog of war, sem terreno real — só pontos + rótulos.

## World units -> px do mapa. A base (região 1) se espalha por ~-1000..1000
## nos dois eixos (ver world/biome_1.tscn); com essa escala cabe inteira
## num painel de ~260x260 com folga.
const MAP_SCALE := 0.11

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var size := get_rect().size
	var center := size / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.06, 0.09, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.15), false, 1.5)

	var root := WorldLayers.active_root()
	if root == null:
		return

	var font := ThemeDB.fallback_font

	# Estruturas construídas pelo jogador (laranja).
	for structure in get_tree().get_nodes_in_group("player_built"):
		if structure is Node2D and root.is_ancestor_of(structure):
			_dot(root.to_local(structure.global_position), center, Color(0.95, 0.75, 0.3), 4.0)

	# Bordas pra outras regiões (roxo + nome do destino).
	for edge in get_tree().get_nodes_in_group("region_edge"):
		if edge is Node2D and root.is_ancestor_of(edge):
			var local: Vector2 = root.to_local(edge.global_position)
			_dot(local, center, Color(0.65, 0.45, 0.95), 6.0)
			var label: String = "→ %s" % WorldLayers.get_region_name(edge.target_region_id)
			draw_string(font, _map_pos(local, center) + Vector2(9, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.75, 1.0))

	# Jogador (branco, por cima de tudo).
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D and root.is_ancestor_of(player):
		_dot(root.to_local(player.global_position), center, Color.WHITE, 5.0)

	# Nome da região atual, canto superior.
	draw_string(font, Vector2(8, 16), WorldLayers.get_region_name(WorldLayers.current_region_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _map_pos(local: Vector2, center: Vector2) -> Vector2:
	return center + local * MAP_SCALE

func _dot(local: Vector2, center: Vector2, color: Color, radius: float) -> void:
	draw_circle(_map_pos(local, center), radius, color)
