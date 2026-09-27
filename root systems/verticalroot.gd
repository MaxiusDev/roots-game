extends MeshInstance3D

@export var interact_distance : float = 2.0
@export var snap_duration : float = 0.4
@onready var path = $Path

var interaction_line

func _ready():
	var asset = get_tree().current_scene.get_node("Assets/InteractionLine")

	interaction_line = MeshInstance3D.new()
	interaction_line.name = "InteractionLine"
	interaction_line.mesh = asset.mesh
	interaction_line.material_override = asset.material_override
	interaction_line.cast_shadow = asset.cast_shadow
	interaction_line.visible = false

	add_child(interaction_line)

func _process(_delta: float) -> void:
	if not interaction_line:
		return

	var player = get_tree().get_first_node_in_group("Player")

	if not player:
		return

	if player.movement_mode != "default":
		interaction_line.visible = false
		return

	var nearest_point = get_nearest_path(player)

	if not nearest_point:
		interaction_line.visible = false
		return

	var distance = player.global_position.distance_to(nearest_point.global_position)

	if distance <= interact_distance:
		interaction_line.visible = true

		update_interaction_line(player, nearest_point)

		if Input.is_action_just_pressed("interact"):
			interaction_line.visible = false

			player.verticalPath = path
			player.verticalcurrentPoint = int(nearest_point.name)
			player.verticalTargetPoint = player.verticalcurrentPoint
			player.movement_mode = "snap"
			player.update_animation()
			player.get_node("Interact").play()

			await snap_player_to_point(player, nearest_point)
			player.get_node("Blob").play()
			await player.changeCharacter(
				player.get_node("Character").get_node("Ring")
			)

			player.movement_mode = "vertical_root"
	else:
		interaction_line.visible = false

func update_interaction_line(player, point):
	var Start = player.global_position
	var End = point.global_position

	var Direction = End - Start
	var Distance = Direction.length()

	if Distance <= 0.001:
		return

	interaction_line.global_position = (Start + End) / 2.0

	interaction_line.look_at(
		End,
		Vector3.UP
	)

	interaction_line.rotate_object_local(
		Vector3.RIGHT,
		PI / 2.0
	)

	interaction_line.scale = Vector3(
		1.0,
		Distance,
		1.0
	)

func get_nearest_path(player):
	var nearest_point = null
	var nearest_distance = INF

	for point in path.get_children():
		var distance = player.global_position.distance_to(point.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_point = point

	return nearest_point

func snap_player_to_point(player, point):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		player,
		"global_position",
		point.global_position,
		snap_duration
	)

	tween.parallel().tween_property(
		player.get_node("Character"),
		"global_rotation",
		point.global_rotation,
		snap_duration
	)

	await tween.finished
