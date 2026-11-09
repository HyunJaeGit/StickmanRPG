extends Control
class_name LobbyView
## 로비 홈 화면을 그리고, 출전·메뉴·단계 선택 요청을 신호로 전달합니다.

signal start_requested
signal menu_requested(section: String)
signal stage_requested(index: int)

const GAME_DATA = preload("res://scripts/game_data.gd")
const ITEM_ATLAS: Texture2D = preload("res://art/weapon_items_atlas.png")
const ITEM_CELL := 362.0

var title_label: Label
var currency_label: Label
var portrait: TextureRect
var weapon_label: Label
var weapon_description: Label
var stat_values: Dictionary = {}
var stage_label: Label
var stage_buttons: Array[Button] = []
var status_label: Label
var enter_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_view()
	hide()


func show_home(state: Dictionary) -> void:
	_update_view(state)
	show()


func update_home(state: Dictionary) -> void:
	_update_view(state)


func _build_view() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.04, 0.03, 0.73)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(840.0, 450.0)
	var panel_style := _surface(Color("f2e6cf"), Color("b8a27f"))
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	panel.add_child(frame)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 42.0
	header.add_theme_constant_override("separation", 12)
	frame.add_child(header)
	title_label = Label.new()
	title_label.text = "STICKMAN RPG  /  모험의 거점"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("3a342d"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	currency_label = Label.new()
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	currency_label.custom_minimum_size = Vector2(350.0, 36.0)
	currency_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	currency_label.add_theme_font_size_override("font_size", 14)
	currency_label.add_theme_color_override("font_color", Color("766650"))
	header.add_child(currency_label)
	frame.add_child(HSeparator.new())
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(main)
	var showcase := VBoxContainer.new()
	showcase.custom_minimum_size.x = 240.0
	showcase.alignment = BoxContainer.ALIGNMENT_CENTER
	showcase.add_theme_constant_override("separation", 3)
	main.add_child(showcase)
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(220.0, 100.0)
	portrait_panel.add_theme_stylebox_override("panel", _flat_style(Color("e8dcc7")))
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_panel.add_child(portrait)
	showcase.add_child(portrait_panel)
	weapon_label = Label.new()
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", 19)
	showcase.add_child(weapon_label)
	weapon_description = Label.new()
	weapon_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_description.add_theme_font_size_override("font_size", 14)
	showcase.add_child(weapon_description)
	var stats_card := _card(showcase, Color("f7efdf"), Color("c7b58d"))
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
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		stats_grid.add_child(cell)
		var stat_title := Label.new()
		stat_title.text = str(stat.title)
		stat_title.add_theme_font_size_override("font_size", 12)
		stat_title.add_theme_color_override("font_color", Color("766f63"))
		cell.add_child(stat_title)
		var stat_value := Label.new()
		stat_value.add_theme_font_size_override("font_size", 14)
		stat_value.add_theme_color_override("font_color", Color("3a342d"))
		cell.add_child(stat_value)
		stat_values[str(stat.id)] = stat_value
	var center_column := VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 5)
	main.add_child(center_column)
	stage_label = Label.new()
	stage_label.add_theme_font_size_override("font_size", 22)
	center_column.add_child(stage_label)
	var route_title := Label.new()
	route_title.text = "CHAPTER 1   ·   먹물 숲의 경로"
	route_title.add_theme_color_override("font_color", Color("766650"))
	center_column.add_child(route_title)
	var route := HBoxContainer.new()
	route.add_theme_constant_override("separation", 4)
	center_column.add_child(route)
	for index in GAME_DATA.STAGE_IDS.size():
		var stage_button := Button.new()
		stage_button.custom_minimum_size = Vector2(82.0, 48.0)
		stage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage_button.pressed.connect(_emit_stage_request.bind(index))
		route.add_child(stage_button)
		stage_buttons.append(stage_button)
	status_label = Label.new()
	status_label.custom_minimum_size.y = 38.0
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("8b5947"))
	center_column.add_child(status_label)
	enter_button = Button.new()
	enter_button.custom_minimum_size.y = 58.0
	enter_button.add_theme_font_size_override("font_size", 22)
	enter_button.pressed.connect(func(): start_requested.emit())
	center_column.add_child(enter_button)
	var nav := HBoxContainer.new()
	nav.custom_minimum_size.y = 50.0
	nav.add_theme_constant_override("separation", 10)
	frame.add_child(nav)
	for option in [{"text":"⚔  무기고", "id":"armory"}, {"text":"▣  무기 뽑기", "id":"chest"}, {"text":"✦ 스킬", "id":"skills"}, {"text":"⚙ 설정", "id":"settings"}]:
		var button := Button.new()
		button.text = str(option.text)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 50.0
		if str(option.id) == "settings":
			button.custom_minimum_size.x = 110.0
			button.size_flags_horizontal = Control.SIZE_SHRINK_END
		if str(option.id) == "chest":
			button.icon = _item_icon(11)
			button.add_theme_constant_override("icon_max_width", 38)
		button.pressed.connect(_emit_menu_request.bind(str(option.id)))
		nav.add_child(button)


func _update_view(state: Dictionary) -> void:
	currency_label.text = "골드 %d  ·  무기 조각 %d  ·  마력 조각 %d" % [int(state.gold), int(state.weapon_shards), int(state.magic_shards)]
	stage_label.text = "현재 출전 단계   %s" % str(state.stage_id)
	enter_button.text = "%s  출전하기" % str(state.stage_id)
	weapon_label.text = "장착 무기  ·  %s" % str(state.weapon_name)
	weapon_description.text = str(state.weapon_description)
	portrait.texture = state.portrait
	status_label.text = str(state.message)
	var stats: Dictionary = state.stats
	for key in stat_values:
		stat_values[key].text = str(stats.get(key, "—"))
	var stages: Array = state.stage_ids
	var cleared: Array = state.cleared_stages
	var stage_index := int(state.stage_index)
	var furthest_index := int(state.furthest_stage_index)
	for index in stage_buttons.size():
		var stage_id := str(stages[index])
		var is_cleared := cleared.has(stage_id)
		var is_current := index == stage_index
		var unlocked := index <= furthest_index or is_current
		var stage_button := stage_buttons[index]
		stage_button.text = ("✓ " if is_cleared else "◆ " if is_current else "○ ") + stage_id if unlocked else "🔒 " + stage_id
		stage_button.disabled = not unlocked
		stage_button.remove_theme_color_override("font_color")
		if is_current:
			stage_button.add_theme_color_override("font_color", Color("a74235"))


func _emit_stage_request(index: int) -> void:
	stage_requested.emit(index)


func _emit_menu_request(section: String) -> void:
	menu_requested.emit(section)


func _surface(color: Color, edge: Color) -> StyleBoxFlat:
	var style := _flat_style(color)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = edge
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _card(parent: Control, color: Color, edge: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _surface(color, edge))
	parent.add_child(card)
	return card


func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _item_icon(index: int) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = ITEM_ATLAS
	icon.region = Rect2(float(index % 4) * ITEM_CELL, float(floori(float(index) / 4.0)) * ITEM_CELL, ITEM_CELL, ITEM_CELL)
	return icon
