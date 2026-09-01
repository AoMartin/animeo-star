extends Control

const SkeletonMapperClass = preload("res://scripts/retarget/skeleton_mapper.gd")

const PANEL_COLOR := Color("151b29")
const ACCENT := Color("65a8ff")
const DATA_DIR := "user://processing"

var status_label: Label
var video_info: Label
var frame_label: Label
var video_slider: HSlider
var keyframe_list: ItemList
var video_preview: TextureRect
var video_placeholder: Label
var model_viewport: SubViewport
var model_status: Label
var model_dialog: FileDialog
var model_camera: Camera3D
var camera_target := Vector3.ZERO
var camera_distance := 3.0
var camera_yaw := 0.0
var camera_pitch := 0.0
var source_path := ""
var frame_index := 0
var frame_rate := 30.0
var frame_count := 300
var keyframes: Dictionary = {}
var file_dialog: FileDialog
var local_env: Dictionary = {}

func _ready() -> void:
	_load_local_env()
	_build_ui()

func _load_local_env() -> void:
	var file := FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return
	for line in file.get_as_text().split("\n"):
		var parts := line.strip_edges().split("=", true, 1)
		if parts.size() == 2 and not parts[0].begins_with("#"):
			local_env[parts[0].strip_edges()] = parts[1].strip_edges()

func _config_value(name: String) -> String:
	var system_value := OS.get_environment(name)
	return system_value if not system_value.is_empty() else str(local_env.get(name, ""))

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
	file_dialog.filters = PackedStringArray(["*.mp4 ; MP4 video files"])
	file_dialog.file_selected.connect(_on_video_selected)
	add_child(file_dialog)
	model_dialog = FileDialog.new()
	model_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	model_dialog.access = FileDialog.ACCESS_FILESYSTEM
	model_dialog.filters = PackedStringArray(["*.glb ; GLB 3D models"])
	model_dialog.file_selected.connect(_on_model_selected)
	add_child(model_dialog)

