extends Control

func _ready():
	$StoryLabel.text = """COSMOS — The Tower Between Worlds

Earth is under attack by powerful cosmic entities.
Human weapons are completely useless against them.

The Universal Watchers have selected YOU —
a lone warrior sent into another dimension.

An endless Tower stands before you.
Climb it.  Grow stronger.  Return and save Earth.

Press Begin Journey to enter the Tower."""

func _on_begin_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")
