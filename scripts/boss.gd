extends CharacterBody2D

# ============================================================
# Boss.gd — The Calamity: 2-phase fight with animations
# ============================================================

var health      : int   = 200
var max_health  : int   = 200
var speed       : float = 45.0
var stop_dist   : float = 72.0
var phase       : int   = 1
var dead        : bool  = false
var player_ref          = null
var is_hurting  : bool  = false

signal boss_died
signal boss_health_changed(hp : int)

func _ready():
	add_to_group("enemies")
	if has_node("AttackTimer"):
		$AttackTimer.connect("timeout", _on_melee)
	if has_node("BlastTimer"):
		$BlastTimer.connect("timeout",  _on_blast)
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float):
	if dead or player_ref == null: return

	# Phase 2 trigger at 50% HP
	if health < max_health / 2 and phase == 1:
		_enter_phase2()

	var to_player : Vector2 = player_ref.global_position - global_position
	var distance  : float   = to_player.length()

	if distance > stop_dist:
		var direction : Vector2 = to_player.normalized()
		velocity = direction * speed
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.flip_h = direction.x < 0
		if not is_hurting: _play_anim("walk")
	else:
		velocity = Vector2.ZERO
		if not is_hurting: _play_anim("idle")

	move_and_slide()

func _enter_phase2():
	phase = 2
	speed = 82.0
	if has_node("NameLabel"):
		$NameLabel.text = "THE CALAMITY  —  PHASE 2"
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(2.0, 0.3, 0.1)
	if has_node("RoarSound"): $RoarSound.play()
	var em = get_node_or_null("/root/EventManager")
	if em: EventManager.on_boss_phase_change.emit(2)

func _on_melee():
	if dead or player_ref == null: return
	if global_position.distance_to(player_ref.global_position) < stop_dist + 20:
		_play_anim("attack")
		player_ref.take_damage(10)

func _on_blast():
	if dead or player_ref == null: return
	if has_node("BlastSound"): $BlastSound.play()
	player_ref.take_damage(10)

func take_damage(amount: int):
	if dead: return
	health = max(0, health - amount)
	boss_health_changed.emit(health)
	if has_node("HitSound"): $HitSound.play()
	if not is_hurting: _hurt_flash()
	if health <= 0: die()

func _hurt_flash():
	is_hurting = true
	_play_anim("hurt")
	var tint = Color(3.0, 0.3, 0.3) if phase == 1 else Color(3.0, 1.0, 0.1)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = tint
	await get_tree().create_timer(0.32).timeout
	if not is_instance_valid(self) or dead: return
	var norm = Color(1,1,1) if phase == 1 else Color(2.0, 0.3, 0.1)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = norm
	is_hurting = false

func die():
	dead     = true
	velocity = Vector2.ZERO
	boss_died.emit()
	var em = get_node_or_null("/root/EventManager")
	if em: EventManager.on_enemy_died.emit(name)
	_play_anim("death")
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		queue_free()

func _play_anim(anim_name: String):
	if not has_node("AnimatedSprite2D"): return
	var asp = $AnimatedSprite2D
	if asp.sprite_frames == null: return
	if asp.sprite_frames.has_animation(anim_name) and asp.animation != anim_name:
		asp.play(anim_name)
