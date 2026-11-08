extends Node2D
## 스틱맨 RPG 전투와 골드·무기 성장 메타 진행을 관리합니다.

const W := 960.0
const H := 540.0
const STAGE_IDS := ["1-1", "1-2", "1-3", "1-4", "1-5", "2-1"]
const STAGE_LENGTHS := {"1-1":180.0, "1-2":180.0, "1-3":180.0, "1-4":180.0, "1-5":150.0, "2-1":180.0}
const BOSS_STAGES := ["1-5"]
const GACHA_COST := 5
const MAX_ENHANCEMENT := 20
const RARITY_NAMES := ["일반", "고급", "레어", "유니크", "전설"]
const RARITY_DAMAGE := [1.0, 1.1, 1.22, 1.38, 1.58]
const RARITY_CHANCES := [60, 25, 10, 4, 1]
const SAVE_PATH := "user://stickman_rpg.cfg"
const PAPER_BACKGROUND: Texture2D = preload("res://art/sketch_forest_background.png")
const CHARACTER_ATLAS: Texture2D = preload("res://art/stickman_characters_atlas.png")
const ITEM_ATLAS: Texture2D = preload("res://art/weapon_items_atlas.png")
const ACTION_ATLAS: Texture2D = preload("res://art/stickman_action_animation_atlas.png")
const WEAPON_ACTION_ATLAS: Texture2D = preload("res://art/weapon_attack_animation_atlas.png")
const CHARACTER_CELL := 512.0
const ITEM_CELL := 362.0
const ACTION_FRAME_SIZE := Vector2(362.0, 271.5)
const WEAPON_ACTION_FRAME_SIZE := Vector2(280.5, 1402.0 / 9.0)
const WEAPONS := [
	{"id":"pencil_sword", "name":"연필검", "desc":"가까운 적을 빠르게 베는 기본 무기."},
	{"id":"ink_orb", "name":"먹물 구슬", "desc":"가까운 적을 향해 먹물 구슬을 발사합니다."},
	{"id":"orbit_line", "name":"회전 선분", "desc":"주변을 도는 선분이 가까운 적을 칩니다."},
	{"id":"ruler_spear", "name":"자 대검", "desc":"긴 직선으로 일렬의 적을 관통합니다."},
	{"id":"brush_burst", "name":"붓 폭발탄", "desc":"세 발의 먹물 탄을 부채꼴로 발사합니다."},
	{"id":"eraser_bomb", "name":"지우개 폭탄", "desc":"목표 지점에 잠시 뒤 범위 폭발을 일으킵니다."},
	{"id":"paper_plane", "name":"종이비행기", "desc":"적을 통과한 뒤 플레이어에게 돌아옵니다."},
	{"id":"compass_spear", "name":"컴퍼스 창", "desc":"먼 적까지 뻗는 강한 관통 찌르기."},
	{"id":"stamp_fist", "name":"도장 주먹", "desc":"가까운 적 주변을 넓게 내려칩니다."}
]
const POTENTIALS := [
	{"id":"attack", "name":"공격력", "min":3, "max":8},
	{"id":"attack_speed", "name":"공격 속도", "min":2, "max":6},
	{"id":"gold_gain", "name":"골드 획득량", "min":5, "max":12},
	{"id":"fragment_find", "name":"무기 조각 발견률", "min":1, "max":3},
	{"id":"max_health", "name":"최대 체력", "min":5, "max":10},
	{"id":"move_speed", "name":"이동 속도", "min":2, "max":5}
]
const ENEMY_DATA := {
	"chaser": {"hp":40.0, "speed":48.0, "damage":9.0, "radius":13.0, "color":Color("33302b")},
	"charger": {"hp":68.0, "speed":39.0, "damage":15.0, "radius":15.0, "color":Color("704d37")},
	"thrower": {"hp":52.0, "speed":30.0, "damage":8.0, "radius":14.0, "color":Color("526e68")},
	"elite": {"hp":330.0, "speed":34.0, "damage":20.0, "radius":23.0, "color":Color("a74235")}
}

var mode := "lobby"
var stage_index := 0
var furthest_stage_index := 0
var gold := 0
var weapon_shards := 0
var selected_weapon := "pencil_sword"
var selected_weapon_uid := 1
var next_weapon_uid := 1
var weapon_inventory: Array[Dictionary] = []
var cleared_stages: Array[String] = []
var last_lobby_message := "스케치 세계에 오신 것을 환영합니다."
var elapsed := 0.0
var kills := 0
var spawn_timer := 0.0
var elite_at := 75.0
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
var player_position := Vector2(W / 2.0, H / 2.0)
var player_hp := 100.0
var player_max_hp := 100.0
var player_speed := 190.0
var player_damage := 25.0
var attack_rate := 0.72
var facing := 1.0
var enemies: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var boss: Dictionary = {}
var rng := RandomNumberGenerator.new()
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
var lobby_message: Label
var lobby_stage_path: HBoxContainer
var lobby_content: VBoxContainer
var lobby_enter_button: Button
var lobby_gacha_button: Button
var lobby_section_panel: Control
var lobby_section := "home"


func _ready() -> void:
	rng.randomize()
	_load_progress()
	_build_ui()
	show_lobby()
	queue_redraw()


