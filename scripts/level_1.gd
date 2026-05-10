extends Node2D

# ============================================================
# Level1.gd — Adventure flow:
# Talk to NPC → fight enemies → portal appears → explore freely
# → walk into portal to go to Level 2
# ============================================================

var enemies_alive : int = 0
var battle_done   : bool = false

func _ready():
	await get_tree().process_frame

	# Connect player
	var player = get_node_or_null("Player")
	if player:
		player.connect("player_died", _on_player_died)
	else:
		push_error("Level1: Player node missing")

	# Connect all enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_connected("enemy_died", _on_enemy_died):
			enemy.connect("enemy_died", _on_enemy_died)
			enemies_alive += 1

	if enemies_alive == 0:
		push_warning("Level1: No enemies found")

	# Connect chests
	for chest in get_tree().get_nodes_in_group("chests"):
		if not chest.is_connected("item_collected", _on_item_collected):
			chest.connect("item_collected", _on_item_collected)

	# Connect item drops already in scene
	for drop in get_tree().get_nodes_in_group("drops"):
		_connect_drop(drop)

	# Connect exit portal (hidden at start)
	var portal = get_node_or_null("ExitPortal")
	if portal:
		portal.connect("portal_used", _on_portal_used)

	# Loop BGM
	if has_node("BGMusic"):
		$BGMusic.finished.connect(func(): $BGMusic.play())

func _on_enemy_died():
	enemies_alive = max(0, enemies_alive - 1)
	if enemies_alive <= 0 and not battle_done:
		battle_done = true
		_on_all_enemies_cleared()

func _on_all_enemies_cleared():
	# Wait a moment then activate portal and update NPC dialog
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self): return

	# Show the exit portal
	var portal = get_node_or_null("ExitPortal")
	if portal and portal.has_method("activate"):
		portal.activate()

	# Update NPC to victory dialog
	var npc = get_node_or_null("NPC")
	if npc and npc.has_method("set_battle_complete"):
		npc.set_battle_complete()

	# Show a HUD message
	_show_message("All enemies defeated!
Speak with the Watcher or enter the portal.")

func _on_portal_used():
	# Player chose to go to Level 2
	get_tree().change_scene_to_file("res://scenes/LevelTransition.tscn")

func _on_item_collected(item_name: String, qty: int):
	var inv = get_node_or_null("Inventory")
	var hud = get_node_or_null("HUD")
	if inv: inv.add_item(item_name, qty)
	if hud and inv: hud.update_items(inv.items.size())

func _connect_drop(drop: Node):
	if not drop.is_connected("item_picked_up", _on_drop_collected):
		drop.connect("item_picked_up", _on_drop_collected)

func _on_drop_collected(item_name: String, qty: int):
	var inv = get_node_or_null("Inventory")
	var hud = get_node_or_null("HUD")
	if inv: inv.add_item(item_name, qty)
	if hud and inv: hud.update_items(inv.items.size())

func _on_player_died():
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _show_message(text: String):
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message(text)

func _input(event: InputEvent):
	if event.is_action_pressed("save_game"):
		var player = get_node_or_null("Player")
		var inv    = get_node_or_null("Inventory")
		if player and inv: SaveLoad.save_game(player, inv)
	if event.is_action_pressed("load_game"):
		var data = SaveLoad.load_game()
		if data:
			var player = get_node_or_null("Player")
			var inv    = get_node_or_null("Inventory")
			if player:
				player.health = data["player_health"]
				player.global_position = Vector2(
					data["player_x"], data["player_y"])
			if inv:
				for item in data["inventory_items"]:
					inv.add_item(item, data["inventory_items"][item])
