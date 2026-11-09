extends Node2D
## 스틱맨 RPG 전투와 골드·무기 성장 메타 진행을 관리합니다.

const W := 960.0
const H := 540.0
const GAME_DATA = preload("res://scripts/game_data.gd")
const RENDERER_SCENE: PackedScene = preload("res://scenes/game_renderer.tscn")
const REWARD_PRESENTATION_SCENE: PackedScene = preload("res://scenes/reward_presentation.tscn")
const CHARACTER_ATLAS: Texture2D = preload("res://art/stickman_characters_atlas.png")
const ITEM_ATLAS: Texture2D = preload("res://art/weapon_items_atlas.png")
const MAGIC_SKILL_ATLAS: Texture2D = preload("res://art/magic_skill_icons.png")
const ACTION_ATLAS: Texture2D = preload("res://art/stickman_action_animation_atlas.png")
const CHARACTER_CELL := 512.0
const ITEM_CELL := 362.0
const MAGIC_SKILL_CELL := Vector2(2172.0 / 5.0, 434.0)
const MAGIC_SKILL_REGION_Y := 145.0
const ACTION_FRAME_SIZE := Vector2(362.0, 271.5)

var mode := "lobby"
var stage_index := 0
var furthest_stage_index := 0
var gold := 0
var weapon_shards := 0
var magic_shards := 0
var skills_owned: Array[String] = []
var equipped_skill_slots: Array[String] = ["", "", "", ""]
var skill_levels: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var selected_weapon := "pencil_sword"
var selected_weapon_uid := 1
var next_weapon_uid := 1
var weapon_inventory: Array[Dictionary] = []
var last_weapon_draw: Dictionary = {}
var cleared_stages: Array[String] = []
var last_lobby_message := "스케치 세계에 오신 것을 환영합니다."
var elapsed := 0.0
var kills := 0
var stage_enemy_quota: int = int(GAME_DATA.STAGE_ENEMY_COUNTS["1-1"])
var stage_enemies_spawned := 0
var stage_boss_spawned := false
var spawn_timer := 0.0
var attack_timer := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var invulnerability := 0.0
var slash_timer := 0.0
var player_anim_row := -1
var player_anim_time := 0.0
var player_anim_duration := 0.36
var player_anim_uses_weapon_atlas := false
var dash_origin := Vector2.ZERO
var attack_indicator_timer := 0.0
var attack_indicator_range := 0.0
var attack_indicator_direction := Vector2.RIGHT
var attack_indicator_target := Vector2.ZERO
var attack_indicator_area_radius := 0.0
var attack_indicator_area_center := "target"
var skill_cast_id := ""
var skill_cast_timer := 0.0
var skill_cast_duration := 0.0
var skill_cast_target := Vector2.ZERO
var skill_cast_target_ref: Dictionary = {}
var player_position := Vector2(W / 2.0, H / 2.0)
var player_hp := GAME_DATA.PLAYER_BASE_HEALTH
var player_max_hp := GAME_DATA.PLAYER_BASE_HEALTH
var player_speed := GAME_DATA.PLAYER_BASE_SPEED
var player_damage := GAME_DATA.PLAYER_BASE_DAMAGE
var attack_rate := GAME_DATA.PLAYER_BASE_ATTACK_INTERVAL
var facing := 1.0
var enemies: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var boss: Dictionary = {}
var boss_mechanic_message := ""
var boss_mechanic_message_timer := 0.0
var rng := RandomNumberGenerator.new()
var game_renderer: GameRenderer
var reward_presentation: RewardPresentation
var ui: CanvasLayer
var hud_label: Label
var hp_bar: ProgressBar
var boss_bar: ProgressBar
var overlay: ColorRect
var overlay_panel: PanelContainer
var lobby_panel: PanelContainer
var lobby_status: Label
var lobby_stage_label: Label
var lobby_weapon_label: Label
var lobby_weapon_desc: Label
var lobby_stat_values: Dictionary = {}
var lobby_message: Label
var lobby_stage_path: HBoxContainer
var lobby_enter_button: Button
var lobby_gacha_button: Button
var skill_hud: HBoxContainer
var skill_slot_icons: Array[TextureRect] = []
var skill_slot_labels: Array[Label] = []
var lobby_section := "home"
var lobby_modal_body: VBoxContainer
var master_volume_percent := 80
var settings_volume_label: Label
var selected_skill_slot := -1


func _ready() -> void:
	rng.randomize()
	_load_progress()
	_load_settings()
	game_renderer = RENDERER_SCENE.instantiate() as GameRenderer
	game_renderer.game = self
	add_child(game_renderer)
	reward_presentation = REWARD_PRESENTATION_SCENE.instantiate() as RewardPresentation
	reward_presentation.closed.connect(_on_reward_presentation_closed)
	add_child(reward_presentation)
	_build_ui()
	show_lobby()
	game_renderer.queue_redraw()


func _process(delta: float) -> void:
	if mode == "playing":
		_update_game(minf(delta, 0.04))
	game_renderer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if mode == "playing" and not overlay.visible and not reward_presentation.shade.visible and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_G:
		_try_boss_counter()
		get_viewport().set_input_as_handled()
		return
	if mode == "playing" and not overlay.visible and not reward_presentation.shade.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var key_event := event as InputEventKey
			var skill_keys := {KEY_Q:0, KEY_W:1, KEY_E:2, KEY_R:3}
			if skill_keys.has(key_event.physical_keycode):
				_use_skill(int(skill_keys[key_event.physical_keycode]))
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("dash"):
		dash()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if mode == "playing":
			show_pause()
		elif mode == "paused":
			mode = "playing"
			overlay.hide()
			get_tree().paused = false
		elif mode == "lobby" and lobby_section != "home":
			_close_lobby_window()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	ui = CanvasLayer.new()
	var ui_theme := Theme.new()
	ui_theme.set_color("font_color", "Label", Color("382f27"))
	ui_theme.set_color("font_color", "Button", Color("382f27"))
	ui_theme.set_color("font_hover_color", "Button", Color("7e382e"))
	ui_theme.set_color("font_pressed_color", "Button", Color("7e382e"))
	ui_theme.set_color("font_disabled_color", "Button", Color("837966"))
	var button_normal := _flat_style(Color("e7d8bd"))
	button_normal.set_border_width_all(1)
	button_normal.border_color = Color("b7a383")
	var button_hover := _flat_style(Color("f1e4cc"))
	button_hover.set_border_width_all(1)
	button_hover.border_color = Color("a87d63")
	var button_pressed := _flat_style(Color("d9baa0"))
	button_pressed.set_border_width_all(1)
	button_pressed.border_color = Color("965347")
	var button_disabled := _flat_style(Color("ddd3c2"))
	button_disabled.set_border_width_all(1)
	button_disabled.border_color = Color("c9bdab")
	ui_theme.set_stylebox("normal", "Button", button_normal)
	ui_theme.set_stylebox("hover", "Button", button_hover)
	ui_theme.set_stylebox("pressed", "Button", button_pressed)
	ui_theme.set_stylebox("disabled", "Button", button_disabled)
	add_child(ui)
	var hud := HBoxContainer.new()
	hud.theme = ui_theme
	hud.position = Vector2(18, 14)
	hud.size = Vector2(924, 100)
	hud.add_theme_constant_override("separation", 20)
	ui.add_child(hud)
	hud_label = Label.new()
	hud_label.custom_minimum_size = Vector2(270, 98)
	hud_label.add_theme_font_size_override("font_size", 16)
	hud.add_child(hud_label)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(bars)
	hp_bar = _make_bar(Color("da6254"))
	bars.add_child(hp_bar)
	boss_bar = _make_bar(Color("a74235"))
	boss_bar.visible = false
	boss_bar.custom_minimum_size.y = 14
	bars.add_child(boss_bar)
	var help := Label.new()
	help.text = "WASD / 방향키 이동\nSpace 대시 · Esc 일시정지"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.custom_minimum_size = Vector2(190, 55)
	hud.add_child(help)
	skill_hud = HBoxContainer.new()
	skill_hud.position = Vector2(708.0, H - 82.0)
	skill_hud.size = Vector2(236.0, 70.0)
	skill_hud.add_theme_constant_override("separation", 5)
	ui.add_child(skill_hud)
	for index in 4:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(55.0, 68.0)
		slot.add_theme_stylebox_override("panel", _flat_style(Color("e7d8bd")))
		var slot_body := VBoxContainer.new()
		slot_body.add_theme_constant_override("separation", 0)
		slot.add_child(slot_body)
		var key_label := Label.new()
		key_label.text = ["Q", "W", "E", "R"][index]
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 13)
		slot_body.add_child(key_label)
		var icon_view := TextureRect.new()
		icon_view.custom_minimum_size = Vector2(38.0, 38.0)
		icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_body.add_child(icon_view)
		skill_slot_icons.append(icon_view)
		var slot_label := Label.new()
		slot_label.text = "빈 슬롯"
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 9)
		slot_body.add_child(slot_label)
		skill_slot_labels.append(slot_label)
		skill_hud.add_child(slot)
	overlay = ColorRect.new()
	overlay.theme = ui_theme
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.04, 0.03, 0.73)
	ui.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	overlay_panel = PanelContainer.new()
	overlay_panel.custom_minimum_size = Vector2(520, 250)
	var lobby_style := _lobby_surface(Color("f2e6cf"), Color("b8a27f"))
	lobby_style.set_border_width_all(1)
	lobby_style.content_margin_left = 24.0
	lobby_style.content_margin_right = 24.0
	lobby_style.content_margin_top = 18.0
	lobby_style.content_margin_bottom = 18.0
	overlay_panel.add_theme_stylebox_override("panel", lobby_style)
	center.add_child(overlay_panel)
	overlay.hide()


func _make_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _flat_style(fill))
	bar.add_theme_stylebox_override("background", _flat_style(Color("554c40")))
	return bar


func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _show_panel(title: String, body: String, button_text: String, callback: Callable) -> void:
	for child in overlay_panel.get_children():
		overlay_panel.remove_child(child)
		child.queue_free()
	overlay_panel.custom_minimum_size = Vector2(520, 250)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	overlay_panel.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	content.add_child(heading)
	var message := Label.new()
	message.text = body
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	if not button_text.is_empty():
		var button := Button.new()
		button.text = button_text
		button.custom_minimum_size.y = 42
		button.pressed.connect(callback)
		content.add_child(button)
	overlay.show()


func _show_catalog_info(title: String, body: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = body
	ui.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(480, 260))


func _show_unowned_weapon_info(weapon_id: String) -> void:
	var weapon := _weapon_profile(weapon_id)
	var ratio := float(weapon.get("damage_ratio", 1.0))
	var info := "%s\n사거리 %.0f\n공격 계수 %.0f%% · 일반 등급 기준 피해 %.1f\n%s\n\n미보유 무기입니다. 획득하면 무기고에서 장착할 수 있습니다." % [str(weapon.get("name", "무기")), _weapon_attack_range(weapon_id), ratio * 100.0, GAME_DATA.PLAYER_BASE_DAMAGE * ratio, str(weapon.get("desc", ""))]
	_show_catalog_info("무기 정보", info)


func _show_unowned_skill_info(skill: Dictionary) -> void:
	var skill_level := 1
	var info := "%s · %s\n%s\n\n미수집 스킬입니다. 획득하면 보관함에서 슬롯에 장착할 수 있습니다." % [str(skill.get("name", "스킬")), str(skill.get("role", "")), _skill_description(skill, skill_level)]
	_show_catalog_info("스킬 정보", info)


