extends CharacterBody3D

@export_category("Movement 🎈")
@export var speed : float = 3.0
@export var jump_velocity : float = 3.5
@export var tilt_amount : float = -15.0
@export var tilt_smoothness : float = 5.0

var current_checkpoint : Node3D
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export_category("Input ⬇️")
@export var input_left : String = "left"
@export var input_right : String = "right"
@export var input_forward : String = "forward"
@export var input_backward : String = "backward"
@export var input_jump : String = "jump"

@export_category("Settings ⚙️")
@export var mouse_sensitivity : float = 0.003
@export var smoothness : float = 10.0
@export var vertical_jump_forward : float = 3.0
@export var idle_animation_delay : float = 8.0

@export_category("Camera 🎥")
@export var camera_lag : float = -0.6
@export var camera_lag_smoothness : float = 2.0
var CameraLagPosition : Vector3
var CameraTargetPosition : Vector3
var CameraTeleporting : bool = false

var verticalJumping = false
var idle_timer : float = 0.0

@onready var cameraPivot = $Pivot
@onready var spring_arm = $Pivot/SpringArm3D
@onready var camera_check = $Pivot/SpringArm3D/Camera3D/Area3D
@onready var characterMesh = $Character
@onready var animationPlayer = $AnimationPlayer
@onready var mesh = $Character/Armature/Skeleton3D/Character

var target_rotation_y : float = 0.0
var movement_mode = "default"

@export var normal_texture: Texture2D
@export var blink_texture: Texture2D

@onready var currentCharacter = $Character/Armature

var defaultCharacterScale = $Character/Armature.scale
var ringCharacterScale = $Character/Ring.scale
var hookCharacterScale = $Character/Hook.scale
var coneCharacterScale = $Character/Cone.scale

var verticalPath = null
var verticalcurrentPoint = 1
var verticalTargetPoint = 0

@export var vertical_bottom_scale : float = 3.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_rotation_y = cameraPivot.rotation.y
	CameraTargetPosition = cameraPivot.global_position
	CameraLagPosition = cameraPivot.position
	random_blink()
	animationPlayer.play("idle", 0.3, 1.5)

func update_animation():
	if movement_mode == "snap":
		idle_timer = 0.0

		if animationPlayer.current_animation != "morph":
			animationPlayer.play("morph", 0.3, 6.0)
	elif  movement_mode == "respawn":
		idle_timer = 0.0

		if animationPlayer.current_animation != "morph":
			animationPlayer.play("idle_2", 0.3, 1.0)
	else:
		if not is_on_floor():
			idle_timer = 0.0

			if animationPlayer.current_animation != "jump":
				animationPlayer.play("jump", 0.3, 2.0)

		elif velocity.length() > 0.1:
			idle_timer = 0.0

			if animationPlayer.current_animation != "walk":
				animationPlayer.play("walk", 0.3, 4.5)

		else:
			idle_timer += get_physics_process_delta_time()

			if idle_timer >= idle_animation_delay:
				if animationPlayer.current_animation != "idle_2":
					animationPlayer.play("idle_2", 0.3, 1.0)
			else:
				if animationPlayer.current_animation != "idle":
					animationPlayer.play("idle", 0.3, 1.5)

func _input(event):
	#if Input.is_action_just_pressed(input_left):
		#print("Left")
	#elif Input.is_action_just_pressed(input_right):
		#print("Right")
	#elif Input.is_action_just_pressed(input_forward):
		#print("Forward")
	#elif Input.is_action_just_pressed(input_backward):
		#print("Backward")

	if event is InputEventMouseMotion:
		target_rotation_y -= event.relative.x * mouse_sensitivity

	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func random_blink():
	while true:
		await get_tree().create_timer(randf_range(2.0, 6.0)).timeout
		await blink()

func blink():
	var material = mesh.get_active_material(0).duplicate()
	mesh.set_surface_override_material(0, material)
	material.albedo_texture = blink_texture

	await get_tree().create_timer(0.15).timeout

	material.albedo_texture = normal_texture

func changeCharacter(character):
	currentCharacter.set_visible(false)
	currentCharacter = character
	currentCharacter.set_visible(true)

	var TargetScale = defaultCharacterScale
	var TargetTime = 0.3

	if currentCharacter == $Character/Ring and verticalPath:
		var Point = verticalPath.get_child(verticalcurrentPoint)
		TargetScale = get_vertical_scale_at_position(Point.global_position)
		TargetTime = 0.25
		mesh = $Character/Ring
	elif currentCharacter == $Character/Hook:
		TargetScale = hookCharacterScale
		TargetTime = 0.5
		mesh = $Character/Hook
	elif currentCharacter == $Character/Armature:
		TargetScale = defaultCharacterScale
		TargetTime = 1.0
		mesh = $Character/Armature/Skeleton3D/Character
	elif currentCharacter == $Character/Cone:
		TargetScale = coneCharacterScale
		TargetTime = 1.0
		mesh = $Character/Cone/Cone

	currentCharacter.scale = Vector3(0.01, 0.01, 0.01)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		currentCharacter,
		"scale",
		TargetScale,
		TargetTime
	)

	await tween.finished


func get_vertical_scale_at_position(Position):
	var TopPoint = verticalPath.get_child(5)
	var BottomPoint = verticalPath.get_child(0)

	var TotalHeight = BottomPoint.global_position.y - TopPoint.global_position.y
	var CurrentHeight = BottomPoint.global_position.y - Position.y
	var Progress = clamp(CurrentHeight / TotalHeight, 0.0, 1.0)

	var Scale = lerp(vertical_bottom_scale, 1.0, Progress)

	return ringCharacterScale * Scale

