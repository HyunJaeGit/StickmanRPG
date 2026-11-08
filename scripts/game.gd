extends Node2D
## 스틱맨 RPG 전투와 골드·무기 성장 메타 진행을 관리합니다.

const W := 960.0
const H := 540.0
const STAGE_IDS := ["1-1", "1-2", "1-3", "1-4", "1-5", "2-1"]
const STAGE_LENGTHS := {"1-1":90.0, "1-2":90.0, "1-3":90.0, "1-4":90.0, "1-5":60.0, "2-1":90.0}
const BOSS_STAGES := ["1-5"]
const GACHA_COST := 5
const SKILL_GACHA_COST := 3
const MAGIC_SHARD_DROP_CHANCE := 0.04
const MAX_ENHANCEMENT := 20
const RARITY_NAMES := ["일반", "고급", "레어", "유니크", "전설"]
const RARITY_DAMAGE := [1.0, 1.1, 1.22, 1.38, 1.58]
const RARITY_CHANCES := [60, 25, 10, 4, 1]
const RENDERER_SCENE: PackedScene = preload("res://scenes/game_renderer.tscn")
const REWARD_PRESENTATION_SCENE: PackedScene = preload("res://scenes/reward_presentation.tscn")
const CHARACTER_ATLAS: Texture2D = preload("res://art/stickman_characters_atlas.png")
const ITEM_ATLAS: Texture2D = preload("res://art/weapon_items_atlas.png")
const MAGIC_SKILL_ATLAS: Texture2D = preload("res://art/magic_skill_icons.png")
const CHARACTER_CELL := 512.0
const ITEM_CELL := 362.0
const MAGIC_SKILL_CELL := Vector2(2172.0 / 5.0, 434.0)
const MAGIC_SKILL_REGION_Y := 145.0
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
const SKILLS := [
	{"id":"ink_wave", "name":"잉크 파동", "role":"범위기", "description":"예정 효과: 반경 140 안에 공격력 120% 피해.", "icon":0, "cooldown":18.0, "radius":140.0, "damage_ratio":1.2},
	{"id":"compass_pierce", "name":"컴퍼스 관통", "role":"단일기", "description":"예정 효과: 가장 가까운 적 하나에 공격력 300% 피해.", "icon":1, "cooldown":14.0, "damage_ratio":3.0},
	{"id":"lifeline", "name":"생명선", "role":"체력 회복", "description":"예정 효과: 최대 체력의 30% 회복.", "icon":2, "cooldown":40.0, "heal_ratio":0.3},
	{"id":"final_ink", "name":"종말의 획", "role":"극딜기", "description":"예정 효과: 1초 집중 후 한 대상에 공격력 700% 피해.", "icon":3, "cooldown":60.0, "charge_time":1.0, "damage_ratio":7.0}
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
var magic_shards := 0
var skills_owned: Array[String] = []
var equipped_skill_slots: Array[String] = ["", "", "", ""]
var selected_weapon := "pencil_sword"
var selected_weapon_uid := 1
var next_weapon_uid := 1
var weapon_inventory: Array[Dictionary] = []
var cleared_stages: Array[String] = []
var last_lobby_message := "스케치 세계에 오신 것을 환영합니다."
var elapsed := 0.0
var kills := 0
var spawn_timer := 0.0
var elite_at := 35.0
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
	lobby_section = "home"
	skill_hud.visible = false
	get_tree().paused = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.color = Color(0.05, 0.04, 0.03, 0.73)
	overlay_panel.add_theme_stylebox_override("panel", _flat_style(Color("f2e6cf")))
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
	armory.pressed.connect(func(): _open_lobby_window("armory"))
	nav.add_child(armory)
	var chest := Button.new()
	chest.text = "▣  무기 뽑기  ·  %d 조각" % weapon_shards
	chest.icon = _item_icon(11)
	chest.add_theme_constant_override("icon_max_width", 38)
	chest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest.custom_minimum_size.y = 42
	chest.pressed.connect(func(): _open_lobby_window("chest"))
	nav.add_child(chest)
	lobby_gacha_button = chest
	var skills_button := Button.new()
	skills_button.text = "✦ 스킬"
	skills_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_button.custom_minimum_size.y = 42
	skills_button.pressed.connect(func(): _open_lobby_window("skills"))
	nav.add_child(skills_button)
	var settings := Button.new()
	settings.text = "⚙ 설정"
	settings.custom_minimum_size.y = 42
	settings.pressed.connect(func(): _open_lobby_window("settings"))
	nav.add_child(settings)
	_update_skill_hud()
	_update_lobby()
	overlay.show()


func _update_lobby() -> void:
	if lobby_status == null:
		return
	lobby_status.text = "골드 ◈ %d   무기 조각 ◆ %d   마력 조각 ✦ %d" % [gold, weapon_shards, magic_shards]
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
	if lobby_section != "home" and overlay.visible:
		_open_lobby_window(lobby_section)


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


func _open_lobby_window(section: String) -> void:
	lobby_section = section
	for child in overlay_panel.get_children():
		overlay_panel.remove_child(child)
		child.queue_free()
	overlay_panel.custom_minimum_size = Vector2(760.0, 430.0)
	overlay_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	overlay_panel.add_child(frame)
	var top := HBoxContainer.new()
	frame.add_child(top)
	var heading := Label.new()
	heading.text = {"armory":"무기고", "chest":"무기 뽑기", "skills":"스킬 보관함", "settings":"설정", "help":"도움말"}.get(section, "메뉴")
	heading.add_theme_font_size_override("font_size", 24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close := Button.new()
	close.text = "닫기  ×"
	close.custom_minimum_size = Vector2(82.0, 38.0)
	close.pressed.connect(_close_lobby_window)
	top.add_child(close)
	var divider := HSeparator.new()
	frame.add_child(divider)
	lobby_modal_body = VBoxContainer.new()
	lobby_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_modal_body.add_theme_constant_override("separation", 8)
	frame.add_child(lobby_modal_body)
	lobby_section = section
	var content := _build_lobby_section()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_modal_body.add_child(content)
	overlay.show()


func _close_lobby_window() -> void:
	lobby_section = "home"
	lobby_modal_body = null
	overlay_panel.custom_minimum_size = Vector2(850.0, 470.0)
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
			var heading := Label.new()
			heading.text = "무기고  ·  보유 %d개  ·  선택 %s" % [weapon_inventory.size(), RARITY_NAMES[int(_equipped_item().get("rarity", 0))]]
			body.add_child(heading)
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size.y = 150
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
		"skills":
			var heading := Label.new()
			heading.text = "스킬 보관함  ·  보유 %d / %d  ·  마력 조각 %d  ·  시전 기능 준비 중" % [skills_owned.size(), SKILLS.size(), magic_shards]
			body.add_child(heading)
			var draw_skill := Button.new()
			draw_skill.text = "스킬 뽑기  ·  마력 조각 %d개" % SKILL_GACHA_COST if skills_owned.size() < SKILLS.size() else "모든 스킬을 획득했습니다"
			draw_skill.icon = _skill_icon("magic_shard")
			draw_skill.add_theme_constant_override("icon_max_width", 30)
			draw_skill.disabled = skills_owned.size() >= SKILLS.size() or magic_shards < SKILL_GACHA_COST
			draw_skill.pressed.connect(_draw_skill)
			body.add_child(draw_skill)
			var slots_label := Label.new()
			var equipped_names := PackedStringArray()
			for index in 4:
				var skill_name := _skill_name(equipped_skill_slots[index]) if not equipped_skill_slots[index].is_empty() else "빈 슬롯"
				equipped_names.append("%s %s" % [["Q", "W", "E", "R"][index], skill_name])
			slots_label.text = "장착 슬롯  ·  " + "   /   ".join(equipped_names)
			body.add_child(slots_label)
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size.y = 135
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			body.add_child(scroll)
			var skill_list := VBoxContainer.new()
			skill_list.add_theme_constant_override("separation", 3)
			scroll.add_child(skill_list)
			for skill in SKILLS:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 5)
				var icon_view := TextureRect.new()
				icon_view.texture = _skill_icon(str(skill.id))
				icon_view.custom_minimum_size = Vector2(38.0, 38.0)
				icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_view.modulate = Color.WHITE if skills_owned.has(str(skill.id)) else Color(0.55, 0.53, 0.48, 0.7)
				row.add_child(icon_view)
				var skill_info := Label.new()
				skill_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				skill_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				skill_info.text = "%s · %s%s\n%s" % [skill.name, skill.role, "  (미보유)" if not skills_owned.has(str(skill.id)) else "", skill.description]
				row.add_child(skill_info)
				for slot_index in 4:
					var equip_button := Button.new()
					equip_button.text = ["Q", "W", "E", "R"][slot_index]
					equip_button.custom_minimum_size = Vector2(36.0, 32.0)
					equip_button.disabled = not skills_owned.has(str(skill.id))
					if equipped_skill_slots[slot_index] == str(skill.id):
						equip_button.text = "✓" + equip_button.text
					equip_button.pressed.connect(_equip_skill_to_slot.bind(str(skill.id), slot_index))
					row.add_child(equip_button)
				skill_list.add_child(row)
		"settings":
			var audio_heading := Label.new()
			audio_heading.text = "소리"
			audio_heading.add_theme_font_size_override("font_size", 18)
			body.add_child(audio_heading)
			var volume_row := HBoxContainer.new()
			volume_row.add_theme_constant_override("separation", 12)
			body.add_child(volume_row)
			var volume_title := Label.new()
			volume_title.text = "전체 음량"
			volume_title.custom_minimum_size.x = 100.0
			volume_row.add_child(volume_title)
			var volume_slider := HSlider.new()
			volume_slider.min_value = 0.0
			volume_slider.max_value = 100.0
			volume_slider.step = 1.0
			volume_slider.value = master_volume_percent
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
			display_heading.add_theme_font_size_override("font_size", 18)
			body.add_child(display_heading)
			var fullscreen := CheckButton.new()
			fullscreen.text = "전체화면 사용"
			fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			fullscreen.toggled.connect(_set_fullscreen)
			body.add_child(fullscreen)
			var help_button := Button.new()
			help_button.text = "도움말 보기"
			help_button.custom_minimum_size.y = 42.0
			help_button.pressed.connect(func(): _open_lobby_window("help"))
			body.add_child(help_button)
			var exit_button := Button.new()
			exit_button.text = "게임 종료"
			exit_button.custom_minimum_size.y = 42.0
			exit_button.pressed.connect(_confirm_exit_game)
			body.add_child(exit_button)
		"help":
			var controls := Label.new()
			controls.text = "조작 방법"
			controls.add_theme_font_size_override("font_size", 19)
			body.add_child(controls)
			var help_text := Label.new()
			help_text.text = "이동  ·  WASD 또는 방향키\n대시  ·  Space\n공격  ·  자동 공격\n스킬 슬롯  ·  Q / W / E / R (현재는 장착 및 슬롯 표시만 지원)\n일시 정지  ·  Esc\n\n스테이지를 클리어하거나 적을 처치해 골드와 조각을 모으세요. 로비에서 무기를 강화하고, 스킬을 뽑아 슬롯에 장착할 수 있습니다."
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
	for index in WEAPONS.size():
		if str(WEAPONS[index].id) == weapon_id:
			return index
	return 0


func _item_icon(index: int) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = ITEM_ATLAS
	icon.region = Rect2(float(index % 4) * ITEM_CELL, float(floori(float(index) / 4.0)) * ITEM_CELL, ITEM_CELL, ITEM_CELL)
	return icon


func _skill_icon(skill_id: String) -> AtlasTexture:
	var icon_index := 4
	for skill in SKILLS:
		if str(skill.id) == skill_id:
			icon_index = int(skill.icon)
			break
	var icon := AtlasTexture.new()
	icon.atlas = MAGIC_SKILL_ATLAS
	icon.region = Rect2(float(icon_index) * MAGIC_SKILL_CELL.x, MAGIC_SKILL_REGION_Y, MAGIC_SKILL_CELL.x, MAGIC_SKILL_CELL.y)
	return icon


func _skill_name(skill_id: String) -> String:
	for skill in SKILLS:
		if str(skill.id) == skill_id:
			return str(skill.name)
	return "미장착"


func _update_skill_hud() -> void:
	if skill_slot_icons.size() != 4:
		return
	for index in 4:
		var skill_id := equipped_skill_slots[index]
		var has_skill := not skill_id.is_empty() and skills_owned.has(skill_id)
		skill_slot_icons[index].texture = _skill_icon(skill_id) if has_skill else null
		skill_slot_labels[index].text = _skill_name(skill_id) if has_skill else "빈 슬롯"


func _equip_skill_to_slot(skill_id: String, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= equipped_skill_slots.size() or not skills_owned.has(skill_id):
		return
	for index in equipped_skill_slots.size():
		if equipped_skill_slots[index] == skill_id:
			equipped_skill_slots[index] = ""
	equipped_skill_slots[slot_index] = skill_id
	_save_progress()
	_update_skill_hud()
	_refresh_lobby_window()


func _equipped_item_index() -> int:
	for index in weapon_inventory.size():
		if int(weapon_inventory[index].get("uid", -1)) == selected_weapon_uid:
			return index
	return -1


func _equipped_item() -> Dictionary:
	var index := _equipped_item_index()
	return weapon_inventory[index] if index >= 0 else {}


func _equip_weapon_uid(uid: int) -> void:
	for item in weapon_inventory:
		if int(item.get("uid", -1)) == uid:
			selected_weapon_uid = uid
			selected_weapon = str(item.get("weapon_id", "pencil_sword"))
			last_lobby_message = "%s %s 무기를 장착했습니다." % [RARITY_NAMES[int(item.get("rarity", 0))], _weapon_name(selected_weapon)]
			_save_progress()
			_refresh_lobby_window()
			return


func _refresh_lobby_window() -> void:
	_update_lobby()


func _enhancement_cost(item: Dictionary) -> int:
	var level_value := int(item.get("enhancement", 0))
	var rarity := int(item.get("rarity", 0))
	return 50 * (level_value + 1) * (level_value + 1) * (rarity + 1)


func _potential_reset_cost(item: Dictionary) -> int:
	return 100 * (int(item.get("rarity", 0)) + 1)


func _potential_summary(item: Dictionary) -> String:
	var lines: PackedStringArray = []
	for potential in item.get("potentials", []):
		lines.append("%s +%d%%" % [_potential_name(str(potential.get("id", "attack"))), int(potential.get("value", 0))])
	return "잠재능력  ·  " + "  /  ".join(lines)


func _potential_name(id: String) -> String:
	for potential in POTENTIALS:
		if str(potential.id) == id:
			return str(potential.name)
	return id


func _roll_potentials() -> Array[Dictionary]:
	var pool: Array = POTENTIALS.duplicate(true)
	pool.shuffle()
	var result: Array[Dictionary] = []
	for index in 3:
		var option: Dictionary = pool[index]
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
	if weapon_shards < GACHA_COST:
		last_lobby_message = "무기 조각이 부족합니다. 적 처치나 보스 첫 클리어로 모으세요."
		_update_lobby()
		return
	weapon_shards -= GACHA_COST
	var roll := rng.randi_range(1, 100)
	var rarity := 0
	var boundary := 0
	for index in RARITY_CHANCES.size():
		boundary += int(RARITY_CHANCES[index])
		if roll <= boundary:
			rarity = index
			break
	var weapon_id: String = str(WEAPONS[rng.randi_range(0, WEAPONS.size() - 1)].id)
	var obtained := _make_weapon_record(weapon_id, rarity)
	weapon_inventory.append(obtained)
	selected_weapon_uid = int(obtained.uid)
	selected_weapon = weapon_id
	last_lobby_message = "%s 등급 무기 획득: %s" % [RARITY_NAMES[rarity], _weapon_name(weapon_id)]
	_save_progress()
	var previews: Array[Dictionary] = []
	for weapon in WEAPONS:
		var preview_rarity := rng.randi_range(0, RARITY_NAMES.size() - 1)
		previews.append({"icon":_item_icon(_weapon_icon_index(str(weapon.id))), "label":"%s · %s" % [RARITY_NAMES[preview_rarity], weapon.name]})
	var accent: Color = [Color("928673"), Color("62a68a"), Color("4e88c6"), Color("a46bd1"), Color("e2a73e")][rarity]
	await reward_presentation.reveal_gacha(previews, _item_icon(_weapon_icon_index(weapon_id)), "%s 등급 · %s" % [RARITY_NAMES[rarity], _weapon_name(weapon_id)], "", accent)


func _draw_skill() -> void:
	if magic_shards < SKILL_GACHA_COST or skills_owned.size() >= SKILLS.size():
		return
	var unowned: Array[Dictionary] = []
	for skill in SKILLS:
		if not skills_owned.has(str(skill.id)):
			unowned.append(skill)
	if unowned.is_empty():
		return
	var result: Dictionary = unowned[rng.randi_range(0, unowned.size() - 1)]
	magic_shards -= SKILL_GACHA_COST
	skills_owned.append(str(result.id))
	last_lobby_message = "새 스킬 획득: %s · 스킬 탭에서 QWER 슬롯에 장착할 수 있습니다." % result.name
	_save_progress()
	var previews: Array[Dictionary] = []
	for skill in SKILLS:
		if not skills_owned.has(str(skill.id)) or str(skill.id) == str(result.id):
			previews.append({"icon":_skill_icon(str(skill.id)), "label":str(skill.name)})
	await reward_presentation.reveal_gacha(previews, _skill_icon(str(result.id)), str(result.name), "%s\n현재는 로비 장착과 슬롯 표시만 지원합니다." % result.description, Color("63b8a0"))


func _enhance_equipped_weapon() -> void:
	var index := _equipped_item_index()
	if index < 0:
		return
	var item: Dictionary = weapon_inventory[index]
	var level_value := int(item.get("enhancement", 0))
	var cost := _enhancement_cost(item)
	if level_value >= MAX_ENHANCEMENT or gold < cost:
		return
	var weapon_uid := int(item.uid)
	var next_level := level_value + 1
	await reward_presentation.animate_enhancement(_item_icon(_weapon_icon_index(selected_weapon)), _weapon_name(selected_weapon), level_value, next_level)
	index = -1
	for item_index in weapon_inventory.size():
		if int(weapon_inventory[item_index].get("uid", -1)) == weapon_uid:
			index = item_index
			break
	if index < 0 or gold < cost:
		show_lobby()
		return
	item = weapon_inventory[index]
	gold -= cost
	item.enhancement = next_level
	weapon_inventory[index] = item
	last_lobby_message = "%s 무기 +%d 강화 성공" % [_weapon_name(selected_weapon), next_level]
	_save_progress()
	reward_presentation.show_result("강화 성공!  +%d" % next_level, "%s 무기의 공격력이 상승했습니다." % _weapon_name(selected_weapon), _item_icon(_weapon_icon_index(selected_weapon)), Color("d99a48"))


func _reset_equipped_potentials() -> void:
	var index := _equipped_item_index()
	if index < 0:
		return
	var item: Dictionary = weapon_inventory[index]
	var cost := _potential_reset_cost(item)
	if gold < cost:
		return
	var weapon_uid := int(item.uid)
	var accepted: bool = await reward_presentation.confirm_potential_reset(_potential_summary(item), cost, _item_icon(_weapon_icon_index(selected_weapon)))
	if not accepted:
		_refresh_lobby_window()
		return
	var preview_lines: Array[String] = []
	for spin in 9:
		preview_lines.append(_potential_summary({"potentials":_roll_potentials()}))
	await reward_presentation.animate_potential_roll(_item_icon(_weapon_icon_index(selected_weapon)), preview_lines)
	var new_potentials := _roll_potentials()
	index = -1
	for item_index in weapon_inventory.size():
		if int(weapon_inventory[item_index].get("uid", -1)) == weapon_uid:
			index = item_index
			break
	if index < 0 or gold < cost:
		show_lobby()
		return
	item = weapon_inventory[index]
	gold -= cost
	item.potentials = new_potentials
	weapon_inventory[index] = item
	last_lobby_message = "%s 무기의 잠재능력 3줄을 다시 설정했습니다." % _weapon_name(selected_weapon)
	_save_progress()
	reward_presentation.show_result("새 잠재능력이 적용됐습니다", _potential_summary(item), _item_icon(_weapon_icon_index(selected_weapon)), Color("8b73bd"))


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
	last_lobby_message = "%s 무기 2개를 합성해 %s 등급 %s를 만들었습니다." % [RARITY_NAMES[rarity], RARITY_NAMES[rarity + 1], _weapon_name(weapon_id)]
	_save_progress()
	_update_lobby()


func _remove_weapon_uid(uid: int) -> void:
	for index in range(weapon_inventory.size() - 1, -1, -1):
		if int(weapon_inventory[index].get("uid", -1)) == uid:
			weapon_inventory.remove_at(index)
			return


func _weapon_name(weapon_id: String) -> String:
	for weapon in WEAPONS:
		if weapon.id == weapon_id:
			return weapon.name
	return "연필검"


func start_run() -> void:
	_reset_run()
	mode = "playing"
	skill_hud.visible = true
	get_tree().paused = false
	overlay.hide()
	last_lobby_message = "%s에 출전했습니다." % STAGE_IDS[stage_index]
	_update_hud()


func _reset_run() -> void:
	elapsed = 0.0
	kills = 0
	spawn_timer = 0.0
	elite_at = 35.0
	attack_timer = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	invulnerability = 0.0
	slash_timer = 0.0
	player_anim_row = -1
	player_anim_time = 0.0
	player_position = Vector2(W / 2.0, H / 2.0)
	var item := _equipped_item()
	var rarity := clampi(int(item.get("rarity", 0)), 0, RARITY_DAMAGE.size() - 1)
	var attack_bonus := _potential_total(item, "attack")
	var speed_bonus := _potential_total(item, "attack_speed")
	player_max_hp = 100.0 * (1.0 + _potential_total(item, "max_health") / 100.0)
	player_hp = player_max_hp
	player_speed = 190.0 * (1.0 + _potential_total(item, "move_speed") / 100.0)
	player_damage = 25.0 * float(RARITY_DAMAGE[rarity]) * pow(1.1, float(item.get("enhancement", 0))) * (1.0 + attack_bonus / 100.0)
	attack_rate = 0.72 * 100.0 / (100.0 + speed_bonus)
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
	var saved_selected := "pencil_sword"
	if has_save:
		stage_index = clampi(int(saved_progress.get("stage_index", 0)), 0, STAGE_IDS.size() - 1)
		furthest_stage_index = clampi(int(saved_progress.get("furthest_stage_index", 0)), 0, STAGE_IDS.size() - 1)
		gold = maxi(0, int(saved_progress.get("gold", saved_progress.get("ink_shards", 0))))
		weapon_shards = maxi(0, int(saved_progress.get("weapon_shards", 0)))
		magic_shards = maxi(0, int(saved_progress.get("magic_shards", 0)))
		var stored_skills: Variant = saved_progress.get("skills_owned", [])
		if stored_skills is Array:
			for skill_id in stored_skills:
				for skill in SKILLS:
					if str(skill.id) == str(skill_id) and not skills_owned.has(str(skill_id)):
						skills_owned.append(str(skill_id))
		var stored_slots: Variant = saved_progress.get("equipped_skill_slots", ["", "", "", ""])
		if stored_slots is Array:
			for index in mini(4, stored_slots.size()):
				var skill_id := str(stored_slots[index])
				if skills_owned.has(skill_id) and not equipped_skill_slots.has(skill_id):
					equipped_skill_slots[index] = skill_id
		saved_selected = str(saved_progress.get("selected_weapon", "pencil_sword"))
		var stored_inventory: Variant = saved_progress.get("weapon_inventory", [])
		if stored_inventory is Array:
			for raw_item in stored_inventory:
				if raw_item is Dictionary and WEAPONS.any(func(weapon): return str(weapon.id) == str(raw_item.get("weapon_id", ""))):
					var item: Dictionary = raw_item.duplicate(true)
					item["uid"] = int(item.get("uid", next_weapon_uid))
					item["rarity"] = clampi(int(item.get("rarity", 0)), 0, 4)
					item["enhancement"] = clampi(int(item.get("enhancement", 0)), 0, MAX_ENHANCEMENT)
					var saved_potentials: Variant = item.get("potentials", [])
					if not (saved_potentials is Array) or saved_potentials.size() != 3:
						item["potentials"] = _roll_potentials()
					weapon_inventory.append(item)
					next_weapon_uid = maxi(next_weapon_uid, int(item.uid) + 1)
		if weapon_inventory.is_empty():
			var legacy_weapons: Variant = saved_progress.get("unlocked_weapons", ["pencil_sword"])
			if legacy_weapons is Array:
				for weapon_id in legacy_weapons:
					if WEAPONS.any(func(weapon): return str(weapon.id) == str(weapon_id)):
						weapon_inventory.append(_make_weapon_record(str(weapon_id), 0))
		var saved_clears: Variant = saved_progress.get("cleared_stages", [])
		if saved_clears is Array:
			for stage_id in saved_clears:
				if STAGE_IDS.has(str(stage_id)) and not cleared_stages.has(str(stage_id)):
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


func _save_progress() -> void:
	var progress := {
		"stage_index":stage_index,
		"furthest_stage_index":furthest_stage_index,
		"gold":gold,
		"weapon_shards":weapon_shards,
		"magic_shards":magic_shards,
		"skills_owned":skills_owned,
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
			var amount := 2 if elapsed > 24.0 and rng.randf() < minf(0.68, 0.32 + elapsed / 260.0) else 1
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
			spawn_timer = maxf(0.34, 0.72 - elapsed / 240.0)
		if elapsed >= elite_at:
			_spawn_enemy("elite")
			elite_at += 42.0
	if BOSS_STAGES.has(stage_id) and elapsed >= float(STAGE_LENGTHS[stage_id]) and boss.is_empty():
		boss = {"position":Vector2(W/2.0, 90.0), "hp":1200.0, "max_hp":1200.0, "radius":35.0, "attack":2.2, "warning":0.0, "phase":0, "aim_y":0.0}
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
func _start_player_animation(row: int, duration: float, weapon_specific: bool = false) -> void:
	player_anim_row = row
	player_anim_duration = duration
	player_anim_time = duration
	player_anim_uses_weapon_atlas = weapon_specific


func _spawn_player_shot(kind: String, velocity: Vector2, position: Vector2, damage: float, lifetime: float) -> void:
	projectiles.append({"team":"player", "kind":kind, "position":position, "velocity":velocity, "life":lifetime, "damage":damage, "returning":false})


func _effective_damage() -> float:
	return player_damage


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
	var magic_chance := MAGIC_SHARD_DROP_CHANCE + (0.08 if enemy.kind == "elite" else 0.0)
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
	dash_cooldown = 2.5
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
		var clear_gold := (100 + stage_index * 40) if first_clear else (60 + stage_index * 25)
		var gold_bonus := _potential_total(_equipped_item(), "gold_gain")
		var clear_award := roundi(float(clear_gold) * (1.0 + gold_bonus / 100.0))
		gold += clear_award
		var reward_message := "%s 클리어 골드 %d" % [finished_stage, clear_award]
		if BOSS_STAGES.has(finished_stage):
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
		furthest_stage_index = maxi(furthest_stage_index, mini(stage_index + 1, STAGE_IDS.size() - 1))
		stage_index = maxi(furthest_stage_index, mini(stage_index + 1, STAGE_IDS.size() - 1))
		last_lobby_message = "%s · 다음 출전 %s" % [reward_message, STAGE_IDS[stage_index]]
	else:
		stage_index = maxi(0, stage_index - 1)
		last_lobby_message = "%s에서 쓰러졌습니다. 한 단계 후퇴해 %s부터 재도전합니다. 정산된 무기와 조각은 유지됩니다." % [finished_stage, STAGE_IDS[stage_index]]
	_save_progress()
	_reset_run()
	show_lobby()


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _update_hud() -> void:
	hud_label.text = "%s · %s +%d\n체력 %.0f / %.0f\n골드 %d · 무기 %d · 마력 %d\n처치 %d · %s" % [STAGE_IDS[stage_index], _weapon_name(selected_weapon), int(_equipped_item().get("enhancement", 0)), player_hp, player_max_hp, gold, weapon_shards, magic_shards, kills, _format_time(elapsed)]
	hp_bar.max_value = player_max_hp
	hp_bar.value = player_hp
	_update_skill_hud()
	if not boss.is_empty():
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp


func _burst(position: Vector2, color: Color, amount: int) -> void:
	for index in amount:
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(25.0, 130.0)
		particles.append({"position":position, "velocity":Vector2(cos(angle), sin(angle))*speed, "life":rng.randf_range(0.18, 0.5), "color":color, "radius":rng.randf_range(1.5, 4.0)})
