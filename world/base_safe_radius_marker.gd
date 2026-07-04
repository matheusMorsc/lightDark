extends Node2D

@export var radius: float = 420.0
@export var fill_color: Color = Color(0.28, 0.62, 1.0, 0.05)
@export var ring_color: Color = Color(0.5, 0.78, 1.0, 0.45)
@export var ring_width: float = 4.0
@export var pulse_amplitude: float = 0.08
@export var pulse_speed: float = 1.8

var _time: float = 0.0

func _ready() -> void:
	z_index = -1
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(_time * pulse_speed) * pulse_amplitude
	var draw_radius := radius * pulse
	draw_circle(Vector2.ZERO, draw_radius, fill_color)
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 96, ring_color, ring_width, true)
