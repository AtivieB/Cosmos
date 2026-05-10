extends Area2D

# ============================================================
# ExitPortal.gd — Appears after all enemies are defeated.
# Player walks into it to go to the next level.
# ============================================================

@export var next_scene : String = "res://scenes/LevelTransition.tscn"

var active : bool = false

signal portal_used

func _ready():
	connect("body_entered", _on_body_entered)
	visible = false   # hidden at start — activated by Level script

func activate():
	if active: return
	active  = true
	visible = true
	# Pulsing glow effect to draw player attention
	var tween = create_tween().set_loops()
	tween.tween_property($PortalGlow, "modulate",
		Color(1.5, 0.8, 3.0, 1.0), 0.7).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($PortalGlow, "modulate",
		Color(0.6, 0.3, 1.2, 1.0), 0.7).set_ease(Tween.EASE_IN_OUT)
	# Fade in the portal
	modulate = Color(1, 1, 1, 0)
	var fade = create_tween()
	fade.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.8)
	if has_node("PortalSound"): $PortalSound.play()
	if has_node("PortalLabel"): $PortalLabel.visible = true

#func _on_body_entered(body: Node2D):
#	if not active: return
#	if body.is_in_group("player"):
#		portal_used.emit()
#		call_deferred("_go_next")
		
func _on_body_entered(body: Node2D):
	print("ENTERED PORTAL BY:", body.name)

	if not active:
		print("Portal not active")
		return

	if body.is_in_group("player"):
		print("PLAYER DETECTED → switching scene")
		call_deferred("_go_next")

func _go_next():
	get_tree().change_scene_to_file(next_scene)
	
