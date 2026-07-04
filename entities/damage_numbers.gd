class_name DamageNumbers
extends RefCounted
## Número de dano flutuante (registrado jul/2026, pedido do usuário: "número
## em vermelho acima do inimigo a cada golpe, tipo -10"). Função utilitária
## ESTÁTICA sem estado — mesmo padrão do `items/placeholder_icons.gd` — pra
## não duplicar a mesma lógica de spawn/tween em cada script de inimigo
## (hoje enemy.gd e boss.gd).
##
## `world` é o nó onde o Label é adicionado (sempre `get_parent()` de quem
## apanhou, mesma ideia de `player.gd::_spawn_hit_fx`) — o Label usa
## `global_position` direto, então sobe/desaparece no lugar certo mesmo que
## o inimigo continue se movendo depois do golpe.

const RISE_DISTANCE := 34.0
const DURATION := 0.7

static func spawn(world: Node, global_pos: Vector2, amount: float, color: Color = Color(1.0, 0.25, 0.25)) -> void:
	if world == null or not is_instance_valid(world):
		return
	var lbl := Label.new()
	lbl.text = "-%d" % int(round(amount))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 60
	world.add_child(lbl)
	lbl.global_position = global_pos + Vector2(randf_range(-10.0, 10.0), -12.0)
	var tween := lbl.create_tween()
	tween.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -RISE_DISTANCE), DURATION)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, DURATION)
	tween.tween_callback(lbl.queue_free)
