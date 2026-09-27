extends MeshInstance3D

@export var interact_distance : float = 2.0
@export var snap_duration : float = 0.3
@export var slide_duration : float = 2.0
@export var swing_amount : float = 2.0
@export var swing_speed : float = 0.5
@export var bob_amount : float = 0.03
@export var forward_lean : float = 15.0
@export var turn_lean : float = 10.0
@export var end_jump_force : float = 3.0

@onready var path = $Path

var interaction_line
var zipline_tween
var cancel_zipline = false

func _ready():
	var asset = get_tree().current_scene.get_node("Assets/InteractionLine")

	interaction_line = MeshInstance3D.new()
	interaction_line.name = "InteractionLine"
	interaction_line.mesh = asset.mesh
	interaction_line.material_override = asset.material_override
	interaction_line.cast_shadow = asset.cast_shadow
	interaction_line.visible = false

	get_tree().current_scene.add_child.call_deferred(interaction_line)

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("Player")

	if not player:
		return

	if player.movement_mode == "zipline":
		if Input.is_action_just_pressed("jump"):
			jump_off_zipline(player)

		return

	var Nearest = get_nearest_point(player)
	var NearestPathPoint = get_nearest_path(player)

	if Nearest["distance"] <= interact_distance and player.movement_mode == "default":
		interaction_line.visible = true

		update_interaction_line(player, NearestPathPoint)

		if Input.is_action_just_pressed("interact"):
			interaction_line.visible = false
			start_zipline(player, Nearest)
	else:
		interaction_line.visible = false

func get_nearest_path(player):
	var NearestPoint = null
	var NearestDistance = INF

	for Point in path.get_children():
		var Distance = player.global_position.distance_to(
			Point.global_position
		)

		if Distance < NearestDistance:
			NearestDistance = Distance
			NearestPoint = Point

	return NearestPoint

func update_interaction_line(player, point):
	if not point:
		return

	var Start = player.global_position
	var End = point.global_position

	var Direction = End - Start
	var Distance = Direction.length()

	if Distance <= 0.001:
		return

	interaction_line.global_position = (Start + End) / 2.0

	var Up = Vector3.UP

	if abs(Direction.normalized().dot(Vector3.UP)) > 0.99:
		Up = Vector3.FORWARD

	interaction_line.look_at(
		End,
		Up
	)

	interaction_line.rotate_object_local(
		Vector3.RIGHT,
		PI / 2.0
	)

	interaction_line.scale = Vector3(
		1.0,
		Distance * 0.65,
		1.0
	)

func stopSound(player):
	var FadeTween = create_tween()

	FadeTween.tween_property(
		player.get_node("Zipline"),
		"volume_db",
		-80.0,
		0.5
	)

	await FadeTween.finished

	player.get_node("Zipline").volume_db = -10.0
	player.get_node("Zipline").stop()

func get_points():
	var Points = path.get_children()

	Points.sort_custom(func(A, B):
		return int(A.name) < int(B.name)
	)

	return Points

func get_nearest_point(player):
	var Points = get_points()
	var BestDistance = INF
	var BestSegment = 0
	var BestProgress = 0.0

	for Index in range(Points.size() - 1):
		var Start = Points[Index].global_position
		var End = Points[Index + 1].global_position
		var Line = End - Start

		if Line.length_squared() <= 0.001:
			continue

		var T = clamp(
			(player.global_position - Start).dot(Line) / Line.length_squared(),
			0.0,
			1.0
		)

		var Point = Start + Line * T
		var Distance = player.global_position.distance_to(Point)

		if Distance < BestDistance:
			BestDistance = Distance
			BestSegment = Index
			BestProgress = T

	return {
		"distance": BestDistance,
		"segment": BestSegment,
		"progress": BestProgress
	}

func start_zipline(player, nearest):
	cancel_zipline = false

	player.movement_mode = "snap"
	player.get_node("Interact").play()
	player.update_animation()

	var Points = get_points()
	var StartProgress = nearest["segment"] + nearest["progress"]

	var StartPosition = get_spline_position(
		Points,
		nearest["segment"],
		nearest["progress"]
	)

	var Direction = get_spline_direction(
		Points,
		nearest["segment"],
		nearest["progress"]
	)

	var Rotation = atan2(Direction.x, Direction.z)
	var Character = player.get_node("Character")

	Character.global_rotation = Vector3(
		deg_to_rad(forward_lean),
		Rotation,
		0.0
	)

	var SnapTween = create_tween()
	SnapTween.set_trans(Tween.TRANS_QUAD)
	SnapTween.set_ease(Tween.EASE_OUT)

	SnapTween.tween_property(
		player,
		"global_position",
		StartPosition,
		snap_duration
	)

	await SnapTween.finished

	player.get_node("Blob").play()

	if cancel_zipline:
		return

	await player.changeCharacter(
		player.get_node("Character/Hook")
	)

	player.get_node("Zipline").play()

	if cancel_zipline:
		return

	player.movement_mode = "zipline"
	slide_zipline(player, Points, StartProgress)