func show_lobby() -> void:
	mode = "lobby"
	lobby_section = "home"
	skill_hud.visible = false
	get_tree().paused = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.color = Color(0.05, 0.04, 0.03, 0.73)
	var lobby_style := _lobby_surface(Color("f2e6cf"), Color("b8a27f"))
	lobby_style.set_border_width_all(1)
	lobby_style.content_margin_left = 24.0
	lobby_style.content_margin_right = 24.0
	lobby_style.content_margin_top = 14.0
	lobby_style.content_margin_bottom = 14.0
	overlay_panel.add_theme_stylebox_override("panel", lobby_style)
	for child in overlay_panel.get_children():
		overlay_panel.remove_child(child)
		child.queue_free()
	var lobby_view_size := get_viewport().get_visible_rect().size
	overlay_panel.custom_minimum_size = Vector2(minf(840.0, lobby_view_size.x - 64.0), minf(450.0, lobby_view_size.y - 64.0))
	overlay_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	overlay_panel.add_child(frame)
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 42.0
	top.add_theme_constant_override("separation", 12)
	frame.add_child(top)
	var title := Label.new()
	title.text = "STICKMAN RPG  /  모험의 거점"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("3a342d"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	lobby_status = Label.new()
	lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lobby_status.custom_minimum_size = Vector2(350.0, 36.0)
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status.add_theme_font_size_override("font_size", 14)
	lobby_status.add_theme_color_override("font_color", Color("766650"))
	top.add_child(lobby_status)
	var divider := HSeparator.new()
	frame.add_child(divider)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(main)
	var showcase := VBoxContainer.new()
	showcase.custom_minimum_size.x = 240
	showcase.alignment = BoxContainer.ALIGNMENT_CENTER
	showcase.add_theme_constant_override("separation", 3)
	main.add_child(showcase)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(220, 100)
	portrait.add_theme_stylebox_override("panel", _flat_style(Color("e8dcc7")))
	var hero_preview := TextureRect.new()
	var hero_atlas := AtlasTexture.new()
	hero_atlas.atlas = CHARACTER_ATLAS
	hero_atlas.region = Rect2(0.0, 0.0, CHARACTER_CELL, CHARACTER_CELL)
	hero_preview.texture = hero_atlas
	hero_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.add_child(hero_preview)
	showcase.add_child(portrait)
	lobby_weapon_label = Label.new()
	lobby_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_weapon_label.add_theme_font_size_override("font_size", 19)
	showcase.add_child(lobby_weapon_label)
	lobby_weapon_desc = Label.new()
	lobby_weapon_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_weapon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_weapon_desc.add_theme_font_size_override("font_size", 14)
	showcase.add_child(lobby_weapon_desc)
	lobby_stat_values.clear()
	var stats_card := _lobby_card(showcase, Color("f7efdf"), Color("c7b58d"))
	var stats_style := _lobby_surface(Color("f7efdf"), Color("c7b58d"))
	stats_style.content_margin_left = 10.0
	stats_style.content_margin_right = 10.0
	stats_style.content_margin_top = 5.0
	stats_style.content_margin_bottom = 5.0
	stats_card.add_theme_stylebox_override("panel", stats_style)
	var stats_column := VBoxContainer.new()
	stats_column.add_theme_constant_override("separation", 2)
	stats_card.add_child(stats_column)
	var stats_title := Label.new()
	stats_title.text = "전투 스탯"
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_title.add_theme_color_override("font_color", Color("766650"))
	stats_column.add_child(stats_title)
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 1)
	stats_column.add_child(stats_grid)
	for stat in [{"id":"health", "title":"최대 체력"}, {"id":"damage", "title":"공격력"}, {"id":"speed", "title":"이동 속도"}, {"id":"attack_rate", "title":"초당 공격"}]:
		var stat_cell := VBoxContainer.new()
		stat_cell.add_theme_constant_override("separation", 0)
		stats_grid.add_child(stat_cell)
		var stat_title := Label.new()
		stat_title.text = str(stat.title)
		stat_title.add_theme_font_size_override("font_size", 12)
		stat_title.add_theme_color_override("font_color", Color("766f63"))
		stat_cell.add_child(stat_title)
		var stat_value := Label.new()
		stat_value.add_theme_font_size_override("font_size", 14)
		stat_value.add_theme_color_override("font_color", Color("3a342d"))
		stat_cell.add_child(stat_value)
		lobby_stat_values[str(stat.id)] = stat_value
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 5)
	main.add_child(center)
	lobby_stage_label = Label.new()
	lobby_stage_label.add_theme_font_size_override("font_size", 22)
	center.add_child(lobby_stage_label)
	var route_title := Label.new()
	route_title.text = "CHAPTER 1   ·   먹물 숲의 경로"
	route_title.add_theme_color_override("font_color", Color("766650"))
	center.add_child(route_title)
	lobby_stage_path = HBoxContainer.new()
	lobby_stage_path.add_theme_constant_override("separation", 4)
	center.add_child(lobby_stage_path)
	lobby_message = Label.new()
	lobby_message.custom_minimum_size.y = 38
	lobby_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_message.add_theme_color_override("font_color", Color("8b5947"))
	center.add_child(lobby_message)
	var enter := Button.new()
	enter.text = "%s  출전하기" % GAME_DATA.STAGE_IDS[stage_index]
	enter.custom_minimum_size.y = 58
	enter.add_theme_font_size_override("font_size", 22)
	enter.pressed.connect(start_run)
	center.add_child(enter)
	lobby_enter_button = enter
	var nav := HBoxContainer.new()
	nav.custom_minimum_size.y = 50.0
	nav.add_theme_constant_override("separation", 10)
	frame.add_child(nav)
	var armory := Button.new()
	armory.text = "⚔  무기고"
	armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armory.custom_minimum_size.y = 50
	armory.pressed.connect(func(): _open_lobby_window("armory"))
	nav.add_child(armory)
	var chest := Button.new()
	chest.text = "▣  무기 뽑기  ·  %d 조각" % weapon_shards
	chest.icon = _item_icon(11)
	chest.add_theme_constant_override("icon_max_width", 38)
	chest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest.custom_minimum_size.y = 50
	chest.pressed.connect(func(): _open_lobby_window("chest"))
	nav.add_child(chest)
	lobby_gacha_button = chest
	var skills_button := Button.new()
	skills_button.text = "✦ 스킬"
	skills_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_button.custom_minimum_size.y = 50
	skills_button.pressed.connect(func(): _open_lobby_window("skills"))
	nav.add_child(skills_button)
	var settings := Button.new()
	settings.text = "⚙ 설정"
	settings.custom_minimum_size = Vector2(110.0, 50.0)
	settings.pressed.connect(func(): _open_lobby_window("settings"))
	nav.add_child(settings)
	_update_skill_hud()
	_update_lobby()
	overlay.show()


func _update_lobby() -> void:
	if lobby_status == null:
		return
	lobby_status.text = "골드 %d  ·  무기 조각 %d  ·  마력 조각 %d" % [gold, weapon_shards, magic_shards]
	lobby_gacha_button.text = "▣  무기 뽑기  ·  %d 조각" % weapon_shards
	lobby_stage_label.text = "현재 출전 단계   %s" % GAME_DATA.STAGE_IDS[stage_index]
	lobby_enter_button.text = "%s  출전하기" % GAME_DATA.STAGE_IDS[stage_index]
	lobby_weapon_label.text = "장착 무기  ·  %s" % _weapon_name(selected_weapon)
	lobby_weapon_desc.text = _weapon_description(selected_weapon)
	_update_lobby_stats()
	lobby_message.text = last_lobby_message
	for child in lobby_stage_path.get_children():
		lobby_stage_path.remove_child(child)
		child.queue_free()
	for index in GAME_DATA.STAGE_IDS.size():
		var node := Button.new()
		var stage_id: String = GAME_DATA.STAGE_IDS[index]
		var cleared := cleared_stages.has(stage_id)
		var current := index == stage_index
		var unlocked := index <= furthest_stage_index or current
		node.text = ("✓ " if cleared else "◆ " if current else "○ ") + stage_id if unlocked else "🔒 " + stage_id
		node.disabled = not unlocked
		node.custom_minimum_size = Vector2(82, 48)
		if current:
			node.add_theme_color_override("font_color", Color("a74235"))
		node.pressed.connect(_select_lobby_stage.bind(index))
		lobby_stage_path.add_child(node)


func _update_lobby_stats() -> void:
	var item := _equipped_item()
	lobby_stat_values["health"].text = "%.0f" % _player_max_health_for_item(item)
	lobby_stat_values["damage"].text = "%.1f" % _weapon_attack_power(item)
	lobby_stat_values["speed"].text = "%.0f" % _player_move_speed_for_item(item)
	lobby_stat_values["attack_rate"].text = "%.1f회/초" % (1.0 / _player_attack_interval_for_item(item))


func _player_max_health_for_item(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_HEALTH * (1.0 + _potential_total(item, "max_health") / 100.0)


func _player_move_speed_for_item(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_SPEED * (1.0 + _potential_total(item, "move_speed") / 100.0)


func _player_attack_interval_for_item(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_ATTACK_INTERVAL * 100.0 / (100.0 + _potential_total(item, "attack_speed"))


func _weapon_profile(weapon_id: String) -> Dictionary:
	for weapon in GAME_DATA.WEAPONS:
		if str(weapon.id) == weapon_id:
			return weapon
	return GAME_DATA.WEAPONS[0]


func _weapon_attack_range(weapon_id: String) -> float:
	return float(_weapon_profile(weapon_id).get("attack_range", 470.0))


func _weapon_description(weapon_id: String) -> String:
	var weapon := _weapon_profile(weapon_id)
	var attack_power := _weapon_attack_power(_equipped_item())
	var damage_ratio := float(weapon.get("damage_ratio", 1.0))
	return "%s\n사거리 %.0f  ·  공격력 %.0f%% / %.1f 피해" % [str(weapon.desc), _weapon_attack_range(weapon_id), damage_ratio * 100.0, attack_power * damage_ratio]


func _select_lobby_stage(index: int) -> void:
	if index > furthest_stage_index and index != stage_index:
		return
	stage_index = index
	_save_progress()
	_update_lobby()


func _lobby_surface(color: Color, edge: Color = Color("5d6662")) -> StyleBoxFlat:
	var style := _flat_style(color)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = edge
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _lobby_card(parent: Control, color: Color, edge: Color = Color("5d6662")) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _lobby_surface(color, edge))
	parent.add_child(card)
	return card


func _open_lobby_window(section: String) -> void:
	lobby_section = section
	if section == "skills" and selected_skill_slot < 0:
		selected_skill_slot = 0
	for child in overlay_panel.get_children():
		overlay_panel.remove_child(child)
		child.queue_free()
	var menu_view_size := get_viewport().get_visible_rect().size
	overlay_panel.custom_minimum_size = Vector2(minf(900.0, menu_view_size.x - 40.0), minf(500.0, menu_view_size.y - 40.0))
	overlay_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var shell_style := _lobby_surface(Color("26373e"), Color("c9a766"))
	shell_style.set_border_width_all(2)
	shell_style.content_margin_left = 18.0
	shell_style.content_margin_right = 18.0
	shell_style.content_margin_top = 14.0
	shell_style.content_margin_bottom = 14.0
	overlay_panel.add_theme_stylebox_override("panel", shell_style)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	overlay_panel.add_child(frame)
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 48.0
	frame.add_child(top)
	var heading := Label.new()
	heading.text = {"armory":"무기고", "chest":"무기 뽑기", "skills":"스킬 보관함", "settings":"설정", "help":"도움말"}.get(section, "메뉴")
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("f3e9d4"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close := Button.new()
	close.text = "뒤로"
	close.custom_minimum_size = Vector2(104.0, 42.0)
	close.pressed.connect(_close_lobby_window)
	top.add_child(close)
	var body_card := _lobby_card(frame, Color("ede2cc"), Color("766d5d"))
	body_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body_style := _lobby_surface(Color("ede2cc"), Color("766d5d"))
	body_style.content_margin_left = 10.0
	body_style.content_margin_right = 10.0
	body_style.content_margin_top = 10.0
	body_style.content_margin_bottom = 10.0
	body_card.add_theme_stylebox_override("panel", body_style)
	lobby_modal_body = VBoxContainer.new()
	lobby_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_modal_body.add_theme_constant_override("separation", 8)
	body_card.add_child(lobby_modal_body)
	lobby_section = section
	var content := _build_lobby_section()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_modal_body.add_child(content)
	overlay.show()


func _close_lobby_window() -> void:
	lobby_section = "home"
	lobby_modal_body = null
	overlay_panel.custom_minimum_size = Vector2(840.0, 430.0)
	show_lobby()


func _load_settings() -> void:
	var settings := ProgressStore.load_settings()
	master_volume_percent = clampi(int(settings.get("master_volume", 80)), 0, 100)
	_apply_master_volume()


func _set_master_volume(value: float) -> void:
	master_volume_percent = clampi(roundi(value), 0, 100)
	_apply_master_volume()
	if is_instance_valid(settings_volume_label):
		settings_volume_label.text = "%d%%" % master_volume_percent
	ProgressStore.save_settings({"master_volume":master_volume_percent})


func _apply_master_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, master_volume_percent == 0)
	if master_volume_percent > 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(master_volume_percent) / 100.0))


func _set_fullscreen(enabled: bool) -> void:
	var window_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)


func _confirm_exit_game() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "게임 종료"
	dialog.dialog_text = "게임을 종료할까요?"
	dialog.ok_button_text = "종료"
	dialog.cancel_button_text = "계속 플레이"
	dialog.confirmed.connect(func(): get_tree().quit())
	dialog.close_requested.connect(dialog.queue_free)
	ui.add_child(dialog)
	dialog.popup_centered()


func _on_reward_presentation_closed() -> void:
	if mode == "lobby" and lobby_section != "home":
		_refresh_lobby_window()
	else:
		show_lobby()


