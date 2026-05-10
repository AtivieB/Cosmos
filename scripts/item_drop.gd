extends Area2D

# ============================================================
# ItemDrop.gd — Enemy loot with scatter + magnet attraction
# ============================================================

@export var item_name    : String = "Gold Coin"
@export var quantity     : int    = 1
@export var magnet_speed : float  = 210.0

var collected : bool = false

signal item_picked_up(item : String, qty : int)

func _ready():
	add_to_group("drops")
	connect("body_entered", _on_body_entered)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("spin")
	_scatter()

func _scatter():
	# Random scatter effect when spawned
	var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var tween  = create_tween()
	tween.tween_property(self, "global_position",
		global_position + offset, 0.3).set_ease(Tween.EASE_OUT)

func _on_body_entered(body: Node2D):
	if collected: return
	if body.is_in_group("player"):
		collected = true
		call_deferred("_collect")

func attract_to(target_pos: Vector2, delta: float):
	# Called by Player._attract_items when within MAGNET_RANGE
	# VECTOR: normalised direction toward player
	var direction : Vector2 = (target_pos - global_position).normalized()
	global_position += direction * magnet_speed * delta

func _collect():
	item_picked_up.emit(item_name, quantity)
	queue_free()