func slide_zipline(player, Points, StartProgress):
	cancel_zipline = false

	var Character = player.get_node("Character")
	var EndProgress = Points.size() - 1.0

	var RemainingProgress = EndProgress - StartProgress
	var Duration = slide_duration * RemainingProgress / EndProgress

	zipline_tween = create_tween()
	zipline_tween.set_trans(Tween.TRANS_QUAD)
	zipline_tween.set_ease(Tween.EASE_IN)

	zipline_tween.tween_method(
		func(Progress):
			if player.movement_mode == "zipline" and not cancel_zipline:
				update_player(
					player,
					Character,
					Points,
					Progress
				),
		StartProgress,
		EndProgress,
		Duration
	)

	await zipline_tween.finished

	if cancel_zipline or player.movement_mode != "zipline":
		return

	player.global_position = Points[-1].global_position

	stopSound(player)

	player.movement_mode = "default"
	player.changeCharacter(
		player.get_node("Character/Armature")
	)

	Character.rotation = Vector3.ZERO

	player.velocity = Vector3.ZERO
	player.velocity.y = end_jump_force

	player.update_animation()

	zipline_tween = null

func jump_off_zipline(player):
	cancel_zipline = true
	player.get_node("Jump").play()

	if zipline_tween:
		zipline_tween.kill()
		zipline_tween = null

	var Character = player.get_node("Character")

	player.movement_mode = "default"
	player.get_node("Zipline").stop()

	player.changeCharacter(
		player.get_node("Character/Armature")
	)

	Character.rotation = Vector3.ZERO

	player.velocity = Vector3.ZERO
	player.velocity.y = player.jump_velocity

	player.update_animation()

func update_player(player, Character, Points, Progress):
	var Segment = clampi(
		int(Progress),
		0,
		Points.size() - 2
	)

	var LocalProgress = Progress - Segment

	var Position = get_spline_position(
		Points,
		Segment,
		LocalProgress
	)

	var Direction = get_spline_direction(
		Points,
		Segment,
		LocalProgress
	)

	var PreviousDirection = get_spline_direction(
		Points,
		Segment,
		clamp(LocalProgress - 0.05, 0.0, 1.0)
	)

	var Rotation = atan2(Direction.x, Direction.z)
	var Turn = PreviousDirection.cross(Direction).y

	var Swing = sin(
		Progress * swing_speed * PI
	) * deg_to_rad(swing_amount)

	var TurnLean = clamp(
		-Turn * deg_to_rad(turn_lean) * 8.0,
		-deg_to_rad(turn_lean),
		deg_to_rad(turn_lean)
	)

	var Bob = sin(
		Progress * PI * 4.0
	) * bob_amount

	player.global_position = Position + Vector3.UP * Bob

	Character.global_rotation = Vector3(
		deg_to_rad(forward_lean),
		Rotation,
		Swing + TurnLean
	)

func get_spline_position(Points, Segment, Progress):
	var Point0 = Points[max(Segment - 1, 0)].global_position
	var Point1 = Points[Segment].global_position
	var Point2 = Points[Segment + 1].global_position
	var Point3 = Points[min(Segment + 2, Points.size() - 1)].global_position

	var T2 = Progress * Progress
	var T3 = T2 * Progress

	return 0.5 * (
		2.0 * Point1 +
		(-Point0 + Point2) * Progress +
		(2.0 * Point0 - 5.0 * Point1 + 4.0 * Point2 - Point3) * T2 +
		(-Point0 + 3.0 * Point1 - 3.0 * Point2 + Point3) * T3
	)

func get_spline_direction(Points, Segment, Progress):
	var Current = get_spline_position(
		Points,
		Segment,
		Progress
	)

	var Next = get_spline_position(
		Points,
		Segment,
		clamp(Progress + 0.01, 0.0, 1.0)
	)

	return (Next - Current).normalized()