func _build_lobby_section() -> Control:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	match lobby_section:
		"armory":
			var equipped := _equipped_item()
			var showcase := HBoxContainer.new()
			showcase.add_theme_constant_override("separation", 12)
			var showcase_card := _lobby_card(body, Color("f7efdf"), Color("c49645"))
			showcase_card.add_child(showcase)
			var weapon_icon := TextureRect.new()
			weapon_icon.texture = _item_icon(_weapon_icon_index(selected_weapon))
			weapon_icon.custom_minimum_size = Vector2(72.0, 72.0)
			weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			showcase.add_child(weapon_icon)
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			details.add_theme_constant_override("separation", 3)
			showcase.add_child(details)
			var equipped_heading := Label.new()
			equipped_heading.text = "장착 슬롯  ·  %s" % _weapon_name(selected_weapon)
			equipped_heading.add_theme_font_size_override("font_size", 18)
			details.add_child(equipped_heading)
			var weapon_summary := Label.new()
			weapon_summary.text = "%s 등급  ·  강화 +%d  ·  기본 공격력 %.1f" % [GAME_DATA.RARITY_NAMES[int(equipped.get("rarity", 0))], int(equipped.get("enhancement", 0)), _weapon_attack_power(equipped)]
			details.add_child(weapon_summary)
			var weapon_description := Label.new()
			weapon_description.text = _weapon_description(selected_weapon)
			weapon_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(weapon_description)
			var potential_label := Label.new()
			potential_label.text = _potential_summary(equipped)
			potential_label.add_theme_font_size_override("font_size", 14)
			potential_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(potential_label)
			var actions := HBoxContainer.new()
			actions.add_theme_constant_override("separation", 5)
			actions.custom_minimum_size.y = 38.0
			body.add_child(actions)
			var enhance := Button.new()
			var enhance_cost := _enhancement_cost(equipped)
			var enhance_level := int(equipped.get("enhancement", 0))
			enhance.text = "강화 +%d  ·  %d 골드" % [enhance_level + 1, enhance_cost] if enhance_level < GAME_DATA.MAX_ENHANCEMENT else "강화 최대"
			enhance.disabled = enhance_level >= GAME_DATA.MAX_ENHANCEMENT or gold < enhance_cost
			enhance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			enhance.pressed.connect(_enhance_equipped_weapon)
			actions.add_child(enhance)
			var reroll := Button.new()
			var reroll_cost := _potential_reset_cost(equipped)
			reroll.text = "잠재 재설정  ·  %d 골드" % reroll_cost
			reroll.disabled = gold < reroll_cost
			reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reroll.pressed.connect(_reset_equipped_potentials)
			actions.add_child(reroll)
			var synthesize := Button.new()
			var can_synthesize := _can_synthesize_equipped()
			var shard_cost := int(equipped.get("rarity", 0)) + 1
			synthesize.text = "동일 무기 합성  ·  조각 %d" % shard_cost
			synthesize.disabled = not can_synthesize or int(equipped.get("rarity", 0)) >= 4 or weapon_shards < shard_cost
			synthesize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			synthesize.pressed.connect(_confirm_synthesize_equipped_weapon)
			actions.add_child(synthesize)
			var collection_heading := Label.new()
			collection_heading.text = "무기 도감 및 보유 카피  ·  보유 %d개" % weapon_inventory.size()
			collection_heading.add_theme_font_size_override("font_size", 16)
			body.add_child(collection_heading)
			var collection_scroll := ScrollContainer.new()
			collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			body.add_child(collection_scroll)
			var weapon_grid := GridContainer.new()
			weapon_grid.columns = 3
			weapon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon_grid.add_theme_constant_override("h_separation", 8)
			weapon_grid.add_theme_constant_override("v_separation", 8)
			collection_scroll.add_child(weapon_grid)
			for weapon in GAME_DATA.WEAPONS:
				var weapon_id := str(weapon.id)
				var copies: Array[Dictionary] = []
				for inventory_item in weapon_inventory:
					if str(inventory_item.get("weapon_id", "")) == weapon_id:
						copies.append(inventory_item)
				var card_rarity := int(copies[0].get("rarity", 0)) if not copies.is_empty() else 0
				var card_edges: Array[Color] = [Color("82796b"), Color("67916f"), Color("5485a5"), Color("936bb0"), Color("c49645")]
				var card := _lobby_card(weapon_grid, Color("f7efdf") if not copies.is_empty() else Color("e5dfd4"), card_edges[card_rarity])
				card.custom_minimum_size = Vector2(214.0, 72.0)
				var card_body := VBoxContainer.new()
				card_body.add_theme_constant_override("separation", 3)
				card.add_child(card_body)
				var weapon_row := HBoxContainer.new()
				weapon_row.add_theme_constant_override("separation", 5)
				card_body.add_child(weapon_row)
				var catalog_icon := TextureRect.new()
				catalog_icon.texture = _item_icon(_weapon_icon_index(weapon_id))
				catalog_icon.custom_minimum_size = Vector2(28.0, 28.0)
				catalog_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				catalog_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				weapon_row.add_child(catalog_icon)
				var weapon_name := Label.new()
				weapon_name.text = str(weapon.name)
				weapon_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				weapon_row.add_child(weapon_name)
				if copies.is_empty():
					var missing := Button.new()
					missing.text = "미보유 · 정보 보기"
					missing.custom_minimum_size.y = 28.0
					missing.pressed.connect(_show_unowned_weapon_info.bind(weapon_id))
					card_body.add_child(missing)
				else:
					for copy in copies:
						var copy_uid := int(copy.get("uid", -1))
						var copy_button := Button.new()
						var is_selected := copy_uid == selected_weapon_uid
						copy_button.text = ("✓ 장착 중  ·  " if is_selected else "장착  ·  ") + "%s  +%d" % [GAME_DATA.RARITY_NAMES[clampi(int(copy.get("rarity", 0)), 0, 4)], int(copy.get("enhancement", 0))]
						copy_button.custom_minimum_size.y = 26.0
						copy_button.pressed.connect(_equip_weapon_uid.bind(copy_uid))
						card_body.add_child(copy_button)
		"chest":
			var chest_scroll := ScrollContainer.new()
			chest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			chest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			chest_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			body.add_child(chest_scroll)
			var chest_layout := VBoxContainer.new()
			chest_layout.add_theme_constant_override("separation", 8)
			chest_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chest_scroll.add_child(chest_layout)
			var chest_heading := Label.new()
			chest_heading.text = "무기 뽑기"
			chest_heading.add_theme_font_size_override("font_size", 22)
			chest_layout.add_child(chest_heading)
			var resource_card := _lobby_card(chest_layout, Color("f7efdf"), Color("c7b58d"))
			var resource_row := HBoxContainer.new()
			resource_row.add_theme_constant_override("separation", 12)
			resource_card.add_child(resource_row)
			var shard_icon := TextureRect.new()
			shard_icon.texture = _item_icon(11)
			shard_icon.custom_minimum_size = Vector2(38.0, 38.0)
			shard_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			resource_row.add_child(shard_icon)
			var resource_info := VBoxContainer.new()
			resource_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			resource_row.add_child(resource_info)
			var resource_title := Label.new()
			resource_title.text = "무기 조각"
			resource_title.add_theme_font_size_override("font_size", 16)
			resource_info.add_child(resource_title)
			var resource_hint := Label.new()
			resource_hint.text = "뽑기 1회에 조각 %d개가 필요합니다" % GAME_DATA.GACHA_COST
			resource_hint.add_theme_color_override("font_color", Color("786f61"))
			resource_info.add_child(resource_hint)
			var resource_count := Label.new()
			resource_count.text = "%d개 보유" % weapon_shards
			resource_count.add_theme_font_size_override("font_size", 19)
			resource_row.add_child(resource_count)
			var chance_heading := Label.new()
			chance_heading.text = "등급별 획득 확률"
			chance_heading.add_theme_font_size_override("font_size", 17)
			chest_layout.add_child(chance_heading)
			var chance_row := HBoxContainer.new()
			chance_row.add_theme_constant_override("separation", 8)
			chest_layout.add_child(chance_row)
			var rarity_colors: Array[Color] = [Color("82796b"), Color("67916f"), Color("5485a5"), Color("936bb0"), Color("c49645")]
			for index in GAME_DATA.RARITY_NAMES.size():
				var chance_card := _lobby_card(chance_row, Color("f7efdf"), rarity_colors[index])
				chance_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				chance_card.custom_minimum_size.y = 50.0
				var chance_info := VBoxContainer.new()
				chance_info.alignment = BoxContainer.ALIGNMENT_CENTER
				chance_card.add_child(chance_info)
				var rarity_label := Label.new()
				rarity_label.text = GAME_DATA.RARITY_NAMES[index]
				rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rarity_label.add_theme_color_override("font_color", rarity_colors[index])
				chance_info.add_child(rarity_label)
				var chance_label := Label.new()
				chance_label.text = "%d%%" % GAME_DATA.RARITY_CHANCES[index]
				chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				chance_info.add_child(chance_label)
			var showcase_card := _lobby_card(chest_layout, Color("e4d8c2"), Color("c7b58d"))
			showcase_card.custom_minimum_size.y = 108.0
			var showcase_row := HBoxContainer.new()
			showcase_row.alignment = BoxContainer.ALIGNMENT_CENTER
			showcase_row.add_theme_constant_override("separation", 18)
			showcase_card.add_child(showcase_row)
			var preview_icon := TextureRect.new()
			var preview_name := "무기 상자"
			var preview_note := "뽑기를 누르면 무기가 공개됩니다"
			if not last_weapon_draw.is_empty():
				var preview_weapon_id := str(last_weapon_draw.get("weapon_id", "pencil_sword"))
				preview_icon.texture = _item_icon(_weapon_icon_index(preview_weapon_id))
				preview_name = "%s · %s 등급" % [_weapon_name(preview_weapon_id), GAME_DATA.RARITY_NAMES[int(last_weapon_draw.get("rarity", 0))]]
				preview_note = "마지막으로 획득한 무기"
			else:
				preview_icon.texture = _item_icon(11)
			preview_icon.custom_minimum_size = Vector2(92.0, 92.0)
			preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			showcase_row.add_child(preview_icon)
			var preview_info := VBoxContainer.new()
			preview_info.alignment = BoxContainer.ALIGNMENT_CENTER
			showcase_row.add_child(preview_info)
			var preview_title := Label.new()
			preview_title.text = preview_name
			preview_title.add_theme_font_size_override("font_size", 19)
			preview_info.add_child(preview_title)
			var preview_subtitle := Label.new()
			preview_subtitle.text = preview_note
			preview_subtitle.add_theme_color_override("font_color", Color("786f61"))
			preview_info.add_child(preview_subtitle)
			var draw_button := Button.new()
			draw_button.text = "무기 뽑기  ·  조각 %d개" % GAME_DATA.GACHA_COST
			draw_button.icon = _item_icon(11)
			draw_button.add_theme_constant_override("icon_max_width", 34)
			draw_button.custom_minimum_size = Vector2(320.0, 46.0)
			draw_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			draw_button.disabled = weapon_shards < GAME_DATA.GACHA_COST
			if weapon_shards < GAME_DATA.GACHA_COST:
				draw_button.tooltip_text = "조각이 %d개 더 필요합니다" % (GAME_DATA.GACHA_COST - weapon_shards)
			draw_button.pressed.connect(_draw_weapon)
			body.add_child(draw_button)
		"skills":
			body.add_theme_constant_override("separation", 6)
			var heading := Label.new()
			heading.text = "보유 스킬 %d / %d  ·  마력 조각 %d" % [skills_owned.size(), GAME_DATA.SKILLS.size(), magic_shards]
			body.add_child(heading)
			var draw_skill := Button.new()
			draw_skill.text = "스킬 뽑기  ·  마력 조각 %d개" % GAME_DATA.SKILL_GACHA_COST if skills_owned.size() < GAME_DATA.SKILLS.size() else "중복 뽑기 · 보유 스킬 강화  ·  마력 조각 %d개" % GAME_DATA.SKILL_GACHA_COST
			draw_skill.icon = _skill_icon("magic_shard")
			draw_skill.add_theme_constant_override("icon_max_width", 30)
			draw_skill.disabled = magic_shards < GAME_DATA.SKILL_GACHA_COST or not _can_draw_skill()
			draw_skill.pressed.connect(_draw_skill)
			draw_skill.custom_minimum_size = Vector2(330.0, 44.0)
			draw_skill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			body.add_child(draw_skill)
			var slot_picker := HBoxContainer.new()
			slot_picker.add_theme_constant_override("separation", 8)
			body.add_child(slot_picker)
			for index in 4:
				var slot_button := Button.new()
				var slot_skill_id := equipped_skill_slots[index]
				var slot_skill_name := _skill_name(slot_skill_id) if not slot_skill_id.is_empty() else "빈 슬롯"
				slot_button.text = "%s  ·  %s" % [["Q", "W", "E", "R"][index], slot_skill_name]
				slot_button.custom_minimum_size = Vector2(166.0, 54.0)
				slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slot_button.add_theme_constant_override("icon_max_width", 30)
				if not slot_skill_id.is_empty():
					slot_button.icon = _skill_icon(slot_skill_id)
				slot_button.tooltip_text = "%s 슬롯: %s" % [["Q", "W", "E", "R"][index], slot_skill_name]
				var slot_style := _flat_style(Color("f1e4cc") if index == selected_skill_slot else Color("e2d6c2"))
				slot_style.set_border_width_all(2 if index == selected_skill_slot else 1)
				slot_style.border_color = Color("9b624b") if index == selected_skill_slot else Color("b7a383")
				slot_button.add_theme_stylebox_override("normal", slot_style)
				slot_button.pressed.connect(_select_skill_slot.bind(index))
				slot_picker.add_child(slot_button)
			var slot_hint := Label.new()
			var selected_key: String = ["Q", "W", "E", "R"][selected_skill_slot] if selected_skill_slot >= 0 else ""
			slot_hint.text = "%s 슬롯 선택" % selected_key if not selected_key.is_empty() else "장착할 슬롯을 선택하세요."
			slot_hint.add_theme_color_override("font_color", Color("8b5947"))
			slot_hint.add_theme_font_size_override("font_size", 14)
			body.add_child(slot_hint)
			var scroll := ScrollContainer.new()
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			body.add_child(scroll)
			var skill_list := VBoxContainer.new()
			skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skill_list.add_theme_constant_override("separation", 4)
			scroll.add_child(skill_list)
			for skill in GAME_DATA.SKILLS:
				var skill_id := str(skill.id)
				var is_owned := skills_owned.has(skill_id)
				var is_passive := bool(skill.get("passive", false))
				var assigned_slot := -1 if is_passive else equipped_skill_slots.find(skill_id)
				var assignment_note := ""
				if assigned_slot >= 0:
					assignment_note = "  ·  %s 장착 중" % ["Q", "W", "E", "R"][assigned_slot]
				var skill_edge := Color("bd9854") if assigned_slot >= 0 else Color("c8bba3")
				var row_card := _lobby_card(skill_list, Color("f7efdf") if is_owned else Color("ebe4d8"), skill_edge)
				row_card.custom_minimum_size.y = 56.0
				var skill_row_style := _lobby_surface(Color("f7efdf") if is_owned else Color("ebe4d8"), skill_edge)
				skill_row_style.content_margin_left = 8.0
				skill_row_style.content_margin_right = 8.0
				skill_row_style.content_margin_top = 6.0
				skill_row_style.content_margin_bottom = 6.0
				row_card.add_theme_stylebox_override("panel", skill_row_style)
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 10)
				row_card.add_child(row)
				var icon_view := TextureRect.new()
				icon_view.texture = _skill_icon(skill_id)
				icon_view.custom_minimum_size = Vector2(40.0, 40.0)
				icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(icon_view)
				var skill_info := Label.new()
				skill_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				skill_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				skill_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				var skill_level := int(skill_levels.get(skill_id, 1))
				skill_info.text = "%s  ·  %s%s%s%s\n%s" % [skill.name, skill.role, "  ·  Lv.%d" % skill_level if is_owned else "", "  ·  보유" if is_owned else "  ·  미수집", assignment_note, _skill_description(skill, skill_level)]
				row.add_child(skill_info)
				var equip_button := Button.new()
				if is_passive:
					equip_button.text = "패시브"
				elif not is_owned:
					equip_button.text = "정보 보기"
				elif assigned_slot == selected_skill_slot:
					equip_button.text = "장착됨"
				elif assigned_slot >= 0:
					equip_button.text = "이동"
				else:
					equip_button.text = "교체" if selected_skill_slot >= 0 and not equipped_skill_slots[selected_skill_slot].is_empty() else "장착"
				equip_button.custom_minimum_size = Vector2(76.0, 34.0)
				equip_button.disabled = is_passive or (is_owned and (selected_skill_slot < 0 or assigned_slot == selected_skill_slot))
				if not is_owned:
					equip_button.pressed.connect(_show_unowned_skill_info.bind(skill))
				elif not is_passive and selected_skill_slot >= 0:
					equip_button.pressed.connect(_equip_skill_to_slot.bind(skill_id, selected_skill_slot))
				row.add_child(equip_button)
				if is_owned:
					var upgrade_button := Button.new()
					var upgrade_cost := _skill_upgrade_cost(skill_level)
					upgrade_button.text = "강화 %d" % upgrade_cost
					upgrade_button.custom_minimum_size = Vector2(72, 34)
					upgrade_button.disabled = skill_level >= GAME_DATA.MAX_ENHANCEMENT or magic_shards < upgrade_cost
					upgrade_button.pressed.connect(_upgrade_skill.bind(skill_id))
					row.add_child(upgrade_button)
		"settings":
			var settings_column := VBoxContainer.new()
			settings_column.custom_minimum_size.x = 620.0
			settings_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			settings_column.alignment = BoxContainer.ALIGNMENT_CENTER
			settings_column.add_theme_constant_override("separation", 14)
			body.add_child(settings_column)
			var audio_heading := Label.new()
			audio_heading.text = "소리"
			audio_heading.add_theme_font_size_override("font_size", 20)
			settings_column.add_child(audio_heading)
			var audio_card := _lobby_card(settings_column, Color("f5ecdc"), Color("c5b69d"))
			var audio_content := VBoxContainer.new()
			audio_content.add_theme_constant_override("separation", 10)
			audio_card.add_child(audio_content)
			var volume_row := HBoxContainer.new()
			volume_row.add_theme_constant_override("separation", 14)
			audio_content.add_child(volume_row)
			var volume_title := Label.new()
			volume_title.text = "전체 음량"
			volume_title.custom_minimum_size.x = 100.0
			volume_row.add_child(volume_title)
			var volume_slider := HSlider.new()
			volume_slider.min_value = 0.0
			volume_slider.max_value = 100.0
			volume_slider.step = 1.0
			volume_slider.value = master_volume_percent
			volume_slider.custom_minimum_size.x = 300.0
			volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			volume_slider.value_changed.connect(_set_master_volume)
			volume_row.add_child(volume_slider)
			settings_volume_label = Label.new()
			settings_volume_label.custom_minimum_size.x = 52.0
			settings_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			settings_volume_label.text = "%d%%" % master_volume_percent
			volume_row.add_child(settings_volume_label)
			var display_heading := Label.new()
			display_heading.text = "화면"
			display_heading.add_theme_font_size_override("font_size", 20)
			settings_column.add_child(display_heading)
			var display_card := _lobby_card(settings_column, Color("f5ecdc"), Color("c5b69d"))
			var display_row := HBoxContainer.new()
			display_row.add_theme_constant_override("separation", 12)
			display_card.add_child(display_row)
			var display_info := VBoxContainer.new()
			display_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			display_row.add_child(display_info)
			var display_title := Label.new()
			display_title.text = "전체 화면"
			display_title.add_theme_font_size_override("font_size", 17)
			display_info.add_child(display_title)
			var display_hint := Label.new()
			display_hint.text = "게임 화면을 모니터에 맞춥니다"
			display_hint.add_theme_color_override("font_color", Color("756f65"))
			display_info.add_child(display_hint)
			var fullscreen := CheckButton.new()
			fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			fullscreen.toggled.connect(_set_fullscreen)
			display_row.add_child(fullscreen)
			var settings_actions := HBoxContainer.new()
			settings_actions.alignment = BoxContainer.ALIGNMENT_END
			settings_actions.add_theme_constant_override("separation", 12)
			settings_column.add_child(settings_actions)
			var help_button := Button.new()
			help_button.text = "도움말"
			help_button.custom_minimum_size = Vector2(170.0, 48.0)
			help_button.pressed.connect(func(): _open_lobby_window("help"))
			settings_actions.add_child(help_button)
			var exit_button := Button.new()
			exit_button.text = "게임 종료"
			exit_button.custom_minimum_size = Vector2(170.0, 48.0)
			var danger_style := _flat_style(Color("a34842"))
			danger_style.set_border_width_all(1)
			danger_style.border_color = Color("7c322e")
			exit_button.add_theme_stylebox_override("normal", danger_style)
			exit_button.add_theme_stylebox_override("hover", _flat_style(Color("bd5a50")))
			exit_button.add_theme_color_override("font_color", Color("fff3e5"))
			exit_button.pressed.connect(_confirm_exit_game)
			settings_actions.add_child(exit_button)
		"help":
			var controls := Label.new()
			controls.text = "조작 방법"
			controls.add_theme_font_size_override("font_size", 19)
			body.add_child(controls)
			var help_text := Label.new()
			help_text.text = "이동  ·  WASD 또는 방향키\n대시  ·  Space\n공격  ·  자동 공격\n스킬 슬롯  ·  Q / W / E / R\n일시 정지  ·  Esc\n\n스테이지의 적을 모두 처치하면 클리어합니다. 보스 스테이지에서는 일반 적을 정리한 뒤 보스까지 처치하세요. 골드와 조각을 모아 무기와 스킬을 성장시킬 수 있습니다."
			help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			help_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
			body.add_child(help_text)
			var back_button := Button.new()
			back_button.text = "설정으로 돌아가기"
			back_button.custom_minimum_size.y = 42.0
			back_button.pressed.connect(func(): _open_lobby_window("settings"))
			body.add_child(back_button)
		_: 
			var hint := Label.new()
			hint.text = "스테이지 보상 골드로 무기를 강화하고, 무기 조각으로 뽑기와 합성을 하세요."
			body.add_child(hint)
	return body


