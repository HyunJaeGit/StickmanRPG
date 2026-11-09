extends Node2D
class_name GameRenderer
## 전투와 로비의 배경·캐릭터·적·투사체·이펙트를 그리는 전용 노드입니다.

var game: Node2D

const W := 960.0
const H := 540.0
const GAME_DATA = preload("res://scripts/game_data.gd")
const PAPER_BACKGROUND: Texture2D = preload("res://art/sketch_forest_background.png")
const CHARACTER_ATLAS: Texture2D = preload("res://art/stickman_characters_atlas.png")
const ITEM_ATLAS: Texture2D = preload("res://art/weapon_items_atlas.png")
const ACTION_ATLAS: Texture2D = preload("res://art/stickman_action_animation_atlas.png")
const WEAPON_ACTION_ATLAS: Texture2D = preload("res://art/weapon_attack_animation_atlas.png")
const MAGIC_SKILL_ATLAS: Texture2D = preload("res://art/magic_skill_icons.png")
const CHARACTER_CELL := 512.0
const ITEM_CELL := 362.0
const ACTION_FRAME_SIZE := Vector2(362.0, 271.5)
const WEAPON_ACTION_FRAME_SIZE := Vector2(280.5, 1402.0 / 9.0)
const MAGIC_SKILL_CELL := Vector2(2172.0 / 5.0, 434.0)
const MAGIC_SKILL_REGION_Y := 145.0

func _draw() -> void:
	_draw_paper()
	for drop in game.drops:
		if str(drop.get("type", "weapon_shard")) == "magic_shard":
			draw_circle(drop.position, 13.0, Color(0.22, 0.74, 0.74, 0.28))
			_draw_skill_icon(drop.position, Vector2(24.0, 24.0), 4)
		else:
			_draw_item(drop.position, Vector2(19.0, 19.0), 9)
	for projectile in game.projectiles:
		_draw_projectile(projectile)
	for enemy in game.enemies:
		_draw_enemy(enemy)
	if not game.boss.is_empty():
		_draw_boss()
	for particle in game.particles:
		draw_circle(particle.position, particle.radius, particle.color)
	if game.mode == "lobby":
		_draw_character(Vector2(W/2.0, H/2.0+20.0), Vector2(95.0, 118.0), 0)
	else:
		_draw_player()
		_draw_attack_indicator()
		_draw_skill_cast()


func _draw_attack_indicator() -> void:
	if game.mode != "playing" or game.attack_indicator_timer <= 0.0:
		return
	var direction: Vector2 = game.attack_indicator_direction.normalized()
	var origin: Vector2 = game.player_position
	var target: Vector2 = game.attack_indicator_target
	var endpoint: Vector2 = origin + direction * float(game.attack_indicator_range)
	var alpha := clampf(game.attack_indicator_timer / 0.22, 0.0, 1.0)
	var faint := Color(0.98, 0.82, 0.43, 0.12 + alpha * 0.12)
	var aim := Color(1.0, 0.88, 0.57, 0.22 + alpha * 0.32)
	draw_line(origin, endpoint, faint, 1.5, true)
	draw_line(origin, target, aim, 2.5, true)
	var end_tick := direction.orthogonal() * 8.0
	draw_line(endpoint - end_tick, endpoint + end_tick, faint, 2.0, true)
	if game.selected_weapon == "pencil_sword":
		var angle := direction.angle()
		draw_arc(origin, game.attack_indicator_range, angle - 0.38, angle + 0.38, 18, aim, 2.0, true)
	if game.attack_indicator_area_radius > 0.0:
		var area_center: Vector2 = origin if game.attack_indicator_area_center == "player" else target
		draw_circle(area_center, game.attack_indicator_area_radius, Color(0.97, 0.75, 0.34, 0.08 + alpha * 0.06))
		draw_arc(area_center, game.attack_indicator_area_radius, 0.0, TAU, 32, aim, 2.0, true)