func _process(delta: float) -> void:
	if mode == "playing":
		_update_game(minf(delta, 0.04))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
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
	hud.size = Vector2(924, 76)
	hud.add_theme_constant_override("separation", 20)
	ui.add_child(hud)
	hud_label = Label.new()
	hud_label.custom_minimum_size = Vector2(270, 82)
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
	overlay_panel.add_theme_stylebox_override("panel", _flat_style(Color("f2e6cf")))
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


func show_lobby() -> void:
	mode = "lobby"
	get_tree().paused = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	for child in overlay_panel.get_children():
		overlay_panel.remove_child(child)
		child.queue_free()
	overlay_panel.custom_minimum_size = Vector2(850, 470)
	overlay_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	overlay_panel.add_child(frame)
	var top := HBoxContainer.new()
	frame.add_child(top)
	var title := Label.new()
	title.text = "STICKMAN RPG  /  모험의 거점"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	lobby_status = Label.new()
	lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(lobby_status)
	var divider := HSeparator.new()
	frame.add_child(divider)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 20)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(main)
	var showcase := VBoxContainer.new()
	showcase.custom_minimum_size.x = 250
	showcase.alignment = BoxContainer.ALIGNMENT_CENTER
	showcase.add_theme_constant_override("separation", 8)
	main.add_child(showcase)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(230, 175)
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
	showcase.add_child(lobby_weapon_desc)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
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
	enter.text = "%s  출전하기" % STAGE_IDS[stage_index]
	enter.custom_minimum_size.y = 58
	enter.add_theme_font_size_override("font_size", 22)
	enter.pressed.connect(start_run)
	center.add_child(enter)
	lobby_enter_button = enter
	var nav := HBoxContainer.new()
	frame.add_child(nav)
	var armory := Button.new()
	armory.text = "⚔  무기고"
	armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armory.custom_minimum_size.y = 42
	armory.pressed.connect(func(): _set_lobby_section("armory"))
	nav.add_child(armory)
	var chest := Button.new()
	chest.text = "▣  무기 뽑기  ·  %d 조각" % weapon_shards
	chest.icon = _item_icon(11)
	chest.add_theme_constant_override("icon_max_width", 38)
	chest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest.custom_minimum_size.y = 42
	chest.pressed.connect(func(): _set_lobby_section("chest"))
	nav.add_child(chest)
	lobby_gacha_button = chest
	var settings := Button.new()
	settings.text = "⚙ 설정"
	settings.custom_minimum_size.y = 42
	settings.pressed.connect(func(): _set_lobby_section("settings"))
	nav.add_child(settings)
	lobby_content = frame
	_update_lobby()
	overlay.show()


func _update_lobby() -> void:
	if lobby_status == null:
		return
	lobby_status.text = "골드  ◈ %d     무기 조각  ◆ %d" % [gold, weapon_shards]
	lobby_gacha_button.text = "▣  무기 뽑기  ·  %d 조각" % weapon_shards
	lobby_stage_label.text = "현재 출전 단계   %s" % STAGE_IDS[stage_index]
	lobby_enter_button.text = "%s  출전하기" % STAGE_IDS[stage_index]
	lobby_weapon_label.text = "장착 무기  ·  %s" % _weapon_name(selected_weapon)
	lobby_weapon_desc.text = _weapon_description(selected_weapon)
	lobby_message.text = last_lobby_message
	for child in lobby_stage_path.get_children():
		lobby_stage_path.remove_child(child)
		child.queue_free()
	for index in STAGE_IDS.size():
		var node := Button.new()
		var stage_id: String = STAGE_IDS[index]
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
	if is_instance_valid(lobby_section_panel):
		lobby_content.remove_child(lobby_section_panel)
		lobby_section_panel.free()
	lobby_section_panel = _build_lobby_section()
	lobby_content.add_child(lobby_section_panel)


func _weapon_description(weapon_id: String) -> String:
	for weapon in WEAPONS:
		if weapon.id == weapon_id:
			return str(weapon.desc)
	return "기본 무기"


func _select_lobby_stage(index: int) -> void:
	if index > furthest_stage_index and index != stage_index:
		return
	stage_index = index
	_save_progress()
	_update_lobby()


func _set_lobby_section(section: String) -> void:
	lobby_section = section
	_update_lobby()


