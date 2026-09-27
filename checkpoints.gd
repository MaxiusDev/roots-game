extends Node3D

func _ready() -> void:
	for Checkpoint in get_children():
		if Checkpoint is Area3D:
			Checkpoint.body_entered.connect(_on_checkpoint_entered.bind(Checkpoint))

func _on_checkpoint_entered(Body : Node3D, Checkpoint : Area3D) -> void:
	if not Body.is_in_group("Player"):
		return
	
	var CheckpointNumber = int(Checkpoint.name)
	var CurrentCheckpointNumber = 0
	
	if Body.current_checkpoint:
		CurrentCheckpointNumber = int(Body.current_checkpoint.name)
	
	if CheckpointNumber > CurrentCheckpointNumber:
		Body.current_checkpoint = Checkpoint
