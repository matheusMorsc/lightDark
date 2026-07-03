extends Node2D

## Gera uma formacao rochosa organica (blob irregular) usando o SmartShape2D:
## contorno fechado com jitter aleatorio, colisao solida e um LightOccluder2D
## com o mesmo contorno para que a tocha do player projete sombra real.
##
## Os nos do addon SmartShape2D sao anexados via set_script() direto (sem
## depender de class_name/ClassDB), seguindo o mesmo padrao ja usado para o
## Phantom Camera e o Lit neste projeto.

const SHAPE_SCRIPT := preload("res://addons/rmsmartshape/shapes/shape.gd")
const POINT_ARRAY_SCRIPT := preload("res://addons/rmsmartshape/shapes/point_array.gd")
const SHAPE_MATERIAL_SCRIPT := preload("res://addons/rmsmartshape/materials/shape_material.gd")
const LIT_SHADER := preload("res://addons/lit/shaders/lit_receiver.gdshader")

@export var num_points: int = 10
@export var base_radius: float = 90.0
@export_range(0.0, 0.9, 0.01) var jitter: float = 0.35
@export var rng_seed: int = 1
@export var fill_texture: Texture2D

@onready var collision_polygon: CollisionPolygon2D = $Body/CollisionPolygon2D
@onready var occluder: LightOccluder2D = $Occluder


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var pts := PackedVector2Array()
	for i in num_points:
		var angle: float = (TAU / num_points) * i
		var r: float = base_radius * (1.0 - jitter + rng.randf() * jitter * 2.0)
		pts.append(Vector2(cos(angle), sin(angle)) * r)

	var shape := Node2D.new()
	shape.name = "Shape"
	shape.set_script(SHAPE_SCRIPT)
	add_child(shape)

	var arr := POINT_ARRAY_SCRIPT.new()
	for p in pts:
		arr.add_point(p)
	arr.close_shape()
	shape.set_point_array(arr)

	shape.render_edges = false
	shape.collision_generation_method = 0  # Default: preenchido, bloqueia todo o corpo
	shape.collision_update_mode = 1        # Runtime: gera a colisao ao rodar o jogo
	shape.collision_polygon_node_path = shape.get_path_to(collision_polygon)

	var mat := SHAPE_MATERIAL_SCRIPT.new()
	if fill_texture:
		mat.fill_textures = [fill_texture]
	mat.fill_texture_z_index = 0
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = LIT_SHADER
	mat.fill_mesh_material = shader_mat
	shape.shape_material = mat

	var occ_poly := OccluderPolygon2D.new()
	occ_poly.polygon = pts
	occluder.occluder = occ_poly
