extends StaticBody2D
## Interação por E (registrado jul/2026, a pedido do usuário) que abre a
## lista de receitas/estruturas ESPECÍFICAS desta estação (Forja, Mesa de
## Pesquisa, Mesa de Alquimia, Workbench) — separado do painel geral de
## craft (C, mostra TUDO junto). Antes disso não dava pra saber o que uma
## estação faz sem abrir o craft geral e procurar pelo texto "(perto de
## X)" em cada receita; agora chegar perto e apertar E já mostra só o
## relevante. E (não F) de propósito: F já é usado por baú/talismã/
## portais — usar a mesma tecla criaria risco de entrar numa run sem
## querer se a Forja estiver perto do Talismã.
##
## Mesmo padrão "só a mais próxima responde" do baú/talismã (ver
## chest.gd), mas aqui o grupo usado pra achar "quem mais perto" é o
## PRÓPRIO grupo da estação (station_group) — nunca vai ter uma Forja
## competindo com uma Mesa de Pesquisa pela resposta, só com outra Forja
## (cenário raro, mas o padrão defensivo não custa nada).
##
## Reusa o painel de craft do HUD (`hud.gd::open_station_crafting`), só
## que filtrado por `RecipeDef.required_station == station_group`. Para a
## Workbench (jul/2026), o E agora lista/constrói as estruturas movidas do
## fluxo geral do B (Baú Grande e Poste de Luz).

@export var station_group: String = ""
@export var station_display_name: String = ""

@onready var area: Area2D = $Area2D
@onready var label: Label = $Label

var _player_inside: bool = false
var _e_was_pressed: bool = true  # true evita disparo no frame em que spawna
var is_open: bool = false

func _ready() -> void:
	add_to_group(station_group)
	label.text = "E — %s" % station_display_name
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
		if is_open:
			close()

func _is_nearest() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var my_dist := global_position.distance_squared_to(player.global_position)
	for other in get_tree().get_nodes_in_group(station_group):
		if other != self and other is Node2D and (other as Node2D).global_position.distance_squared_to(player.global_position) < my_dist:
			return false
	return true

func _process(_delta: float) -> void:
	var active := _player_inside and _is_nearest()
	label.visible = active and not is_open
	var e_pressed := Input.is_key_pressed(KEY_E)
	if active and e_pressed and not _e_was_pressed and not GameState.is_dead and not BuildMode.active:
		toggle()
	_e_was_pressed = e_pressed

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	label.hide()
	if station_group == "workbench":
		BuildMode.force_refresh_available()
	get_tree().call_group("hud", "open_station_crafting", station_group, station_display_name, self)

func close() -> void:
	is_open = false
	get_tree().call_group("hud", "close_station_crafting", self)
