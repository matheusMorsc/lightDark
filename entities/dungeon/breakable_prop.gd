extends StaticBody2D
## Prop decorativo do dungeon (caixote, barril, pote, saco, entulho de
## pedra...): quebra num único golpe de QUALQUER arma, sem exigir
## ferramenta equipada. Recebe hit() — mesma interface do Enemy e do
## ResourceNode, então o ataque do player já os enxerga como alvo.
##
## Por quê: run_map.gd espalha esses props aleatoriamente dentro de cada
## sala, sem checar se sobra passagem livre. Numa sala pequena, um punhado
## deles pode (raramente) fechar a única rota e prender o jogador — sem
## este script eles não tinham hit() nenhum, então eram obstáculo
## permanente. Regra geral: tudo que a geração procedural pode colocar no
## caminho do jogador precisa ser quebrável.

const BREAK_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/mine_000.ogg"),
	preload("res://assets/audio/sfx/mine_001.ogg"),
	preload("res://assets/audio/sfx/mine_002.ogg"),
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _broken: bool = false

func hit(_amount: float) -> void:
	if _broken:
		return
	_broken = true
	collision_shape.set_deferred("disabled", true)
	sprite.hide()
	for child in get_children():
		if child is LightOccluder2D or (child is Sprite2D and child != sprite):
			child.hide()
	_spawn_break_fx()
	_play_random(BREAK_SOUNDS)
	await get_tree().create_timer(0.25).timeout
	queue_free()

## Fagulhas de destroços — mesma receita do hit_fx do player, cor terrosa.
func _spawn_break_fx() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.72, 0.6, 0.46)
	p.z_index = 50
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -10)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

func _play_random(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	var player := AudioStreamPlayer2D.new()
	get_parent().add_child(player)
	player.global_position = global_position
	player.stream = sounds[randi() % sounds.size()]
	player.play()
	player.finished.connect(player.queue_free)
