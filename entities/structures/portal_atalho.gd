extends StaticBody2D
## Portal de Atalho: teleporte curto entre dois portais construídos na base.
## Uso: F no portal mais próximo. Se não houver par, ele só informa isso.

const TELEPORT_COOLDOWN_MS := 1200
const EXIT_OFFSET := Vector2(0, 24)

@onready var area: Area2D = $Area2D
@onready var label: Label = $Label

var _player_inside := false
var _f_was_pressed := true
var _cooldown_until_ms := 0

func _ready() -> void:
	add_to_group("portal_shortcuts")
	label.text = "Portal sem par"
	label.hide()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		label.hide()

func _is_nearest() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var my_dist := global_position.distance_squared_to(player.global_position)
	for other in get_tree().get_nodes_in_group("portal_shortcuts"):
		if other != self and other is Node2D and (other as Node2D).global_position.distance_squared_to(player.global_position) < my_dist:
			return false
	return true

func _nearest_target() -> Node2D:
	var target: Node2D = null
	var best := INF
	for other in get_tree().get_nodes_in_group("portal_shortcuts"):
		if other == self or not (other is Node2D):
			continue
		var d := global_position.distance_squared_to((other as Node2D).global_position)
		if d < best:
			best = d
			target = other as Node2D
	return target

func _process(_delta: float) -> void:
	var active := _player_inside and _is_nearest() and not WorldLayers.in_run
	label.visible = active
	var target := _nearest_target()
	var now := Time.get_ticks_msec()
	if active:
		if target == null:
			label.text = "Portal sem par"
		elif now < _cooldown_until_ms:
			label.text = "Portal recarregando..."
		else:
			label.text = "F — Usar Portal de Atalho"
	var f_pressed := Input.is_key_pressed(KEY_F)
	if active and f_pressed and not _f_was_pressed and not GameState.is_dead and not BuildMode.active:
		if target != null and now >= _cooldown_until_ms:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player != null:
				player.global_position = target.global_position + EXIT_OFFSET
				if player is CharacterBody2D:
					(player as CharacterBody2D).velocity = Vector2.ZERO
				var until := now + TELEPORT_COOLDOWN_MS
				_set_cooldown_until(until)
				if target.has_method("_set_cooldown_until"):
					target.call("_set_cooldown_until", until)
				SaveManager.save_game()
	_f_was_pressed = f_pressed

func _set_cooldown_until(until_ms: int) -> void:
	_cooldown_until_ms = until_ms