func _build_lobby_section() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LobbySection"
	panel.custom_minimum_size.y = 110
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	panel.add_child(body)
	match lobby_section:
		"armory":
			var heading := Label.new()
			heading.text = "무기고  ·  보유 %d개  ·  선택 %s" % [weapon_inventory.size(), RARITY_NAMES[int(_equipped_item().get("rarity", 0))]]
			body.add_child(heading)
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size.y = 86
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			body.add_child(scroll)
			var grid := GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			scroll.add_child(grid)
			for item in weapon_inventory:
				var button := Button.new()
				var weapon_id := str(item.get("weapon_id", "pencil_sword"))
				var selected := int(item.get("uid", -1)) == selected_weapon_uid
				button.text = ("✓ " if selected else "") + "%s %s +%d" % [RARITY_NAMES[clampi(int(item.get("rarity", 0)), 0, 4)], _weapon_name(weapon_id), int(item.get("enhancement", 0))]
				button.custom_minimum_size = Vector2(176, 38)
				button.icon = _item_icon(_weapon_icon_index(weapon_id))
				button.add_theme_constant_override("icon_max_width", 24)
				button.pressed.connect(_equip_weapon_uid.bind(int(item.get("uid", -1))))
				grid.add_child(button)
			var details := Label.new()
			details.text = _potential_summary(_equipped_item())
			body.add_child(details)
			var actions := HBoxContainer.new()
			actions.add_theme_constant_override("separation", 5)
			body.add_child(actions)
			var enhance := Button.new()
			var enhance_cost := _enhancement_cost(_equipped_item())
			var enhance_level := int(_equipped_item().get("enhancement", 0))
			enhance.text = "강화 +%d  ·  %d 골드" % [enhance_level + 1, enhance_cost] if enhance_level < MAX_ENHANCEMENT else "강화 최대"
			enhance.disabled = enhance_level >= MAX_ENHANCEMENT or gold < enhance_cost
			enhance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			enhance.pressed.connect(_enhance_equipped_weapon)
			actions.add_child(enhance)
			var reroll := Button.new()
			var reroll_cost := _potential_reset_cost(_equipped_item())
			reroll.text = "잠재 재설정  ·  %d 골드" % reroll_cost
			reroll.disabled = gold < reroll_cost
			reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reroll.pressed.connect(_reset_equipped_potentials)
			actions.add_child(reroll)
			var synthesize := Button.new()
			var can_synthesize := _can_synthesize_equipped()
			var shard_cost := int(_equipped_item().get("rarity", 0)) + 1
			synthesize.text = "동일 무기 합성  ·  조각 %d" % shard_cost
			synthesize.disabled = not can_synthesize or int(_equipped_item().get("rarity", 0)) >= 4 or weapon_shards < shard_cost
			synthesize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			synthesize.pressed.connect(_synthesize_equipped_weapon)
			actions.add_child(synthesize)
		"chest":
			var heading := Label.new()
			heading.text = "무기 뽑기  ·  5개 등급"
			body.add_child(heading)
			var details := Label.new()
			details.text = "일반 60% · 고급 25% · 레어 10% · 유니크 4% · 전설 1%\n보유 무기 조각 %d  /  뽑기 비용 %d" % [weapon_shards, GACHA_COST]
			body.add_child(details)
			var button := Button.new()
			button.text = "무기 뽑기  ·  조각 %d개" % GACHA_COST
			button.icon = _item_icon(11)
			button.add_theme_constant_override("icon_max_width", 34)
			button.disabled = weapon_shards < GACHA_COST
			button.pressed.connect(_draw_weapon)
			body.add_child(button)
		"settings":
			var heading := Label.new()
			heading.text = "설정"
			body.add_child(heading)
			var info := Label.new()
			info.text = "WASD / 방향키 이동  ·  Space 대시  ·  Esc 일시정지"
			body.add_child(info)
			var close := Button.new()
			close.text = "닫기"
			close.pressed.connect(func(): _set_lobby_section("home"))
			body.add_child(close)
		_: 
			var hint := Label.new()
			hint.text = "스테이지 보상 골드로 무기를 강화하고, 무기 조각으로 뽑기와 합성을 하세요."
			body.add_child(hint)
	return panel


func _weapon_icon_index(weapon_id: String) -> int:
	for index in WEAPONS.size():
		if str(WEAPONS[index].id) == weapon_id:
			return index
	return 0


func _item_icon(index: int) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = ITEM_ATLAS
	icon.region = Rect2(float(index % 4) * ITEM_CELL, float(floori(float(index) / 4.0)) * ITEM_CELL, ITEM_CELL, ITEM_CELL)
	return icon


func _equip_weapon(weapon_id: String) -> void:
	if not unlocked_weapons.has(weapon_id):
		return
	selected_weapon = weapon_id
	last_lobby_message = "%s를 장착했습니다." % _weapon_name(weapon_id)
	_save_progress()
	_update_lobby()


func _cycle_weapon(direction: int) -> void:
	var index := unlocked_weapons.find(selected_weapon)
	index = posmod(index + direction, unlocked_weapons.size())
	selected_weapon = unlocked_weapons[index]
	_save_progress()
	last_lobby_message = "%s를 선택했습니다." % _weapon_name(selected_weapon)
	show_lobby()


func _open_weapon_chest() -> void:
	if ink_shards < CHEST_COST:
		last_lobby_message = "잉크 조각이 부족합니다. 스테이지를 클리어해 조각을 모으세요."
		show_lobby()
		return
	ink_shards -= CHEST_COST
	var candidates: Array[String] = []
	for weapon in WEAPONS:
		if not unlocked_weapons.has(weapon.id):
			candidates.append(weapon.id)
	if candidates.is_empty():
		ink_shards += 40
		last_lobby_message = "중복 상자 보상이 잉크 조각 40개로 전환됐습니다."
	else:
		var obtained: String = candidates[rng.randi_range(0, candidates.size() - 1)]
		unlocked_weapons.append(obtained)
		selected_weapon = obtained
		last_lobby_message = "새 무기 해금: %s" % _weapon_name(obtained)
	_save_progress()
	show_lobby()