func _draw_skill_cast() -> void:
	if game.mode != "playing" or game.skill_cast_timer <= 0.0:
		return
	var progress := 1.0 - clampf(game.skill_cast_timer / maxf(game.skill_cast_duration, 0.01), 0.0, 1.0)
	var player: Vector2 = game.player_position
	var target: Vector2 = game.skill_cast_target
	var pulse := 0.65 + 0.35 * sin(game.elapsed * 18.0)
	match game.skill_cast_id:
		"ink_wave":
			var radius := float(game._skill_data("ink_wave").get("radius", 140.0))
			draw_circle(player, radius, Color(0.23, 0.77, 0.73, 0.08 + progress * 0.08))
			draw_arc(player, radius * (0.82 + progress * 0.18), 0.0, TAU, 40, Color(0.34, 0.96, 0.88, pulse), 4.0, true)
		"lifeline":
			draw_circle(player, 48.0, Color(0.39, 0.9, 0.46, 0.1 + progress * 0.12))
			draw_arc(player, 25.0 + progress * 35.0, 0.0, TAU, 32, Color(0.54, 1.0, 0.58, pulse), 4.0, true)
		_:
			var cast_color := Color(0.98, 0.55, 0.32, pulse) if game.skill_cast_id == "final_ink" else Color(0.92, 0.79, 0.42, pulse)
			draw_line(player, target, Color(cast_color.r, cast_color.g, cast_color.b, 0.28), 8.0, true)
			draw_line(player, target, cast_color, 2.5, true)
			draw_arc(target, 13.0 + progress * 22.0, 0.0, TAU, 28, cast_color, 3.0, true)


func _draw_paper() -> void:
	draw_texture_rect(PAPER_BACKGROUND, Rect2(0.0, 0.0, W, H), false)
	var tint := Color.WHITE
	match GAME_DATA.STAGE_IDS[game.stage_index]:
		"1-2": tint = Color(0.85, 0.95, 0.89, 0.20)
		"1-3": tint = Color(0.88, 0.87, 0.83, 0.20)
		"1-4": tint = Color(0.95, 0.88, 0.77, 0.20)
		"1-5": tint = Color(0.95, 0.78, 0.70, 0.23)
		"2-1": tint = Color(0.78, 0.85, 0.96, 0.22)
	if tint != Color.WHITE:
		draw_rect(Rect2(0.0, 0.0, W, H), tint)


func _character_region(index: int) -> Rect2:
	return Rect2(float(index % 3) * CHARACTER_CELL, float(floori(float(index) / 3.0)) * CHARACTER_CELL, CHARACTER_CELL, CHARACTER_CELL)


