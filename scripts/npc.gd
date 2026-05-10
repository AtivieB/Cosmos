extends Area2D

# ============================================================
# NPC.gd — Two-stage dialog: before battle and after battle
# Level script calls set_battle_complete() after all enemies die
# ============================================================

@export var speaker_name : String = "The Watcher"

@export var pre_battle_lines : Array[String] = [
	"Welcome, chosen warrior. I am the Watcher.",
	"This floor is overrun with dimensional creatures.",
	"You must defeat them all before you can advance.",
	"Collect any items you find — they will help you.",
	"When all enemies fall, a portal will appear.",
    "Return to me when the battle is done. Now go!"
]

@export var post_battle_lines : Array[String] = [
	"You have done it! The floor is clear.",
	"I can feel your strength growing, warrior.",
	"The next floor will be far more dangerous.",
	"The Calamity is powerful — but so are you now.",
    "Enter the portal when you are ready. Good luck."
]

@export var typing_speed : float = 0.04

var dialog_lines  : Array[String] = []
var current_line  : int    = 0
var player_nearby : bool   = false
var is_typing     : bool   = false
var full_text     : String = ""
var player_ref             = null
var battle_done   : bool   = false

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited",  _on_body_exited)
	_set_dialog_visible(false)
	if has_node("InteractHint"):
		$InteractHint.visible = false
	# Start with pre-battle dialog
	dialog_lines = pre_battle_lines
	_safe_play("idle_down")

func set_battle_complete():
	# Called by Level script after all enemies are defeated
	battle_done  = true
	dialog_lines = post_battle_lines
	current_line = 0   # reset so player can read all victory lines
	# Glow effect to signal NPC has new things to say
	if has_node("AnimatedSprite2D"):
		var tween = create_tween().set_loops(3)
		tween.tween_property($AnimatedSprite2D, "modulate",
			Color(1.5, 2.0, 1.5), 0.4)
		tween.tween_property($AnimatedSprite2D, "modulate",
			Color(1, 1, 1), 0.4)

func _process(_delta: float):
	if player_nearby and player_ref != null and not is_typing:
		_face_player()

func _face_player():
	if not is_instance_valid(player_ref): return
	var to_player : Vector2 = player_ref.global_position - global_position
	var ax = abs(to_player.x)
	var ay = abs(to_player.y)
	if ay >= ax:
		_safe_play("idle_down" if to_player.y > 0 else "idle_up")
	else:
		if to_player.x > 0:
			_safe_play("idle_right")
		else:
			if _anim_exists("idle_left"):
				_safe_play("idle_left")
			else:
				_safe_play_flipped("idle_right", true)

func _input(event: InputEvent):
	if not player_nearby: return
	if event.is_action_pressed("interact"):
		if is_typing:
			_skip_typing()
		else:
			_show_next_line()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_nearby = true
		player_ref    = body
		if has_node("InteractHint"):
			$InteractHint.text    = "Press E to speak"
			$InteractHint.visible = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_nearby = false
		player_ref    = null
		is_typing     = false
		current_line  = 0    # reset so player hears all lines next visit
		_set_dialog_visible(false)
		if has_node("InteractHint"):
			$InteractHint.visible = false
		_safe_play("idle_down")

func _show_next_line():
	if has_node("TalkSound"): $TalkSound.play()
	var em = get_node_or_null("/root/EventManager")
	if em: EventManager.on_npc_interacted.emit(name)
	if current_line >= dialog_lines.size():
		_set_dialog_visible(false)
		current_line = 0
		return
	full_text    = dialog_lines[current_line]
	current_line += 1
	_set_dialog_visible(true)
	if has_node("DialogUI/DialogBox/SpeakerLabel"):
		$DialogUI/DialogBox/SpeakerLabel.text = speaker_name + ":"
	if has_node("DialogUI/DialogBox/DialogText"):
		$DialogUI/DialogBox/DialogText.text = ""
	_start_typing()

func _start_typing():
	is_typing = true
	_safe_play("talk") if _anim_exists("talk") else _safe_play("idle_down")
	for i in full_text.length():
		if not is_typing or not is_instance_valid(self): break
		if has_node("DialogUI/DialogBox/DialogText"):
			$DialogUI/DialogBox/DialogText.text = full_text.substr(0, i + 1)
		await get_tree().create_timer(typing_speed).timeout
	if is_instance_valid(self):
		is_typing = false
		_safe_play("idle_down")

func _skip_typing():
	is_typing = false
	if has_node("DialogUI/DialogBox/DialogText"):
		$DialogUI/DialogBox/DialogText.text = full_text
	_safe_play("idle_down")

func _set_dialog_visible(show: bool):
	if has_node("DialogUI/DialogBox"):
		$DialogUI/DialogBox.visible = show

# ── ANIMATION HELPERS ─────────────────────────────────────────
func _safe_play(anim_name: String):
	if not has_node("AnimatedSprite2D"): return
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null: return
	asp.flip_h = false
	if asp.sprite_frames.has_animation(anim_name):
		if asp.animation != anim_name: asp.play(anim_name)
		return
	var base = anim_name.split("_")[0]
	if asp.sprite_frames.has_animation(base) and asp.animation != base:
		asp.play(base)

func _safe_play_flipped(anim_name: String, flip: bool):
	if not has_node("AnimatedSprite2D"): return
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null: return
	asp.flip_h = flip
	if asp.sprite_frames.has_animation(anim_name):
		if asp.animation != anim_name: asp.play(anim_name)
		return
	var base = anim_name.split("_")[0]
	if asp.sprite_frames.has_animation(base) and asp.animation != base:
		asp.play(base)

func _anim_exists(anim_name: String) -> bool:
	if not has_node("AnimatedSprite2D"): return false
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null: return false
	return asp.sprite_frames.has_animation(anim_name)
