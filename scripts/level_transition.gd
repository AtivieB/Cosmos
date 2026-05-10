extends Control

# No button needed — auto-advances after 2.5 seconds
func _ready():
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/Level2.tscn")
