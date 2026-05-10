extends Area2D

# ============================================================
# HealthItem.gd — Restores player HP on contact
# Floating tween makes it easy to spot in the level
# ============================================================

@export var heal_amount : int = 35
var collected : bool = false

func _ready():
	add_to_group("health_items")
	connect("body_entered", _on_body_entered)
	_start_float()

func _start_float():
	# Gentle up-down float animation — no extra animation nodes needed
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position",
		position + Vector2(0, -8), 0.9).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position",
		position, 0.9).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D):
	if collected: return
	if body.is_in_group("player"):
		collected = true
		call_deferred("_collect", body)

func _collect(player: Node):
	if not is_instance_valid(player): return
	if player.has_method("heal"):
		player.heal(heal_amount)
	queue_free()