func _weapon_name(weapon_id: String) -> String:
	for weapon in WEAPONS:
		if weapon.id == weapon_id:
			return weapon.name
	return "연필검"


func start_run() -> void:
	_reset_run()
	mode = "playing"
	get_tree().paused = false
	overlay.hide()
	last_lobby_message = "%s에 출전했습니다." % STAGE_IDS[stage_index]
	_update_hud()


func _reset_run() -> void:
	elapsed = 0.0
	kills = 0
	level = 1
	xp = 0
	xp_need = 5
	spawn_timer = 0.0
	elite_at = 75.0
	attack_timer = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	invulnerability = 0.0
	slash_timer = 0.0
	player_anim_row = -1
	player_anim_time = 0.0
	player_position = Vector2(W / 2.0, H / 2.0)
	player_hp = 100.0
	player_max_hp = 100.0
	player_speed = 190.0
	player_damage = 25.0
	attack_rate = 0.72
	facing = 1.0
	upgrades.clear()
	enemies.clear()
	drops.clear()
	projectiles.clear()
	particles.clear()
	boss.clear()
	boss_bar.hide()


func _load_progress() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK:
		return
	stage_index = clampi(int(save.get_value("progress", "stage_index", 0)), 0, STAGE_IDS.size() - 1)
	furthest_stage_index = clampi(int(save.get_value("progress", "furthest_stage_index", 0)), 0, STAGE_IDS.size() - 1)
	ink_shards = maxi(0, int(save.get_value("progress", "ink_shards", 0)))
	var saved_weapons: Variant = save.get_value("progress", "unlocked_weapons", ["pencil_sword"])
	for weapon_id in saved_weapons:
		for weapon in WEAPONS:
			if weapon.id == str(weapon_id) and not unlocked_weapons.has(str(weapon_id)):
				unlocked_weapons.append(str(weapon_id))
	if not unlocked_weapons.has("pencil_sword"):
		unlocked_weapons.push_front("pencil_sword")
	var saved_selected := str(save.get_value("progress", "selected_weapon", "pencil_sword"))
	selected_weapon = saved_selected if unlocked_weapons.has(saved_selected) else "pencil_sword"
	var saved_clears: Variant = save.get_value("progress", "cleared_stages", [])
	for stage_id in saved_clears:
		if STAGE_IDS.has(str(stage_id)) and not cleared_stages.has(str(stage_id)):
			cleared_stages.append(str(stage_id))


