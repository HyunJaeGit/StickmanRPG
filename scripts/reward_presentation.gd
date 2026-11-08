extends CanvasLayer
class_name RewardPresentation
## 강화·잠재 재설정·뽑기의 화면 연출과 사용자 확인을 담당합니다.

signal closed
signal decision_made(confirmed: bool)

var shade: ColorRect
var panel: PanelContainer
var rng := RandomNumberGenerator.new()


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
