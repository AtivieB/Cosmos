extends Node

# ============================================================
# SaveLoad.gd — FIXED: error handling on all file operations
# Press F5 to save, F9 to load (custom Input Map actions)
# ============================================================

const SAVE_PATH = "user://cosmos_save.json"

func save_game(player, inventory):
	if not is_instance_valid(player):
		push_error("SaveLoad: player is invalid")
		return
	var save_data = {
		"player_health"   : player.health,
		"player_x"        : player.global_position.x,
		"player_y"        : player.global_position.y,
		"inventory_items" : inventory.items if inventory else {},
		"current_level"   : get_tree().current_scene.scene_file_path,
		"timestamp"       : Time.get_datetime_string_from_system()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveLoad: could not open file for writing")
		return
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("Game saved: " + save_data["timestamp"])

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveLoad: no save file found at " + SAVE_PATH)
		return null
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveLoad: could not open save file for reading")
		return null
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	if data == null:
		push_error("SaveLoad: save file is corrupted")
		return null
	print("Game loaded successfully")
	return data

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")
