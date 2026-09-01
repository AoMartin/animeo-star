extends Control

const PANEL_COLOR := Color("151b29")
const ACCENT := Color("65a8ff")
var status_label: Label
var video_slider: HSlider

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	margin.add_child(columns)
	columns.add_child(_make_workspace("VIDEO", "Load Video", true))
	columns.add_child(_make_workspace("3D MODEL", "Load Humanoid Model", false))
	columns.add_child(_make_options())

func _make_workspace(title: String, action: String, is_video: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, 10))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", ACCENT)
	root.add_child(heading)
	var viewport := ColorRect.new()
	viewport.color = Color("090d15")
	viewport.custom_minimum_size = Vector2(0, 360)
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(viewport)
	var controls := VBoxContainer.new()
	root.add_child(controls)
	var button := Button.new()
	button.text = action
	button.pressed.connect(_on_action.bind(action))
	controls.add_child(button)
	if is_video:
		var row := HBoxContainer.new()
		controls.add_child(row)
		for label_text in ["◀", "▶", "Mark Keyframe"]:
			var b := Button.new()
			b.text = label_text
			row.add_child(b)
		video_slider = HSlider.new()
		video_slider.min_value = 0
		video_slider.max_value = 1
		video_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(video_slider)
		var info := Label.new()
		info.text = "Frame: 0    Time: 0.000 s    Duration: --"
		controls.add_child(info)
	else:
		var info := Label.new()
		info.text = "Animation: --    Time: 0.000 s"
		controls.add_child(info)
	return panel

func _make_options() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, 10))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT)
	root.add_child(title)
	for action in ["Load Video", "Load Humanoid Model", "Process Keyframes", "Generate Animation", "Export Animation / GLB"]:
		var b := Button.new()
		b.text = action
		b.custom_minimum_size.y = 38
		b.pressed.connect(_on_action.bind(action))
		root.add_child(b)
	var separator := HSeparator.new()
	root.add_child(separator)
	status_label = Label.new()
	status_label.text = "Ready. STAR Neutral worker not configured."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)
	root.add_spacer(false)
	return panel

func _on_action(action: String) -> void:
	if status_label:
		status_label.text = action + " — scaffold ready; implementation queued."

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 14
	box.content_margin_top = 14
	box.content_margin_right = 14
	box.content_margin_bottom = 14
	return box
