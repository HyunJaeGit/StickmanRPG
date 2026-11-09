extends Control
class_name TitleScreen
## 최초 진입과 타이틀 복귀 때 이어하기·새 게임 메뉴를 표시합니다.

signal continue_requested
signal new_game_requested
signal settings_requested
signal exit_requested


var continue_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_screen()
	hide()


func show_screen(has_save: bool) -> void:
	continue_button.disabled = not has_save
	continue_button.text = "이어하기" if has_save else "이어하기  ·  저장 데이터 없음"
	show()


func _build_screen() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.07, 0.08, 0.09, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470.0, 430.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("26373e")
	panel_style.border_color = Color("c9a766")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 34.0
	panel_style.content_margin_right = 34.0
	panel_style.content_margin_top = 28.0
	panel_style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var eyebrow := Label.new()
	eyebrow.text = "INKBOUND  ·  SOLO ACTION RPG"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("c9a766"))
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "STICKMAN RPG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f3e9d4"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "스케치 세계의 모험을 이어가세요"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("d8c8a9"))
	subtitle.custom_minimum_size.y = 36.0
	content.add_child(subtitle)
	var divider := HSeparator.new()
	content.add_child(divider)
	continue_button = _add_menu_button(content, "이어하기", continue_requested.emit)
	_add_menu_button(content, "새 게임", new_game_requested.emit)
	_add_menu_button(content, "설정", settings_requested.emit)
	_add_menu_button(content, "게임 종료", exit_requested.emit)
	var save_note := Label.new()
	save_note.text = "진행 상황은 자동 저장됩니다."
	save_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_note.add_theme_font_size_override("font_size", 13)
	save_note.add_theme_color_override("font_color", Color("b8ad9b"))
	content.add_child(save_note)


func _add_menu_button(parent: VBoxContainer, button_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(390.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
