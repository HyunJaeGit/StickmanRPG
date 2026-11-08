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
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.035, 0.07, 0.88)
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
	return style


func _begin(title: String, subtitle: String, accent: Color) -> VBoxContainer:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	_set_accent(accent)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	content.add_child(heading)
	var message := Label.new()
	message.text = subtitle
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	shade.show()
	return content


func _set_accent(accent: Color) -> void:
	panel.add_theme_stylebox_override("panel", _flat_style(Color("f2e6cf")))
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_border_width_all(4)
	style.border_color = accent


func _add_icon(parent: Control, texture: Texture2D, size: Vector2 = Vector2(112.0, 112.0)) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)
	return icon


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
	panel.custom_minimum_size = Vector2(560.0, 410.0)
	var content := _begin("무기 강화", "STAR FORCE  ·  별을 쌓아 무기를 성장시킵니다", Color("d99a48"))
	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	enhancement_icon = _add_icon(icon_row, weapon_icon, Vector2(104.0, 104.0))
	var name_label := Label.new()
	name_label.text = weapon_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
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
	enhancement_progress.add_theme_stylebox_override("fill", _flat_style(Color("d99a48")))
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


func open_potential_cube_window(weapon_icon: Texture2D, weapon_name: String, lines: Array[String], cost: int, gold: int) -> void:
	panel.custom_minimum_size = Vector2(560.0, 440.0)
	var content := _begin("잠재능력 큐브", "%s  ·  한 번 사용할 때마다 골드가 소모됩니다" % weapon_name, Color("8b73bd"))
	cube_line_labels.clear()
	_add_icon(content, weapon_icon, Vector2(72.0, 72.0))
	var line_stack := VBoxContainer.new()
	line_stack.add_theme_constant_override("separation", 8)
	content.add_child(line_stack)
	for index in 3:
		var line_panel := PanelContainer.new()
		line_panel.custom_minimum_size = Vector2(430.0, 48.0)
		line_panel.add_theme_stylebox_override("panel", _flat_style(Color("e8dcc7")))
		line_stack.add_child(line_panel)
		var line_label := Label.new()
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_label.add_theme_font_size_override("font_size", 17)
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
	cube_roll_button.custom_minimum_size.y = 48.0
	cube_roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cube_roll_button.pressed.connect(func(): weapon_window_action.emit("roll"))
	actions.add_child(cube_roll_button)
	cube_stop_button = Button.new()
	cube_stop_button.text = "그만하기"
	cube_stop_button.custom_minimum_size.y = 48.0
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
