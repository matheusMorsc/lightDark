extends Node2D
## Portal de escolha no fim de cada mapa da run (estilo Hades): anuncia o
## viés de recompensa do PRÓXIMO mapa; o jogador entra com F.

const REWARDS := {
	"minerio": {"label": "Veio de minério", "color": Color(0.55, 0.9, 1.0)},
	"combate": {"label": "Covil — perigo e loot", "color": Color(1.0, 0.55, 0.55)},
	"suprimentos": {"label": "Depósito de suprimentos", "color": Color(1.0, 0.9, 0.55)},
}

@export var reward: String = "minerio"
## Portal de saída (pós-boss): volta pra base em vez de gerar outro mapa.
@export var is_exit: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var area: Area2D = $Area2D

var _player_inside := false
var _f_was_pressed := true  # true evita disparo no frame em que spawna

func _ready() -> void:
	add_to_group("run_portals")
	if is_exit:
		sprite.modulate = Color(0.5, 1.0, 0.6)
		label.text = "F — Voltar à base (vitória!)"
	else:
		var info: Dictionary = REWARDS.get(reward, REWARDS["minerio"])
		sprite.modulate = info["color"]
		label.text = "F — " + info["label"]
	label.hide()
	var light := get_node_or_null("Light")
	if light:
		light.color = sprite.modulate
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		label.hide()

## Com dois portais ao alcance, só o mais próximo "possui" o player
## (uma label na tela, um destino por F — nunca os dois).
func _is_nearest() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var my_dist := global_position.distance_squared_to(player.global_position)
	for other in get_tree().get_nodes_in_group("run_portals"):
		if other != self and other.global_position.distance_squared_to(player.global_position) < my_dist:
			return false
	return true

func _process(_delta: float) -> void:
	var active := _player_inside and _is_nearest()
	label.visible = active
	var f_pressed := Input.is_key_pressed(KEY_F)
	if active and f_pressed and not _f_was_pressed and not GameState.is_dead:
		if is_exit:
			WorldLayers.end_run()
		else:
			WorldLayers.enter_next_map(reward)
	_f_was_pressed = f_pressed
