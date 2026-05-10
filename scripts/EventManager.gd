extends Node

# ============================================================
# EventManager.gd — Central event trigger system
# All game events flow through here as signals
# This is the Event Triggers system for the rubric
# ============================================================

signal on_enemy_died(enemy_name)
signal on_boss_phase_change(phase_number)
signal on_item_collected(item_name, quantity)
signal on_chest_opened(chest_id)
signal on_player_damaged(amount)
signal on_level_complete(level_name)
signal on_npc_interacted(npc_name)
signal on_game_saved
signal on_game_loaded
