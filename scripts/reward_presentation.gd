extends CanvasLayer
class_name RewardPresentation
## 강화·잠재 재설정·뽑기의 화면 연출과 사용자 확인을 담당합니다.

signal closed
signal decision_made(confirmed: bool)
signal weapon_window_action(action: String)

var shade: ColorRect
var panel: PanelContainer
var rng := RandomNumberGenerator.new()
var enhancement_icon: TextureRect
var enhancement_progress: ProgressBar
var enhancement_status: Label
var enhancement_summary: Label
var enhancement_button: Button
var enhancement_close_button: Button
var cube_line_labels: Array[Label] = []
var cube_cost_label: Label
var cube_status: Label
var cube_roll_button: Button
var cube_stop_button: Button


func _ready() -> void:
	rng.randomize()
	var presentation_theme := Theme.new()
	presentation_theme.set_color("font_color", "Label", Color("f2e8d4"))
	presentation_theme.set_color("font_color", "Button", Color("f2e8d4"))
	presentation_theme.set_color("font_hover_color", "Button", Color("ffffff"))
	presentation_theme.set_color("font_pressed_color", "Button", Color("e3bd72"))
	presentation_theme.set_color("font_disabled_color", "Button", Color("8f918e"))
	var button_style := _flat_style(Color("344650"))
	button_style.set_border_width_all(1)
	button_style.border_color = Color("65767a")
	var button_hover := _flat_style(Color("405861"))
	button_hover.set_border_width_all(1)
	button_hover.border_color = Color("d2ad67")
	var button_pressed := _flat_style(Color("26363e"))
	button_pressed.set_border_width_all(1)
	button_pressed.border_color = Color("d2ad67")
	presentation_theme.set_stylebox("normal", "Button", button_style)
	presentation_theme.set_stylebox("hover", "Button", button_hover)
	presentation_theme.set_stylebox("pressed", "Button", button_pressed)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.035, 0.07, 0.88)
	shade.theme = presentation_theme
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 350.0)
	center.add_child(panel)
	shade.hide()


func _flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _fit_panel(preferred_size: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_size := viewport_size - Vector2(40.0, 40.0)
	panel.custom_minimum_size = Vector2(minf(preferred_size.x, safe_size.x), minf(preferred_size.y, safe_size.y))


func _begin(title: String, subtitle: String, accent: Color) -> VBoxContainer:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	_set_accent(accent)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color("f4e8cf"))
	content.add_child(heading)
	var divider := HSeparator.new()
	content.add_child(divider)
	var message := Label.new()
	message.text = subtitle
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color("bdc2bd"))
	content.add_child(message)
	shade.show()
	return content


func _set_accent(accent: Color) -> void:
	var panel_style := _flat_style(Color("293940"))
	panel_style.set_corner_radius_all(14)
	panel_style.set_border_width_all(4)
	panel_style.border_color = Color("43555b")
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = accent.lerp(Color("d9c7a3"), 0.28)


func _add_icon(parent: Control, texture: Texture2D, size: Vector2 = Vector2(112.0, 112.0)) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)
	return icon


func _add_relic_plate(parent: Control, texture: Texture2D, size: Vector2, accent: Color) -> TextureRect:
	var plate := PanelContainer.new()
	plate.custom_minimum_size = size + Vector2(18.0, 18.0)
	var plate_style := _flat_style(Color("1e2a30"))
	plate_style.set_border_width_all(2)
	plate_style.border_color = accent
	plate_style.set_corner_radius_all(12)
	plate.add_theme_stylebox_override("panel", plate_style)
	parent.add_child(plate)
	return _add_icon(plate, texture, size)


func _add_close_button(parent: Control) -> void:
	var button := Button.new()
	button.text = "계속하기"
	button.custom_minimum_size.y = 42
	button.pressed.connect(func():
		shade.hide()
		closed.emit()
	)
	parent.add_child(button)


func confirm_potential_reset(current_lines: String, cost: int, weapon_icon: Texture2D) -> bool:
	_fit_panel(Vector2(500.0, 390.0))
	var content := _begin("잠재능력 재설정", "현재 세 줄이 모두 사라지고 새 능력으로 교체됩니다.\n비용: 골드 %d" % cost, Color("8b73bd"))
	_add_icon(content, weapon_icon, Vector2(76.0, 76.0))
	var current := Label.new()
	current.text = current_lines
	current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(current)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	for option in [{"text":"3줄 재설정", "value":true}, {"text":"취소", "value":false}]:
		var button := Button.new()
		button.text = str(option.text)
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_emit_decision.bind(bool(option.value)))
		actions.add_child(button)
	var confirmed: bool = await decision_made
	shade.hide()
	return confirmed


func _emit_decision(confirmed: bool) -> void:
	decision_made.emit(confirmed)


