extends Node

@export_category("Wind 🍃")
@export var wind_amount : float = 4.0
@export var wind_speed : float = 1.5
@export var update_rate : float = 0.03
@export var wind_distance : float = 40.0

var Foliage = []
var FoliageData = []
var UpdateTimer : float = 0.0
var time : float = 0.0
var Player

func _ready() -> void:
	Foliage = get_tree().get_nodes_in_group("Foliage")
	Player = get_tree().get_first_node_in_group("Player")

	for Index in Foliage.size():
		var object = Foliage[Index]

		if not is_instance_valid(object):
			continue

		FoliageData.append({
			"Object": object,
			"Rotation": object.rotation,
			"Offset": Index * 0.37
		})

func _process(delta : float) -> void:
	time += delta
	UpdateTimer += delta

	if UpdateTimer < update_rate:
		return

	UpdateTimer = 0.0

	for Data in FoliageData:
		var object = Data["Object"]

		if not is_instance_valid(object):
			continue

		if Player:
			var Distance = object.global_position.distance_to(
				Player.global_position
			)

			if Distance > wind_distance:
				continue

		var Offset = Data["Offset"]
		var OriginalRotation = Data["Rotation"]

		var WindX = sin(time * wind_speed + Offset) * wind_amount
		var WindZ = cos(time * wind_speed * 0.8 + Offset) * wind_amount

		object.rotation.x = OriginalRotation.x + deg_to_rad(WindX)
		object.rotation.z = OriginalRotation.z + deg_to_rad(WindZ)
