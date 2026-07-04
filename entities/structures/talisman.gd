extends StaticBody2D
## Talismã: estrutura construível na base que dá acesso à run — substitui a
## antiga tecla T global. F leva pra dentro da run (mesma regra "só o mais
## próximo responde" do baú e dos portais). Uma vez dentro, não existe mais
## saída voluntária: só se volta ganhando (portal de saída pós-boss, ver
## run_portal.gd) ou morrendo (WorldLayers._on_player_died). Este nó nem
## processa durante a run — a superfície inteira fica desabilitada.

@onready var area: Area2D = $Area2D
@onready var label: Label = $Label

var _player_inside: bool = false
var _f_was_pressed: bool = true  # true evita disparo no frame em que spawna

func _ready() -> void:
	add_to_group("talismans")
	label.text = "F — Entrar na run"
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

## Com vários talismãs na base, só o mais próximo responde — mesma regra
## do baú e dos portais de run.
func _is_nearest() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var my_dist := global_position.distance_squared_to(player.global_position)
	for other in get_tree().get_nodes_in_group("talismans"):
		if other != self and other.global_position.distance_squared_to(player.global_position) < my_dist:
			return false
	return true

func _process(_delta: float) -> void:
	var active := _player_inside and _is_nearest()
	label.visible = active
	var f_pressed := Input.is_key_pressed(KEY_F)
	if active and f_pressed and not _f_was_pressed and not GameState.is_dead and not BuildMode.active:
		WorldLayers.start_run()
	_f_was_pressed = f_pressed