func _weapon_icon_index(weapon_id: String) -> int:
	for index in GAME_DATA.WEAPONS.size():
		if str(GAME_DATA.WEAPONS[index].id) == weapon_id:
			return index
	return 0


func _item_icon(index: int) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = ITEM_ATLAS
	icon.region = Rect2(float(index % 4) * ITEM_CELL, float(floori(float(index) / 4.0)) * ITEM_CELL, ITEM_CELL, ITEM_CELL)
	return icon


func _skill_icon(skill_id: String) -> AtlasTexture:
	if skill_id == GAME_DATA.DASH_SKILL_ID:
		var dash_icon := AtlasTexture.new()
		dash_icon.atlas = ACTION_ATLAS
		dash_icon.region = Rect2(0.0, ACTION_FRAME_SIZE.y * 3.0, ACTION_FRAME_SIZE.x, ACTION_FRAME_SIZE.y)
		return dash_icon
	var icon_index := 4
	for skill in GAME_DATA.SKILLS:
		if str(skill.id) == skill_id:
			icon_index = int(skill.icon)
			break
	var icon := AtlasTexture.new()
	icon.atlas = MAGIC_SKILL_ATLAS
	icon.region = Rect2(float(icon_index) * MAGIC_SKILL_CELL.x, MAGIC_SKILL_REGION_Y, MAGIC_SKILL_CELL.x, MAGIC_SKILL_CELL.y)
	return icon


func _skill_name(skill_id: String) -> String:
	for skill in GAME_DATA.SKILLS:
		if str(skill.id) == skill_id:
			return str(skill.name)
	return "미장착"


func _skill_data(skill_id: String) -> Dictionary:
	for skill in GAME_DATA.SKILLS:
		if str(skill.id) == skill_id:
			return skill
	return {}


func _skill_upgrade_cost(level: int) -> int:
	return 3 + maxi(0, level - 1) * 2


func _skill_strength(skill_id: String) -> float:
	return 1.0 + float(maxi(0, int(skill_levels.get(skill_id, 1)) - 1)) * 0.15


func _can_draw_skill() -> bool:
	if skills_owned.size() < GAME_DATA.SKILLS.size():
		return true
	for skill_id in skills_owned:
		if int(skill_levels.get(skill_id, 1)) < GAME_DATA.MAX_ENHANCEMENT:
			return true
	return false


func _skill_description(skill: Dictionary, level: int) -> String:
	var skill_id := str(skill.get("id", ""))
	var strength := 1.0 + float(maxi(0, level - 1)) * 0.15
	var cooldown := maxf(5.0, float(skill.get("cooldown", 10.0)) * (1.0 - float(level - 1) * 0.025))
	var cast_time := float(skill.get("cast_time", 0.0))
	if bool(skill.get("passive", false)):
		var dash_ratio := float(skill.get("damage_ratio", 1.0)) * strength
		var dash_damage := _weapon_attack_power(_equipped_item()) * dash_ratio
		return "패시브 · Space 대시 경로의 적 전체 · 공격력 %.0f%% / %.1f 피해 · 쿨다운 %.1f초" % [dash_ratio * 100.0, dash_damage, GAME_DATA.DASH_COOLDOWN_DURATION]
	match skill_id:
		"ink_wave": return "반경 %d 안 적 전체 · 공격력 %.0f%% / %.1f 피해/대상 · 시전 %.1f초 · 쿨다운 %.0f초" % [int(skill.radius), float(skill.damage_ratio) * strength * 100.0, _weapon_attack_power(_equipped_item()) * float(skill.damage_ratio) * strength, cast_time, cooldown]
		"compass_pierce": return "가장 가까운 적 1명 · 공격력 %.0f%% / %.1f 피해 · 시전 %.1f초 · 쿨다운 %.0f초" % [float(skill.damage_ratio) * strength * 100.0, _weapon_attack_power(_equipped_item()) * float(skill.damage_ratio) * strength, cast_time, cooldown]
		"lifeline": return "최대 체력 %.0f%% 회복 · 시전 %.1f초 · 쿨다운 %.0f초" % [minf(0.75, float(skill.heal_ratio) * strength) * 100.0, cast_time, cooldown]
		"final_ink": return "%.1f초 집중 후 적 1명 · 공격력 %.0f%% / %.1f 피해 · 쿨다운 %.0f초" % [cast_time, float(skill.damage_ratio) * strength * 100.0, _weapon_attack_power(_equipped_item()) * float(skill.damage_ratio) * strength, cooldown]
	return str(skill.get("description", ""))


func _upgrade_skill(skill_id: String) -> void:
	var level := int(skill_levels.get(skill_id, 1))
	var cost := _skill_upgrade_cost(level)
	if not skills_owned.has(skill_id) or level >= GAME_DATA.MAX_ENHANCEMENT or magic_shards < cost:
		return
	magic_shards -= cost
	skill_levels[skill_id] = level + 1
	last_lobby_message = "%s 스킬이 Lv.%d로 강화됐습니다." % [_skill_name(skill_id), level + 1]
	_save_progress()
	_refresh_lobby_window()


