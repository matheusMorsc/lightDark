extends Sprite2D
## Sombra de contato reutilizável: blob elíptico nos pés do dono.
## Anexe a um Sprite2D com a textura res://assets/fx/shadow_blob.png,
## como primeiro filho do nó da entidade (origem = pés).
## A sombra é ~50% da ilusão de profundidade nesta perspectiva.

## Largura visual da sombra em pixels (a profundidade é derivada dela).
@export var width: float = 24.0
@export_range(0.0, 1.0, 0.05) var opacity: float = 0.55

func _ready() -> void:
	show_behind_parent = true
	modulate.a = opacity
	if texture:
		scale = Vector2(
			width / texture.get_width(),
			width * 0.45 / texture.get_height()
		)
