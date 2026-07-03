extends Node
## Troca o cursor do mouse conforme o que está embaixo dele: espada sobre um
## inimigo, picareta sobre um recurso (comida/minério), seta normal no resto.
## É puramente visual — o jogo continua controlado pelo teclado (WASD/Espaço/E).

const CURSOR_DEFAULT := preload("res://assets/ui/cursors/cursor_default.png")
const CURSOR_ATTACK := preload("res://assets/ui/cursors/cursor_attack.png")
const CURSOR_MINE := preload("res://assets/ui/cursors/cursor_mine.png")

enum State { DEFAULT, ATTACK, MINE }

var _current_state: State = State.DEFAULT

func _ready() -> void:
	_apply_cursor(State.DEFAULT)

func _process(_delta: float) -> void:
	var new_state := _detect_state()
	if new_state != _current_state:
		_apply_cursor(new_state)

func _detect_state() -> State:
	var viewport := get_viewport()
	if viewport == null:
		return State.DEFAULT

	var world_pos: Vector2 = viewport.canvas_transform.affine_inverse() * viewport.get_mouse_position()

	var space_state := get_tree().root.world_2d.direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results := space_state.intersect_point(query, 4)
	for result in results:
		var collider: Object = result.get("collider")
		if collider == null:
			continue
		if collider.is_in_group("enemies"):
			return State.ATTACK
		if collider.is_in_group("resources"):
			return State.MINE
	return State.DEFAULT

func _apply_cursor(state: State) -> void:
	_current_state = state
	match state:
		State.ATTACK:
			Input.set_custom_mouse_cursor(CURSOR_ATTACK, Input.CURSOR_ARROW, Vector2(24, 24))
		State.MINE:
			Input.set_custom_mouse_cursor(CURSOR_MINE, Input.CURSOR_ARROW, Vector2(24, 24))
		_:
			Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, Vector2(4, 4))
