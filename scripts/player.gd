extends CharacterBody2D

# ============================================================
# Player.gd — Cosmos: Full Directional Animation System
# Animations: idle_down/up/left/right, walk_down/up/left/right,
#             attack, hurt, death
# Physics: Newton's 2nd Law (F = ma)
# Vectors: Vector2 for all direction/distance calculations
# ============================================================

const MASS         = 2.0
const MAX_SPEED    = 220.0
const ACCELERATION = 900.0
const FRICTION     = 700.0
const MAGNET_RANGE = 130.0

@export var cam_limit_right  : int = 1600
@export var cam_limit_bottom : int = 900

var health       : int   = 100
var max_health   : int   = 100
var alive        : bool  = true
var attack_power : int   = 25
var throw_power  : int   = 15
var attack_timer : float = 0.0
var throw_timer  : float = 0.0
var stunned      : bool  = false
var stun_timer   : float = 0.0
var state_locked : bool  = false

# Tracks which direction the player last moved in
# so idle animation matches the last walk direction
var last_dir : String = "down"

signal health_changed(new_hp : int)
signal player_died

# ── SETUP ───────────────────────────────────────────────────
func _ready():
	add_to_group("player")
	if has_node("Camera2D"):
		$Camera2D.limit_left   = 0
		$Camera2D.limit_top    = 0
		$Camera2D.limit_right  = cam_limit_right
		$Camera2D.limit_bottom = cam_limit_bottom

# ── MAIN LOOP ────────────────────────────────────────────────
func _physics_process(delta: float):
	if not alive: return

	# STUN STATE: cannot move, plays hurt animation
	if stunned:
		stun_timer = max(0.0, stun_timer - delta)
		if stun_timer <= 0.0:
			stunned      = false
			state_locked = false
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	# VECTOR: 2D input direction
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1.0
	if Input.is_action_pressed("move_left"):  dir.x -= 1.0
	if Input.is_action_pressed("move_down"):  dir.y += 1.0
	if Input.is_action_pressed("move_up"):    dir.y -= 1.0
	if dir.length() > 0:
		dir = dir.normalized()   # VECTOR: normalise

	# NEWTON'S 2ND LAW: a = F / m
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(
			dir * MAX_SPEED, (ACCELERATION / MASS) * delta * MASS)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO, (FRICTION / MASS) * delta * MASS)
	velocity = velocity.limit_length(MAX_SPEED)

	move_and_slide()
	_attract_items(delta)
	attack_timer = max(0.0, attack_timer - delta)
	throw_timer  = max(0.0, throw_timer  - delta)

	# Animation — only when not locked by attack or hurt
	if not state_locked:
		if velocity.length() > 10.0:
			_update_last_dir(velocity)
			_play_walk_anim(velocity)
		else:
			_play_idle_anim()

	# Sword position — follows last direction
	_update_sword_pos()

# ── DIRECTION HELPERS ────────────────────────────────────────
func _update_last_dir(vel: Vector2):
	var ax = abs(vel.x)
	var ay = abs(vel.y)
	if ay >= ax:
		last_dir = "down" if vel.y > 0 else "up"
	else:
		last_dir = "right" if vel.x > 0 else "left"

func _update_sword_pos():
	if not has_node("Sword"): return
	match last_dir:
		"down":  $Sword.position = Vector2(10,  18)
		"up":    $Sword.position = Vector2(10, -18)
		"right": $Sword.position = Vector2(22,   0)
		"left":  $Sword.position = Vector2(-22,  0)

# ── ANIMATION ───────────────────────────────────────────────
func _play_walk_anim(vel: Vector2):
	var ax  = abs(vel.x)
	var ay  = abs(vel.y)
	if ay >= ax:
		_safe_play("walk_down" if vel.y > 0 else "walk_up")
	else:
		if vel.x > 0:
			_safe_play("walk_right")
		else:
			# Try walk_left first — if missing, flip walk_right
			if _anim_exists("walk_left"):
				_safe_play("walk_left")
			else:
				_safe_play_flipped("walk_right", true)

func _play_idle_anim():
	var anim = "idle_" + last_dir
	# Try directional idle first, then fall back to idle_down
	if _anim_exists(anim):
		_safe_play(anim)
	else:
		_safe_play("idle_down")

# ── INPUT ────────────────────────────────────────────────────
func _input(event: InputEvent):
	if not alive or stunned or state_locked: return
	if event.is_action_pressed("attack") and attack_timer <= 0.0:
		_do_attack()
	if event.is_action_pressed("throw") and throw_timer <= 0.0:
		_do_throw()

func _do_attack():
	attack_timer = 0.6
	state_locked = true
	_safe_play("attack")
	if has_node("AttackSound"): $AttackSound.play()
	if has_node("Sword"):       $Sword.modulate = Color(2.2, 2.2, 0.4)
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < 90:
			e.take_damage(attack_power)
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self): return
	if has_node("Sword"): $Sword.modulate = Color(1, 1, 1)
	state_locked = false

func _do_throw():
	throw_timer = 1.2
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_enemy : Vector2 = e.global_position - global_position
		if to_enemy.length() < 260:
			e.take_damage(throw_power)

# ── DAMAGE / HEAL / STUN ─────────────────────────────────────
func take_damage(amount: int):
	if not alive: return
	health = max(0, health - amount)
	health_changed.emit(health)
	if has_node("HurtSound"): $HurtSound.play()
	_trigger_stun(0.55)
	if health <= 0:
		alive = false
		_safe_play("death")
		player_died.emit()

func _trigger_stun(duration: float):
	stunned      = true
	stun_timer   = duration
	state_locked = true
	_safe_play("hurt")
	modulate = Color(2.5, 0.3, 0.3)
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1)

func heal(amount: int):
	health = min(health + amount, max_health)
	health_changed.emit(health)
	modulate = Color(0.4, 2.8, 0.4)
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(self): modulate = Color(1, 1, 1)

# ── ITEM MAGNET ──────────────────────────────────────────────
func _attract_items(delta: float):
	for drop in get_tree().get_nodes_in_group("drops"):
		if not is_instance_valid(drop): continue
		var to_player : Vector2 = global_position - drop.global_position
		if to_player.length() < MAGNET_RANGE:
			drop.attract_to(global_position, delta)

# ── SAFE ANIMATION HELPERS ───────────────────────────────────
func _safe_play(anim_name: String):
	if not has_node("AnimatedSprite2D"): return
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null: return
	asp.flip_h = false   # reset flip
	if asp.sprite_frames.has_animation(anim_name):
		if asp.animation != anim_name: asp.play(anim_name)
		return
	# Fallback: try base name before underscore (e.g. "walk" from "walk_down")
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