func _make_video_panel() -> Control:
	var panel := _panel()
	panel.size_flags_stretch_ratio = 38.0
	var root := _column(panel)
	root.add_child(_heading("VIDEO"))
	var preview := ColorRect.new()
	preview.color = Color("090d15")
	preview.custom_minimum_size = Vector2(0, 0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	video_preview = TextureRect.new()
	video_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	video_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(video_preview)
	video_placeholder = Label.new()
	video_placeholder.text = "No video loaded\n\nUse Load Video to select a source"
	video_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	video_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	video_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(video_placeholder)
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
	var viewport_wrapper := Control.new()
	viewport_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview := SubViewportContainer.new()
	preview.stretch = true
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_wrapper.add_child(preview)
	var input_layer := Control.new()
	input_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	input_layer.z_index = 10
	input_layer.gui_input.connect(_on_viewport_input)
	viewport_wrapper.add_child(input_layer)
	model_viewport = SubViewport.new()
	model_viewport.size = Vector2i(800, 600)
	model_viewport.handle_input_locally = false
	model_viewport.transparent_bg = false
	model_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(model_viewport)
	var world := Node3D.new()
	world.name = "PreviewWorld"
	model_viewport.add_child(world)
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(0, 1.2, 4.0)
	camera.current = true
	camera.look_at_from_position(camera.position, Vector3(0, 1.0, 0))
	world.add_child(camera)
	model_camera = camera
	var light := DirectionalLight3D.new()
	light.name = "PreviewLight"
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.5
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("090d15")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9c9e8")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	model_status = Label.new()
	model_status.text = "STAR NEUTRAL PREVIEW\n\nLoad a humanoid GLB to preview retargeted motion"
	model_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	model_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	model_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(model_status)
	root.add_child(viewport_wrapper)
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

func _heading(title: String) -> Label:
	var label := Label.new()
	label.text = title
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
	if not FileAccess.file_exists(path):
		_set_status("El archivo seleccionado no existe: " + path)
		return
	source_path = path
	frame_index = 0
	keyframes.clear()
	_set_status("Extrayendo frames de " + path.get_file() + "...")
	_extract_video_frames(path)
	_update_video_state()

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
	_refresh_video_frame()
	if keyframe_list:
		keyframe_list.clear()
		var frames := keyframes.keys()
		frames.sort()
		for frame in frames:
			keyframe_list.add_item("Frame %d  —  %.3f s  —  %s" % [frame, frame / frame_rate, keyframes[frame].get("status", "pending")])

func _extract_video_frames(path: String) -> void:
	var cache_dir := ProjectSettings.globalize_path(DATA_DIR + "/frames")
	var metadata := ProjectSettings.globalize_path(DATA_DIR + "/video_metadata.json")
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var python := _config_value("PYTHON_EXECUTABLE_PATH")
	if python.is_empty():
		python = "python"
	var extractor := ProjectSettings.globalize_path("res://worker/extract_frames.py")
	var output: Array = []
	var exit_code := OS.execute(python, [extractor, "--video", path, "--out-dir", cache_dir, "--metadata", metadata], output, true)
	if exit_code != 0 or not FileAccess.file_exists(metadata):
		_set_status("No se pudieron extraer frames. Configura PYTHON_EXECUTABLE_PATH con un Python que tenga opencv-python.")
		return
	var metadata_file := FileAccess.open(metadata, FileAccess.READ)
	var info = JSON.parse_string(metadata_file.get_as_text()) if metadata_file else {}
	if info is Dictionary:
		frame_rate = maxf(float(info.get("fps", 30.0)), 1.0)
		frame_count = maxi(int(info.get("frame_count", 1)), 1)
		video_slider.max_value = frame_count - 1
		if video_placeholder:
			video_placeholder.hide()
	_set_status("Video cargado: %d frames a %.2f FPS." % [frame_count, frame_rate])

func _refresh_video_frame() -> void:
	if not video_preview or source_path.is_empty():
		return
	var frame_path := ProjectSettings.globalize_path(DATA_DIR + "/frames/frame_%06d.jpg" % frame_index)
	if not FileAccess.file_exists(frame_path):
		return
	var image := Image.load_from_file(frame_path)
	if image:
		video_preview.texture = ImageTexture.create_from_image(image)

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
	var python := _config_value("PYTHON_EXECUTABLE_PATH")
	if python.is_empty():
		python = "python"
	var worker := ProjectSettings.globalize_path("res://worker/cli.py")
	var pid := OS.create_process(python, [worker, "--input", input_path, "--output", output_path])
	if pid == -1:
		_set_status("No se pudo iniciar Python. Revisa PYTHON_EXECUTABLE_PATH.")
	else:
		_set_status("Procesamiento iniciado para %d keyframe(s)." % keyframes.size())

func _on_viewport_input(event: InputEvent) -> void:
	if model_camera == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = maxf(camera_distance * 0.85, 0.15)
			_update_model_camera()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = minf(camera_distance * 1.18, 100.0)
			_update_model_camera()
			accept_event()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# Horizontal rotation is intentionally inverted.
			camera_yaw -= event.relative.x * 0.01
			camera_pitch = clampf(camera_pitch - event.relative.y * 0.01, -1.45, 1.45)
			_update_model_camera()
			accept_event()
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			camera_target += Vector3(-event.relative.x, event.relative.y, 0.0) * camera_distance * 0.0015
			_update_model_camera()
			accept_event()

func _update_model_camera() -> void:
	if model_camera == null:
		return
	var orbit := Vector3(
		 sin(camera_yaw) * cos(camera_pitch),
		 sin(camera_pitch),
		 cos(camera_yaw) * cos(camera_pitch)
	) * camera_distance
	model_camera.position = camera_target + orbit
	model_camera.look_at(camera_target, Vector3.UP)

func _load_model() -> void:
	model_dialog.popup_centered_ratio(0.75)

func _on_model_selected(path: String) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state, 0, path.get_base_dir())
	if error != OK:
		_set_status("No se pudo cargar el GLB: " + error_string(error))
		return
	var scene := document.generate_scene(state)
	if scene == null:
		_set_status("El GLB no pudo generar una escena.")
		return
	var world := model_viewport.get_node("PreviewWorld")
	for child in world.get_children():
		if child is Node3D and child.name not in ["PreviewCamera", "PreviewLight", "WorldEnvironment"]:
			child.queue_free()
	world.add_child(scene)
	var bounds := _find_model_bounds(scene)
	if bounds.size.length() > 0.001:
		var center := bounds.position + bounds.size * 0.5
		var radius := maxf(bounds.size.length() * 0.5, 0.5)
		var camera := world.get_node("PreviewCamera") as Camera3D
		# Aim at the vertical midpoint of the complete model, not its origin.
		camera_target = Vector3(center.x, bounds.position.y + bounds.size.y * 0.5, center.z)
		camera_distance = maxf(radius * 3.5, 3.5)
		camera_yaw = 0.0
		camera_pitch = 0.25
		_update_model_camera()
	var skeletons: Array[String] = []
	_collect_skeletons(scene, skeletons)
	var skeleton := _find_first_skeleton(scene)
	var mapped_count := 0
	if skeleton:
		mapped_count = SkeletonMapperClass.new().build_mapping(skeleton).size()
	if model_status:
		model_status.hide()
	_set_status("Modelo cargado: %s — Skeleton3D: %d — huesos mapeados: %d" % [path.get_file(), skeletons.size(), mapped_count])

func _collect_skeletons(node: Node, result: Array[String]) -> void:
	if node is Skeleton3D:
		result.append(node.name + " (%d bones)" % node.get_bone_count())
	for child in node.get_children():
		_collect_skeletons(child, result)

func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found:
			return found
	return null

func _find_model_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var found := false
	if node is MeshInstance3D:
		bounds = node.global_transform * node.get_aabb()
		found = true
	for child in node.get_children():
		var child_bounds := _find_model_bounds(child)
		if child_bounds.size.length() > 0.001:
			bounds = child_bounds if not found else bounds.merge(child_bounds)
			found = true
	return bounds if found else AABB()

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
