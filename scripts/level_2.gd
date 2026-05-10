extends Node2D

# ============================================================
# Level2.gd — Boss fight level
# Kill boss → portal appears → player chooses to enter
# ============================================================

var enemies_alive : int  = 0
var boss_ref             = null
var battle_done   : bool = false

func _ready():
	await get_tree().process_frame

	var player = get_node_or_null("Player")
	if player:
		player.connect("player_died", _on_player_died)
	else:
		push_error("Level2: Player node missing")

	# Separate boss from regular enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.name == "Boss":
			boss_ref = enemy
			if not enemy.is_connected("boss_died", _on_boss_died):
				enemy.connect("boss_died", _on_boss_died)
		else:
			if not enemy.is_connected("enemy_died", _on_enemy_died):
				enemy.connect("enemy_died", _on_enemy_died)
				enemies_alive += 1

	if boss_ref == null:
		push_warning("Level2: No Boss node found")

	for chest in get_tree().get_nodes_in_group("chests"):
		if not chest.is_connected("item_collected", _on_item_collected):
			chest.connect("item_collected", _on_item_collected)

	for drop in get_tree().get_nodes_in_group("drops"):
		_connect_drop(drop)

	var portal = get_node_or_null("ExitPortal")
	if portal:
		portal.connect("portal_used", _on_portal_used)

	if has_node("BGMusic"):
		$BGMusic.finished.connect(func(): $BGMusic.play())

func _on_enemy_died():
	enemies_alive = max(0, enemies_alive - 1)

func _on_boss_died():
	if battle_done: return
	battle_done = true
	_on_boss_cleared()

func _on_boss_cleared():
	# Stop boss music
	if has_node("BGMusic"): $BGMusic.stop()
	if has_node("LevelCompleteSound"): $LevelCompleteSound.play()

	var em = get_node_or_null("/root/EventManager")
	if em: EventManager.on_level_complete.emit("Level2")

	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self): return

	# Activate exit portal
	var portal = get_node_or_null("ExitPortal")
	if portal and portal.has_method("activate"):
		portal.activate()

	# Update NPC victory dialog
	var npc = get_node_or_null("NPC")
	if npc and npc.has_method("set_battle_complete"):
		npc.set_battle_complete()

	_show_message("The Calamity is defeated!
Return to the Watcher or enter the portal.")

func _on_portal_used():
	get_tree().change_scene_to_file("res://scenes/Win.tscn")

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
