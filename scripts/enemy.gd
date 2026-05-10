extends CharacterBody2D

# ============================================================
# Enemy.gd — Advanced: AnimatedSprite2D + item drop
# ============================================================

@export var health          : int   = 60
@export var max_health      : int   = 60
@export var speed           : float = 55.0
@export var damage          : int   = 8
@export var detection_range : float = 320.0
@export var stop_distance   : float = 52.0
@export var drop_chance     : float = 0.5   # 50% chance on death
@export var drop_item       : String = "Gold Coin"

var player_ref = null
var dead       : bool = false
var is_hurting : bool = false

signal enemy_died

func _ready():
	add_to_group("enemies")
	if has_node("AttackTimer"):
		$AttackTimer.connect("timeout", _on_attack_timer)
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float):
	if dead or player_ref == null: return

	# VECTOR: direction and distance to player
	var to_player : Vector2 = player_ref.global_position - global_position
	var distance  : float   = to_player.length()

	if distance < detection_range and distance > stop_distance:
		var direction : Vector2 = to_player.normalized()
		velocity = direction * speed
		move_and_slide()
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.flip_h = direction.x < 0
		if not is_hurting: _play_anim("walk")
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if not is_hurting:
			_play_anim("attack" if distance <= stop_distance else "idle")

func _on_attack_timer():
	if dead or player_ref == null: return
	if global_position.distance_to(player_ref.global_position) < stop_distance + 15:
		player_ref.take_damage(damage)

func take_damage(amount: int):
	if dead: return
	health -= amount
	if has_node("HitSound"): $HitSound.play()
	if not is_hurting:
		_hurt_flash()
	if health <= 0:
		die()

func _hurt_flash():
	is_hurting = true
	_play_anim("hurt")
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(2.8, 0.4, 0.4)
	await get_tree().create_timer(0.28).timeout
	if not is_instance_valid(self) or dead: return
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 1, 1)
	is_hurting = false

func die():
	dead     = true
	velocity = Vector2.ZERO
	enemy_died.emit()
	var em = get_node_or_null("/root/EventManager")
	if em: EventManager.on_enemy_died.emit(name)
	_spawn_drop()       # spawn before death animation
	_play_anim("death")
	await get_tree().create_timer(0.85).timeout
	if is_instance_valid(self):
		queue_free()

func _spawn_drop():
	if randf() > drop_chance: return
	var scene = load("res://scenes/ItemDrop.tscn")
	if scene == null:
		push_warning("Enemy: res://scenes/ItemDrop.tscn not found")
		return
	var drop        = scene.instantiate()
	drop.item_name  = drop_item
	drop.global_position = global_position
	get_parent().call_deferred("add_child", drop)

func _play_anim(anim_name: String):
	if not has_node("AnimatedSprite2D"): return
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null: return
	if asp.sprite_frames.has_animation(anim_name) and asp.animation != anim_name:
		asp.play(anim_name)
