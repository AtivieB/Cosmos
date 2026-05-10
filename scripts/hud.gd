extends CanvasLayer

# ============================================================
# HUD.gd — FIXED: waits for player to be ready before
# connecting health signal. Safe null checks throughout.
# ============================================================

func _ready():
	# Wait one frame so player has finished its own _ready()
	await get_tree().process_frame
	_connect_to_player()

func _connect_to_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if not player.is_connected("health_changed", _on_health_changed):
			player.connect("health_changed", _on_health_changed)
		_on_health_changed(player.health)   # set bar to current HP immediately
	else:
		# Try again next frame if player not ready yet
		await get_tree().process_frame
		_connect_to_player()

func _on_health_changed(new_hp):
	var safe_hp = max(0, new_hp)
	if has_node("HPBar"):
		$HPBar.value = safe_hp
	if has_node("HPLabel"):
		$HPLabel.text = "HP: " + str(safe_hp) + " / 100"

func update_items(count):
	if has_node("ItemsLabel"):
		$ItemsLabel.text = "Items: " + str(count)
		
func show_message(text: String):
	# Shows a temporary centered message on screen
	if not has_node("MessageLabel"):
		# Create the label if it doesn't exist
		var lbl  = Label.new()
		lbl.name = "MessageLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.position   = Vector2(200, 280)
		lbl.size       = Vector2(400, 80)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		add_child(lbl)
		var font_size = lbl.get_theme_font_size("font_size")
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 0.4))
	var label = $MessageLabel
	label.text    = text
	label.visible = true
	# Auto-hide after 4 seconds
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(label):
		label.visible = false