func animate_enhancement(weapon_icon: Texture2D, weapon_name: String, old_level: int, next_level: int) -> void:
	var content := _begin("강화 준비", "%s  +%d  →  +%d" % [weapon_name, old_level, next_level], Color("d99a48"))
	var icon := _add_icon(content, weapon_icon, Vector2(100.0, 100.0))
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(300.0, 18.0)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("fill", _flat_style(Color("d99a48")))
	content.add_child(progress)
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)
	var sparks := Label.new()
	sparks.text = "✧    ✦    ✧"
	sparks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sparks.add_theme_font_size_override("font_size", 24)
	content.add_child(sparks)
	for step in 10:
		status.text = ["강화석을 정렬합니다", "연필심을 벼립니다", "마력을 두드립니다", "마지막 불꽃을 더합니다"][mini(3, step / 3)]
		progress.value = float(step + 1) * 10.0
		icon.rotation = rng.randf_range(-0.08, 0.08)
		icon.scale = Vector2.ONE * rng.randf_range(0.94, 1.06)
		sparks.rotation = rng.randf_range(-0.12, 0.12)
		sparks.modulate = Color("f0b84f") if step >= 7 else Color("9a856b")
		sparks.scale = Vector2.ONE * (1.0 + float(step % 2) * 0.14)
		await get_tree().create_timer(0.09).timeout


func animate_potential_roll(weapon_icon: Texture2D, preview_lines: Array[String]) -> void:
	var content := _begin("잠재능력 재설정", "새로운 세 가지 능력을 찾는 중...", Color("8b73bd"))
	var icon := _add_icon(content, weapon_icon, Vector2(88.0, 88.0))
	var lines := Label.new()
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(lines)
	for spin in preview_lines.size():
		lines.text = preview_lines[spin]
		icon.rotation = float(spin % 2) * 0.12 - 0.06
		icon.scale = Vector2.ONE * (0.92 if spin % 2 == 0 else 1.06)
		await get_tree().create_timer(0.09).timeout


func open_enhancement_window(weapon_icon: Texture2D, weapon_name: String, level: int, cost: int, gold: int) -> void:
	_fit_panel(Vector2(560.0, 500.0))
	var content := _begin("무기 강화", "STAR FORCE  ·  별을 쌓아 무기를 성장시킵니다", Color("d99a48"))
	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	enhancement_icon = _add_relic_plate(icon_row, weapon_icon, Vector2(88.0, 88.0), Color("d99a48"))
	var name_label := Label.new()
	name_label.text = weapon_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color("f0d39b"))
	content.add_child(name_label)
	enhancement_status = Label.new()
	enhancement_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(enhancement_status)
	var star_strip := Label.new()
	star_strip.name = "StarStrip"
	star_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_strip.add_theme_font_size_override("font_size", 18)
	content.add_child(star_strip)
	enhancement_progress = ProgressBar.new()
	enhancement_progress.custom_minimum_size = Vector2(380.0, 18.0)
	enhancement_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enhancement_progress.max_value = 20.0
	enhancement_progress.show_percentage = false
	enhancement_progress.add_theme_stylebox_override("fill", _flat_style(Color("e2b653")))
	enhancement_progress.add_theme_stylebox_override("background", _flat_style(Color("19262d")))
	content.add_child(enhancement_progress)
	enhancement_summary = Label.new()
	enhancement_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(enhancement_summary)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	enhancement_button = Button.new()
	enhancement_button.text = "강화 시도"
	enhancement_button.custom_minimum_size.y = 48.0
	enhancement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enhancement_button.pressed.connect(func(): weapon_window_action.emit("enhance"))
	actions.add_child(enhancement_button)
	enhancement_close_button = Button.new()
	enhancement_close_button.text = "닫기"
	enhancement_close_button.custom_minimum_size.y = 48.0
	enhancement_close_button.pressed.connect(_close_weapon_window)
	actions.add_child(enhancement_close_button)
	update_enhancement_window(level, cost, gold)


func update_enhancement_window(level: int, cost: int, gold: int) -> void:
	if not is_instance_valid(enhancement_status):
		return
	var safe_level := clampi(level, 0, 20)
	enhancement_status.text = "현재 강화 +%d   →   다음 강화 +%d" % [safe_level, mini(safe_level + 1, 20)]
	var star_strip := panel.find_child("StarStrip", true, false) as Label
	if star_strip != null:
		star_strip.text = "★".repeat(safe_level) + "☆".repeat(20 - safe_level)
	enhancement_progress.value = safe_level
	enhancement_summary.text = "보유 골드  %d     ·     다음 시도 비용  %d 골드" % [gold, cost]
	enhancement_button.text = "강화 시도  ·  %d 골드" % cost if safe_level < 20 else "강화 최대 단계"
	enhancement_button.disabled = safe_level >= 20 or gold < cost


