extends CharacterBody2D

# ============================================================
# Player.gd — Cosmos Game
# This is a TOP-DOWN game. No gravity.
# Physics: Newton's 2nd Law F=ma for acceleration and friction
# Vectors: Vector2 used for all direction calculations
# ============================================================

# --- PHYSICS CONSTANTS (Newton's Law visible to marker) ---
const MASS          = 2.0     # kg — heavier = slower acceleration
const MAX_SPEED     = 220.0   # pixels/second — terminal velocity
const ACCELERATION  = 900.0   # Force applied when moving (px/s²)
const FRICTION      = 700.0   # Opposing force when stopping (px/s²)
# Note: actual acceleration = ACCELERATION / MASS = 450 px/s²

var health      = 100
var max_health  = 100
var alive       = true
var attack_power = 25
var throw_power  = 15
var attack_timer = 0.0
var throw_timer  = 0.0

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO

var state : String = "idle"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D


signal health_changed(new_health)
signal player_died

func _ready():
	add_to_group("player")

func _physics_process(delta):
	if not alive:
		return
		
	

	# --- VECTOR: read input as a 2D direction vector ---
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"): direction.x += 1
	if Input.is_action_pressed("move_left"):  direction.x -= 1
	if Input.is_action_pressed("move_down"):  direction.y += 1
	if Input.is_action_pressed("move_up"):    direction.y -= 1

	# VECTOR: normalise so diagonal = same speed as cardinal
	if direction.length() > 0:
		direction = direction.normalized()

	if direction != Vector2.ZERO:
		# NEWTON'S 2ND LAW: Force = Mass x Acceleration
		# Player pushes off ground → engine applies force
		# velocity approaches max speed smoothly
		velocity = velocity.move_toward(
			direction * MAX_SPEED,
			(ACCELERATION / MASS) * delta * MASS
		)
	else:
		# FRICTION: opposing force slows player to a stop
		# when no input is pressed
		velocity = velocity.move_toward(
			Vector2.ZERO,
			(FRICTION / MASS) * delta * MASS
		)

	# Clamp to max speed (terminal velocity)
	velocity = velocity.limit_length(MAX_SPEED)

	# Flip sprite to face movement direction
	if direction.x > 0:
		$Sprite2D.flip_h = false
	elif direction.x < 0:
		$Sprite2D.flip_h = true

	move_and_slide()

	# Count down attack cooldowns
	attack_timer -= delta
	throw_timer  -= delta

func _input(event):
	if not alive: return
	if event.is_action_pressed("attack") and attack_timer <= 0:
		do_attack()
	if event.is_action_pressed("throw") and throw_timer <= 0:
		do_throw()

func do_attack():
	attack_timer = 0.5
	if has_node("AttackSound"): $AttackSound.play()
	# Flash yellow briefly to show attack
	modulate = Color(1.6, 1.6, 0.4)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		# VECTOR: distance check using vector magnitude
		if global_position.distance_to(e.global_position) < 85:
			e.take_damage(attack_power)

func do_throw():
	throw_timer = 1.2
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		# VECTOR: direction and distance to each enemy
		var to_enemy = e.global_position - global_position
		if to_enemy.length() < 260:
			e.take_damage(throw_power)

func take_damage(amount):
	if not alive: return
	health -= amount
	if has_node("HurtSound"): $HurtSound.play()
	# Flash red when hurt
	modulate = Color(2.2, 0.3, 0.3)
	await get_tree().create_timer(0.15).timeout
	modulate = Color(1, 1, 1)
	health_changed.emit(health)
	if health <= 0:
		health = 0
		alive  = false
		player_died.emit()
		
func SetDirection() -> bool:
	
	return true
	

func SetState() -> bool:
	
	return true
	
func UpdateAnimation() -> void:
	animation_player.play(state + "_" + "down")
	pass
