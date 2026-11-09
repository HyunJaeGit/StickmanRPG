extends Control
## 챕터 도입, 보스 등장, 장면 마무리와 전투 결과를 그림과 짧은 대사로 전달합니다.

signal sequence_finished

const PAPER_BACKGROUND: Texture2D = preload("res://art/sketch_forest_background.png")

var scene_kind := ""
var stage_id := "1-1"
var pages: Array[Dictionary] = []
var page_index := 0
var result_data: Dictionary = {}
var title_label: Label
var story_label: Label
var action_button: Button
var skip_button: Button
var phase := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_overlay()
	hide()


func _process(delta: float) -> void:
	if visible:
		phase += delta
		queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	if PAPER_BACKGROUND != null:
		draw_texture_rect(PAPER_BACKGROUND, bounds, false, Color(0.36, 0.34, 0.31, 1.0))
	draw_rect(bounds, Color(0.08, 0.075, 0.07, 0.38))
	var scale_factor := minf(size.x / 960.0, size.y / 540.0)
	var origin := Vector2((size.x - 960.0 * scale_factor) * 0.5, (size.y - 540.0 * scale_factor) * 0.5)
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	_draw_illustration()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_illustration() -> void:
	var breath := sin(phase * 2.0) * 3.0
	var ink := Color("272521")
	var charcoal := Color("4b4037")
	var scarf := Color("b34d3c")
	# 연필검을 든 주인공의 단순한 선화 실루엣.
	var hero := Vector2(282.0, 286.0 + breath)
	draw_circle(hero + Vector2(0, -87), 22, Color("f2e6cf"))
	draw_arc(hero + Vector2(0, -87), 22, 0, TAU, 32, ink, 4.0, true)
	draw_line(hero + Vector2(0, -62), hero + Vector2(0, 6), ink, 7.0, true)
	draw_line(hero + Vector2(0, -44), hero + Vector2(31, -29), scarf, 11.0, true)
	draw_line(hero + Vector2(0, -45), hero + Vector2(-28, -21), ink, 5.0, true)
	draw_line(hero + Vector2(0, 3), hero + Vector2(-22, 43), ink, 6.0, true)
	draw_line(hero + Vector2(0, 3), hero + Vector2(24, 42), ink, 6.0, true)
	draw_line(hero + Vector2(24, -29), hero + Vector2(75, -75), Color("d9c69e"), 6.0, true)
	draw_line(hero + Vector2(75, -75), hero + Vector2(110, -108), Color("f2e6cf"), 3.0, true)
	draw_line(hero + Vector2(20, -32), hero + Vector2(45, -14), scarf, 5.0, true)
	# 잉크 괴물은 번진 얼룩과 종이 위의 눈으로 표현합니다.
	for i in 3:
		var x := 600.0 + float(i) * 92.0
		var bob := sin(phase * 1.7 + float(i)) * 5.0
		draw_circle(Vector2(x, 260.0 + bob), 31.0 + float(i % 2) * 5.0, Color(0.12, 0.115, 0.105, 0.92))
		draw_circle(Vector2(x - 9, 253.0 + bob), 3.0, Color("efe5ce"))
		draw_circle(Vector2(x + 9, 253.0 + bob), 3.0, Color("efe5ce"))
		draw_line(Vector2(x - 12, 282.0 + bob), Vector2(x - 24, 311.0 + bob), charcoal, 5.0, true)
		draw_line(Vector2(x + 12, 282.0 + bob), Vector2(x + 24, 311.0 + bob), charcoal, 5.0, true)
	# 보스 장면은 거대한 지우개 실루엣과 종이 가루로 위협을 강조합니다.
	if scene_kind in ["boss", "ending"]:
		var boss_center := Vector2(711.0, 203.0 + sin(phase * 1.1) * 2.0)
		var points := PackedVector2Array([boss_center + Vector2(-91, -58), boss_center + Vector2(52, -71), boss_center + Vector2(94, 37), boss_center + Vector2(-54, 70)])
		draw_colored_polygon(points, Color("a7473f") if scene_kind == "boss" else Color("d9c69e"))
		for i in 4:
			draw_line(points[i], points[(i + 1) % 4], ink, 5.0, true)
		draw_line(boss_center + Vector2(-45, -4), boss_center + Vector2(42, -13), Color("f2e6cf"), 7.0, true)
		draw_circle(boss_center + Vector2(-29, -9), 5.0, ink)
		draw_circle(boss_center + Vector2(23, -15), 5.0, ink)
		for i in 8:
			var speck := boss_center + Vector2(cos(float(i) * TAU / 8.0), sin(float(i) * TAU / 8.0)) * (112.0 + sin(phase * 2.0 + i) * 7.0)
			draw_circle(speck, 3.0, Color("f2e6cf", 0.75))
	# 종이 위 연필선이 장면의 인상을 묶습니다.
	draw_line(Vector2(80, 352), Vector2(872, 352), Color(0.17, 0.15, 0.13, 0.42), 2.0, true)
	draw_line(Vector2(80, 358), Vector2(872, 358), Color(0.17, 0.15, 0.13, 0.16), 1.0, true)


