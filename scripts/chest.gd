extends Area2D

# ============================================================
# Chest.gd — FIXED: await moved out of physics callback
# Uses call_deferred to run chest logic after physics step
# ============================================================

@export var item_name : String = "Gold Coin"
@export var quantity  : int    = 1

var opened = false

signal item_collected(item, qty)

func _ready():
	add_to_group("chests")
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	# IMPORTANT: do NOT use await here — physics callback
	# Use call_deferred to safely run logic after physics step
	if opened:
		return
	if body.is_in_group("player"):
		opened = true
		call_deferred("_open_chest")   # ← key fix

func _open_chest():
	# This runs safely outside the physics callback
	# Swap sprite to open chest
	if has_node("Sprite2D"):
		var open_tex = load("res://assets/sprites/Tiles/tile_0107.png")
		if open_tex:
			$Sprite2D.texture = open_tex
		else:
			# If texture not found, just tint the sprite grey
			$Sprite2D.modulate = Color(0.5, 0.5, 0.5)

	# Play open sound safely
	if has_node("OpenSound"):
		$OpenSound.play()

	# Emit item collected signal
	item_collected.emit(item_name, quantity)

	# Emit EventManager signals safely
	if Engine.has_singleton("EventManager") or get_node_or_null("/root/EventManager"):
		EventManager.on_item_collected.emit(item_name, quantity)
		EventManager.on_chest_opened.emit(name)

	# Show popup label safely
	if has_node("PopupLabel"):
		$PopupLabel.text    = "+" + str(quantity) + "  " + item_name
		$PopupLabel.visible = true
		_hide_popup_later()   # separate function handles the await

func _hide_popup_later():
	# await lives here — safe because this is not a physics callback
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self) and has_node("PopupLabel"):
		$PopupLabel.visible = false
