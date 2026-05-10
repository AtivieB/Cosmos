extends Area2D

# ============================================================
# SafeZone.gd — Tracks which bodies are inside
# Enemies check this before chasing the player
# ============================================================

var bodies_inside : Array = []

func _ready():
	add_to_group("safe_zones")
	connect("body_entered", _on_body_entered)
	connect("body_exited",  _on_body_exited)

func _on_body_entered(body: Node2D):
	if not bodies_inside.has(body):
		bodies_inside.append(body)

func _on_body_exited(body: Node2D):
	bodies_inside.erase(body)

func contains_body(body: Node2D) -> bool:
	return bodies_inside.has(body)