func _use_skill(slot_index: int) -> void:
	if not skill_cast_id.is_empty() or slot_index < 0 or slot_index >= equipped_skill_slots.size():
		return
	var skill_id := equipped_skill_slots[slot_index]
	if skill_id.is_empty() or not skills_owned.has(skill_id) or float(skill_cooldowns.get(skill_id, 0.0)) > 0.0:
		return
	var skill := _skill_data(skill_id)
	if skill.is_empty():
		return
	var level := int(skill_levels.get(skill_id, 1))
	var strength := _skill_strength(skill_id)
	var cooldown := maxf(5.0, float(skill.cooldown) * (1.0 - float(level - 1) * 0.025))
	var target: Dictionary = {}
	if skill_id == "compass_pierce" or skill_id == "final_ink":
		target = _nearest_target(1000.0)
		if target.is_empty():
			last_lobby_message = "사거리 안에 공격할 적이 없습니다."
			return
	skill_cooldowns[skill_id] = cooldown
	skill_cast_id = skill_id
	skill_cast_duration = float(skill.get("cast_time", 0.0))
	skill_cast_timer = skill_cast_duration
	skill_cast_target = target.get("position", player_position)
	skill_cast_target_ref = target
	if skill_cast_duration > 0.0:
		await get_tree().create_timer(skill_cast_duration, false).timeout
	if mode != "playing":
		skill_cast_id = ""
		skill_cast_timer = 0.0
		skill_cast_target_ref = {}
		return
	skill_cast_id = ""
	skill_cast_timer = 0.0
	skill_cast_target_ref = {}
	match skill_id:
		"ink_wave":
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(player_position) <= float(skill.radius):
					_damage_enemy(enemy, player_damage * float(skill.damage_ratio) * strength)
			if not boss.is_empty() and boss.position.distance_to(player_position) <= float(skill.radius):
				_damage_boss(player_damage * float(skill.damage_ratio) * strength)
			_burst(player_position, Color("6bd2ca"), 28)
		"compass_pierce", "final_ink":
			_damage_target(target, player_damage * float(skill.damage_ratio) * strength)
			_burst(target.position, Color("e3b761") if skill_id == "final_ink" else Color("c3a66d"), 20)
		"lifeline":
			var healed := player_max_hp * minf(0.75, float(skill.heal_ratio) * strength)
			player_hp = minf(player_max_hp, player_hp + healed)
			_burst(player_position, Color("8bd68a"), 18)
	_update_hud()


func _update_skill_hud() -> void:
	if skill_slot_icons.size() != 4:
		return
	for index in 4:
		var skill_id := equipped_skill_slots[index]
		var has_skill := not skill_id.is_empty() and skills_owned.has(skill_id)
		skill_slot_icons[index].texture = _skill_icon(skill_id) if has_skill else null
		var cooldown := float(skill_cooldowns.get(skill_id, 0.0)) if has_skill else 0.0
		var skill_level := int(skill_levels.get(skill_id, 1)) if has_skill else 0
		skill_slot_labels[index].text = ("Lv.%d · %.0fs" % [skill_level, cooldown] if cooldown > 0.0 else "Lv.%d · 사용" % skill_level) if has_skill else "빈 슬롯"


