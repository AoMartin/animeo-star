extends Control

const PANEL_COLOR := Color("151b29")
const ACCENT := Color("65a8ff")
const DATA_DIR := "user://processing"

var status_label: Label
var video_info: Label
var frame_label: Label
var video_slider: HSlider
var keyframe_list: ItemList
var source_path := ""
var frame_index := 0
var frame_rate := 30.0
var frame_count := 300
var keyframes: Dictionary = {}
var file_dialog: FileDialog

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for property in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(property, 18)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(columns)
	columns.add_child(_make_video_panel())
	columns.add_child(_make_model_panel())
	columns.add_child(_make_options_panel())
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.mp4, *.mov, *.avi, *.webm, *.ogv ; Video files", "*.* ; All files"])
	file_dialog.file_selected.connect(_on_video_selected)
	add_child(file_dialog)

func _make_video_panel() -> Control:
	var panel := _panel()
	panel.size_flags_stretch_ratio = 38.0
	var root := _column(panel)
	root.add_child(_heading("VIDEO"))
	var preview := ColorRect.new()
	preview.color = Color("090d15")
	preview.custom_minimum_size = Vector2(0, 0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_text := Label.new()
	preview_text.text = "No video loaded\n\nUse Load Video to select a source"
	preview_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(preview_text)
	root.add_child(preview)
	var controls := VBoxContainer.new()
	root.add_child(controls)
	var buttons := HBoxContainer.new()
	controls.add_child(buttons)
	_add_button(buttons, "◀ Frame", _previous_frame)
	_add_button(buttons, "▶ Frame", _next_frame)
	_add_button(buttons, "Mark Keyframe", _mark_keyframe)
	_add_button(buttons, "Remove", _remove_keyframe)
	video_slider = HSlider.new()
	video_slider.min_value = 0
	video_slider.max_value = frame_count - 1
	video_slider.step = 1
	video_slider.value_changed.connect(_on_slider_changed)
	controls.add_child(video_slider)
	frame_label = Label.new()
	controls.add_child(frame_label)
	video_info = Label.new()
	controls.add_child(video_info)
	keyframe_list = ItemList.new()
	keyframe_list.custom_minimum_size.y = 75
	controls.add_child(keyframe_list)
	_update_video_state()
	return panel

func _make_model_panel() -> Control:
	var panel := _panel()
	panel.size_flags_stretch_ratio = 38.0
	var root := _column(panel)
	root.add_child(_heading("3D MODEL / ANIMATION"))
	var preview := ColorRect.new()
	preview.color = Color("090d15")
	preview.custom_minimum_size = Vector2(0, 0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text := Label.new()
	text.text = "STAR NEUTRAL PREVIEW\n\nLoad a humanoid GLB to preview retargeted motion"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(text)
	root.add_child(preview)
	var controls := VBoxContainer.new()
	root.add_child(controls)
	_add_button(controls, "Play Animation", _play_animation)
	var animation_slider := HSlider.new()
	animation_slider.max_value = 1.0
	controls.add_child(animation_slider)
	return panel

func _make_options_panel() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 300
	panel.size_flags_stretch_ratio = 24.0
	var root := _column(panel)
	root.add_child(_heading("OPTIONS"))
	_add_button(root, "Load Video", _open_video)
	_add_button(root, "Load Humanoid Model", _load_model)
	_add_button(root, "Process Keyframes", _process_keyframes)
	_add_button(root, "Generate Animation", _generate_animation)
	_add_button(root, "Export Animation / GLB", _export_animation)
	root.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Ready. Select a video and mark keyframes."
	root.add_child(status_label)
	root.add_spacer(false)
	return panel

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, 10))
	return panel

func _column(parent: Control) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	parent.add_child(root)
	return root

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", ACCENT)
	return label

func _add_button(parent: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _open_video() -> void:
	file_dialog.popup_centered_ratio(0.75)

func _on_video_selected(path: String) -> void:
	source_path = path
	frame_index = 0
	keyframes.clear()
	_update_video_state()
	_set_status("Video seleccionado. Marca los frames que quieres procesar.")

func _previous_frame() -> void:
	_set_frame(frame_index - 1)

func _next_frame() -> void:
	_set_frame(frame_index + 1)

func _set_frame(value: int) -> void:
	frame_index = clampi(value, 0, frame_count - 1)
	if video_slider:
		video_slider.set_value_no_signal(frame_index)
	_update_video_state()

func _on_slider_changed(value: float) -> void:
	_set_frame(roundi(value))

func _mark_keyframe() -> void:
	keyframes[frame_index] = {"frame_index": frame_index, "timestamp": frame_index / frame_rate, "status": "pending"}
	_update_video_state()
	_set_status("Keyframe %d marcado." % frame_index)

func _remove_keyframe() -> void:
	keyframes.erase(frame_index)
	_update_video_state()

func _update_video_state() -> void:
	if not frame_label:
		return
	frame_label.text = "Frame: %d / %d    Time: %.3f s    Keyframes: %d" % [frame_index, frame_count - 1, frame_index / frame_rate, keyframes.size()]
	if video_info:
		video_info.text = source_path if source_path else "No source selected (timeline de prueba disponible)"
	if keyframe_list:
		keyframe_list.clear()
		var frames := keyframes.keys()
		frames.sort()
		for frame in frames:
			keyframe_list.add_item("Frame %d  —  %.3f s  —  %s" % [frame, frame / frame_rate, keyframes[frame].get("status", "pending")])

func _process_keyframes() -> void:
	if keyframes.is_empty():
		_set_status("Marca al menos un keyframe antes de procesar.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var input_path := ProjectSettings.globalize_path(DATA_DIR + "/motion_input.json")
	var output_path := ProjectSettings.globalize_path(DATA_DIR + "/motion_result.json")
	var payload := {"schema_version": 1, "source_video": source_path, "model": "STAR_NEUTRAL", "keyframes": keyframes.values()}
	var file := FileAccess.open(input_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	var python := OS.get_environment("PYTHON_EXECUTABLE_PATH")
	if python.is_empty():
		python = "python"
	var worker := ProjectSettings.globalize_path("res://worker/cli.py")
	var pid := OS.create_process(python, [worker, "--input", input_path, "--output", output_path])
	if pid == -1:
		_set_status("No se pudo iniciar Python. Revisa PYTHON_EXECUTABLE_PATH.")
	else:
		_set_status("Procesamiento iniciado para %d keyframe(s)." % keyframes.size())

func _load_model() -> void:
	_set_status("Carga de GLB preparada; el importador de Skeleton3D se implementará en el siguiente paso.")

func _generate_animation() -> void:
	if keyframes.size() < 2:
		_set_status("Se necesitan al menos 2 keyframes para interpolar una animación.")
		return
	_set_status("Generación preparada: interpolación temporal y SLERP se aplicarán a los resultados STAR.")

func _export_animation() -> void:
	_set_status("Exportación GLB preparada; requiere un humanoide cargado y resultados STAR procesados.")

func _play_animation() -> void:
	_set_status("Preview preparado; carga un humanoide GLB para reproducir la animación.")

func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message

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