func _build_overlay() -> void:
	title_label = Label.new()
	title_label.position = Vector2(64, 35)
	title_label.size = Vector2(832, 54)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color("fff3d8"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.69
	panel.anchor_bottom = 0.94
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f2e6cf", 0.96)
	style.border_color = Color("a58a67")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 15
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(layout)
	story_label = Label.new()
	story_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_font_size_override("font_size", 19)
	story_label.add_theme_color_override("font_color", Color("382f27"))
	story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(story_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(actions)
	skip_button = Button.new()
	skip_button.text = "건너뛰기"
	skip_button.pressed.connect(_on_skip_pressed)
	actions.add_child(skip_button)
	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(190, 42)
	action_button.pressed.connect(_on_action_pressed)
	actions.add_child(action_button)


func play_chapter_intro(stage: String) -> void:
	scene_kind = "chapter"
	stage_id = stage
	var chapter := stage.split("-")[0]
	var pages_for_scene := [
		{"title":"제%s장 · 스케치의 틈" % chapter, "text":"스케치북의 숲에 검은 잉크가 번져든다.\n목도리를 고쳐 맨 작은 검사는 지워진 길 위에 첫 선을 긋는다."},
		{"title":"%s · 연필 숲" % stage, "text":"잉크는 그림뿐 아니라 그 안에 남은 기억까지 삼키고 있다.\n흔적을 따라가면 번짐의 근원을 찾을 수 있을 것이다."}
	]
	_open_pages(pages_for_scene)


func play_boss_intro(stage: String) -> void:
	scene_kind = "boss"
	stage_id = stage
	_open_pages([
		{"title":"%s · 지우개 작업실" % stage, "text":"숲 너머, 종이 위에 깊게 패인 지우개 자국이 길을 막는다.\n그 흔적 아래에서 거대한 무언가가 몸을 일으킨다."},
		{"title":"지우개 거인", "text":"“이 그림은 잘못 그려졌어. 전부 지워야 해.”\n연필검의 끝이 빛난다. 이 세계가 지워지기 전에 맞서 싸워라."}
	])


func play_ending(stage: String) -> void:
	scene_kind = "ending"
	stage_id = stage
	_open_pages([
		{"title":"마지막 획", "text":"지우개 거인의 몸에 마지막 선이 그어진다.\n거대한 지우개는 종이 가루와 함께 조용히 무너진다."},
		{"title":"지워진 자리에서", "text":"검은 얼룩 아래, 누군가 지웠다가 다시 그은 낯선 선이 드러난다.\n잉크는 사고가 아니었다. 누군가 이 그림을 고치려 하고 있다."},
		{"title":"다음 페이지", "text":"숲의 길은 다시 이어지고, 스케치북의 다음 장이 열린다.\n주인공은 연필을 쥐고 새로운 흔적을 향해 나아간다."}
	])


func show_result(data: Dictionary) -> void:
	scene_kind = "result"
	stage_id = str(data.get("stage", "1-1"))
	result_data = data.duplicate(true)
	var won := bool(data.get("won", false))
	title_label.text = "%s · 작전 결과" % ["스테이지 클리어" if won else "전투 실패"]
	var lines := [str(data.get("story", "")), "", "처치 %d  ·  전투 시간 %s" % [int(data.get("kills", 0)), str(data.get("time", "00:00"))], str(data.get("rewards", "")), "골드 %s  ·  무기 조각 %s  ·  마력 조각 %s" % [str(data.get("gold", 0)), str(data.get("weapon_shards", 0)), str(data.get("magic_shards", 0))], "다음 출전 단계  %s" % str(data.get("next_stage", "1-1"))]
	story_label.text = "\n".join(lines)
	action_button.text = "클릭하여 로비로"
	skip_button.hide()
	show()
	queue_redraw()


func _open_pages(new_pages: Array) -> void:
	pages.clear()
	for page in new_pages:
		pages.append(page)
	page_index = 0
	skip_button.show()
	show()
	_show_page()
	queue_redraw()


func _show_page() -> void:
	var page: Dictionary = pages[page_index]
	title_label.text = str(page.get("title", ""))
	story_label.text = str(page.get("text", ""))
	action_button.text = "다음" if page_index < pages.size() - 1 else "전투 시작"


func _on_action_pressed() -> void:
	_advance_or_finish()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_or_finish()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_advance_or_finish()
		accept_event()


func _advance_or_finish() -> void:
	if scene_kind == "result":
		hide()
		sequence_finished.emit()
		return
	if page_index < pages.size() - 1:
		page_index += 1
		_show_page()
	else:
		hide()
		sequence_finished.emit()


func _on_skip_pressed() -> void:
	hide()
	sequence_finished.emit()