func update_vertical_scale():
	currentCharacter.scale = get_vertical_scale_at_position(global_position)

func _physics_process(delta: float):
	var camera_collisions = camera_check.get_overlapping_bodies()

	if camera_collisions.size() > 0:
		spring_arm.collision_mask = 1
	else:
		spring_arm.collision_mask = 0

	cameraPivot.rotation.y = lerp_angle(
		cameraPivot.rotation.y,
		target_rotation_y,
		smoothness * delta
	)

	if movement_mode == "default":
		if $Wood.playing:
			$Wood.stop()

		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			if verticalJumping:
				verticalJumping = false
			elif Input.is_action_just_pressed(input_jump):
				$Jump.play()
				velocity.y = jump_velocity

		var input = Input.get_vector(
			input_left,
			input_right,
			input_forward,
			input_backward
		)

		var direction = cameraPivot.global_basis * Vector3(
			input.x,
			0,
			input.y
		)

		direction.y = 0
		direction = direction.normalized()

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		if direction:
			characterMesh.rotation.y = lerp_angle(
				characterMesh.rotation.y,
				atan2(-direction.x, -direction.z),
				7.5 * delta
			)

			if is_on_floor():
				var TargetTiltX = input.y * deg_to_rad(tilt_amount)
				var TargetTiltZ = -input.x * deg_to_rad(tilt_amount)

				characterMesh.rotation.x = lerp(
					characterMesh.rotation.x,
					TargetTiltX,
					tilt_smoothness * delta
				)

				characterMesh.rotation.z = lerp(
					characterMesh.rotation.z,
					TargetTiltZ,
					tilt_smoothness * delta
				)
		else:
			if is_on_floor():
				characterMesh.rotation.x = lerp(
					characterMesh.rotation.x,
					0.0,
					tilt_smoothness * delta
				)

				characterMesh.rotation.z = lerp(
					characterMesh.rotation.z,
					0.0,
					tilt_smoothness * delta
				)

		update_animation()
		move_and_slide()
		
		var TargetCameraPosition = Vector3.ZERO

		if velocity.length() > 0.1:
			TargetCameraPosition = -velocity.normalized() * camera_lag

		CameraLagPosition = CameraLagPosition.lerp(
			TargetCameraPosition,
			camera_lag_smoothness * delta
		)

		cameraPivot.position = CameraLagPosition

	elif movement_mode == "vertical_root":
		var movement = Input.get_axis(
			input_backward,
			input_forward
		)

		var rotationInput = Input.get_axis(
			input_left,
			input_right
		)

		update_vertical_scale()

		if Input.is_action_just_pressed(input_jump):
			var ForwardDirection = characterMesh.global_transform.basis.z.normalized()

			$Jump.play()

			velocity = ForwardDirection * vertical_jump_forward
			velocity.y += jump_velocity

			verticalJumping = true

			changeCharacter($Character/Armature)

			var FlatDirection = ForwardDirection
			FlatDirection.y = 0
			FlatDirection = FlatDirection.normalized()

			var JumpRotation = atan2(
				FlatDirection.x,
				FlatDirection.z
			)

			$Character.global_rotation = Vector3(
				0.0,
				JumpRotation,
				0.0
			)

			movement_mode = "default"
			$Wood.stop()

		if rotationInput != 0:
			characterMesh.rotate_object_local(
				Vector3.UP,
				-rotationInput * 3.5 * delta
			)

		if movement != 0:
			if not $Wood.playing:
				$Wood.play()

			var CurrentPoint = verticalPath.get_child(verticalcurrentPoint)
			var CameraDirection = -cameraPivot.global_transform.basis.z.normalized()

			var ForwardPointIndex = verticalcurrentPoint + 1
			var BackwardPointIndex = verticalcurrentPoint - 1

			var ForwardDirection = Vector3.ZERO
			var BackwardDirection = Vector3.ZERO

			if ForwardPointIndex < verticalPath.get_child_count():
				ForwardDirection = (
					verticalPath.get_child(ForwardPointIndex).global_position -
					CurrentPoint.global_position
				).normalized()

			if BackwardPointIndex >= 0:
				BackwardDirection = (
					verticalPath.get_child(BackwardPointIndex).global_position -
					CurrentPoint.global_position
				).normalized()

			var InputDirection = CameraDirection * movement
			var Direction = 0

			if ForwardDirection != Vector3.ZERO and BackwardDirection != Vector3.ZERO:
				if InputDirection.dot(ForwardDirection) > InputDirection.dot(BackwardDirection):
					Direction = 1
				else:
					Direction = -1

			elif ForwardDirection != Vector3.ZERO:
				if InputDirection.dot(ForwardDirection) > 0.0:
					Direction = 1

			elif BackwardDirection != Vector3.ZERO:
				if InputDirection.dot(BackwardDirection) > 0.0:
					Direction = -1

			if Direction != 0:
				var TargetPoint = verticalcurrentPoint + Direction

				if TargetPoint >= 0 and TargetPoint < verticalPath.get_child_count():
					verticalTargetPoint = TargetPoint

					var Point = verticalPath.get_child(verticalTargetPoint)
					var MoveDirection = (
						Point.global_position - global_position
					).normalized()

					var MovementDistance = (speed * 1.25) * delta

					if global_position.distance_to(Point.global_position) <= MovementDistance:
						global_position = Point.global_position
						verticalcurrentPoint = verticalTargetPoint
					else:
						global_position += MoveDirection * MovementDistance
		else:
			$Wood.stop()