func _equip_skill_to_slot(skill_id: String, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= equipped_skill_slots.size() or not skills_owned.has(skill_id) or bool(_skill_data(skill_id).get("passive", false)):
		return
	var previous_slot := equipped_skill_slots.find(skill_id)
	if previous_slot == slot_index:
		return
	if previous_slot >= 0:
		equipped_skill_slots[previous_slot] = equipped_skill_slots[slot_index]
	equipped_skill_slots[slot_index] = skill_id
	_save_progress()
	_update_skill_hud()
	_refresh_lobby_window()


func _select_skill_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= equipped_skill_slots.size():
		return
	selected_skill_slot = slot_index
	_refresh_lobby_window()


func _equipped_item_index() -> int:
	for index in weapon_inventory.size():
		if int(weapon_inventory[index].get("uid", -1)) == selected_weapon_uid:
			return index
	return -1


func _equipped_item() -> Dictionary:
	var index := _equipped_item_index()
	return weapon_inventory[index] if index >= 0 else {}


func _weapon_inventory_index(uid: int) -> int:
	for index in weapon_inventory.size():
		if int(weapon_inventory[index].get("uid", -1)) == uid:
			return index
	return -1


func _equip_weapon_uid(uid: int) -> void:
	for item in weapon_inventory:
		if int(item.get("uid", -1)) == uid:
			selected_weapon_uid = uid
			selected_weapon = str(item.get("weapon_id", "pencil_sword"))
			last_lobby_message = "%s %s 무기를 장착했습니다." % [GAME_DATA.RARITY_NAMES[int(item.get("rarity", 0))], _weapon_name(selected_weapon)]
			_save_progress()
			_refresh_lobby_window()
			return


func _refresh_lobby_window() -> void:
	_update_lobby()
	if lobby_section != "home" and overlay.visible:
		_open_lobby_window(lobby_section)


func _enhancement_cost(item: Dictionary) -> int:
	var level_value := int(item.get("enhancement", 0))
	var rarity := int(item.get("rarity", 0))
	return 50 * (level_value + 1) * (level_value + 1) * (rarity + 1)


func _enhancement_success_chance(level: int) -> float:
	var chance_index := clampi(level, 0, GAME_DATA.ENHANCEMENT_SUCCESS_CHANCES.size() - 1)
	return float(GAME_DATA.ENHANCEMENT_SUCCESS_CHANCES[chance_index])


func _potential_reset_cost(item: Dictionary) -> int:
	return 100 * (int(item.get("rarity", 0)) + 1)


func _potential_summary(item: Dictionary) -> String:
	var lines: PackedStringArray = []
	for potential in item.get("potentials", []):
		lines.append("%s +%d%%" % [_potential_name(str(potential.get("id", "attack"))), int(potential.get("value", 0))])
	return "잠재능력  ·  " + "  /  ".join(lines)


func _potential_lines(item: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for potential in item.get("potentials", []):
		lines.append("%s +%d%%" % [_potential_name(str(potential.get("id", "attack"))), int(potential.get("value", 0))])
	return lines


func _potential_name(id: String) -> String:
	for potential in GAME_DATA.POTENTIALS:
		if str(potential.id) == id:
			return str(potential.name)
	return id


func _roll_potentials() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in 3:
		var option: Dictionary = GAME_DATA.POTENTIALS[rng.randi_range(0, GAME_DATA.POTENTIALS.size() - 1)]
		result.append({"id":str(option.id), "value":rng.randi_range(int(option.min), int(option.max))})
	return result


func _potential_total(item: Dictionary, id: String) -> float:
	var total := 0.0
	for potential in item.get("potentials", []):
		if str(potential.get("id", "")) == id:
			total += float(potential.get("value", 0))
	return total


func _can_synthesize_equipped() -> bool:
	var equipped := _equipped_item()
	if equipped.is_empty() or int(equipped.get("rarity", 0)) >= 4:
		return false
	for item in weapon_inventory:
		if int(item.get("uid", -1)) != selected_weapon_uid and str(item.get("weapon_id", "")) == str(equipped.weapon_id) and int(item.get("rarity", -1)) == int(equipped.rarity):
			return true
	return false


func _make_weapon_record(weapon_id: String, rarity: int, enhancement: int = 0) -> Dictionary:
	var record := {"uid":next_weapon_uid, "weapon_id":weapon_id, "rarity":rarity, "enhancement":enhancement, "potentials":_roll_potentials()}
	next_weapon_uid += 1
	return record


func _draw_weapon() -> void:
	if weapon_shards < GAME_DATA.GACHA_COST:
		last_lobby_message = "무기 조각이 부족합니다. 적 처치나 보스 첫 클리어로 모으세요."
		_update_lobby()
		return
	weapon_shards -= GAME_DATA.GACHA_COST
	var roll := rng.randi_range(1, 100)
	var rarity := 0
	var boundary := 0
	for index in GAME_DATA.RARITY_CHANCES.size():
		boundary += int(GAME_DATA.RARITY_CHANCES[index])
		if roll <= boundary:
			rarity = index
			break
	var weapon_id: String = str(GAME_DATA.WEAPONS[rng.randi_range(0, GAME_DATA.WEAPONS.size() - 1)].id)
	var obtained := _make_weapon_record(weapon_id, rarity)
	last_weapon_draw = obtained.duplicate(true)
	weapon_inventory.append(obtained)
	selected_weapon_uid = int(obtained.uid)
	selected_weapon = weapon_id
	last_lobby_message = "%s 등급 무기 획득: %s" % [GAME_DATA.RARITY_NAMES[rarity], _weapon_name(weapon_id)]
	_save_progress()
	var previews: Array[Dictionary] = []
	for weapon in GAME_DATA.WEAPONS:
		var preview_rarity := rng.randi_range(0, GAME_DATA.RARITY_NAMES.size() - 1)
		previews.append({"icon":_item_icon(_weapon_icon_index(str(weapon.id))), "label":"%s · %s" % [GAME_DATA.RARITY_NAMES[preview_rarity], weapon.name]})
	var accent: Color = [Color("928673"), Color("62a68a"), Color("4e88c6"), Color("a46bd1"), Color("e2a73e")][rarity]
	await reward_presentation.reveal_gacha(previews, _item_icon(_weapon_icon_index(weapon_id)), "%s 등급 · %s" % [GAME_DATA.RARITY_NAMES[rarity], _weapon_name(weapon_id)], "", accent)


func _draw_skill() -> void:
	if magic_shards < GAME_DATA.SKILL_GACHA_COST:
		return
	var unowned: Array[Dictionary] = []
	for skill in GAME_DATA.SKILLS:
		if not skills_owned.has(str(skill.id)):
			unowned.append(skill)
	var result: Dictionary
	var obtained_new_skill := not unowned.is_empty()
	magic_shards -= GAME_DATA.SKILL_GACHA_COST
	if not unowned.is_empty():
		result = unowned[rng.randi_range(0, unowned.size() - 1)]
		skills_owned.append(str(result.id))
		skill_levels[str(result.id)] = 1
	else:
		var upgradeable: Array[String] = []
		for skill_id in skills_owned:
			if int(skill_levels.get(skill_id, 1)) < GAME_DATA.MAX_ENHANCEMENT:
				upgradeable.append(skill_id)
		if upgradeable.is_empty():
			magic_shards += GAME_DATA.SKILL_GACHA_COST
			return
		var owned_skill_id := upgradeable[rng.randi_range(0, upgradeable.size() - 1)]
		result = _skill_data(owned_skill_id)
		skill_levels[owned_skill_id] = int(skill_levels.get(owned_skill_id, 1)) + 1
	var result_level := int(skill_levels.get(str(result.id), 1))
	last_lobby_message = "새 스킬 획득: %s" % result.name if obtained_new_skill else "%s 스킬이 Lv.%d로 강화됐습니다." % [result.name, result_level]
	_save_progress()
	var previews: Array[Dictionary] = []
	for skill in GAME_DATA.SKILLS:
		if not skills_owned.has(str(skill.id)) or str(skill.id) == str(result.id):
			previews.append({"icon":_skill_icon(str(skill.id)), "label":str(skill.name)})
	await reward_presentation.reveal_gacha(previews, _skill_icon(str(result.id)), str(result.name), _skill_description(result, result_level), Color("63b8a0"))


func _enhance_equipped_weapon() -> void:
	var index := _equipped_item_index()
	if index < 0:
		return
	var weapon_uid := int(weapon_inventory[index].get("uid", -1))
	var item: Dictionary = weapon_inventory[index]
	var initial_level := int(item.get("enhancement", 0))
	reward_presentation.open_enhancement_window(_item_icon(_weapon_icon_index(selected_weapon)), _weapon_name(selected_weapon), initial_level, _enhancement_cost(item), gold, _weapon_attack_power(item), _enhancement_success_chance(initial_level))
	var action: String = await reward_presentation.weapon_window_action
	while action != "close":
		if action == "enhance":
			index = _weapon_inventory_index(weapon_uid)
			if index >= 0:
				item = weapon_inventory[index]
				var old_level := int(item.get("enhancement", 0))
				var cost := _enhancement_cost(item)
				var success_chance := _enhancement_success_chance(old_level)
				if old_level < GAME_DATA.MAX_ENHANCEMENT and gold >= cost:
					var succeeded := rng.randf_range(0.0, 100.0) < success_chance
					await reward_presentation.animate_enhancement_attempt(old_level, old_level + 1, succeeded)
					index = _weapon_inventory_index(weapon_uid)
					if index >= 0 and gold >= cost and int(weapon_inventory[index].get("enhancement", 0)) == old_level:
						item = weapon_inventory[index]
						gold -= cost
						if succeeded:
							item.enhancement = old_level + 1
							last_lobby_message = "%s 무기 +%d 강화 성공" % [_weapon_name(str(item.get("weapon_id", selected_weapon))), old_level + 1]
						else:
							last_lobby_message = "%s 무기 강화 실패 · +%d 유지" % [_weapon_name(str(item.get("weapon_id", selected_weapon))), old_level]
						weapon_inventory[index] = item
						_save_progress()
						_refresh_lobby_window()
						index = _weapon_inventory_index(weapon_uid)
						if index >= 0:
							item = weapon_inventory[index]
							reward_presentation.update_enhancement_window(int(item.get("enhancement", 0)), _enhancement_cost(item), gold, _weapon_attack_power(item), _enhancement_success_chance(int(item.get("enhancement", 0))))
		index = _weapon_inventory_index(weapon_uid)
		if index < 0:
			break
		item = weapon_inventory[index]
		var current_level := int(item.get("enhancement", 0))
		reward_presentation.update_enhancement_window(current_level, _enhancement_cost(item), gold, _weapon_attack_power(item), _enhancement_success_chance(current_level))
		action = await reward_presentation.weapon_window_action


func _reset_equipped_potentials() -> void:
	var index := _equipped_item_index()
	if index < 0:
		return
	var weapon_uid := int(weapon_inventory[index].get("uid", -1))
	var item: Dictionary = weapon_inventory[index]
	var cost := _potential_reset_cost(item)
	reward_presentation.open_potential_cube_window(_item_icon(_weapon_icon_index(selected_weapon)), _weapon_name(selected_weapon), _potential_lines(item), cost, gold)
	var action: String = await reward_presentation.weapon_window_action
	while action != "stop" and action != "close":
		if action == "roll":
			index = _weapon_inventory_index(weapon_uid)
			if index >= 0:
				item = weapon_inventory[index]
				cost = _potential_reset_cost(item)
				if gold >= cost:
					var new_potentials := _roll_potentials()
					var new_lines: Array[String] = []
					for potential in new_potentials:
						new_lines.append("%s +%d%%" % [_potential_name(str(potential.id)), int(potential.value)])
					await reward_presentation.animate_cube_roll(new_lines)
					index = _weapon_inventory_index(weapon_uid)
					if index >= 0 and gold >= cost:
						item = weapon_inventory[index]
						gold -= cost
						item.potentials = new_potentials
						weapon_inventory[index] = item
						last_lobby_message = "%s 무기의 잠재능력을 재설정했습니다." % _weapon_name(str(item.get("weapon_id", selected_weapon)))
						_save_progress()
						_refresh_lobby_window()
						item = weapon_inventory[_weapon_inventory_index(weapon_uid)]
						reward_presentation.update_potential_cube_window(_potential_lines(item), _potential_reset_cost(item), gold)
			index = _weapon_inventory_index(weapon_uid)
			if index >= 0:
				item = weapon_inventory[index]
				reward_presentation.update_potential_cube_window(_potential_lines(item), _potential_reset_cost(item), gold)
		action = await reward_presentation.weapon_window_action


func _synthesize_equipped_weapon() -> void:
	if not _can_synthesize_equipped():
		return
	var equipped_index := _equipped_item_index()
	var equipped: Dictionary = weapon_inventory[equipped_index]
	var rarity := int(equipped.rarity)
	var cost := rarity + 1
	if weapon_shards < cost:
		last_lobby_message = "합성에 무기 조각 %d개가 필요합니다." % cost
		_update_lobby()
		return
	var partner_uid := -1
	for item in weapon_inventory:
		if int(item.get("uid", -1)) != selected_weapon_uid and str(item.get("weapon_id", "")) == str(equipped.weapon_id) and int(item.get("rarity", -1)) == rarity:
			partner_uid = int(item.uid)
			break
	if partner_uid < 0:
		return
	weapon_shards -= cost
	var weapon_id := str(equipped.weapon_id)
	_remove_weapon_uid(selected_weapon_uid)
	_remove_weapon_uid(partner_uid)
	var result := _make_weapon_record(weapon_id, rarity + 1)
	weapon_inventory.append(result)
	selected_weapon_uid = int(result.uid)
	selected_weapon = weapon_id
	last_lobby_message = "%s 무기 2개를 합성해 %s 등급 %s를 만들었습니다." % [GAME_DATA.RARITY_NAMES[rarity], GAME_DATA.RARITY_NAMES[rarity + 1], _weapon_name(weapon_id)]
	_save_progress()
	_update_lobby()


func _confirm_synthesize_equipped_weapon() -> void:
	if not _can_synthesize_equipped():
		return
	var equipped := _equipped_item()
	var rarity := int(equipped.get("rarity", 0))
	var cost := rarity + 1
	if rarity >= GAME_DATA.RARITY_NAMES.size() - 1 or weapon_shards < cost:
		return
	var weapon_name := _weapon_name(str(equipped.get("weapon_id", selected_weapon)))
	var confirmed: bool = await reward_presentation.confirm_weapon_synthesis(_item_icon(_weapon_icon_index(selected_weapon)), weapon_name, GAME_DATA.RARITY_NAMES[rarity + 1], cost)
	if not confirmed:
		return
	_synthesize_equipped_weapon()
	var result := _equipped_item()
	reward_presentation.play_synthesis_result(_item_icon(_weapon_icon_index(selected_weapon)), weapon_name, GAME_DATA.RARITY_NAMES[int(result.get("rarity", rarity + 1))])


func _remove_weapon_uid(uid: int) -> void:
	for index in range(weapon_inventory.size() - 1, -1, -1):
		if int(weapon_inventory[index].get("uid", -1)) == uid:
			weapon_inventory.remove_at(index)
			return


func _weapon_name(weapon_id: String) -> String:
	for weapon in GAME_DATA.WEAPONS:
		if weapon.id == weapon_id:
			return weapon.name
	return "연필검"


func start_run() -> void:
	_reset_run()
	mode = "playing"
	skill_hud.visible = true
	get_tree().paused = false
	overlay.hide()
	last_lobby_message = "%s에 출전했습니다." % GAME_DATA.STAGE_IDS[stage_index]
	_update_hud()


func _reset_run() -> void:
	elapsed = 0.0
	skill_cooldowns.clear()
	skill_cast_id = ""
	skill_cast_timer = 0.0
	skill_cast_duration = 0.0
	skill_cast_target_ref = {}
	attack_indicator_timer = 0.0
	boss_mechanic_message = ""
	boss_mechanic_message_timer = 0.0
	kills = 0
	spawn_timer = 0.0
	stage_enemy_quota = int(GAME_DATA.STAGE_ENEMY_COUNTS[GAME_DATA.STAGE_IDS[stage_index]])
	stage_enemies_spawned = 0
	stage_boss_spawned = false
	attack_timer = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	invulnerability = 0.0
	slash_timer = 0.0
	player_anim_row = -1
	player_anim_time = 0.0
	player_position = Vector2(W / 2.0, H / 2.0)
	var item := _equipped_item()
	player_max_hp = _player_max_health_for_item(item)
	player_hp = player_max_hp
	player_speed = _player_move_speed_for_item(item)
	player_damage = _weapon_attack_power(item)
	attack_rate = _player_attack_interval_for_item(item)
	facing = 1.0
	enemies.clear()
	drops.clear()
	projectiles.clear()
	particles.clear()
	boss.clear()
	boss_bar.hide()


func _load_progress() -> void:
	var saved_progress := ProgressStore.load_progress()
	var has_save := bool(saved_progress.get("_has_save", false))
	var skill_progress_changed := false
	var saved_selected := "pencil_sword"
	if has_save:
		stage_index = clampi(int(saved_progress.get("stage_index", 0)), 0, GAME_DATA.STAGE_IDS.size() - 1)
		furthest_stage_index = clampi(int(saved_progress.get("furthest_stage_index", 0)), 0, GAME_DATA.STAGE_IDS.size() - 1)
		gold = maxi(0, int(saved_progress.get("gold", saved_progress.get("ink_shards", 0))))
		weapon_shards = maxi(0, int(saved_progress.get("weapon_shards", 0)))
		magic_shards = maxi(0, int(saved_progress.get("magic_shards", 0)))
		var stored_skills: Variant = saved_progress.get("skills_owned", [])
		if stored_skills is Array:
			for skill_id in stored_skills:
				for skill in GAME_DATA.SKILLS:
					if str(skill.id) == str(skill_id) and not skills_owned.has(str(skill_id)):
						skills_owned.append(str(skill_id))
		var stored_skill_levels: Variant = saved_progress.get("skill_levels", {})
		if stored_skill_levels is Dictionary:
			for skill_id in skills_owned:
				skill_levels[skill_id] = clampi(int(stored_skill_levels.get(skill_id, 1)), 1, GAME_DATA.MAX_ENHANCEMENT)
		else:
			for skill_id in skills_owned:
				skill_levels[skill_id] = 1
		var stored_slots: Variant = saved_progress.get("equipped_skill_slots", ["", "", "", ""])
		if stored_slots is Array:
			for index in mini(4, stored_slots.size()):
				var skill_id := str(stored_slots[index])
				if skills_owned.has(skill_id) and not bool(_skill_data(skill_id).get("passive", false)) and not equipped_skill_slots.has(skill_id):
					equipped_skill_slots[index] = skill_id
		saved_selected = str(saved_progress.get("selected_weapon", "pencil_sword"))
		var stored_inventory: Variant = saved_progress.get("weapon_inventory", [])
		if stored_inventory is Array:
			for raw_item in stored_inventory:
				if raw_item is Dictionary and GAME_DATA.WEAPONS.any(func(weapon): return str(weapon.id) == str(raw_item.get("weapon_id", ""))):
					var item: Dictionary = raw_item.duplicate(true)
					item["uid"] = int(item.get("uid", next_weapon_uid))
					item["rarity"] = clampi(int(item.get("rarity", 0)), 0, 4)
					item["enhancement"] = clampi(int(item.get("enhancement", 0)), 0, GAME_DATA.MAX_ENHANCEMENT)
					var saved_potentials: Variant = item.get("potentials", [])
					if not (saved_potentials is Array) or saved_potentials.size() != 3:
						item["potentials"] = _roll_potentials()
					weapon_inventory.append(item)
					next_weapon_uid = maxi(next_weapon_uid, int(item.uid) + 1)
		if weapon_inventory.is_empty():
			var legacy_weapons: Variant = saved_progress.get("unlocked_weapons", ["pencil_sword"])
			if legacy_weapons is Array:
				for weapon_id in legacy_weapons:
					if GAME_DATA.WEAPONS.any(func(weapon): return str(weapon.id) == str(weapon_id)):
						weapon_inventory.append(_make_weapon_record(str(weapon_id), 0))
		var saved_clears: Variant = saved_progress.get("cleared_stages", [])
		if saved_clears is Array:
			for stage_id in saved_clears:
				if GAME_DATA.STAGE_IDS.has(str(stage_id)) and not cleared_stages.has(str(stage_id)):
					cleared_stages.append(str(stage_id))
	if weapon_inventory.is_empty():
		weapon_inventory.append(_make_weapon_record("pencil_sword", 0))
	selected_weapon_uid = int(saved_progress.get("selected_weapon_uid", -1)) if has_save else -1
	var selected_index := _equipped_item_index()
	if selected_index < 0:
		for index in weapon_inventory.size():
			if str(weapon_inventory[index].get("weapon_id", "")) == saved_selected:
				selected_index = index
				break
	if selected_index < 0:
		selected_index = 0
	selected_weapon_uid = int(weapon_inventory[selected_index].uid)
	selected_weapon = str(weapon_inventory[selected_index].get("weapon_id", "pencil_sword"))
	if not skills_owned.has(GAME_DATA.DASH_SKILL_ID):
		skills_owned.append(GAME_DATA.DASH_SKILL_ID)
		skill_levels[GAME_DATA.DASH_SKILL_ID] = 1
		skill_progress_changed = true
	elif not skill_levels.has(GAME_DATA.DASH_SKILL_ID):
		skill_levels[GAME_DATA.DASH_SKILL_ID] = 1
		skill_progress_changed = true
	if skill_progress_changed:
		_save_progress()


func _save_progress() -> void:
	var progress := {
		"stage_index":stage_index,
		"furthest_stage_index":furthest_stage_index,
		"gold":gold,
		"weapon_shards":weapon_shards,
		"magic_shards":magic_shards,
		"skills_owned":skills_owned,
		"skill_levels":skill_levels,
		"equipped_skill_slots":equipped_skill_slots,
		"weapon_inventory":weapon_inventory,
		"selected_weapon":selected_weapon,
		"selected_weapon_uid":selected_weapon_uid,
		"cleared_stages":cleared_stages
	}
	var result := ProgressStore.save_progress(progress)
	if result != OK:
		push_warning("진행 정보를 저장하지 못했습니다. 오류 코드: %s" % result)


func show_pause() -> void:
	mode = "paused"
	get_tree().paused = true
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_show_panel("일시 정지", "잠시 숨을 고르세요.", "계속하기", func():
		get_tree().paused = false
		mode = "playing"
		overlay.hide()
	)
	var content := overlay_panel.get_child(0) as VBoxContainer
	var quit_button := Button.new()
	quit_button.text = "전투 포기"
	quit_button.pressed.connect(func():
		get_tree().paused = false
		finish(false)
	)
	content.add_child(quit_button)


func _update_game(delta: float) -> void:
	elapsed += delta
	attack_timer -= delta
	attack_indicator_timer = maxf(0.0, attack_indicator_timer - delta)
	boss_mechanic_message_timer = maxf(0.0, boss_mechanic_message_timer - delta)
	if boss_mechanic_message_timer <= 0.0:
		boss_mechanic_message = ""
	skill_cast_timer = maxf(0.0, skill_cast_timer - delta)
	if not skill_cast_target_ref.is_empty():
		if bool(skill_cast_target_ref.get("is_boss", false)):
			if not boss.is_empty():
				skill_cast_target = boss.position
		else:
			skill_cast_target = skill_cast_target_ref.get("position", skill_cast_target)
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = maxf(0.0, float(skill_cooldowns[skill_id]) - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	slash_timer = maxf(0.0, slash_timer - delta)
	player_anim_time = maxf(0.0, player_anim_time - delta)
	if player_anim_time <= 0.0:
		player_anim_row = -1
	var input := _movement_input()
	player_position += input * player_speed * delta
	player_position.x = clampf(player_position.x, 18.0, W - 18.0)
	player_position.y = clampf(player_position.y, 20.0, H - 20.0)
	if absf(input.x) > 0.1:
		facing = signf(input.x)
	if attack_timer <= 0.0:
		_auto_attack()
		if mode != "playing":
			return
		attack_timer = attack_rate
	_spawn_enemies(delta)
	_update_enemies(delta)
	if mode != "playing":
		return
	_update_projectiles(delta)
	if mode != "playing":
		return
	_update_drops(delta)
	if mode != "playing":
		return
	_update_particles(delta)
	if not boss.is_empty():
		_update_boss(delta)
	if mode != "playing":
		return
	_update_hud()


func _spawn_enemies(delta: float) -> void:
	var stage_id: String = GAME_DATA.STAGE_IDS[stage_index]
	if stage_enemies_spawned < stage_enemy_quota:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var roll := rng.randf()
			var kind := "chaser"
			var wave_progress := float(stage_enemies_spawned) / float(stage_enemy_quota)
			if stage_enemies_spawned > 0 and stage_enemies_spawned % 12 == 0:
				kind = "elite"
			else:
				match stage_id:
					"1-2":
						if wave_progress > 0.35 and roll < 0.32: kind = "thrower"
					"1-3":
						if roll < 0.38: kind = "charger"
						elif roll > 0.82: kind = "thrower"
					"1-4":
						if roll < 0.28: kind = "thrower"
						elif roll < 0.62: kind = "charger"
					"1-5":
						if roll < 0.38: kind = "charger"
					"2-1":
						if roll < 0.27: kind = "thrower"
						elif roll < 0.58: kind = "charger"
			_spawn_enemy(kind)
			stage_enemies_spawned += 1
			spawn_timer = 0.82
		return
	if GAME_DATA.BOSS_STAGES.has(stage_id) and not stage_boss_spawned and enemies.is_empty():
		stage_boss_spawned = true
		boss = {"position":Vector2(W/2.0, 90.0), "hp":4350.0, "max_hp":4350.0, "radius":35.0, "attack":1.9, "warning":0.0, "phase":0, "aim_y":0.0, "special_thresholds":[0.7, 0.3], "special_state":"", "special_timer":0.0, "special_target":Vector2(W/2.0, H/2.0), "special_face":1.0, "damage_reduction":0.0, "stagger_timer":0.0, "counter_window":0.0, "counter_success":false}
		boss_bar.show()
	elif not GAME_DATA.BOSS_STAGES.has(stage_id) and enemies.is_empty():
		finish(true)


func _movement_input() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	return direction.normalized() if direction.length_squared() > 1.0 else direction


func _spawn_enemy(kind: String) -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(390.0, 520.0)
	var spawn_position := player_position + Vector2(cos(angle), sin(angle)) * distance
	spawn_position.x = clampf(spawn_position.x, 22.0, W - 22.0)
	spawn_position.y = clampf(spawn_position.y, 22.0, H - 22.0)
	var data: Dictionary = GAME_DATA.ENEMY_DATA[kind].duplicate(true)
	var health_scale := 1.0 + float(stage_index) * 0.14
	data["kind"] = kind
	data["position"] = spawn_position
	data["hp"] *= health_scale
	data["max_hp"] = data["hp"]
	data["speed"] *= 1.0 + float(stage_index) * 0.025
	data["damage"] *= 1.0 + float(stage_index) * 0.08
	data["attack"] = rng.randf_range(1.0, 2.0)
	data["windup"] = 0.0
	data["charge"] = 0.0
	data["flash"] = 0.0
	enemies.append(data)


func _update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		enemy.attack -= delta
		enemy.flash = maxf(0.0, enemy.flash - delta)
		enemy.hit_time = maxf(0.0, float(enemy.get("hit_time", 0.0)) - delta)
		var enemy_position: Vector2 = enemy.position
		var to_player := player_position - enemy_position
		var distance := to_player.length()
		if enemy.kind == "charger":
			if enemy.charge > 0.0:
				enemy_position += enemy.velocity * delta
				enemy.charge -= delta
			elif enemy.windup > 0.0:
				enemy.windup -= delta
				if enemy.windup <= 0.0:
					enemy.velocity = to_player.normalized() * 310.0
					enemy.charge = 0.45
			elif distance < 260.0 and enemy.attack <= 0.0:
				enemy.windup = 0.5
				enemy.attack = 2.2
			else:
				enemy_position += to_player.normalized() * float(enemy.speed) * 0.72 * delta
		elif enemy.kind == "thrower":
			if distance > 245.0:
				enemy_position += to_player.normalized() * float(enemy.speed) * delta
			elif distance < 175.0:
				enemy_position -= to_player.normalized() * float(enemy.speed) * delta
			if enemy.attack <= 0.0 and distance < 360.0:
				projectiles.append({"team":"enemy", "kind":"enemy_orb", "position":enemy_position, "velocity":to_player.normalized()*185.0, "life":3.0, "damage":enemy.damage})
				enemy.attack = 1.8
		else:
			enemy_position += to_player.normalized() * float(enemy.speed) * delta
		enemy.position = enemy_position
		if enemy_position.distance_to(player_position) < float(enemy.radius) + 13.0:
			_hurt(float(enemy.damage) * 0.6)


func _update_projectiles(delta: float) -> void:
	for projectile in projectiles.duplicate():
		projectile.life -= delta
		if projectile.kind == "eraser_bomb":
			if projectile.life <= 0.0:
				for enemy in enemies.duplicate():
					if enemy.position.distance_to(projectile.position) < 78.0:
						_damage_enemy(enemy, projectile.damage)
				if not boss.is_empty() and boss.position.distance_to(projectile.position) < 78.0:
					_damage_boss(projectile.damage)
				_burst(projectile.position, Color("d16a49"), 20)
				continue
		if projectile.get("returning", false):
			projectile.velocity = (player_position - projectile.position).normalized() * 320.0
		projectile.position += projectile.velocity * delta
		if projectile.team == "enemy":
			if projectile.position.distance_to(player_position) < 20.0:
				_hurt(float(projectile.damage))
				projectile.life = 0.0
		elif not projectile.get("returning", false):
			var radius := 13.0
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(projectile.position) < float(enemy.radius) + radius:
					_damage_enemy(enemy, projectile.damage)
					if projectile.kind == "paper_plane":
						projectile.returning = true
						break
					projectile.life = 0.0
					break
			if not boss.is_empty() and boss.position.distance_to(projectile.position) < float(boss.radius) + radius:
				_damage_boss(projectile.damage)
				if projectile.kind == "paper_plane":
					projectile.returning = true
				else:
					projectile.life = 0.0
		if projectile.kind == "paper_plane" and not projectile.get("returning", false) and projectile.life < 1.8:
			projectile.returning = true
		if projectile.get("returning", false) and projectile.position.distance_to(player_position) < 18.0:
			projectile.life = 0.0
	projectiles = projectiles.filter(func(item): return item.life > 0.0)


func _update_drops(delta: float) -> void:
	for drop in drops.duplicate():
		drop.life -= delta
		var distance: float = drop.position.distance_to(player_position)
		if distance < 115.0:
			drop.position = drop.position.move_toward(player_position, minf(390.0, distance * 3.5) * delta)
		if distance < 22.0:
			if str(drop.get("type", "weapon_shard")) == "magic_shard":
				magic_shards += int(drop.get("amount", 1))
				_burst(player_position, Color("68d4cf"), 11)
			else:
				weapon_shards += int(drop.get("amount", 1))
				_burst(player_position, Color("57bdb4"), 7)
			drops.erase(drop)
			_save_progress()
		elif drop.life <= 0.0:
			drops.erase(drop)


func _update_particles(delta: float) -> void:
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.life -= delta
	particles = particles.filter(func(item): return item.life > 0.0)


func _nearest_target(max_distance: float) -> Dictionary:
	var target: Dictionary = {}
	var best_distance := max_distance
	for enemy in enemies:
		var distance: float = enemy.position.distance_to(player_position)
		if distance < best_distance:
			best_distance = distance
			target = enemy
	if not boss.is_empty():
		var distance: float = boss.position.distance_to(player_position)
		if distance < best_distance:
			target = {"is_boss":true, "position":boss.position}
	return target


func _damage_target(target: Dictionary, amount: float) -> void:
	if target.is_empty():
		return
	if target.get("is_boss", false):
		_damage_boss(amount)
	else:
		_damage_enemy(target, amount)


func _auto_attack() -> void:
	var damage := _effective_damage()
	var weapon := _weapon_profile(selected_weapon)
	var damage_ratio := float(weapon.get("damage_ratio", 1.0))
	var attack_range := _weapon_attack_range(selected_weapon)
	var target := _nearest_target(attack_range)
	var target_position: Vector2 = target.get("position", player_position + Vector2(facing * 120.0, 0.0))
	var direction := (target_position - player_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(facing, 0.0)
	facing = signf(direction.x) if absf(direction.x) > 0.1 else facing
	attack_indicator_timer = 0.22
	attack_indicator_range = attack_range
	attack_indicator_direction = direction
	attack_indicator_target = target_position if not target.is_empty() else player_position + direction * attack_range
	attack_indicator_area_radius = float(weapon.get("area_radius", 0.0))
	attack_indicator_area_center = str(weapon.get("area_center", "target"))
	if not target.is_empty():
		var weapon_durations := [0.34, 0.46, 0.52, 0.44, 0.48, 0.52, 0.42, 0.36, 0.52]
		var weapon_row := _weapon_icon_index(selected_weapon)
		_start_player_animation(weapon_row, float(weapon_durations[weapon_row]), true)
	match selected_weapon:
		"pencil_sword":
			var close_target := _nearest_target(185.0)
			if not close_target.is_empty():
				slash_timer = 0.18
				_damage_target(close_target, damage * damage_ratio)
		"ink_orb":
			if not target.is_empty():
				_spawn_player_shot("ink_orb", direction * 275.0, player_position, damage * damage_ratio, 2.5)
		"orbit_line":
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(player_position) < 58.0:
					_damage_enemy(enemy, damage * damage_ratio)
			if not boss.is_empty() and boss.position.distance_to(player_position) < 58.0:
				_damage_boss(damage * damage_ratio)
		"ruler_spear":
			if not target.is_empty():
				var end := player_position + direction * minf(attack_range, player_position.distance_to(target_position) + 45.0)
				slash_timer = 0.2
				for enemy in enemies.duplicate():
					if _segment_distance(enemy.position, player_position, end) < float(enemy.radius) + 16.0:
						_damage_enemy(enemy, damage * damage_ratio)
				if not boss.is_empty() and _segment_distance(boss.position, player_position, end) < float(boss.radius) + 16.0:
					_damage_boss(damage * damage_ratio)
		"brush_burst":
			if not target.is_empty():
				for angle in [-0.24, 0.0, 0.24]:
					_spawn_player_shot("brush_burst", direction.rotated(angle) * 250.0, player_position, damage * damage_ratio, 1.7)
		"eraser_bomb":
			if not target.is_empty():
				projectiles.append({"team":"player", "kind":"eraser_bomb", "position":target_position, "velocity":Vector2.ZERO, "life":0.7, "damage":damage * damage_ratio})
		"paper_plane":
			if not target.is_empty():
				_spawn_player_shot("paper_plane", direction * 290.0, player_position, damage * damage_ratio, 2.4)
		"compass_spear":
			if not target.is_empty():
				var end := player_position + direction * minf(attack_range, player_position.distance_to(target_position) + 45.0)
				slash_timer = 0.24
				for enemy in enemies.duplicate():
					if _segment_distance(enemy.position, player_position, end) < float(enemy.radius) + 20.0:
						_damage_enemy(enemy, damage * damage_ratio)
				if not boss.is_empty() and _segment_distance(boss.position, player_position, end) < float(boss.radius) + 20.0:
					_damage_boss(damage * damage_ratio)
		"stamp_fist":
			if not target.is_empty():
				slash_timer = 0.24
				for enemy in enemies.duplicate():
					if enemy.position.distance_to(target_position) < 88.0:
						_damage_enemy(enemy, damage * damage_ratio)
				if not boss.is_empty() and boss.position.distance_to(target_position) < 88.0:
					_damage_boss(damage * damage_ratio)
func _start_player_animation(row: int, duration: float, weapon_specific: bool = false) -> void:
	player_anim_row = row
	player_anim_duration = duration
	player_anim_time = duration
	player_anim_uses_weapon_atlas = weapon_specific


func _spawn_player_shot(kind: String, velocity: Vector2, shot_origin: Vector2, damage: float, lifetime: float) -> void:
	projectiles.append({"team":"player", "kind":kind, "position":shot_origin, "velocity":velocity, "life":lifetime, "damage":damage, "returning":false})


func _effective_damage() -> float:
	return player_damage


func _weapon_attack_power(item: Dictionary) -> float:
	var rarity := clampi(int(item.get("rarity", 0)), 0, GAME_DATA.RARITY_DAMAGE.size() - 1)
	var enhancement := clampi(int(item.get("enhancement", 0)), 0, GAME_DATA.MAX_ENHANCEMENT)
	var attack_bonus := _potential_total(item, "attack")
	return GAME_DATA.PLAYER_BASE_DAMAGE * float(GAME_DATA.RARITY_DAMAGE[rarity]) * pow(1.1, float(enhancement)) * (1.0 + attack_bonus / 100.0)


func _damage_enemy(enemy: Dictionary, amount: float) -> void:
	if not enemies.has(enemy):
		return
	enemy.hp -= amount
	enemy.flash = 0.12
	enemy.hit_time = 0.13
	enemy.hit_direction = (enemy.position - player_position).normalized()
	_burst(enemy.position, Color("302c27"), 5)
	if enemy.hp <= 0.0:
		_kill_enemy(enemy)


func _kill_enemy(enemy: Dictionary) -> void:
	enemies.erase(enemy)
	kills += 1
	_burst(enemy.position, Color("24211d"), 12)
	var base_gold := 3 + stage_index * 2
	if enemy.kind == "elite":
		base_gold *= 4
	elif enemy.kind == "charger" or enemy.kind == "thrower":
		base_gold *= 2
	var gold_bonus := _potential_total(_equipped_item(), "gold_gain")
	gold += roundi(float(base_gold) * (1.0 + gold_bonus / 100.0))
	var fragment_chance := 0.03 + _potential_total(_equipped_item(), "fragment_find") / 100.0
	var shard_position: Vector2 = enemy.position
	if enemy.kind == "elite":
		fragment_chance += 0.08
	if rng.randf() < fragment_chance:
		drops.append({"position":shard_position, "type":"weapon_shard", "amount":1, "life":25.0})
		_burst(enemy.position, Color("57bdb4"), 5)
	var magic_chance := GAME_DATA.MAGIC_SHARD_DROP_CHANCE + (0.08 if enemy.kind == "elite" else 0.0)
	if rng.randf() < magic_chance:
		drops.append({"position":shard_position + Vector2(11.0, -8.0), "type":"magic_shard", "amount":1, "life":25.0})
		_burst(shard_position, Color("68d4cf"), 7)
	_save_progress()


func dash() -> void:
	if mode != "playing" or dash_cooldown > 0.0:
		return
	var direction := _movement_input()
	if direction == Vector2.ZERO:
		direction = Vector2(facing, 0.0)
	var old_position := player_position
	dash_origin = old_position
	player_position += direction.normalized() * 118.0
	player_position.x = clampf(player_position.x, 20.0, W - 20.0)
	player_position.y = clampf(player_position.y, 22.0, H - 22.0)
	invulnerability = 0.48
	dash_timer = 0.2
	_start_player_animation(3, 0.32)
	dash_cooldown = GAME_DATA.DASH_COOLDOWN_DURATION
	var dash_skill := _skill_data(GAME_DATA.DASH_SKILL_ID)
	var dash_damage_ratio := float(dash_skill.get("damage_ratio", 1.35)) * _skill_strength(GAME_DATA.DASH_SKILL_ID)
	for enemy in enemies.duplicate():
		if _segment_distance(enemy.position, old_position, player_position) < float(enemy.radius) + 13.0:
			_damage_enemy(enemy, _effective_damage() * dash_damage_ratio)
	if not boss.is_empty() and _segment_distance(boss.position, old_position, player_position) < float(boss.radius) + 12.0:
		_damage_boss(_effective_damage() * dash_damage_ratio)
	_burst(player_position, Color("69c5bd"), 7)


func _segment_distance(point: Vector2, start: Vector2, endpoint: Vector2) -> float:
	var segment := endpoint - start
	var amount := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _update_boss(delta: float) -> void:
	boss.flash = maxf(0.0, float(boss.get("flash", 0.0)) - delta)
	boss.hit_time = maxf(0.0, float(boss.get("hit_time", 0.0)) - delta)
	if _boss_try_start_special():
		return
	var special_state := str(boss.get("special_state", ""))
	if special_state != "":
		_update_boss_special(delta, special_state)
		return
	if float(boss.get("stagger_timer", 0.0)) > 0.0:
		boss.stagger_timer = maxf(0.0, float(boss.stagger_timer) - delta)
		boss.damage_reduction = 0.0
		boss.attack = 0.5
		return
	boss.attack -= delta
	if boss.warning > 0.0:
		boss.warning -= delta
		if boss.warning <= 0.0:
			if boss.phase == 1:
				if absf(player_position.y - float(boss.aim_y)) < 42.0:
					_hurt(60.0)
				boss.position.y = clampf(boss.position.y + rng.randf_range(-85.0, 85.0), 65.0, H - 70.0)
			else:
				if player_position.distance_to(boss.position) < 100.0:
					_hurt(65.0)
				_burst(boss.position, Color("ad4a3e"), 20)
			boss.attack = 1.8
	elif boss.attack <= 0.0:
		boss.phase = 1 if rng.randf() < 0.55 else 2
		boss.aim_y = player_position.y
		boss.warning = 0.75
	elif boss.position.distance_to(player_position) > 155.0:
		boss.position = boss.position.move_toward(player_position, 35.0 * delta)


func _boss_try_start_special() -> bool:
	var thresholds: Array = boss.get("special_thresholds", [])
	var ratio := float(boss.hp) / maxf(float(boss.max_hp), 1.0)
	for index in range(thresholds.size()):
		if ratio <= float(thresholds[index]):
			thresholds.remove_at(index)
			boss.special_thresholds = thresholds
			boss.special_state = "gather"
			boss.special_timer = 0.0
			boss.special_target = Vector2(W * 0.5, H * 0.5)
			boss.damage_reduction = 0.9
			boss.warning = 0.0
			boss_mechanic_message = "보스가 강력한 공격을 준비중입니다"
			boss_mechanic_message_timer = 5.0
			return true
	return false


func _update_boss_special(delta: float, special_state: String) -> void:
	boss.attack = 1.0
	boss.special_timer = float(boss.special_timer) + delta
	if special_state == "gather":
		boss.position = boss.position.move_toward(Vector2(W * 0.5, H * 0.5), 260.0 * delta)
		if boss.position.distance_to(Vector2(W * 0.5, H * 0.5)) <= 3.0:
			boss.position = Vector2(W * 0.5, H * 0.5)
			boss.special_state = "charge"
			boss.special_timer = 0.0
			boss.special_face = 1.0 if player_position.x >= boss.position.x else -1.0
			boss.counter_success = false
			boss_mechanic_message = "보스가 강력한 공격을 준비중입니다"
			boss_mechanic_message_timer = 5.0
		return
	if special_state == "charge":
		boss.counter_window = maxf(0.0, float(boss.get("counter_window", 0.0)) - delta)
		if float(boss.special_timer) >= 5.0:
			boss.special_state = "slam"
			boss.special_timer = 0.0
			boss.counter_window = 0.42
			boss_mechanic_message = "정확한 타이밍에 G키를 눌러 반격하세요"
			boss_mechanic_message_timer = 1.25
			_burst(boss.position, Color("63c7ff"), 22)
		return
	if special_state == "slam":
		boss.counter_window = maxf(0.0, float(boss.get("counter_window", 0.0)) - delta)
		if float(boss.special_timer) >= 0.62:
			if bool(boss.get("counter_success", false)):
				boss.special_state = ""
				boss.stagger_timer = 4.0
				boss.damage_reduction = 0.0
				boss_mechanic_message = "반격 성공! 보스가 무력화되었습니다 · 피해 2배"
				boss_mechanic_message_timer = 3.0
				_burst(boss.position, Color("82d8ff"), 36)
			else:
				_hurt(player_max_hp)
				if mode != "playing" or boss.is_empty():
					return
				boss.special_state = "recover"
				boss.special_timer = 0.0
				boss_mechanic_message = "전방 내려찍기! 다음 공격을 피하세요"
				boss_mechanic_message_timer = 1.6
				_burst(Vector2(W * 0.5, H * 0.5), Color("bf493d"), 45)
		return
	if special_state == "recover" and float(boss.special_timer) >= 1.0:
		boss.special_state = ""
		boss.special_timer = 0.0
		boss.damage_reduction = 0.0
		boss.attack = 1.1


func _try_boss_counter() -> void:
	if boss.is_empty() or str(boss.get("special_state", "")) != "slam":
		return
	if float(boss.get("counter_window", 0.0)) <= 0.0 or bool(boss.get("counter_success", false)):
		return
	var facing_boss := 1.0 if player_position.x >= boss.position.x else -1.0
	var front_distance: float = (player_position.x - boss.position.x) * float(boss.special_face)
	if front_distance <= 0.0 or front_distance > 175.0 or absf(player_position.y - boss.position.y) > 100.0:
		return
	boss.counter_success = true
	boss.counter_window = 0.0
	boss.special_timer = 0.62
	boss_mechanic_message = "반격 성공! 보스가 무력화되었습니다 · 피해 2배"
	boss_mechanic_message_timer = 3.0
	_burst(boss.position + Vector2(facing_boss * 48.0, 0.0), Color("8adfff"), 24)


func _damage_boss(amount: float) -> void:
	if boss.is_empty():
		return
	var boss_damage_bonus := _potential_total(_equipped_item(), "boss_damage")
	var stagger_multiplier := 2.0 if float(boss.get("stagger_timer", 0.0)) > 0.0 else 1.0
	var damage_multiplier := (1.0 - float(boss.get("damage_reduction", 0.0))) * stagger_multiplier
	boss.hp -= amount * (1.0 + boss_damage_bonus / 100.0) * damage_multiplier
	boss.flash = 0.15
	boss.hit_time = 0.15
	_burst(boss.position, Color("d65a46"), 8)
	if boss.hp <= 0.0:
		boss.clear()
		kills += 1
		finish(true)


func _hurt(amount: float) -> void:
	if invulnerability > 0.0 or mode != "playing":
		return
	player_hp -= maxf(1.0, amount)
	invulnerability = 0.7
	_start_player_animation(2, 0.32)
	_burst(player_position, Color("bd4e40"), 9)
	if player_hp <= 0.0:
		player_hp = 0.0
		finish(false)


func finish(won: bool) -> void:
	var finished_stage: String = GAME_DATA.STAGE_IDS[stage_index]
	if won:
		var first_clear := not cleared_stages.has(finished_stage)
		var clear_gold := (100 + stage_index * 40) if first_clear else (60 + stage_index * 25)
		var gold_bonus := _potential_total(_equipped_item(), "gold_gain")
		var clear_award := roundi(float(clear_gold) * (1.0 + gold_bonus / 100.0))
		gold += clear_award
		var reward_message := "%s 클리어 골드 %d" % [finished_stage, clear_award]
		if GAME_DATA.BOSS_STAGES.has(finished_stage):
			var boss_gold := (400 + stage_index * 100) if first_clear else (200 + stage_index * 50)
			var boss_award := roundi(float(boss_gold) * (1.0 + gold_bonus / 100.0))
			gold += boss_award
			magic_shards += 3
			if first_clear:
				weapon_shards += 10
				reward_message += " · 보스 첫 클리어 골드 %d + 무기 조각 10개" % boss_award
			else:
				reward_message += " · 보스 재클리어 골드 %d" % boss_award
			reward_message += " + 마력 조각 3개"
		if first_clear:
			cleared_stages.append(finished_stage)
		furthest_stage_index = maxi(furthest_stage_index, mini(stage_index + 1, GAME_DATA.STAGE_IDS.size() - 1))
		stage_index = maxi(furthest_stage_index, mini(stage_index + 1, GAME_DATA.STAGE_IDS.size() - 1))
		last_lobby_message = "%s · 다음 출전 %s" % [reward_message, GAME_DATA.STAGE_IDS[stage_index]]
	else:
		stage_index = maxi(0, stage_index - 1)
		last_lobby_message = "%s에서 쓰러졌습니다. 한 단계 후퇴해 %s부터 재도전합니다. 정산된 무기와 조각은 유지됩니다." % [finished_stage, GAME_DATA.STAGE_IDS[stage_index]]
	_save_progress()
	_reset_run()
	show_lobby()


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _update_hud() -> void:
	var target_count := stage_enemy_quota + (1 if stage_boss_spawned else 0)
	var remaining_count := maxi(0, target_count - kills)
	var objective := "보스 처치" if stage_boss_spawned else "남은 적 %d" % remaining_count
	hud_label.text = "%s · %s +%d\n체력 %.0f / %.0f\n골드 %d · 무기 %d · 마력 %d\n처치 %d / %d  ·  %s\n경과 %s" % [GAME_DATA.STAGE_IDS[stage_index], _weapon_name(selected_weapon), int(_equipped_item().get("enhancement", 0)), player_hp, player_max_hp, gold, weapon_shards, magic_shards, kills, target_count, objective, _format_time(elapsed)]
	hp_bar.max_value = player_max_hp
	hp_bar.value = player_hp
	_update_skill_hud()
	if not boss.is_empty():
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp


func _burst(burst_origin: Vector2, color: Color, amount: int) -> void:
	for index in amount:
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(25.0, 130.0)
		particles.append({"position":burst_origin, "velocity":Vector2(cos(angle), sin(angle))*speed, "life":rng.randf_range(0.18, 0.5), "color":color, "radius":rng.randf_range(1.5, 4.0)})
