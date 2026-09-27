extends MeshInstance3D

@export_category("Movement 🌊")
@export var height_amount : float = 0.15
@export var height_speed : float = 1.0
@export var scroll_speed : Vector2 = Vector2(0.05, 0.05)

var StartPosition : Vector3
var time : float = 0.0
var WaterMaterial : StandardMaterial3D
var UVOffset : Vector3

func _ready() -> void:
	StartPosition = position

	WaterMaterial = get_active_material(0)

	if WaterMaterial is StandardMaterial3D:
		UVOffset = WaterMaterial.uv1_offset

func _process(delta : float) -> void:
	time += delta
	position.y = StartPosition.y + sin(time * height_speed) * height_amount

	if WaterMaterial:
		UVOffset.x += scroll_speed.x * delta
		UVOffset.y += scroll_speed.y * delta
		WaterMaterial.uv1_offset = UVOffset