func animate_enhancement_attempt(old_level: int, next_level: int) -> void:
	_enhancement_set_busy(true)
	for step in 10:
		enhancement_progress.value = float(old_level) + float(step + 1) / 10.0
		enhancement_status.text = ["별의 기운을 모읍니다", "강화석을 두드립니다", "무기에 힘을 새깁니다", "강화 성공!"][mini(3, step / 3)]
		enhancement_icon.rotation = rng.randf_range(-0.08, 0.08)
		enhancement_icon.scale = Vector2.ONE * rng.randf_range(0.94, 1.07)
		await get_tree().create_timer(0.075).timeout
	enhancement_icon.rotation = 0.0
	enhancement_icon.scale = Vector2.ONE
	enhancement_status.text = "+%d 강화 성공!" % next_level
	await get_tree().create_timer(0.24).timeout
	enhancement_close_button.disabled = false


func _enhancement_set_busy(busy: bool) -> void:
	if busy and is_instance_valid(enhancement_button):
		enhancement_button.disabled = true
	if is_instance_valid(enhancement_close_button):
		enhancement_close_button.disabled = busy


func confirm_weapon_synthesis(weapon_icon: Texture2D, weapon_name: String, rarity_name: String, shard_cost: int) -> bool:
	_fit_panel(Vector2(580.0, 440.0))
	var content := _begin("동일 무기 합성", "재료 두 개와 조각을 사용해 다음 등급 무기를 만듭니다.", Color("d7aa56"))
	var material_row := HBoxContainer.new()
	material_row.alignment = BoxContainer.ALIGNMENT_CENTER
	material_row.add_theme_constant_override("separation", 18)
	content.add_child(material_row)
	_add_relic_plate(material_row, weapon_icon, Vector2(84.0, 84.0), Color("c48e4d"))
	var plus := Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 30)
	plus.add_theme_color_override("font_color", Color("e4bb71"))
	material_row.add_child(plus)
	_add_relic_plate(material_row, weapon_icon, Vector2(84.0, 84.0), Color("c48e4d"))
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 28)
	arrow.add_theme_color_override("font_color", Color("e4bb71"))
	material_row.add_child(arrow)
	var result_card := PanelContainer.new()
	result_card.custom_minimum_size = Vector2(116.0, 116.0)
	var result_style := _flat_style(Color("3c4949"))
	result_style.set_border_width_all(2)
	result_style.border_color = Color("e2bc69")
	result_card.add_theme_stylebox_override("panel", result_style)
	material_row.add_child(result_card)
	_add_icon(result_card, weapon_icon, Vector2(88.0, 88.0))
	var result_label := Label.new()
	result_label.text = "%s 등급 · %s" % [rarity_name, weapon_name]
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 18)
	content.add_child(result_label)
	var cost_card := PanelContainer.new()
	cost_card.add_theme_stylebox_override("panel", _flat_style(Color("36474d")))
	var cost_label := Label.new()
	cost_label.text = "사용 재료   ·   동일 무기 2개   +   무기 조각 %d개" % shard_cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color("e9d49d"))
	cost_card.add_child(cost_label)
	content.add_child(cost_card)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	for option in [{"text":"합성하기", "value":true}, {"text":"취소", "value":false}]:
		var button := Button.new()
		button.text = str(option.text)
		button.custom_minimum_size.y = 52.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_emit_decision.bind(bool(option.value)))
		actions.add_child(button)
	var confirmed: bool = await decision_made
	shade.hide()
	return confirmed


func play_synthesis_result(weapon_icon: Texture2D, weapon_name: String, rarity_name: String) -> void:
	_fit_panel(Vector2(500.0, 390.0))
	var content := _begin("합성 성공", "두 무기의 힘이 하나로 모였습니다.", Color("e2bc69"))
	var icon := _add_relic_plate(content, weapon_icon, Vector2(120.0, 120.0), Color("e2bc69"))
	var result := Label.new()
	result.text = "%s  ·  %s 등급" % [weapon_name, rarity_name]
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 22)
	result.add_theme_color_override("font_color", Color("f1d58e"))
	content.add_child(result)
	var tween := create_tween()
	icon.scale = Vector2(0.35, 0.35)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_add_close_button(content)