func _draw_character(draw_position: Vector2, size: Vector2, index: int, tint: Color = Color.WHITE, direction: float = 1.0) -> void:
	var horizontal_flip := -1.0 if direction < 0.0 else 1.0
	draw_set_transform(draw_position, 0.0, Vector2(horizontal_flip, 1.0))
	draw_texture_rect_region(CHARACTER_ATLAS, Rect2(-size * 0.5, size), _character_region(index), tint, false, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_item(draw_position: Vector2, size: Vector2, index: int, direction: float = 1.0) -> void:
	var region := Rect2(float(index % 4) * ITEM_CELL, float(floori(float(index) / 4.0)) * ITEM_CELL, ITEM_CELL, ITEM_CELL)
	var horizontal_flip := -1.0 if direction < 0.0 else 1.0
	draw_set_transform(draw_position, 0.0, Vector2(horizontal_flip, 1.0))
	draw_texture_rect_region(ITEM_ATLAS, Rect2(-size * 0.5, size), region, Color.WHITE, false, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_skill_icon(draw_position: Vector2, size: Vector2, index: int) -> void:
	var region := Rect2(float(index) * MAGIC_SKILL_CELL.x, MAGIC_SKILL_REGION_Y, MAGIC_SKILL_CELL.x, MAGIC_SKILL_CELL.y)
	draw_texture_rect_region(MAGIC_SKILL_ATLAS, Rect2(draw_position - size * 0.5, size), region, Color.WHITE, false, true)


func _draw_stick(origin_point: Vector2, character_scale: float, color: Color) -> void:
	draw_arc(origin_point+Vector2(0,-22*character_scale),7*character_scale,0.0,TAU,24,color,4.0*character_scale,true)
	draw_line(origin_point+Vector2(0,-14*character_scale),origin_point+Vector2(0,9*character_scale),color,4.0*character_scale,true)
	draw_line(origin_point+Vector2(0,-7*character_scale),origin_point+Vector2(-11*character_scale,-1),color,4.0*character_scale,true)
	draw_line(origin_point+Vector2(0,-7*character_scale),origin_point+Vector2(10*character_scale,1),color,4.0*character_scale,true)
	draw_line(origin_point+Vector2(0,9*character_scale),origin_point+Vector2(-9*character_scale,23*character_scale),color,4.0*character_scale,true)
	draw_line(origin_point+Vector2(0,9*character_scale),origin_point+Vector2(10*character_scale,23*character_scale),color,4.0*character_scale,true)


func _draw_player() -> void:
	var tint := Color("d99582") if game.invulnerability > 0.0 and int(game.elapsed*20.0)%2 == 0 else Color.WHITE
	if game.player_anim_time > 0.0 and game.player_anim_row >= 0:
		var progress: float = 1.0 - game.player_anim_time / game.player_anim_duration
		var frame := clampi(floori(progress * 4.0), 0, 3)
		var frame_size := WEAPON_ACTION_FRAME_SIZE if game.player_anim_uses_weapon_atlas else ACTION_FRAME_SIZE
		var source := Rect2(float(frame) * frame_size.x, float(game.player_anim_row) * frame_size.y, frame_size.x, frame_size.y)
		var animation_atlas := WEAPON_ACTION_ATLAS if game.player_anim_uses_weapon_atlas else ACTION_ATLAS
		var horizontal_flip := -1.0 if game.facing < 0.0 else 1.0
		draw_set_transform(game.player_position, 0.0, Vector2(horizontal_flip, 1.0))
		draw_texture_rect_region(animation_atlas, Rect2(Vector2(-52.0, -42.0), Vector2(104.0, 84.0)), source, tint, false, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_character(game.player_position, Vector2(64.0, 72.0), 0, tint, game.facing)
	if game.dash_timer > 0.0:
		draw_line(game.dash_origin, game.player_position, Color(0.30, 0.71, 0.68, 0.65), 7.0, true)
	_draw_item(game.player_position + Vector2(game.facing * 25.0, -17.0), Vector2(24.0, 24.0), game._weapon_icon_index(game.selected_weapon), game.facing)
	if game.slash_timer > 0.0:
		draw_arc(game.player_position+Vector2(game.facing*12.0,-8.0),38.0,-0.8,0.8,24,Color("36312b"),5.0)
	var orbit_count := 2 if game.selected_weapon == "orbit_line" else 0
	if orbit_count > 0:
		for index in orbit_count:
			var angle: float = game.elapsed*3.0+float(index)*TAU/float(orbit_count)
			draw_line(game.player_position+Vector2(cos(angle),sin(angle))*35.0,game.player_position+Vector2(cos(angle),sin(angle))*48.0,Color("494239"),4.0,true)


func _draw_scarf(character_position: Vector2, character_scale: float, direction: float) -> void:
	var neck := character_position + Vector2(0.0, -8.0 * character_scale)
	draw_line(neck + Vector2(-5.0 * character_scale, 0.0), neck + Vector2(5.0 * character_scale, 0.0), Color("bb4b3e"), 5.0 * character_scale, true)
	draw_line(neck + Vector2(-4.0 * character_scale, 1.0 * character_scale), neck + Vector2(-17.0 * character_scale * direction, 8.0 * character_scale), Color("bb4b3e"), 4.0 * character_scale, true)
	draw_line(neck + Vector2(0.0, 2.0 * character_scale), neck + Vector2(-12.0 * character_scale * direction, 10.0 * character_scale), Color("d06a50"), 2.0 * character_scale, true)


func _draw_projectile(projectile: Dictionary) -> void:
	var direction: float = signf(projectile.velocity.x) if absf(projectile.velocity.x) > 0.1 else 1.0
	if projectile.kind == "paper_plane":
		_draw_item(projectile.position, Vector2(28.0, 28.0), 6, direction)
	elif projectile.kind == "eraser_bomb":
		_draw_item(projectile.position, Vector2(27.0, 27.0), 5, direction)
	else:
		_draw_item(projectile.position, Vector2(24.0, 24.0), 1, direction)


func _draw_enemy(enemy: Dictionary) -> void:
	var tint := Color("e7a599") if enemy.flash > 0.0 else Color.WHITE
	var sprite_index := 1
	var sprite_size := Vector2(47.0, 55.0)
	match enemy.kind:
		"charger": sprite_index = 2
		"thrower": sprite_index = 3
		"elite": sprite_index = 4; sprite_size = Vector2(68.0, 75.0)
	var hit_time := float(enemy.get("hit_time", 0.0))
	var hit_direction: Vector2 = enemy.get("hit_direction", Vector2.ZERO)
	var recoil := hit_direction * (sin((hit_time / 0.13) * PI) * 5.0) if hit_time > 0.0 else Vector2.ZERO
	var draw_position: Vector2 = enemy.position + recoil
	var enemy_direction := 1.0 if game.player_position.x >= enemy.position.x else -1.0
	_draw_character(draw_position, sprite_size, sprite_index, tint, enemy_direction)
	if hit_time > 0.0:
		var spark := draw_position + Vector2(0.0, -sprite_size.y * 0.28)
		draw_line(spark + Vector2(-9.0, -7.0), spark + Vector2(-3.0, -1.0), Color("f1b95e"), 2.5, true)
		draw_line(spark + Vector2(8.0, -8.0), spark + Vector2(3.0, -1.0), Color("f1b95e"), 2.5, true)
	if enemy.kind == "elite":
		draw_arc(enemy.position,enemy.radius,0.0,TAU,24,Color("a74235"),5.0)
		draw_rect(Rect2(enemy.position+Vector2(-23,-39),Vector2(46,4)),Color("30251f"))
		draw_rect(Rect2(enemy.position+Vector2(-23,-39),Vector2(46.0*enemy.hp/enemy.max_hp,4)),Color("db7560"))
	elif enemy.kind == "charger" and enemy.windup > 0.0:
		draw_arc(enemy.position,enemy.radius+9.0,0.0,TAU,24,Color("d45a46"),2.0)


func _draw_boss() -> void:
	var boss_position: Vector2 = game.boss.position
	if game.boss.warning > 0.0:
		if game.boss.phase == 1:
			draw_line(Vector2(30,game.boss.aim_y),Vector2(W-30,game.boss.aim_y),Color(0.76,0.25,0.21,0.62),18.0,true)
		else:
			draw_arc(game.player_position,53.0,0.0,TAU,36,Color(0.76,0.25,0.21,0.62),5.0)
	var boss_tint := Color("e99a85") if float(game.boss.get("flash", 0.0)) > 0.0 else Color.WHITE
	var recoil: Vector2 = (boss_position - game.player_position).normalized() * 7.0 if float(game.boss.get("hit_time", 0.0)) > 0.0 else Vector2.ZERO
	var boss_direction := 1.0 if game.player_position.x >= boss_position.x else -1.0
	_draw_character(boss_position + recoil, Vector2(126.0, 142.0), 5, boss_tint, boss_direction)
