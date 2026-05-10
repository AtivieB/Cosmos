extends CharacterBody2D

# ============================================================
# Enemy.gd — Cosmos Game (Complete Script)
# Features:
#   - Directional animations: walk_down, walk_up,
#     walk_left, walk_right, idle per direction,
#     attack, hurt, death
#   - Safe zone respect (cannot enter player safe area)
#   - Item drop on death (configurable chance + item)
#   - Hurt flash with colour tint
#   - Physics: velocity-based movement with Vector2
#   - All node access guarded with has_node()
# ============================================================

# --- Exported stats — change per enemy in the Inspector ---
@export var health          : int   = 60
@export var max_health      : int   = 60
@export var speed           : float = 55.0
@export var damage          : int   = 8
@export var detection_range : float = 320.0   # how far enemy sees player
@export var stop_distance   : float = 52.0    # how close enemy gets before stopping
@export var drop_chance     : float = 0.5     # 0.0 = never drop, 1.0 = always drop
@export var drop_item       : String = "Gold Coin"

# --- Internal state ---
var player_ref  = null        # reference to the player node
var dead        : bool = false
var is_hurting  : bool = false
var last_dir    : String = "down"   # last movement direction for idle animation

# --- Signal emitted when this enemy dies ---
signal enemy_died

# ============================================================
# READY
# ============================================================
func _ready():
	add_to_group("enemies")

	# Connect attack timer — node must exist in scene
	if has_node("AttackTimer"):
		$AttackTimer.timeout.connect(_on_attack_timer)
	else:
		push_warning("Enemy: AttackTimer node missing — add a Timer node named AttackTimer")

	# Wait one frame so player has finished its own _ready()
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")

	if player_ref == null:
		push_warning("Enemy: No node found in group 'player'")

	# Start in idle animation
	_play_idle_anim()

# ============================================================
# MAIN PHYSICS LOOP
# ============================================================
func _physics_process(_delta: float):
	if dead or player_ref == null:
		return

	# --- SAFE ZONE CHECK ---
	# If the player is inside a safe zone, stop chasing
	if _is_player_safe():
		velocity = Vector2.ZERO
		move_and_slide()
		if not is_hurting:
			_play_idle_anim()
		return

	# --- VECTOR: direction and distance to player ---
	var to_player : Vector2 = player_ref.global_position - global_position
	var distance  : float   = to_player.length()   # VECTOR: magnitude

	if distance < detection_range and distance > stop_distance:
		# Player is in range and not too close — chase
		var direction : Vector2 = to_player.normalized()   # VECTOR: normalise
		velocity = direction * speed
		move_and_slide()
		_update_last_dir(direction)
		if not is_hurting:
			_play_walk_anim(direction)

	elif distance <= stop_distance:
		# Close enough — stand still and attack
		velocity = Vector2.ZERO
		move_and_slide()
		if not is_hurting:
			_safe_play("attack")

	else:
		# Player out of detection range — idle
		velocity = Vector2.ZERO
		move_and_slide()
		if not is_hurting:
			_play_idle_anim()

# ============================================================
# ATTACK TIMER — deals damage when standing beside player
# ============================================================
func _on_attack_timer():
	if dead or player_ref == null:
		return
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < stop_distance + 15:
		player_ref.take_damage(damage)

# ============================================================
# TAKE DAMAGE
# ============================================================
func take_damage(amount: int):
	if dead:
		return
	health -= amount
	if has_node("HitSound"):
		$HitSound.play()
	if not is_hurting:
		_hurt_flash()
	if health <= 0:
		die()

# ============================================================
# HURT FLASH — brief colour tint + hurt animation
# ============================================================
func _hurt_flash():
	is_hurting = true
	_safe_play("hurt")
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(2.8, 0.4, 0.4)
	await get_tree().create_timer(0.28).timeout
	if not is_instance_valid(self) or dead:
		return
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 1, 1)
	is_hurting = false

# ============================================================
# DEATH — animation, item drop, then remove from scene
# ============================================================
func die():
	dead     = true
	velocity = Vector2.ZERO

	# Emit signal so Level script counts down enemies_alive
	enemy_died.emit()

	# Notify EventManager if it is registered as Autoload
	var em = get_node_or_null("/root/EventManager")
	if em:
		EventManager.on_enemy_died.emit(name)

	# Spawn item drop BEFORE death animation so it appears on time
	_spawn_drop()

	# Play death animation then free the node
	_safe_play("death")
	await get_tree().create_timer(0.85).timeout
	if is_instance_valid(self):
		queue_free()