func open_potential_cube_window(weapon_icon: Texture2D, weapon_name: String, lines: Array[String], cost: int, gold: int) -> void:
	_fit_panel(Vector2(560.0, 500.0))
	var content := _begin("잠재능력 큐브", "%s  ·  한 번 사용할 때마다 골드가 소모됩니다" % weapon_name, Color("8b73bd"))
	cube_line_labels.clear()
	_add_relic_plate(content, weapon_icon, Vector2(60.0, 60.0), Color("a892d0"))
	var line_stack := VBoxContainer.new()
	line_stack.add_theme_constant_override("separation", 6)
	content.add_child(line_stack)
	for index in 3:
		var line_panel := PanelContainer.new()
		line_panel.custom_minimum_size = Vector2(minf(430.0, panel.custom_minimum_size.x - 72.0), 36.0)
		var line_style := _flat_style(Color("e9ddc5"))
		line_style.set_border_width_all(1)
		line_style.border_color = Color("74628c")
		line_panel.add_theme_stylebox_override("panel", line_style)
		line_stack.add_child(line_panel)
		var line_label := Label.new()
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_label.add_theme_font_size_override("font_size", 15)
		line_label.add_theme_color_override("font_color", Color("332c34"))
		line_panel.add_child(line_label)
		cube_line_labels.append(line_label)
	cube_status = Label.new()
	cube_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cube_status)
	cube_cost_label = Label.new()
	cube_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cube_cost_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	cube_roll_button = Button.new()
	cube_roll_button.text = "큐브 사용"
	cube_roll_button.custom_minimum_size.y = 44.0
	cube_roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cube_roll_button.pressed.connect(func(): weapon_window_action.emit("roll"))
	actions.add_child(cube_roll_button)
	cube_stop_button = Button.new()
	cube_stop_button.text = "그만하기"
	cube_stop_button.custom_minimum_size.y = 44.0
	cube_stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cube_stop_button.pressed.connect(_stop_cube_window)
	actions.add_child(cube_stop_button)
	update_potential_cube_window(lines, cost, gold)


func update_potential_cube_window(lines: Array[String], cost: int, gold: int) -> void:
	for index in mini(3, cube_line_labels.size()):
		cube_line_labels[index].text = "잠재능력 %d  ·  %s" % [index + 1, lines[index]]
	cube_cost_label.text = "보유 골드  %d     ·     큐브 비용  %d 골드" % [gold, cost]
	cube_status.text = "새 잠재능력은 즉시 무기에 적용됩니다. 결과가 마음에 들면 그만두세요."
	cube_roll_button.text = "한 번 더 돌리기  ·  %d 골드" % cost
	cube_roll_button.disabled = gold < cost


func animate_cube_roll(lines: Array[String]) -> void:
	cube_roll_button.disabled = true
	cube_stop_button.disabled = true
	cube_status.text = "잠재능력을 다시 조합합니다..."
	for index in 3:
		var line_label := cube_line_labels[index]
		for spin in 5:
			line_label.text = "잠재능력 %d  ·  옵션 탐색%s" % [index + 1, ".".repeat(spin % 3 + 1)]
			line_label.modulate = Color("b49acb")
			await get_tree().create_timer(0.055).timeout
		line_label.text = "잠재능력 %d  ·  %s" % [index + 1, lines[index]]
		line_label.modulate = Color.WHITE
		await get_tree().create_timer(0.14).timeout
		cube_status.text = "새 능력 %d / 3 적용 중" % (index + 1)
	cube_status.text = "새 잠재능력이 적용됐습니다. 계속 돌리거나 그만둘 수 있습니다."
	cube_stop_button.disabled = false


func _stop_cube_window() -> void:
	weapon_window_action.emit("stop")
	_close_weapon_window()


func _close_weapon_window() -> void:
	shade.hide()
	weapon_window_action.emit("close")
	closed.emit()


func show_result(title: String, description: String, icon_texture: Texture2D, accent: Color = Color("d6b251")) -> void:
	var content := _begin(title, description, accent)
	var icon := _add_icon(content, icon_texture)
	icon.scale = Vector2(0.45, 0.45)
	var tween := create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_add_close_button(content)


func reveal_gacha(previews: Array[Dictionary], final_icon: Texture2D, final_title: String, final_description: String, accent: Color) -> void:
	var content := _begin("마력이 응집됩니다", "잠시 후 획득 결과를 공개합니다", Color("d6b251"))
	var icon := _add_icon(content, final_icon)
	var result_text := Label.new()
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.add_theme_font_size_override("font_size", 18)
	content.add_child(result_text)
	for spin in 12:
		var preview: Dictionary = previews[rng.randi_range(0, previews.size() - 1)]
		icon.texture = preview.icon
		result_text.text = str(preview.label)
		icon.rotation = -0.15 if spin % 2 == 0 else 0.15
		icon.scale = Vector2.ONE * (0.82 if spin % 2 == 0 else 1.08)
		await get_tree().create_timer(0.075 + float(spin) * 0.006).timeout
	_set_accent(accent)
	icon.texture = final_icon
	icon.rotation = 0.0
	icon.scale = Vector2(0.45, 0.45)
	result_text.text = final_title
	var detail := Label.new()
	detail.text = final_description
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	var tween := create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_add_close_button(content)
