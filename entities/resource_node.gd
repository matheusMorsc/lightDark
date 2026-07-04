extends StaticBody2D
## Nó de recurso colhível. Recebe golpes via hit() (mesma interface do Enemy).
## Pode exigir uma ferramenta EQUIPADA (tipo + tier mínimo) e dropa itens por
## golpe conforme a drop table. Se `drops` estiver vazio, cai no formato
## antigo (resource_id + amount_per_hit) — compatível com as cenas existentes.

@export var resource_id: String = "comida"
@export var hits_to_deplete: int = 3
@export var amount_per_hit: int = 1

@export_group("Requisito de ferramenta")
## "" = coleta à mão. Ex.: "machado", "picareta".
@export var required_tool_type: String = ""
@export var required_tool_tier: int = 1

@export_group("Drops")
## Cada entrada: {"item_id": String, "min": int, "max": int, "chance": float}
@export var drops: Array[Dictionary] = []

const MINE_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/mine_000.ogg"),
	preload("res://assets/audio/sfx/mine_001.ogg"),
	preload("res://assets/audio/sfx/mine_002.ogg"),
]
const TOOL_NAMES := {"machado": "Machado", "picareta": "Picareta"}
const TIER_ROMAN := ["", "I", "II", "III", "IV"]

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_player: AudioStreamPlayer2D = $SfxPlayer

var _hits_remaining: int
var _flash_tween: Tween

func _ready() -> void:
	add_to_group("resources")
	_hits_remaining = hits_to_deplete

func hit(_amount: float) -> void:
	if not GameState.has_tool(required_tool_type, required_tool_tier):
		_deny_feedback()
		return
	_hits_remaining -= 1
	_roll_drops()
	_flash(Color(1.4, 1.4, 1.4))
	_play_random(MINE_SOUNDS)
	if _hits_remaining <= 0:
		_deplete()

func _roll_drops() -> void:
	if drops.is_empty():
		GameState.add_resource(resource_id, amount_per_hit)
	else:
		for d: Dictionary in drops:
			if randf() <= float(d.get("chance", 1.0)):
				var n := randi_range(int(d.get("min", 1)), int(d.get("max", 1)))
				if n > 0:
					GameState.add_resource(String(d.get("item_id", resource_id)), n)
	# Bônus da árvore de progressão ("Mão Precisa"): chance de uma unidade
	# extra do recurso PRINCIPAL deste nó, além do que já rolou acima.
	if GameState.resource_yield_bonus_pct > 0.0 and randf() < GameState.resource_yield_bonus_pct:
		GameState.add_resource(resource_id, 1)

## Ferramenta errada/ausente: escurece o nó e mostra o requisito flutuando.
func _deny_feedback() -> void:
	_flash(Color(0.45, 0.45, 0.5))
	var tool_name: String = TOOL_NAMES.get(required_tool_type, required_tool_type.capitalize())
	var tier: String = TIER_ROMAN[clampi(required_tool_tier, 0, TIER_ROMAN.size() - 1)]
	_show_hint("Requer %s %s" % [tool_name, tier])

func _flash(color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	sprite.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

## Texto flutuante que sobe e some (aviso de requisito).
func _show_hint(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.top_level = true
	label.z_index = 200
	label.z_as_relative = false
	label.custom_minimum_size = Vector2(120, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.global_position = global_position + Vector2(-60, -44)
	var tween := create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 16.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

## Esgota: some na hora, mas só libera o nó depois do som tocar.
func _deplete() -> void:
	SaveManager.mark_depleted(self)
	collision_shape.set_deferred("disabled", true)
	sprite.hide()
	for child in get_children():
		if child is LightOccluder2D or (child is Sprite2D and child != sprite):
			child.hide()
	_play_random(MINE_SOUNDS)
	await get_tree().create_timer(0.4).timeout
	queue_free()

func _play_random(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	sfx_player.stream = sounds[randi() % sounds.size()]
	sfx_player.play()
