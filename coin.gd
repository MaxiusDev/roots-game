extends MeshInstance3D

@export_category("Collection 🪙")
@export var collect_distance : float = 1.5
@export var collect_animation_duration : float = 0.6
@export var collect_jump_amount : float = 5.0
@export var display : bool = false
@export var displayCoin : Node3D

var defaultColor : Color

@export_category("Animation ✨")
@export var spin_speed : float = 2.5
@export var hover_amount : float = 0.15
@export var hover_speed : float = 2.0

@onready var CoinMesh = self
var CollectSound : AudioStreamPlayer3D

var StartPosition : Vector3
var StartScale : Vector3
var time : float = 0.0
var Player
var Collected : bool = false

func _ready() -> void:
	StartPosition = CoinMesh.position
	StartScale = CoinMesh.scale
	Player = get_tree().get_first_node_in_group("Player")
	
	var material = get_active_material(0)
	defaultColor = material.albedo_color
	
	if display:
		material.albedo_color = defaultColor.darkened(0.6)
	else:
		CollectSound = $Collect

func _process(delta : float) -> void:
	if Collected:
		return

	time += delta
	CoinMesh.rotate_y(spin_speed * delta)
	CoinMesh.position.y = StartPosition.y + sin(time * hover_speed) * hover_amount

	if Player and not display:
		if global_position.distance_to(Player.global_position) <= collect_distance:
			collect()

func collect() -> void:
	Collected = true

	CollectSound.play()
	$Sparkle.playing = false
	
	var displayMaterial = displayCoin.get_active_material(0)
	displayMaterial.albedo_color = defaultColor

	var TargetPosition = position + Vector3.UP * collect_jump_amount

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"position",
		TargetPosition,
		collect_animation_duration
	)

	tween.tween_property(
		self,
		"scale",
		Vector3.ZERO,
		collect_animation_duration
	)

	await tween.finished
	queue_free()
