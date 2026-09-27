extends Area3D

var IsRespawning : bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(player : Node3D) -> void:
	if not player.is_in_group("Player") or IsRespawning:
		return
	
	IsRespawning = true
	
	player.movement_mode = "respawn"
	player.update_animation()
	
	player.get_node("Blob").play()
	
	await get_tree().create_timer(0.25).timeout
	
	var CheckpointCollision = player.current_checkpoint.get_node("Collision")
	player.global_position = CheckpointCollision.global_position
	
	player.movement_mode = "default"
	player.update_animation()
	
	IsRespawning = false