func _save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "stage_index", stage_index)
	save.set_value("progress", "furthest_stage_index", furthest_stage_index)
	save.set_value("progress", "ink_shards", ink_shards)
	save.set_value("progress", "unlocked_weapons", unlocked_weapons)
	save.set_value("progress", "selected_weapon", selected_weapon)
	save.set_value("progress", "cleared_stages", cleared_stages)
	var result := save.save(SAVE_PATH)
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
		attack_timer = attack_rate
	_spawn_enemies(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_drops(delta)
	_update_particles(delta)
	if not boss.is_empty():
		_update_boss(delta)
	var stage_id: String = STAGE_IDS[stage_index]
	if mode == "playing" and not BOSS_STAGES.has(stage_id) and elapsed >= float(STAGE_LENGTHS[stage_id]):
		finish(true)
	_update_hud()


func _spawn_enemies(delta: float) -> void:
	var stage_id: String = STAGE_IDS[stage_index]
	if elapsed < float(STAGE_LENGTHS[stage_id]):
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var amount := 2 if elapsed > 120.0 and rng.randf() < minf(0.62, 0.2 + elapsed / 900.0) else 1
			for index in amount:
				var roll := rng.randf()
				var kind := "chaser"
				match stage_id:
					"1-2":
						if elapsed > 30.0 and roll < 0.32:
							kind = "thrower"
					"1-3":
						if elapsed > 25.0 and roll < 0.38:
							kind = "charger"
						elif elapsed > 80.0 and roll > 0.82:
							kind = "thrower"
					"1-4":
						if roll < 0.28:
							kind = "thrower"
						elif roll < 0.62:
							kind = "charger"
					"1-5":
						if roll < 0.38:
							kind = "charger"
					"2-1":
						if roll < 0.27:
							kind = "thrower"
						elif roll < 0.58:
							kind = "charger"
				_spawn_enemy(kind)
			spawn_timer = maxf(0.28, 1.15 - elapsed / 1000.0)
		if elapsed >= elite_at:
			_spawn_enemy("elite")
			elite_at += 115.0
	if BOSS_STAGES.has(stage_id) and elapsed >= float(STAGE_LENGTHS[stage_id]) and boss.is_empty():
		boss = {"position":Vector2(W/2.0, 90.0), "hp":1800.0, "max_hp":1800.0, "radius":35.0, "attack":2.2, "warning":0.0, "phase":0, "aim_y":0.0}
		boss_bar.show()


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
	var position := player_position + Vector2(cos(angle), sin(angle)) * distance
	position.x = clampf(position.x, 22.0, W - 22.0)
	position.y = clampf(position.y, 22.0, H - 22.0)
	var data: Dictionary = ENEMY_DATA[kind].duplicate(true)
	var scale := 1.0 + minf(0.8, elapsed / 500.0)
	data["kind"] = kind
	data["position"] = position
	data["hp"] *= scale
	data["max_hp"] = data["hp"]
	data["speed"] += elapsed * 0.035 if kind == "chaser" else 0.0
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
		var position: Vector2 = enemy.position
		var to_player := player_position - position
		var distance := to_player.length()
		if enemy.kind == "charger":
			if enemy.charge > 0.0:
				position += enemy.velocity * delta
				enemy.charge -= delta
			elif enemy.windup > 0.0:
				enemy.windup -= delta
				if enemy.windup <= 0.0:
					enemy.velocity = to_player.normalized() * 250.0
					enemy.charge = 0.45
			elif distance < 260.0 and enemy.attack <= 0.0:
				enemy.windup = 0.62
				enemy.attack = 2.6
			else:
				position += to_player.normalized() * float(enemy.speed) * 0.72 * delta
		elif enemy.kind == "thrower":
			if distance > 245.0:
				position += to_player.normalized() * float(enemy.speed) * delta
			elif distance < 175.0:
				position -= to_player.normalized() * float(enemy.speed) * delta
			if enemy.attack <= 0.0 and distance < 360.0:
				projectiles.append({"team":"enemy", "kind":"enemy_orb", "position":position, "velocity":to_player.normalized()*145.0, "life":3.0, "damage":enemy.damage})
				enemy.attack = 2.2
		else:
			position += to_player.normalized() * float(enemy.speed) * delta
		enemy.position = position
		if position.distance_to(player_position) < float(enemy.radius) + 13.0:
			_hurt(float(enemy.damage) * delta * 2.2)
		if upgrades.get("spin", 0) > 0 and position.distance_to(player_position) < 50.0:
			_damage_enemy(enemy, 9.0 * float(upgrades.spin) * delta)


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
		var magnet := 210.0 if upgrades.get("magnet", 0) > 0 else 105.0
		if distance < magnet:
			drop.position = drop.position.move_toward(player_position, minf(430.0, distance * 3.0) * delta)
		if distance < 22.0:
			xp += int(drop.xp)
			drops.erase(drop)
			while xp >= xp_need and mode == "playing":
				_level_up()
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
	var target := _nearest_target(470.0)
	var target_position: Vector2 = target.get("position", player_position + Vector2(facing * 120.0, 0.0))
	var direction := (target_position - player_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(facing, 0.0)
	facing = signf(direction.x) if absf(direction.x) > 0.1 else facing
	var anim_target := target
	if selected_weapon == "pencil_sword":
		anim_target = _nearest_target(185.0)
	elif selected_weapon == "orbit_line":
		anim_target = _nearest_target(58.0)
	if not anim_target.is_empty():
		var weapon_durations := [0.34, 0.46, 0.52, 0.44, 0.48, 0.52, 0.42, 0.36, 0.52]
		var weapon_row := _weapon_icon_index(selected_weapon)
		_start_player_animation(weapon_row, float(weapon_durations[weapon_row]), true)
	match selected_weapon:
		"pencil_sword":
			var close_target := _nearest_target(185.0)
			if not close_target.is_empty():
				slash_timer = 0.18
				_damage_target(close_target, damage)
				if upgrades.get("lightning", 0) > 0:
					var nearest: Dictionary = {}
					var nearest_distance := 125.0
					for enemy in enemies:
						var origin: Vector2 = close_target.position
						if enemy == close_target:
							continue
						var distance: float = enemy.position.distance_to(origin)
						if distance < nearest_distance:
							nearest = enemy
							nearest_distance = distance
					_damage_target(nearest, damage * 0.55)
		"ink_orb":
			if not target.is_empty():
				_spawn_player_shot("ink_orb", direction * 275.0, player_position, damage, 2.5)
		"orbit_line":
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(player_position) < 58.0:
					_damage_enemy(enemy, damage * 0.8)
			if not boss.is_empty() and boss.position.distance_to(player_position) < 58.0:
				_damage_boss(damage * 0.8)
		"ruler_spear":
			if not target.is_empty():
				var end := player_position + direction * minf(430.0, player_position.distance_to(target_position) + 45.0)
				slash_timer = 0.2
				for enemy in enemies.duplicate():
					if _segment_distance(enemy.position, player_position, end) < float(enemy.radius) + 16.0:
						_damage_enemy(enemy, damage * 1.25)
				if not boss.is_empty() and _segment_distance(boss.position, player_position, end) < float(boss.radius) + 16.0:
					_damage_boss(damage * 1.25)
		"brush_burst":
			if not target.is_empty():
				for angle in [-0.24, 0.0, 0.24]:
					_spawn_player_shot("brush_burst", direction.rotated(angle) * 250.0, player_position, damage * 0.55, 1.7)
		"eraser_bomb":
			if not target.is_empty():
				projectiles.append({"team":"player", "kind":"eraser_bomb", "position":target_position, "velocity":Vector2.ZERO, "life":0.7, "damage":damage * 1.55})
		"paper_plane":
			if not target.is_empty():
				_spawn_player_shot("paper_plane", direction * 290.0, player_position, damage * 0.9, 2.4)
		"compass_spear":
			if not target.is_empty():
				var end := player_position + direction * 475.0
				slash_timer = 0.24
				for enemy in enemies.duplicate():
					if _segment_distance(enemy.position, player_position, end) < float(enemy.radius) + 20.0:
						_damage_enemy(enemy, damage * 1.65)
				if not boss.is_empty() and _segment_distance(boss.position, player_position, end) < float(boss.radius) + 20.0:
					_damage_boss(damage * 1.65)
		"stamp_fist":
			if not target.is_empty():
				slash_timer = 0.24
				for enemy in enemies.duplicate():
					if enemy.position.distance_to(target_position) < 88.0:
						_damage_enemy(enemy, damage * 1.3)
				if not boss.is_empty() and boss.position.distance_to(target_position) < 88.0:
					_damage_boss(damage * 1.3)
	if upgrades.get("spin", 0) > 0 and selected_weapon != "orbit_line":
		for enemy in enemies.duplicate():
			if enemy.position.distance_to(player_position) < 50.0:
				_damage_enemy(enemy, 9.0 * float(upgrades.spin))


func _start_player_animation(row: int, duration: float, weapon_specific: bool = false) -> void:
	player_anim_row = row
	player_anim_duration = duration
	player_anim_time = duration
	player_anim_uses_weapon_atlas = weapon_specific


func _spawn_player_shot(kind: String, velocity: Vector2, position: Vector2, damage: float, lifetime: float) -> void:
	projectiles.append({"team":"player", "kind":kind, "position":position, "velocity":velocity, "life":lifetime, "damage":damage, "returning":false})


func _effective_damage() -> float:
	return player_damage * (1.35 if upgrades.get("last", 0) > 0 and player_hp < player_max_hp * 0.5 else 1.0)


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
	drops.append({"position":enemy.position, "xp":enemy.xp, "life":32.0})
	if upgrades.get("ink", 0) > 0:
		for nearby in enemies.duplicate():
			if nearby.position.distance_to(enemy.position) < 72.0:
				_damage_enemy(nearby, 24.0 * float(upgrades.ink))
		_burst(enemy.position, Color("b65043"), 14)


func dash() -> void:
	if mode != "playing" or dash_cooldown > 0.0:
		return
	var direction := _movement_input()
	if direction == Vector2.ZERO:
		direction = Vector2(facing, 0.0)
	var old_position := player_position
	dash_origin = old_position
	player_position += direction.normalized() * (118.0 + 13.0 * float(upgrades.get("light", 0)))
	player_position.x = clampf(player_position.x, 20.0, W - 20.0)
	player_position.y = clampf(player_position.y, 22.0, H - 22.0)
	invulnerability = 0.48
	dash_timer = 0.2
	_start_player_animation(3, 0.32)
	dash_cooldown = maxf(0.85, 2.5 * pow(0.8, float(upgrades.get("dash", 0))))
	for enemy in enemies.duplicate():
		if _segment_distance(enemy.position, old_position, player_position) < float(enemy.radius) + 13.0:
			_damage_enemy(enemy, _effective_damage() * 1.35)
	if not boss.is_empty() and _segment_distance(boss.position, old_position, player_position) < float(boss.radius) + 12.0:
		_damage_boss(_effective_damage() * 1.35)
	_burst(player_position, Color("69c5bd"), 7)


func _segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var amount := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _level_up() -> void:
	mode = "levelup"
	level += 1
	xp -= xp_need
	xp_need = floori(xp_need * 1.42 + 3.0)
	var pool: Array = UPGRADES.duplicate(true)
	pool.shuffle()
	var options: Array = pool.slice(0, 3)
	_show_upgrade_choices(options)


func _show_upgrade_choices(options: Array) -> void:
	for child in overlay_panel.get_children():
		overlay_panel.remove_child(child)
		child.queue_free()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	overlay_panel.add_child(content)
	var heading := Label.new()
	heading.text = "레벨 %d 달성! 성장 선택" % level
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	for option in options:
		var button := Button.new()
		button.text = "%s — %s" % [option.name, option.desc]
		button.custom_minimum_size.y = 48
		button.pressed.connect(func(): _choose_upgrade(option))
		content.add_child(button)
	overlay.show()


func _choose_upgrade(option: Dictionary) -> void:
	var id: String = option.id
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	match id:
		"wind": player_damage *= 1.22
		"shell": player_max_hp += 25.0; player_hp = minf(player_max_hp, player_hp + 25.0)
		"light": player_speed *= 1.09
		"tempo": attack_rate *= 0.85
		"vital": player_hp = minf(player_max_hp, player_hp + 35.0)
	mode = "playing"
	overlay.hide()
	_update_hud()
	if xp >= xp_need:
		_level_up()


func _update_boss(delta: float) -> void:
	boss.flash = maxf(0.0, float(boss.get("flash", 0.0)) - delta)
	boss.hit_time = maxf(0.0, float(boss.get("hit_time", 0.0)) - delta)
	boss.attack -= delta
	if boss.warning > 0.0:
		boss.warning -= delta
		if boss.warning <= 0.0:
			if boss.phase == 1:
				if absf(player_position.y - float(boss.aim_y)) < 42.0:
					_hurt(35.0)
				boss.position.y = clampf(boss.position.y + rng.randf_range(-85.0, 85.0), 65.0, H - 70.0)
			else:
				if player_position.distance_to(boss.position) < 100.0:
					_hurt(30.0)
				_burst(boss.position, Color("ad4a3e"), 20)
			boss.attack = 2.1
	elif boss.attack <= 0.0:
		boss.phase = 1 if rng.randf() < 0.55 else 2
		boss.aim_y = player_position.y
		boss.warning = 0.9
	elif boss.position.distance_to(player_position) > 155.0:
		boss.position = boss.position.move_toward(player_position, 28.0 * delta)


func _damage_boss(amount: float) -> void:
	if boss.is_empty():
		return
	boss.hp -= amount
	boss.flash = 0.15
	boss.hit_time = 0.15
	_burst(boss.position, Color("d65a46"), 8)
	if boss.hp <= 0.0:
		boss.clear()
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
	var finished_stage: String = STAGE_IDS[stage_index]
	if won:
		var first_clear := not cleared_stages.has(finished_stage)
		var reward := (200 if BOSS_STAGES.has(finished_stage) else 100) if first_clear else 25
		ink_shards += reward
		if first_clear:
			cleared_stages.append(finished_stage)
		furthest_stage_index = maxi(furthest_stage_index, mini(stage_index + 1, STAGE_IDS.size() - 1))
		stage_index = maxi(furthest_stage_index, mini(stage_index + 1, STAGE_IDS.size() - 1))
		last_lobby_message = "%s 클리어! 잉크 조각 %d개를 정산했습니다. 다음 출전: %s" % [finished_stage, reward, STAGE_IDS[stage_index]]
	else:
		stage_index = maxi(0, stage_index - 1)
		last_lobby_message = "%s에서 쓰러졌습니다. 한 단계 후퇴해 %s부터 재도전합니다. 정산된 무기와 조각은 유지됩니다." % [finished_stage, STAGE_IDS[stage_index]]
	_save_progress()
	_reset_run()
	show_lobby()


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _build_names() -> String:
	var names: Array[String] = [_weapon_name(selected_weapon), "대시 베기"]
	for item in UPGRADES:
		if upgrades.get(item.id, 0) > 0:
			names.append(item.name)
	return " · ".join(names)


func _update_hud() -> void:
	hud_label.text = "%s · %s\n체력 %.0f / %.0f\nLv. %d · 처치 %d · XP %d/%d\n%s" % [STAGE_IDS[stage_index], _weapon_name(selected_weapon), player_hp, player_max_hp, level, kills, xp, xp_need, _format_time(elapsed)]
	hp_bar.max_value = player_max_hp
	hp_bar.value = player_hp
	xp_bar.max_value = xp_need
	xp_bar.value = xp
	if not boss.is_empty():
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp


func _burst(position: Vector2, color: Color, amount: int) -> void:
	for index in amount:
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(25.0, 130.0)
		particles.append({"position":position, "velocity":Vector2(cos(angle), sin(angle))*speed, "life":rng.randf_range(0.18, 0.5), "color":color, "radius":rng.randf_range(1.5, 4.0)})


func _draw() -> void:
	_draw_paper()
	for drop in drops:
		_draw_item(drop.position, Vector2(19.0, 19.0), 9)
	for projectile in projectiles:
		_draw_projectile(projectile)
	for enemy in enemies:
		_draw_enemy(enemy)
	if not boss.is_empty():
		_draw_boss()
	for particle in particles:
		draw_circle(particle.position, particle.radius, particle.color)
	if mode == "lobby":
		_draw_character(Vector2(W/2.0, H/2.0+20.0), Vector2(95.0, 118.0), 0)
	else:
		_draw_player()


func _draw_paper() -> void:
	draw_texture_rect(PAPER_BACKGROUND, Rect2(0.0, 0.0, W, H), false)
	var tint := Color.WHITE
	match STAGE_IDS[stage_index]:
		"1-2": tint = Color(0.85, 0.95, 0.89, 0.20)
		"1-3": tint = Color(0.88, 0.87, 0.83, 0.20)
		"1-4": tint = Color(0.95, 0.88, 0.77, 0.20)
		"1-5": tint = Color(0.95, 0.78, 0.70, 0.23)
		"2-1": tint = Color(0.78, 0.85, 0.96, 0.22)
	if tint != Color.WHITE:
		draw_rect(Rect2(0.0, 0.0, W, H), tint)


func _character_region(index: int) -> Rect2:
	return Rect2(float(index % 3) * CHARACTER_CELL, float(floori(float(index) / 3.0)) * CHARACTER_CELL, CHARACTER_CELL, CHARACTER_CELL)


func _draw_character(position: Vector2, size: Vector2, index: int, tint: Color = Color.WHITE, direction: float = 1.0) -> void:
	var horizontal_flip := -1.0 if direction < 0.0 else 1.0
	draw_set_transform(position, 0.0, Vector2(horizontal_flip, 1.0))
	draw_texture_rect_region(CHARACTER_ATLAS, Rect2(-size * 0.5, size), _character_region(index), tint, false, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_item(position: Vector2, size: Vector2, index: int, direction: float = 1.0) -> void:
	var region := Rect2(float(index % 4) * ITEM_CELL, float(floori(float(index) / 4.0)) * ITEM_CELL, ITEM_CELL, ITEM_CELL)
	var horizontal_flip := -1.0 if direction < 0.0 else 1.0
	draw_set_transform(position, 0.0, Vector2(horizontal_flip, 1.0))
	draw_texture_rect_region(ITEM_ATLAS, Rect2(-size * 0.5, size), region, Color.WHITE, false, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_stick(position: Vector2, scale: float, color: Color) -> void:
	var p := position
	draw_arc(p+Vector2(0,-22*scale),7*scale,0.0,TAU,24,color,4.0*scale,true)
	draw_line(p+Vector2(0,-14*scale),p+Vector2(0,9*scale),color,4.0*scale,true)
	draw_line(p+Vector2(0,-7*scale),p+Vector2(-11*scale,-1),color,4.0*scale,true)
	draw_line(p+Vector2(0,-7*scale),p+Vector2(10*scale,1),color,4.0*scale,true)
	draw_line(p+Vector2(0,9*scale),p+Vector2(-9*scale,23*scale),color,4.0*scale,true)
	draw_line(p+Vector2(0,9*scale),p+Vector2(10*scale,23*scale),color,4.0*scale,true)


func _draw_player() -> void:
	var tint := Color("d99582") if invulnerability > 0.0 and int(elapsed*20.0)%2 == 0 else Color.WHITE
	if player_anim_time > 0.0 and player_anim_row >= 0:
		var progress := 1.0 - player_anim_time / player_anim_duration
		var frame := clampi(floori(progress * 4.0), 0, 3)
		var frame_size := WEAPON_ACTION_FRAME_SIZE if player_anim_uses_weapon_atlas else ACTION_FRAME_SIZE
		var source := Rect2(float(frame) * frame_size.x, float(player_anim_row) * frame_size.y, frame_size.x, frame_size.y)
		var animation_atlas := WEAPON_ACTION_ATLAS if player_anim_uses_weapon_atlas else ACTION_ATLAS
		var horizontal_flip := -1.0 if facing < 0.0 else 1.0
		draw_set_transform(player_position, 0.0, Vector2(horizontal_flip, 1.0))
		draw_texture_rect_region(animation_atlas, Rect2(Vector2(-52.0, -42.0), Vector2(104.0, 84.0)), source, tint, false, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_character(player_position, Vector2(64.0, 72.0), 0, tint, facing)
	if dash_timer > 0.0:
		draw_line(dash_origin, player_position, Color(0.30, 0.71, 0.68, 0.65), 7.0, true)
	_draw_item(player_position + Vector2(facing * 25.0, -17.0), Vector2(24.0, 24.0), _weapon_icon_index(selected_weapon), facing)
	if slash_timer > 0.0:
		draw_arc(player_position+Vector2(facing*12.0,-8.0),38.0,-0.8,0.8,24,Color("36312b"),5.0)
	var orbit_count := int(upgrades.get("spin", 0)) + (2 if selected_weapon == "orbit_line" else 0)
	if orbit_count > 0:
		for index in orbit_count:
			var angle := elapsed*3.0+float(index)*TAU/float(orbit_count)
			draw_line(player_position+Vector2(cos(angle),sin(angle))*35.0,player_position+Vector2(cos(angle),sin(angle))*48.0,Color("494239"),4.0,true)


func _draw_scarf(position: Vector2, scale: float, direction: float) -> void:
	var neck := position + Vector2(0.0, -8.0 * scale)
	draw_line(neck + Vector2(-5.0 * scale, 0.0), neck + Vector2(5.0 * scale, 0.0), Color("bb4b3e"), 5.0 * scale, true)
	draw_line(neck + Vector2(-4.0 * scale, 1.0 * scale), neck + Vector2(-17.0 * scale * direction, 8.0 * scale), Color("bb4b3e"), 4.0 * scale, true)
	draw_line(neck + Vector2(0.0, 2.0 * scale), neck + Vector2(-12.0 * scale * direction, 10.0 * scale), Color("d06a50"), 2.0 * scale, true)


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
	var enemy_direction := 1.0 if player_position.x >= enemy.position.x else -1.0
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
	var position: Vector2 = boss.position
	if boss.warning > 0.0:
		if boss.phase == 1:
			draw_line(Vector2(30,boss.aim_y),Vector2(W-30,boss.aim_y),Color(0.76,0.25,0.21,0.62),18.0,true)
		else:
			draw_arc(player_position,53.0,0.0,TAU,36,Color(0.76,0.25,0.21,0.62),5.0)
	var boss_tint := Color("e99a85") if float(boss.get("flash", 0.0)) > 0.0 else Color.WHITE
	var recoil := (position - player_position).normalized() * 7.0 if float(boss.get("hit_time", 0.0)) > 0.0 else Vector2.ZERO
	var boss_direction := 1.0 if player_position.x >= position.x else -1.0
	_draw_character(position + recoil, Vector2(126.0, 142.0), 5, boss_tint, boss_direction)