# ============================================================
# ITEM DROP — spawns an ItemDrop scene at enemy position
# ============================================================
func _spawn_drop():
	if randf() > drop_chance:
		return   # no drop this time

	var scene = load("res://scenes/ItemDrop.tscn")
	if scene == null:
		push_warning("Enemy: res://scenes/ItemDrop.tscn not found — skipping drop")
		return

	var drop              = scene.instantiate()
	drop.item_name        = drop_item
	drop.global_position  = global_position

	# Use call_deferred so the drop is added after the current physics step
	get_parent().call_deferred("add_child", drop)

# ============================================================
# SAFE ZONE CHECK
# Checks if the player is currently inside any safe zone.
# Returns true if so — enemy will not chase.
# ============================================================
func _is_player_safe() -> bool:
	if player_ref == null:
		return false
	for zone in get_tree().get_nodes_in_group("safe_zones"):
		if zone.has_method("contains_body") and zone.contains_body(player_ref):
			return true
	return false

# ============================================================
# DIRECTION TRACKING
# Updates last_dir based on current movement vector.
# Used to choose the correct idle animation when stopping.
# ============================================================
func _update_last_dir(direction: Vector2):
	var ax = abs(direction.x)
	var ay = abs(direction.y)
	if ay >= ax:
		last_dir = "down" if direction.y > 0 else "up"
	else:
		last_dir = "right" if direction.x > 0 else "left"

# ============================================================
# DIRECTIONAL WALK ANIMATION
# Chooses walk_down / walk_up / walk_right / walk_left
# based on the movement direction vector.
# If walk_left does not exist, mirrors walk_right.
# ============================================================
func _play_walk_anim(direction: Vector2):
	var ax = abs(direction.x)
	var ay = abs(direction.y)
	if ay >= ax:
		# Primarily vertical movement
		_safe_play("walk_down" if direction.y > 0 else "walk_up")
	else:
		# Primarily horizontal movement
		if direction.x > 0:
			_safe_play("walk_right")
		else:
			# Try walk_left first — if missing, flip walk_right
			if _anim_exists("walk_left"):
				_safe_play("walk_left")
			else:
				_safe_play_flipped("walk_right", true)

# ============================================================
# DIRECTIONAL IDLE ANIMATION
# Plays idle_down / idle_up / idle_left / idle_right
# matching the last direction the enemy moved.
# Falls back to idle_down if directional idle is missing.
# ============================================================
func _play_idle_anim():
	var anim = "idle_" + last_dir
	if _anim_exists(anim):
		_safe_play(anim)
	else:
		_safe_play("idle_down")

# ============================================================
# ANIMATION HELPERS
# All three functions guard against missing nodes,
# null SpriteFrames, and missing animation names.
# _safe_play      — plays animation, resets flip_h
# _safe_play_flipped — plays with flip_h set (for mirroring)
# _anim_exists    — checks if animation name exists safely
# ============================================================
func _safe_play(anim_name: String):
	if not has_node("AnimatedSprite2D"):
		return
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null:
		return
	asp.flip_h = false
	if asp.sprite_frames.has_animation(anim_name):
		if asp.animation != anim_name:
			asp.play(anim_name)
		return
	# Fallback: strip direction suffix and try base name
	# e.g. "walk_down" → tries "walk" if walk_down missing
	var base = anim_name.split("_")[0]
	if asp.sprite_frames.has_animation(base) and asp.animation != base:
		asp.play(base)

func _safe_play_flipped(anim_name: String, flip: bool):
	if not has_node("AnimatedSprite2D"):
		return
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null:
		return
	asp.flip_h = flip
	if asp.sprite_frames.has_animation(anim_name):
		if asp.animation != anim_name:
			asp.play(anim_name)
		return
	var base = anim_name.split("_")[0]
	if asp.sprite_frames.has_animation(base) and asp.animation != base:
		asp.play(base)

func _anim_exists(anim_name: String) -> bool:
	if not has_node("AnimatedSprite2D"):
		return false
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null:
		return false
	return asp.sprite_frames.has_animation(anim_name)
