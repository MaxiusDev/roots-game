extends MeshInstance3D

@export var interact_distance : float = 4.0
@export var snap_duration : float = 0.1
@export var snap_angle : float = deg_to_rad(-40.0)
@export var swing_duration : float = 0.35
@export var launch_force : float = 10.0
@export var launch_upward : float = 5.0
@export var line_cooldown : float = 1.5

@onready var pivot = $SwingPoint

var interaction_line
var swinging = false
var line_cooldown_timer = 0.0
var launch_direction = Vector3.FORWARD

func _ready():
	var asset = get_tree().current_scene.get_node("Assets/InteractionLine")

	interaction_line = MeshInstance3D.new()
	interaction_line.name = "InteractionLine"
	interaction_line.mesh = asset.mesh
	interaction_line.material_override = asset.material_override
	interaction_line.cast_shadow = asset.cast_shadow
	interaction_line.visible = false

	add_child(interaction_line)

func _process(delta: float) -> void:
	if not interaction_line:
		return

	if line_cooldown_timer > 0.0:
		line_cooldown_timer -= delta
		interaction_line.visible = false
		return

	var player = get_tree().get_first_node_in_group("Player")

	if not player:
		return

	if player.movement_mode != "default":
		interaction_line.visible = false
		return

	var distance = player.global_position.distance_to(
		pivot.global_position
	)

	if distance <= interact_distance:
		interaction_line.visible = true

		update_interaction_line(player, pivot)

		if Input.is_action_just_pressed("interact"):
			start_swing(player)
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

func start_swing(player):
	swinging = true
	interaction_line.visible = false

	var ToPivot = pivot.global_position - player.global_position
	ToPivot.y = 0.0

	if ToPivot.length_squared() > 0.001:
		ToPivot = ToPivot.normalized()

	launch_direction = ToPivot

	var Character = player.get_node("Character")

	var CharacterYRotation = atan2(
		-ToPivot.x,
		-ToPivot.z
	) + PI

	Character.global_rotation.y = CharacterYRotation

	player.movement_mode = "snap"
	player.update_animation()
	
	player.get_node("Interact").play()
	await snap_player_to_pivot(player)

	player.changeCharacter(
		player.get_node("Character/Cone")
	)
	player.get_node("Blob").play()

	Character = player.get_node("Character")

	Character.rotation.x = -snap_angle

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		Character,
		"rotation:x",
		snap_angle * 1.5,
		swing_duration
	)

	await tween.finished

	if not swinging:
		return
	player.get_node("Wind").play()
	launch_player(player)

func snap_player_to_pivot(player):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		player,
		"global_position",
		pivot.global_position,
		snap_duration
	)

	tween.parallel().tween_property(
		player.get_node("Character"),
		"rotation:x",
		-snap_angle,
		snap_duration
	)

	await tween.finished

func launch_player(player):
	player.changeCharacter(
		player.get_node("Character/Armature")
	)
	
	player.global_position = player.get_node("Character/Cone/Cone/PlayerPos").global_position

	player.movement_mode = "default"
	player.update_animation()

	player.velocity = launch_direction * launch_force
	player.velocity.y = launch_upward

	swinging = false
	line_cooldown_timer = line_cooldown
