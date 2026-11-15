extends CanvasLayer
const PlanetAssetLibrary = preload("res://scripts/planet_assets.gd")

const BG := Color("07111f")
const PANEL := Color("091827")
const PANEL_HOVER := Color("10263a")
const BORDER := Color("20364a")
const TEXT := Color("e8f0f7")
const MUTED := Color("91a4b7")
const ACCENT := Color("49b7e9")
const GREEN := Color("60d5b0")
const HORIZONS_API_URL := "https://ssd.jpl.nasa.gov/api/horizons.api"
const NASA_PLANETARY_URL := "https://nssdc.gsfc.nasa.gov/planetary/factsheet/"
const NASA_POWER_URL := "https://www.nasa.gov/smallsat-institute/sst-soa/power-subsystems/"
const NASA_COMMS_URL := "https://www.nasa.gov/smallsat-institute/sst-soa/soa-communications/"
const NASA_STRUCTURES_URL := "https://www.nasa.gov/smallsat-institute/sst-soa/structures-materials-and-mechanisms/"
const NASA_OPERATIONS_URL := "https://www.nasa.gov/smallsat-institute/sst-soa/ground-data-systems-and-mission-operations/"
const NASA_PLANETARY_DATASET_NAME := "NASA Planetary Fact Sheet - Metric"
const NASA_SST_DATASET_NAME := "NASA State-of-the-Art of Small Spacecraft Technology"
const HORIZONS_BODIES := {
	"earth": {"name": "Earth", "id": "399"},
	"moon": {"name": "Moon", "id": "301"},
	"mars": {"name": "Mars", "id": "499"}
}


const RESOLUTIONS := [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]
const MISSIONS := [
	{
		"id": "earth_observation", "name": "EARTH OBSERVATION",
		"description": "Observe Earth and collect climate data.",
		"difficulty": "STANDARD", "art": 0,
		"objective": "Monitor Earth's climate systems and collect atmospheric and surface data.",
		"target": "EARTH", "duration": "6 days", "duration_days": 6, "budget": "$180M", "budget_millions": 180,
		"data_requirement_gb_day": 12,
		"required_components": ["structure", "solar_panels", "battery", "communication_antenna", "onboard_computer", "scientific_camera"]
	},
	{
		"id": "lunar_exploration", "name": "LUNAR EXPLORATION",
		"description": "Survey the lunar surface and its surroundings.",
		"difficulty": "ADVANCED", "art": 1,
		"objective": "Survey the lunar surface, map key regions and study the near Moon environment.",
		"target": "THE MOON", "duration": "14 days", "duration_days": 14, "budget": "$420M", "budget_millions": 420,
		"data_requirement_gb_day": 18,
		"required_components": ["structure", "solar_panels", "battery", "communication_antenna", "onboard_computer", "radar"]
	},
	{
		"id": "mars_exploration", "name": "MARS EXPLORATION",
		"description": "Study Mars and gather scientific data.",
		"difficulty": "CHALLENGING", "art": 2,
		"objective": "Study Martian geology and atmosphere while collecting high value scientific data.",
		"target": "MARS", "duration": "26 months", "duration_days": 780, "budget": "$1.8B", "budget_millions": 1800,
		"data_requirement_gb_day": 25,
		"required_components": ["structure", "solar_panels", "battery", "communication_antenna", "onboard_computer", "scientific_camera", "spectrometer"]
	},
	{
		"id": "deep_space", "name": "DEEP SPACE",
		"description": "Explore remote regions beyond the Solar System.",
		"difficulty": "EXPERT", "art": 3,
		"objective": "Investigate distant regions beyond the Solar System and return deep space observations.",
		"target": "OUTER SYSTEM", "duration": "5 years", "duration_days": 1825, "budget": "$3.6B", "budget_millions": 3600,
		"data_requirement_gb_day": 18,
		"required_components": ["structure", "solar_panels", "battery", "communication_antenna", "onboard_computer", "spectrometer"]
	}
]

var root: Control
var body: Control
var current_page := "home"
var selected_mission_index := -1
var mission_cards: Array[Button] = []
var continue_button: Button
var design_resource_labels: Dictionary = {}
var design_component_buttons: Dictionary = {}
var required_component_labels: Dictionary = {}
var craft_viewport: SubViewport
var craft_scene_root: Node3D
var craft_model: Node3D
var rocket_cards: Dictionary = {}
var orbit_buttons: Dictionary = {}
var launch_resource_labels: Dictionary = {}
var orbit_detail_root: Control
var orbit_preview_viewport: SubViewport
var orbit_preview_root: Node3D
var orbit_preview_body: Node3D
var launch_next_button: Button
var simulation_metric_labels: Dictionary = {}
var simulation_timeline_cards: Array[PanelContainer] = []
var simulation_event_list: VBoxContainer
var simulation_advance_button: Button
var simulation_phase_label: Label
var simulation_progress_bar: ProgressBar
var launch_graphic: Control
var craft_preview_rect: Control
var craft_dragging := false
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var horizons_request: HTTPRequest
var horizons_output: RichTextLabel
var horizons_status: Label
var horizons_body_id := "earth"
var planetary_facts_body_id := "earth"
var sandbox_rocket_label: Label
var sandbox_orbit_label: Label
var sandbox_rocket_index := 0
var sandbox_orbit_index := 0
var design_continue_button: Button
var sandbox_rocket_buttons: Dictionary = {}
var sandbox_orbit_buttons: Dictionary = {}
var sandbox_selected_rocket := ""
var sandbox_selected_orbit := ""

class LaunchSequenceGraphic extends Control:
	var progress := 0.0:
		set(value):
			progress = value
			if is_instance_valid(rocket_overlay):
				rocket_overlay.progress = value
				rocket_overlay.queue_redraw()
	var planet_disc: TextureRect
	var rocket_overlay: LaunchSequenceOverlay

	func _ready() -> void:
		planet_disc = PlanetAssetLibrary.create_2d_globe(PlanetAssetLibrary.load_surface_texture("EARTH"), "EARTH")
		add_child(planet_disc)
		rocket_overlay = LaunchSequenceOverlay.new()
		rocket_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rocket_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rocket_overlay)
		_layout_planet()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and is_instance_valid(planet_disc):
			_layout_planet()

	func _layout_planet() -> void:
		var earth_radius := minf(size.x * 0.20, size.y * 0.34)
		var earth_center := Vector2(size.x * 0.50, size.y * 0.61)
		planet_disc.position = earth_center - Vector2.ONE * earth_radius
		planet_disc.size = Vector2.ONE * earth_radius * 2.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for i in range(42):
			var x := fposmod(float(i * 83 + 17), maxf(w, 1.0))
			var y := fposmod(float(i * 47 + 9), maxf(h, 1.0))
			draw_circle(Vector2(x, y), 0.7 if i % 5 else 1.25, Color(0.72, 0.85, 1.0, 0.56))
		var earth_radius := minf(w * 0.20, h * 0.34)
		var earth_center := Vector2(w * 0.50, h * 0.61)
		draw_circle(earth_center, earth_radius + 11.0, Color(0.10, 0.53, 0.92, 0.10))
		draw_circle(earth_center, earth_radius + 4.0, Color(0.12, 0.58, 1.0, 0.18))
		draw_arc(earth_center, earth_radius + 4, -2.65, 0.65, 64, Color(0.28, 0.76, 1.0, 0.78), 2.0, true)
		draw_arc(earth_center, earth_radius + 4, 0.65, 3.62, 64, Color(0.12, 0.42, 0.82, 0.28), 2.0, true)

class LaunchSequenceOverlay extends Control:
	var progress := 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var start := Vector2(w * 0.50, h * 0.75)
		var finish := Vector2(w * 0.50, h * 0.18)
		var rocket_pos := start.lerp(finish, smoothstep(0.0, 1.0, progress))
		draw_line(Vector2(w * 0.50, h * 0.83), rocket_pos, Color(0.28, 0.73, 1.0, 0.24), 1.2)
		var flame := 8.0 + 12.0 * absf(sin(Time.get_ticks_msec() * 0.025))
		draw_colored_polygon(PackedVector2Array([
			rocket_pos + Vector2(-5, 12), rocket_pos + Vector2(5, 12), rocket_pos + Vector2(0, 12 + flame)
		]), Color(1.0, 0.56, 0.19, 0.88))
		draw_colored_polygon(PackedVector2Array([
			rocket_pos + Vector2(-7, 8), rocket_pos + Vector2(7, 8), rocket_pos + Vector2(0, 20)
		]), Color("d7e3ec"))
		draw_circle(rocket_pos + Vector2(0, 4), 2.2, Color("59bde9"))
		draw_colored_polygon(PackedVector2Array([
			rocket_pos + Vector2(-7, 9), rocket_pos + Vector2(-11, 14), rocket_pos + Vector2(-6, 13),
			rocket_pos + Vector2(-4, 11)
		]), Color("d08e45"))
		draw_colored_polygon(PackedVector2Array([
			rocket_pos + Vector2(7, 9), rocket_pos + Vector2(11, 14), rocket_pos + Vector2(6, 13),
			rocket_pos + Vector2(4, 11)
		]), Color("d08e45"))

class MissionCardArt extends Control:
	var mission_kind := 0
	var planet_disc: TextureRect
	var moon_viewport_container: SubViewportContainer
	var moon_model: Node3D
	var deep_space_visual: ColorRect

	func _ready() -> void:
		if mission_kind == 3:
			_create_deep_space_visual()
		elif mission_kind == 1:
			_create_moon_preview()
		else:
			var body_key: String = "EARTH" if mission_kind == 0 else "MARS"
			planet_disc = PlanetAssetLibrary.create_2d_globe(PlanetAssetLibrary.load_surface_texture(body_key), body_key)
			add_child(planet_disc)
		_layout_planet_visual()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and is_inside_tree():
			_layout_planet_visual()

	func _layout_planet_visual() -> void:
		var center := Vector2(size.x * 0.78, size.y * 0.53)
		var radius := minf(size.y * 0.39, size.x * 0.20)
		if is_instance_valid(planet_disc):
			planet_disc.position = center - Vector2.ONE * radius
			planet_disc.size = Vector2.ONE * radius * 2.0
		if is_instance_valid(moon_viewport_container):
			var viewport_size := Vector2.ONE * radius * 2.65
			moon_viewport_container.position = center - viewport_size * 0.5
			moon_viewport_container.size = viewport_size
		if is_instance_valid(deep_space_visual):
			deep_space_visual.position = Vector2(size.x * 0.36, 0.0)
			deep_space_visual.size = Vector2(size.x * 0.64, size.y)

	func _create_moon_preview() -> void:
		moon_viewport_container = SubViewportContainer.new()
		moon_viewport_container.name = "NASA_LRO_Moon_Render"
		moon_viewport_container.stretch = true
		moon_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(moon_viewport_container)
		var viewport := SubViewport.new()
		viewport.name = "MoonPreviewViewport"
		viewport.size = Vector2i(256, 256)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		moon_viewport_container.add_child(viewport)
		var world := Node3D.new()
		world.name = "MoonPreviewWorld"
		viewport.add_child(world)
		var environment_node := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("aebbd0")
		environment.ambient_light_energy = 0.58
		environment_node.environment = environment
		world.add_child(environment_node)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-22.0, -32.0, -8.0)
		key.light_color = Color("fff4df")
		key.light_energy = 1.45
		world.add_child(key)
		var fill := OmniLight3D.new()
		fill.position = Vector3(-1.0, 0.25, 1.25)
		fill.light_color = Color("9cb8df")
		fill.light_energy = 0.48
		fill.omni_range = 4.0
		world.add_child(fill)
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 0.0, 2.45)
		camera.fov = 38.0
		world.add_child(camera)
		camera.look_at(Vector3.ZERO, Vector3.UP)
		camera.make_current()
		moon_model = PlanetAssetLibrary.instantiate_model("THE MOON", 0.78)
		if moon_model != null:
			world.add_child(moon_model)
		_layout_planet_visual()

	func _create_deep_space_visual() -> void:
		deep_space_visual = ColorRect.new()
		deep_space_visual.name = "AnimatedDeepSpaceNebula"
		deep_space_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nebula_shader := Shader.new()
		nebula_shader.code = """
		shader_type canvas_item;
		float hash21(vec2 p) {
			p = fract(p * vec2(123.34, 456.21));
			p += dot(p, p + 45.32);
			return fract(p.x * p.y);
		}
		float noise2d(vec2 p) {
			vec2 i = floor(p);
			vec2 f = fract(p);
			f = f * f * (3.0 - 2.0 * f);
			return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
				mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
		}
		float fbm(vec2 p) {
			float value = 0.0;
			float amplitude = 0.5;
			for (int octave = 0; octave < 5; octave++) {
				value += noise2d(p) * amplitude;
				p = p * 2.03 + vec2(17.1, 9.2);
				amplitude *= 0.5;
			}
			return value;
		}
		void fragment() {
			vec2 uv = UV;
			vec2 p = uv * vec2(3.8, 2.5);
			float warp_a = fbm(p + vec2(TIME * 0.035, -TIME * 0.018));
			float warp_b = fbm(p + vec2(8.3, 2.7) - TIME * 0.025);
			float cloud = fbm(p + (vec2(warp_a, warp_b) - 0.5) * 1.55 + vec2(TIME * 0.045, -TIME * 0.022));
			float formation = smoothstep(0.31, 0.78, cloud);
			vec3 nebula = mix(vec3(0.018, 0.034, 0.105), vec3(0.075, 0.11, 0.27), smoothstep(0.24, 0.58, cloud));
			nebula = mix(nebula, vec3(0.25, 0.10, 0.36), smoothstep(0.48, 0.79, cloud) * 0.72);
			nebula += vec3(0.055, 0.30, 0.52) * smoothstep(0.63, 0.89, cloud) * 0.78;
			vec2 grid = uv * vec2(62.0, 38.0);
			vec2 cell = floor(grid);
			float seed = hash21(cell);
			vec2 star_point = fract(grid) - vec2(hash21(cell + 5.1), hash21(cell + 9.7));
			float star_shape = 1.0 - smoothstep(0.012, 0.045, length(star_point));
			float star = step(0.982, seed) * star_shape;
			float twinkle = 0.62 + 0.38 * sin(TIME * (1.4 + seed * 5.0) + seed * 55.0);
			float edge_fade = smoothstep(0.0, 0.18, uv.x) * (1.0 - smoothstep(0.87, 1.0, uv.x));
			edge_fade *= smoothstep(0.0, 0.14, uv.y) * (1.0 - smoothstep(0.86, 1.0, uv.y));
			float alpha = edge_fade * max(0.34 + formation * 0.60, star * twinkle);
			vec3 color = nebula + vec3(0.62, 0.78, 1.0) * star * twinkle * 1.6;
			COLOR = vec4(color, alpha);
		}
		"""
		var nebula_material := ShaderMaterial.new()
		nebula_material.shader = nebula_shader
		deep_space_visual.material = nebula_material
		add_child(deep_space_visual)
		_layout_planet_visual()

	func _process(delta: float) -> void:
		if is_instance_valid(moon_model):
			moon_model.rotate_y(delta * 0.025)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("06101d"))
		for i in range(20):
			var x := fposmod(float(i * 79 + mission_kind * 31), maxf(size.x, 1.0))
			var y := fposmod(float(i * 43 + mission_kind * 17), maxf(size.y, 1.0))
			draw_circle(Vector2(x, y), 0.7 if i % 4 != 0 else 1.1, Color(0.62, 0.82, 1.0, 0.46))
		if mission_kind == 3:
			return
		var center := Vector2(size.x * 0.78, size.y * 0.53)
		var radius := minf(size.y * 0.39, size.x * 0.20)
		var halo_color := Color(0.22, 0.68, 0.98, 0.24) if mission_kind == 0 else Color(0.62, 0.76, 0.90, 0.20) if mission_kind == 1 else Color(0.95, 0.40, 0.25, 0.22)
		draw_circle(center, radius + 3.0, halo_color)

class MissionMark extends Control:
	func _draw() -> void:
		var center := size * 0.5
		draw_arc(center, 15.0, 0.0, TAU, 48, Color("49b7e9"), 1.8, true)
		draw_set_transform(center, deg_to_rad(-28.0), Vector2(1.55, 0.46))
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 48, Color("84d7f5"), 1.4, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(center, 3.2, Color("e8f0f7"))

func _ready() -> void:
	_build_shell()
	_setup_audio()
	horizons_request = HTTPRequest.new()
	horizons_request.name = "JPLHorizonsRequest"
	horizons_request.timeout = 12.0
	horizons_request.request_completed.connect(_on_horizons_request_completed)
	add_child(horizons_request)
	get_window().size_changed.connect(_refresh_responsive_typography)
	_show_home()

func _process(delta: float) -> void:
	if current_page == "spacecraft_design" and is_instance_valid(craft_model):
		craft_model.rotate_y(delta * 0.18)
	if current_page == "rocket_orbit_selection" and is_instance_valid(orbit_preview_body):
		orbit_preview_body.rotate_y(delta * 0.08)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_play_ui_sound()
		if current_page == "spacecraft_design" and is_instance_valid(craft_preview_rect):
			if event.pressed and craft_preview_rect.get_global_rect().has_point(event.position):
				craft_dragging = true
			elif not event.pressed:
				craft_dragging = false
	if event is InputEventMouseMotion and craft_dragging and is_instance_valid(craft_model):
		craft_model.rotate_y(-event.relative.x * 0.008)
		craft_model.rotate_x(-event.relative.y * 0.008)
	if current_page != "rocket_orbit_selection":
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for orbit_id in orbit_buttons:
		var button: Button = orbit_buttons[orbit_id]
		if button.visible and not button.disabled and button.get_global_rect().has_point(event.position):
			_on_orbit_selected(str(orbit_id))
			get_viewport().set_input_as_handled()
			return

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "AmbientMusic"
	music_player.bus = "Master"
	add_child(music_player)
	music_player.stream = _tone_stream(6.0, true)
	music_player.volume_db = linear_to_db(maxf(0.001, float(MissionState.audio_settings["music"])))
	if MissionState.audio_settings["music_enabled"]:
		music_player.play()
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "InterfaceAudio"
	sfx_player.bus = "Master"
	add_child(sfx_player)

func _tone_stream(seconds: float, looped: bool, base_frequency: float = 660.0) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(seconds * sample_rate)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / sample_rate
		var sample := 0.0
		if looped:
			sample = (sin(TAU * 55.0 * t) * 0.30 + sin(TAU * 82.4 * t) * 0.16 + sin(TAU * 110.0 * t) * 0.10) * (0.72 + 0.12 * sin(TAU * t / seconds))
		else:
			var envelope := minf(t * 80.0, 1.0) * exp(-t * 5.5)
			sample = (sin(TAU * (base_frequency - base_frequency * 0.22 * t) * t) + sin(TAU * base_frequency * 1.5 * t) * 0.18) * envelope * 0.45
		samples.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
	return stream

func _play_ui_sound() -> void:
	if not is_instance_valid(sfx_player) or not MissionState.audio_settings["sfx_enabled"]:
		return
	sfx_player.stream = _ui_click_stream()
	sfx_player.volume_db = linear_to_db(maxf(0.001, float(MissionState.audio_settings["sfx"])))
	sfx_player.play()

func _ui_click_stream() -> AudioStreamWAV:
	# Soft, rounded control-room confirmation tick with no sharp transient.
	var sample_rate := 22050
	var seconds := 0.12
	var sample_count := int(seconds * sample_rate)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / sample_rate
		var attack := smoothstep(0.0, 0.008, t)
		var envelope := attack * exp(-t * 24.0)
		var fundamental := sin(TAU * (570.0 - 150.0 * t) * t)
		var overtone := sin(TAU * 860.0 * t) * 0.10
		var sample := (fundamental + overtone) * envelope * 0.23
		samples.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = samples
	return stream

func _build_shell() -> void:
	root = Control.new()
	root.name = "MenuRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	var tint := ColorRect.new()
	tint.color = Color(0.008, 0.025, 0.052, 0.38)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)

	var top_rule := ColorRect.new()
	top_rule.color = Color(ACCENT, 0.42)
	top_rule.anchor_left = 0.055
	top_rule.anchor_right = 0.945
	top_rule.anchor_top = 0.145
	top_rule.anchor_bottom = 0.145
	top_rule.offset_bottom = 1.0
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_rule)

	var mark := MissionMark.new()
	mark.position = Vector2(86, 37)
	mark.size = Vector2(42, 42)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mark)

	var brand := VBoxContainer.new()
	brand.position = Vector2(142, 35)
	brand.size = Vector2(340, 48)
	brand.add_theme_constant_override("separation", 1)
	root.add_child(brand)
	var title := _label("MISSION CONTROL", 22, TEXT)
	_set_font_size(title, 21)
	brand.add_child(title)
	var subtitle := _label("FLIGHT OPERATIONS", 10, ACCENT)
	subtitle.add_theme_color_override("font_color", Color(ACCENT, 0.82))
	brand.add_child(subtitle)

	var status := _label("EARTH ORBIT  /  CONTROL ONLINE", 11, MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.anchor_left = 0.62
	status.anchor_right = 0.945
	status.anchor_top = 0.064
	status.anchor_bottom = 0.10
	root.add_child(status)

	body = Control.new()
	body.name = "PageContent"
	body.anchor_left = 0.055
	body.anchor_right = 0.945
	body.anchor_top = 0.19
	body.anchor_bottom = 0.90
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(body)

func _show_home() -> void:
	current_page = "home"
	_clear_body()

	var nav := VBoxContainer.new()
	nav.anchor_left = 0.025
	nav.anchor_right = 0.54
	nav.anchor_top = 0.12
	nav.anchor_bottom = 0.83
	nav.add_theme_constant_override("separation", 12)
	body.add_child(nav)

	var eyebrow := _label("MISSION DESK", 11, ACCENT)
	eyebrow.add_theme_constant_override("outline_size", 0)
	nav.add_child(eyebrow)
	var heading := _label("Command the next mission.", 27, TEXT)
	_set_font_size(heading, 27)
	var heading_wrap := MarginContainer.new()
	heading_wrap_size(heading_wrap)
	heading_wrap.add_child(heading)
	nav.add_child(heading_wrap)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	nav.add_child(spacer)

	for item in ["NEW MISSION", "MISSIONS", "SANDBOX", "SETTINGS", "EXIT GAME"]:
		var button := _menu_button(item)
		if item == "EXIT GAME":
			button.pressed.connect(_exit_game)
		else:
			button.pressed.connect(_open_page.bind(item.to_lower().replace(" ", "_")))
		nav.add_child(button)

	var stats := _panel()
	stats.anchor_left = 0.66
	stats.anchor_right = 0.98
	stats.anchor_top = 0.26
	stats.anchor_bottom = 0.70
	body.add_child(stats)
	var stats_content := VBoxContainer.new()
	stats_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_content.add_theme_constant_override("separation", 0)
	stats.add_child(stats_content)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	stats_content.add_child(margin)
	var stat_stack := VBoxContainer.new()
	stat_stack.add_theme_constant_override("separation", 7)
	margin.add_child(stat_stack)
	stat_stack.add_child(_label("MISSION RECORD", 11, ACCENT))
	var successful_missions := 0
	for completed in MissionState.mission_history:
		if completed.get("success", false):
			successful_missions += 1
	var total := _stat_row("TOTAL MISSIONS", "%02d" % MissionState.mission_history.size(), TEXT)
	stat_stack.add_child(total)
	var divider := ColorRect.new()
	divider.color = Color(BORDER, 0.9)
	divider.custom_minimum_size.y = 1
	stat_stack.add_child(divider)
	var success := _stat_row("SUCCESSFUL", "%02d" % successful_missions, GREEN)
	stat_stack.add_child(success)

	var footer := _label("SYSTEMS NOMINAL     •     ORBITAL VIEW ACTIVE", 10, Color(MUTED, 0.8))
	footer.anchor_left = 0.055
	footer.anchor_right = 0.945
	footer.anchor_top = 0.93
	footer.anchor_bottom = 0.97
	root.add_child(footer)
	_animate_page_in()

func _open_page(page: String) -> void:
	match page:
		"new_mission":
			_show_mission_picker()
		"missions":
			_show_missions()
		"sandbox":
			_open_sandbox()
		"settings":
			_show_settings()

func _exit_game() -> void:
	get_tree().quit()

func _show_mission_picker(preserve_selection: bool = false) -> void:
	current_page = "new_mission"
	if not preserve_selection:
		selected_mission_index = -1
	mission_cards.clear()
	_clear_body()

	var heading := _label("SELECT MISSION", 24, TEXT)
	_set_font_size(heading, 24)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.62
	heading.anchor_top = 0.0
	heading.anchor_bottom = 0.075
	body.add_child(heading)
	var subheading := _label("Choose an operation to review its mission profile.", 12, MUTED)
	subheading.anchor_left = 0.025
	subheading.anchor_right = 0.66
	subheading.anchor_top = 0.065
	subheading.anchor_bottom = 0.11
	body.add_child(subheading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.anchor_left = 0.025
	grid.anchor_right = 0.665
	grid.anchor_top = 0.14
	grid.anchor_bottom = 0.98
	body.add_child(grid)
	for i in MISSIONS.size():
		var card := _build_mission_card(i)
		mission_cards.append(card)
		grid.add_child(card)

	var detail_panel := _panel()
	detail_panel.anchor_left = 0.69
	detail_panel.anchor_right = 0.99
	detail_panel.anchor_top = 0.14
	detail_panel.anchor_bottom = 0.98
	body.add_child(detail_panel)
	var details := Control.new()
	details.name = "MissionDetails"
	details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_panel.add_child(details)
	_refresh_mission_details(details)
	_animate_page_in()

func _build_mission_card(index: int) -> Button:
	var mission: Dictionary = MISSIONS[index]
	var button := Button.new()
	button.name = "MissionCard_" + str(mission["id"])
	button.custom_minimum_size = Vector2(0, 0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _mission_card_style(index, false, false))
	button.add_theme_stylebox_override("hover", _mission_card_style(index, false, true))
	button.add_theme_stylebox_override("pressed", _mission_card_style(index, true, true))
	button.add_theme_stylebox_override("focus", _mission_card_style(index, index == selected_mission_index, true))
	button.add_theme_stylebox_override("disabled", _mission_card_style(index, false, false))
	button.pressed.connect(_select_mission.bind(index))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)
	var art := MissionCardArt.new()
	art.mission_kind = mission["art"]
	art.custom_minimum_size = Vector2(0, 76)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(art)
	var title := _label(mission["name"], 13, TEXT)
	_set_font_size(title, 13)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)
	var description := _label(mission["description"], 11, MUTED)
	_set_font_size(description, 11)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 27
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(description)
	var difficulty := HBoxContainer.new()
	difficulty.add_theme_constant_override("separation", 8)
	difficulty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	difficulty.add_child(_label("DIFFICULTY", 9, Color(MUTED, 0.8)))
	difficulty.add_child(_label(mission["difficulty"], 9, _difficulty_color(mission["difficulty"])))
	stack.add_child(difficulty)
	return button

func _select_mission(index: int) -> void:
	selected_mission_index = index
	for i in mission_cards.size():
		var selected := i == index
		mission_cards[i].add_theme_stylebox_override("normal", _mission_card_style(i, selected, false))
		mission_cards[i].add_theme_stylebox_override("hover", _mission_card_style(i, selected, true))
		mission_cards[i].add_theme_stylebox_override("pressed", _mission_card_style(i, true, true))
	var details := body.find_child("MissionDetails", true, false) as Control
	if is_instance_valid(details):
		_refresh_mission_details(details)

func _refresh_mission_details(details: Control) -> void:
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 14)
	details.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("MISSION PROFILE", 10, ACCENT))
	if selected_mission_index < 0:
		var prompt := _label("Select a mission", 21, TEXT)
		_set_font_size(prompt, 21)
		stack.add_child(prompt)
		stack.add_child(_label("Mission details and launch parameters will appear here.", 12, MUTED))
	else:
		var mission: Dictionary = MISSIONS[selected_mission_index]
		var title := _label(mission["name"], 16, TEXT)
		_set_font_size(title, 16)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(title)
		var art := MissionCardArt.new()
		art.mission_kind = mission["art"]
		art.custom_minimum_size = Vector2(0, 94)
		art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(art)
		stack.add_child(_label("MISSION OBJECTIVE", 9, ACCENT))
		var objective := _label(mission["objective"], 11, MUTED)
		_set_font_size(objective, 11)
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective.custom_minimum_size.y = 51
		stack.add_child(objective)
		var rule := ColorRect.new()
		rule.color = Color(BORDER, 0.9)
		rule.custom_minimum_size.y = 1
		stack.add_child(rule)
		stack.add_child(_detail_row("TARGET BODY", mission["target"]))
		var planetary_facts := _planet_facts_panel(str(mission["target"]))
		if planetary_facts != null:
			stack.add_child(planetary_facts)
		stack.add_child(_detail_row("EST. DURATION", mission["duration"]))
		stack.add_child(_detail_row("STARTING BUDGET", mission["budget"]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(88, 42)
	_apply_button_style(back, false)
	back.pressed.connect(_show_home)
	actions.add_child(back)
	continue_button = Button.new()
	continue_button.text = "CONTINUE   →"
	continue_button.custom_minimum_size = Vector2(0, 42)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.disabled = selected_mission_index < 0
	continue_button.add_theme_stylebox_override("normal", _style(Color("123047"), ACCENT, 1, 4))
	continue_button.add_theme_stylebox_override("hover", _style(Color("194561"), Color("78d5fa"), 1, 4))
	continue_button.add_theme_stylebox_override("pressed", _style(Color("0c2638"), ACCENT, 1, 4))
	continue_button.add_theme_stylebox_override("disabled", _style(Color("0c1723"), Color("1c2a37"), 1, 4))
	continue_button.add_theme_color_override("font_color", TEXT)
	continue_button.add_theme_color_override("font_hover_color", Color.WHITE)
	continue_button.add_theme_color_override("font_disabled_color", Color("627181"))
	continue_button.pressed.connect(_continue_selected_mission)
	actions.add_child(continue_button)
	stack.add_child(actions)

func _detail_row(caption: String, value: String) -> Control:
	var row := HBoxContainer.new()
	var key := _label(caption, 9, MUTED)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var content := _label(value, 12, TEXT)
	content.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(key)
	row.add_child(content)
	return row

func _planet_facts_panel(target: String) -> Control:
	var facts: Dictionary = MissionState.planetary_facts(target)
	if facts.is_empty():
		return null
	var metadata: Dictionary = MissionState.nasa_planetary_data.get("fields", {})
	var panel := PanelContainer.new()
	panel.name = "PlanetFactsPanel"
	panel.add_theme_stylebox_override("panel", _style(Color("071522", 0.88), BORDER, 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	stack.add_child(_label("NASA FACT SHEET  /  METRIC  /  SOURCE VALUES", 8, ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	stack.add_child(grid)
	for field_id in ["diameter", "mass", "surface_gravity", "escape_velocity", "rotation_period", "length_of_day", "density"]:
		var field: Dictionary = metadata[field_id]
		var source_values: Dictionary = facts.get("source_display", {})
		var value_text: String = str(source_values.get(field_id, facts[field_id]))
		var row := _detail_row(str(field["label"]).to_upper(), "%s %s" % [value_text, field["unit"]])
		row.custom_minimum_size.y = 18
		grid.add_child(row)
	var footer := _label("NASA/NSSDCA  •  UPDATED %s  •  ACCESSED %s" % [MissionState.nasa_planetary_data.get("source_last_updated", "—"), MissionState.nasa_planetary_data.get("accessed_utc_date", "—")], 7, MUTED)
	stack.add_child(footer)
	var definitions := _label("Gravity: equator (gas giants: 1-bar level)  •  Negative rotation: retrograde  •  Day length is solar, not sidereal rotation.", 7, MUTED)
	definitions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(definitions)
	return panel

func _planet_facts_dialog(target: String) -> void:
	var facts: Dictionary = MissionState.planetary_facts(target)
	if facts.is_empty():
		return
	var metadata: Dictionary = MissionState.nasa_planetary_data.get("fields", {})
	var lines := PackedStringArray(["NASA PLANETARY FACT SHEET — METRIC", "Source values shown at the published precision. No conversions applied.", ""])
	for field_id in ["diameter", "mass", "density", "surface_gravity", "escape_velocity", "rotation_period", "length_of_day"]:
		var field: Dictionary = metadata[field_id]
		var source_values: Dictionary = facts.get("source_display", {})
		lines.append("%s: %s %s" % [field["label"], source_values.get(field_id, facts[field_id]), field["unit"]])
	lines.append("\nSource updated %s • Accessed %s" % [MissionState.nasa_planetary_data.get("source_last_updated", "—"), MissionState.nasa_planetary_data.get("accessed_utc_date", "—")])
	var dialog := AcceptDialog.new()
	dialog.title = "%s  /  NASA PLANETARY DATA" % facts["name"].to_upper()
	dialog.dialog_text = "\n".join(lines)
	dialog.min_size = Vector2i(540, 360)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func _mission_card_style(_index: int, selected: bool, hovered: bool) -> StyleBoxFlat:
	var fill := Color("102a40") if selected else PANEL
	if hovered:
		fill = Color("15354c") if selected else PANEL_HOVER
	var border := ACCENT if selected or hovered else BORDER
	return _style(fill, border, 2 if selected else 1, 6)

func _difficulty_color(difficulty: String) -> Color:
	match difficulty:
		"STANDARD": return GREEN
		"ADVANCED": return ACCENT
		"CHALLENGING": return Color("f2b766")
		_: return Color("eb8b82")

func _continue_selected_mission() -> void:
	if selected_mission_index < 0:
		return
	MissionState.set_selected_mission(MISSIONS[selected_mission_index])
	MissionState.begin_spacecraft_design()
	_show_spacecraft_design()

func _show_spacecraft_design() -> void:
	current_page = "spacecraft_design"
	_clear_body()
	design_resource_labels.clear()
	design_component_buttons.clear()
	required_component_labels.clear()
	var mission: Dictionary = MissionState.selected_mission
	var heading := _label("SPACECRAFT DESIGN", 22, TEXT)
	_set_font_size(heading, 22)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.6
	heading.anchor_top = 0.0
	heading.anchor_bottom = 0.06
	body.add_child(heading)
	var mission_line := _label("SANDBOX CONFIGURATION" if MissionState.sandbox_mode else "MISSION  /  %s     •     TARGET  /     %s" % [mission.get("name", "MISSION"), mission.get("target", "UNKNOWN")], 10, ACCENT)
	mission_line.anchor_left = 0.025
	mission_line.anchor_right = 0.96
	mission_line.anchor_top = 0.057
	mission_line.anchor_bottom = 0.095
	body.add_child(mission_line)

	var resource_strip := HBoxContainer.new()
	resource_strip.anchor_left = 0.025
	resource_strip.anchor_right = 0.99
	resource_strip.anchor_top = 0.105
	resource_strip.anchor_bottom = 0.22
	resource_strip.add_theme_constant_override("separation", 9)
	body.add_child(resource_strip)
	for item in [["budget", "AVAILABLE BUDGET"], ["mass", "SPACECRAFT MASS"], ["power", "POWER BALANCE"], ["data", "SCIENCE DATA"]]:
		resource_strip.add_child(_design_resource_card(item[0], item[1]))

	var requirements_panel := _panel()
	requirements_panel.anchor_left = 0.025
	requirements_panel.anchor_right = 0.22
	requirements_panel.anchor_top = 0.245
	requirements_panel.anchor_bottom = 0.99
	body.add_child(requirements_panel)
	_build_mission_requirements(requirements_panel)

	var preview_panel := _panel()
	preview_panel.anchor_left = 0.235
	preview_panel.anchor_right = 0.685
	preview_panel.anchor_top = 0.245
	preview_panel.anchor_bottom = 0.99
	body.add_child(preview_panel)
	_build_craft_preview(preview_panel)
	craft_preview_rect = preview_panel

	var equipment_panel := _panel()
	equipment_panel.anchor_left = 0.70
	equipment_panel.anchor_right = 0.99
	equipment_panel.anchor_top = 0.245
	equipment_panel.anchor_bottom = 0.99
	body.add_child(equipment_panel)
	_build_equipment_list(equipment_panel)
	_refresh_design_indicators()
	_rebuild_craft_preview()
	_animate_page_in()

func _design_resource_card(key: String, caption: String) -> PanelContainer:
	var card := _panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	card.add_child(stack)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 3)
	stack.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 1)
	margin.add_child(content)
	content.add_child(_label(caption, 8, MUTED))
	var value := _label("—", 13, TEXT)
	_set_font_size(value, 13)
	content.add_child(value)
	var detail := _label("", 8, ACCENT)
	_set_font_size(detail, 10)
	content.add_child(detail)
	design_resource_labels[key] = {"value": value, "detail": detail}
	return card

func _build_mission_requirements(panel: PanelContainer) -> void:
	var margin := _page_margin()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	var mission: Dictionary = MissionState.selected_mission
	stack.add_child(_label("MISSION REQUIREMENTS", 9, ACCENT))
	var task := _label(mission.get("objective", ""), 10, MUTED)
	_set_font_size(task, 10)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task.custom_minimum_size.y = 72
	stack.add_child(task)
	var divider := ColorRect.new()
	divider.color = Color(BORDER, 0.9)
	divider.custom_minimum_size.y = 1
	stack.add_child(divider)
	stack.add_child(_label("REQUIRED SYSTEMS", 8, MUTED))
	for component_id in mission.get("required_components", []):
		var component: Dictionary = MissionState.COMPONENTS[component_id]
		var label := _label("", 9, GREEN)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.y = 19
		stack.add_child(label)
		required_component_labels[component_id] = label
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	var helper := _label("All required systems must be installed before continuing.", 9, MUTED)
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(helper)

func _build_craft_preview(panel: PanelContainer) -> void:
	var preview_root := Control.new()
	preview_root.name = "CraftPreviewRoot"
	preview_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(preview_root)
	var host := SubViewportContainer.new()
	host.name = "CraftViewportContainer"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.stretch = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(host)
	craft_viewport = SubViewport.new()
	craft_viewport.name = "CraftViewport"
	craft_viewport.size = Vector2i(800, 640)
	craft_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	craft_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	craft_viewport.own_world_3d = true
	craft_viewport.transparent_bg = false
	host.add_child(craft_viewport)
	craft_scene_root = Node3D.new()
	craft_scene_root.name = "CraftPreviewWorld"
	craft_viewport.add_child(craft_scene_root)
	var preview_world := WorldEnvironment.new()
	var preview_env := Environment.new()
	preview_env.background_mode = Environment.BG_COLOR
	preview_env.background_color = Color("071522")
	preview_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	preview_env.ambient_light_color = Color("8daec9")
	preview_env.ambient_light_energy = 0.62
	preview_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	preview_world.environment = preview_env
	craft_scene_root.add_child(preview_world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -28, -8)
	light.light_color = Color("d5e9ff")
	light.light_energy = 2.4
	light.shadow_enabled = true
	light.light_cull_mask = 0xFFFFF
	craft_scene_root.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(3, -1.0, 3.5)
	fill.light_color = Color("2689c7")
	fill.light_energy = 1.2
	fill.omni_range = 10.0
	fill.light_cull_mask = 0xFFFFF
	craft_scene_root.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-3.5, 2.2, -2.5)
	rim.light_color = Color("57c8ef")
	rim.light_energy = 1.45
	rim.omni_range = 9.0
	rim.light_cull_mask = 0xFFFFF
	craft_scene_root.add_child(rim)
	var camera := Camera3D.new()
	camera.position = Vector3(3.5, 2.5, 5.6)
	camera.fov = 38.0
	camera.cull_mask = 2
	camera.current = true
	craft_scene_root.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.make_current()
	var badge := _label("LIVE CONFIGURATION  /  3D PREVIEW", 8, ACCENT)
	badge.anchor_left = 0.04
	badge.anchor_right = 0.96
	badge.anchor_top = 0.025
	badge.anchor_bottom = 0.07
	preview_root.add_child(badge)
	var caption := _label("ORBITAL VEHICLE", 9, Color(MUTED, 0.85))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.anchor_left = 0.1
	caption.anchor_right = 0.9
	caption.anchor_top = 0.92
	caption.anchor_bottom = 0.97
	preview_root.add_child(caption)

func _build_equipment_list(panel: PanelContainer) -> void:
	var root_content := Control.new()
	root_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(root_content)
	var title := _label("EQUIPMENT", 10, ACCENT)
	title.anchor_left = 0.045
	title.anchor_right = 0.955
	title.anchor_top = 0.02
	title.anchor_bottom = 0.075
	root_content.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.035
	scroll.anchor_right = 0.965
	scroll.anchor_top = 0.09
	scroll.anchor_bottom = 0.81
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	for component_id in MissionState.COMPONENTS:
		list.add_child(_build_component_row(component_id))
	var warning := _label("", 9, Color("f2b766"))
	warning.name = "DesignWarning"
	warning.anchor_left = 0.045
	warning.anchor_right = 0.955
	warning.anchor_top = 0.815
	warning.anchor_bottom = 0.91
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_content.add_child(warning)
	var continue_design := Button.new()
	design_continue_button = continue_design
	continue_design.name = "ContinueDesign"
	continue_design.text = "SAVE SANDBOX DESIGN" if MissionState.sandbox_mode else "SAVE & SELECT ROCKET  →"
	continue_design.anchor_left = 0.045
	continue_design.anchor_right = 0.955
	continue_design.anchor_top = 0.92
	continue_design.anchor_bottom = 0.985
	_set_font_size(continue_design, 10)
	continue_design.add_theme_stylebox_override("normal", _style(Color("123047"), ACCENT, 1, 4))
	continue_design.add_theme_stylebox_override("hover", _style(Color("194561"), Color("78d5fa"), 1, 4))
	continue_design.add_theme_stylebox_override("disabled", _style(Color("0c1723"), Color("1c2a37"), 1, 4))
	continue_design.add_theme_color_override("font_color", TEXT)
	continue_design.add_theme_color_override("font_disabled_color", Color("627181"))
	continue_design.pressed.connect(_continue_to_flight_plan)
	root_content.add_child(continue_design)
	var back := Button.new()
	back.text = "← BACK"
	back.anchor_left = 0.045
	back.anchor_right = 0.29
	back.anchor_top = 0.02
	back.anchor_bottom = 0.075
	_apply_button_style(back, false)
	if MissionState.sandbox_mode:
		back.pressed.connect(_show_sandbox)
	else:
		back.pressed.connect(_show_mission_picker.bind(true))
	title.anchor_left = 0.34
	title.anchor_right = 0.955
	root_content.add_child(back)

func _build_component_row(component_id: String) -> Control:
	var component: Dictionary = MissionState.COMPONENTS[component_id]
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 65)
	row.add_theme_stylebox_override("panel", _style(Color("071522", 0.92), BORDER, 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	margin.add_child(line)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 0)
	line.add_child(text_column)
	var name := _label(component["name"], 9, TEXT)
	_set_font_size(name, 10)
	text_column.add_child(name)
	var description := _label(component["description"], 8, MUTED)
	_set_font_size(description, 10)
	description.clip_text = true
	if component.has("technical_reference"):
		description.tooltip_text = component["description"] + "\n\n" + component["technical_reference"] + "\n\nGame balance values are hypothetical, not NASA hardware specifications."
	text_column.add_child(description)
	var metrics := _label("$%dM  •  %d kg  •  %sW  •  %d GB/d" % [component["cost_m"], component["mass_kg"], _signed_number(component["power_w"]), component["data_gb_day"]], 8, ACCENT)
	_set_font_size(metrics, 10)
	text_column.add_child(metrics)
	if component["battery_wh"] > 0:
		metrics.text += "  •  %d Wh" % component["battery_wh"]
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(56, 28)
	_set_font_size(toggle, 10)
	toggle.pressed.connect(_toggle_design_component.bind(component_id))
	_configure_component_toggle(toggle, MissionState.active_components.has(component_id))
	line.add_child(toggle)
	design_component_buttons[component_id] = toggle
	return row

func _toggle_design_component(component_id: String) -> void:
	var summary: Dictionary = MissionState.toggle_component(component_id)
	var toggle: Button = design_component_buttons[component_id]
	var installed: bool = MissionState.active_components.has(component_id)
	_configure_component_toggle(toggle, installed)
	_refresh_design_indicators(summary)
	_rebuild_craft_preview()

func _configure_component_toggle(toggle: Button, installed: bool) -> void:
	toggle.text = "REMOVE" if installed else "ADD"
	toggle.add_theme_stylebox_override("normal", _style(Color("123047") if installed else PANEL, ACCENT if installed else BORDER, 1, 3))
	toggle.add_theme_stylebox_override("hover", _style(Color("194561"), ACCENT, 1, 3))
	toggle.add_theme_stylebox_override("pressed", _style(Color("0c2638"), ACCENT, 1, 3))
	toggle.add_theme_color_override("font_color", TEXT if installed else MUTED)
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)

func _refresh_design_indicators(summary: Dictionary = {}) -> void:
	if summary.is_empty():
		summary = MissionState.calculate_design()
	var labels: Dictionary = design_resource_labels
	if labels.has("budget"):
		labels["budget"]["value"].text = "%s / %s" % [_format_budget(summary["budget_remaining_m"]), _format_budget(summary["budget_limit_m"])]
		labels["budget"]["detail"].text = "COST  %s" % _format_budget(summary["cost_m"])
		labels["budget"]["value"].add_theme_color_override("font_color", Color("eb8b82") if summary["budget_remaining_m"] < 0 else TEXT)
		labels["mass"]["value"].text = "%d / %d KG" % [summary["mass_kg"], summary["mass_limit_kg"]]
		labels["mass"]["detail"].text = "TOTAL INSTALLED MASS"
		labels["mass"]["value"].add_theme_color_override("font_color", Color("eb8b82") if summary["mass_kg"] > summary["mass_limit_kg"] else TEXT)
		labels["power"]["value"].text = "%dW GEN  /  %dW LOAD" % [summary["power_generation_w"], summary["power_load_w"]]
		labels["power"]["detail"].text = "NET  %+dW" % summary["power_net_w"]
		labels["power"]["value"].add_theme_color_override("font_color", Color("eb8b82") if summary["power_net_w"] < 0 else TEXT)
		labels["data"]["value"].text = "%d / %d GB/DAY" % [summary["data_capacity_gb_day"], summary["data_requirement_gb_day"]]
		labels["data"]["detail"].text = "MISSION MINIMUM"
		labels["data"]["value"].add_theme_color_override("font_color", Color("eb8b82") if summary["data_capacity_gb_day"] < summary["data_requirement_gb_day"] else TEXT)
	for component_id in required_component_labels:
		var installed: bool = MissionState.active_components.has(component_id)
		var component: Dictionary = MissionState.COMPONENTS[component_id]
		required_component_labels[component_id].text = ("✓  " if installed else "!  ") + component["name"]
		required_component_labels[component_id].add_theme_color_override("font_color", GREEN if installed else Color("f2b766"))
	var warning := body.find_child("DesignWarning", true, false) as Label
	var continue_design := body.find_child("ContinueDesign", true, false) as Button
	if is_instance_valid(warning):
		if summary["warnings"].is_empty():
			warning.text = "DESIGN WITHIN MISSION LIMITS"
			warning.add_theme_color_override("font_color", GREEN)
		else:
			warning.text = "  •  ".join(summary["warnings"])
			warning.add_theme_color_override("font_color", Color("f2b766"))
	if is_instance_valid(continue_design):
		continue_design.disabled = not summary["valid"]

func _rebuild_craft_preview() -> void:
	if not is_instance_valid(craft_viewport) or not is_instance_valid(craft_scene_root):
		return
	if is_instance_valid(craft_model):
		craft_scene_root.remove_child(craft_model)
		craft_model.queue_free()
	craft_model = Node3D.new()
	craft_model.name = "ConfiguredSpacecraft"
	craft_scene_root.add_child(craft_model)
	var installed: Array = MissionState.active_components
	if installed.has("structure"):
		_add_craft_box("MainBus", Vector3(0.72, 0.36, 1.0), Vector3.ZERO, Color("b6c3ce"), 0.72)
		_add_craft_box("NoseCap", Vector3(0.46, 0.20, 0.18), Vector3(0, 0.02, -0.56), Color("d7e1e8"), 0.64)
		_add_craft_box("ServiceBand", Vector3(0.76, 0.08, 0.12), Vector3(0, 0.02, -0.22), Color("d69149"), 0.52)
		_add_craft_box("BusRailL", Vector3(0.045, 0.29, 0.92), Vector3(-0.37, 0, 0.015), Color("7d8d9b"), 0.58)
		_add_craft_box("BusRailR", Vector3(0.045, 0.29, 0.92), Vector3(0.37, 0, 0.015), Color("7d8d9b"), 0.58)
	if installed.has("solar_panels"):
		_add_craft_box("SolarBoomL", Vector3(0.76, 0.045, 0.07), Vector3(-0.80, 0.0, 0), Color("8295a7"), 0.7)
		_add_craft_box("SolarBoomR", Vector3(0.76, 0.045, 0.07), Vector3(0.80, 0.0, 0), Color("8295a7"), 0.7)
		_add_craft_box("SolarHingeL", Vector3(0.10, 0.10, 0.13), Vector3(-1.15, 0.0, 0), Color("d09a53"), 0.42)
		_add_craft_box("SolarHingeR", Vector3(0.10, 0.10, 0.13), Vector3(1.15, 0.0, 0), Color("d09a53"), 0.42)
		_add_craft_box("SolarPanelL", Vector3(0.68, 0.035, 0.50), Vector3(-1.43, 0.0, 0), Color("153f70"), 0.48)
		_add_craft_box("SolarPanelR", Vector3(0.68, 0.035, 0.50), Vector3(1.43, 0.0, 0), Color("153f70"), 0.48)
		_add_craft_panel_cells(-1.43)
		_add_craft_panel_cells(1.43)
	if installed.has("battery"):
		_add_craft_box("Battery", Vector3(0.28, 0.22, 0.32), Vector3(0.49, -0.25, 0.12), Color("38a6c9"), 0.42)
	if installed.has("communication_antenna"):
		_add_craft_box("AntennaMast", Vector3(0.045, 0.42, 0.045), Vector3(0.0, 0.36, 0.27), Color("ccd4dc"), 0.7)
		_add_craft_dish("CommunicationDish", Vector3(0, 0.60, 0.27), 0.22, Color("d7dde2"))
	if installed.has("onboard_computer"):
		_add_craft_box("ComputerModule", Vector3(0.34, 0.16, 0.30), Vector3(-0.43, 0.20, 0.12), Color("d59a4b"), 0.58)
	if installed.has("scientific_camera"):
		_add_craft_cylinder("CameraBarrel", Vector3(0.0, -0.20, -0.61), 0.12, 0.28, Color("899dad"), PI * 0.5)
		_add_craft_cylinder("CameraLens", Vector3(0.0, -0.20, -0.77), 0.085, 0.035, Color("45a8e8"), PI * 0.5)
	if installed.has("radar"):
		_add_craft_box("RadarMast", Vector3(0.05, 0.42, 0.05), Vector3(0.42, 0.36, 0.24), Color("c6d0d9"), 0.7)
		_add_craft_dish("RadarReflector", Vector3(0.42, 0.61, 0.24), 0.32, Color("e0e5e9"))
	if installed.has("spectrometer"):
		_add_craft_box("Spectrometer", Vector3(0.28, 0.20, 0.37), Vector3(-0.34, -0.28, -0.27), Color("bd7049"), 0.62)
		_add_craft_cylinder("SpectrometerOptics", Vector3(-0.34, -0.28, -0.49), 0.10, 0.08, Color("e6ad57"), PI * 0.5)

func _add_craft_box(node_name: String, dimensions: Vector3, position: Vector3, color: Color, roughness: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.layers = 2
	instance.material_override = _craft_material(color, roughness)
	craft_model.add_child(instance)

func _add_craft_panel_cells(x_position: float) -> void:
	for i in range(1, 4):
		_add_craft_box("PanelCell_%s_%d" % [str(x_position), i], Vector3(0.68, 0.04, 0.012), Vector3(x_position, 0.025, -0.25 + float(i) * 0.125), Color("4e91c5"), 0.4)

func _add_craft_dish(node_name: String, position: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.92
	mesh.height = 0.035
	mesh.radial_segments = 32
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation.x = PI * 0.5
	instance.layers = 2
	instance.material_override = _craft_material(color, 0.32)
	craft_model.add_child(instance)
	_add_craft_cylinder(node_name + "Feed", position + Vector3(0, 0, 0.07), 0.025, 0.15, Color("d59a4b"), PI * 0.5)

func _add_craft_cylinder(node_name: String, position: Vector3, radius: float, height: float, color: Color, rotation_x: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation.x = rotation_x
	instance.layers = 2
	instance.material_override = _craft_material(color, 0.35)
	craft_model.add_child(instance)

func _craft_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = roughness
	return material

func _signed_number(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)

func _format_budget(value_millions: int) -> String:
	if value_millions < 0:
		return "-" + _format_budget(absi(value_millions))
	if value_millions >= 1000 and value_millions % 1000 == 0:
		return "$%dB" % (value_millions / 1000)
	if value_millions >= 1000:
		return "$%.1fB" % (float(value_millions) / 1000.0)
	return "$%dM" % value_millions

func _continue_to_flight_plan() -> void:
	if not MissionState.calculate_design().get("valid", false):
		return
	var saved_design := MissionState.save_spacecraft_design()
	if saved_design.get("valid", false):
		if MissionState.sandbox_mode:
			_show_sandbox()
			return
		MissionState.begin_launch_selection()
		_show_rocket_orbit_selection()

func _show_rocket_orbit_selection() -> void:
	current_page = "rocket_orbit_selection"
	_clear_body()
	rocket_cards.clear()
	orbit_buttons.clear()
	launch_resource_labels.clear()
	var mission: Dictionary = MissionState.selected_mission
	var heading := _label("ROCKET & ORBIT SELECTION", 21, TEXT)
	_set_font_size(heading, 21)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.70
	heading.anchor_top = 0.0
	heading.anchor_bottom = 0.06
	body.add_child(heading)
	var mission_line := _label("MISSION  /  %s     •     TARGET  /  %s" % [mission.get("name", "MISSION"), mission.get("target", "UNKNOWN")], 10, ACCENT)
	mission_line.anchor_left = 0.025
	mission_line.anchor_right = 0.96
	mission_line.anchor_top = 0.057
	mission_line.anchor_bottom = 0.095
	body.add_child(mission_line)
	var resource_strip := HBoxContainer.new()
	resource_strip.anchor_left = 0.025
	resource_strip.anchor_right = 0.99
	resource_strip.anchor_top = 0.105
	resource_strip.anchor_bottom = 0.21
	resource_strip.add_theme_constant_override("separation", 9)
	body.add_child(resource_strip)
	for item in [["budget", "MISSION FUNDS"], ["capacity", "LAUNCH CAPACITY"], ["orbit", "MISSION PROFILE"]]:
		resource_strip.add_child(_launch_resource_card(item[0], item[1]))

	var rocket_panel := _panel()
	rocket_panel.anchor_left = 0.025
	rocket_panel.anchor_right = 0.49
	rocket_panel.anchor_top = 0.235
	rocket_panel.anchor_bottom = 0.875
	body.add_child(rocket_panel)
	var rocket_title := _label("ROCKET SELECTION", 10, ACCENT)
	rocket_title.anchor_left = 0.035
	rocket_title.anchor_right = 0.97
	rocket_title.anchor_top = 0.025
	rocket_title.anchor_bottom = 0.095
	rocket_panel.add_child(rocket_title)
	var rocket_list := VBoxContainer.new()
	rocket_list.anchor_left = 0.025
	rocket_list.anchor_right = 0.975
	rocket_list.anchor_top = 0.115
	rocket_list.anchor_bottom = 0.98
	rocket_list.add_theme_constant_override("separation", 7)
	rocket_panel.add_child(rocket_list)
	for rocket_id in ["light", "medium", "heavy"]:
		var card := _build_rocket_card(rocket_id)
		rocket_cards[rocket_id] = card
		rocket_list.add_child(card)

	var orbit_panel := _panel()
	orbit_panel.anchor_left = 0.51
	orbit_panel.anchor_right = 0.99
	orbit_panel.anchor_top = 0.235
	orbit_panel.anchor_bottom = 0.875
	body.add_child(orbit_panel)
	_build_orbit_section(orbit_panel)

	var back := Button.new()
	back.text = "←   BACK TO SPACECRAFT DESIGN"
	back.anchor_left = 0.025
	back.anchor_right = 0.28
	back.anchor_top = 0.895
	back.anchor_bottom = 0.985
	_set_font_size(back, 10)
	_apply_button_style(back, false)
	back.pressed.connect(_show_spacecraft_design)
	body.add_child(back)
	var launch_warning := _label("", 9, Color("f2b766"))
	launch_warning.name = "LaunchWarning"
	launch_warning.anchor_left = 0.30
	launch_warning.anchor_right = 0.70
	launch_warning.anchor_top = 0.90
	launch_warning.anchor_bottom = 0.98
	launch_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	launch_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	launch_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(launch_warning)
	launch_next_button = Button.new()
	launch_next_button.name = "LaunchNext"
	launch_next_button.text = "NEXT  →"
	launch_next_button.anchor_left = 0.80
	launch_next_button.anchor_right = 0.99
	launch_next_button.anchor_top = 0.895
	launch_next_button.anchor_bottom = 0.985
	_set_font_size(launch_next_button, 12)
	launch_next_button.add_theme_stylebox_override("normal", _style(Color("123047"), ACCENT, 1, 4))
	launch_next_button.add_theme_stylebox_override("hover", _style(Color("194561"), Color("78d5fa"), 1, 4))
	launch_next_button.add_theme_stylebox_override("disabled", _style(Color("0c1723"), Color("1c2a37"), 1, 4))
	launch_next_button.add_theme_color_override("font_color", TEXT)
	launch_next_button.add_theme_color_override("font_disabled_color", Color("627181"))
	launch_next_button.pressed.connect(_continue_launch_selection)
	body.add_child(launch_next_button)
	_update_launch_selection_ui()
	_animate_page_in()

func _launch_resource_card(key: String, caption: String) -> PanelContainer:
	var card := _panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	card.add_child(stack)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 3)
	stack.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 1)
	margin.add_child(content)
	content.add_child(_label(caption, 8, MUTED))
	var value := _label("—", 13, TEXT)
	_set_font_size(value, 13)
	content.add_child(value)
	var detail := _label("", 8, ACCENT)
	content.add_child(detail)
	launch_resource_labels[key] = {"value": value, "detail": detail}
	return card

func _build_rocket_card(rocket_id: String) -> Button:
	var rocket: Dictionary = MissionState.ROCKETS[rocket_id]
	var button := Button.new()
	button.name = "Rocket_" + rocket_id
	button.custom_minimum_size = Vector2(0, 104)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _launch_card_style(false, false))
	button.add_theme_stylebox_override("hover", _launch_card_style(false, true))
	button.add_theme_stylebox_override("pressed", _launch_card_style(true, true))
	button.pressed.connect(_on_rocket_selected.bind(rocket_id))
	var viewport_host := SubViewportContainer.new()
	viewport_host.anchor_left = 0.02
	viewport_host.anchor_right = 0.36
	viewport_host.anchor_top = 0.08
	viewport_host.anchor_bottom = 0.92
	viewport_host.stretch = true
	viewport_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(viewport_host)
	var layer_index := 1 if rocket_id == "light" else (2 if rocket_id == "medium" else 3)
	var layer_mask := 1 << layer_index
	var viewport := _create_preview_viewport(viewport_host, Vector2i(300, 180), layer_mask)
	_add_rocket_preview(viewport, rocket_id, layer_mask)
	var info := VBoxContainer.new()
	info.anchor_left = 0.39
	info.anchor_right = 0.97
	info.anchor_top = 0.13
	info.anchor_bottom = 0.89
	info.add_theme_constant_override("separation", 3)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(info)
	var name := _label(rocket["name"], 10, TEXT)
	_set_font_size(name, 10)
	info.add_child(name)
	var capacity := _label("PAYLOAD  /  %d KG" % rocket["capacity_kg"], 9, ACCENT)
	info.add_child(capacity)
	var cost := _label("LAUNCH COST  /  %s" % _format_budget(rocket["cost_m"]), 9, TEXT)
	info.add_child(cost)
	var description := _label(rocket["description"], 8, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(description)
	return button

func _create_preview_viewport(host: SubViewportContainer, preview_size: Vector2i, layer_mask: int) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = preview_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.own_world_3d = false
	viewport.transparent_bg = false
	host.add_child(viewport)
	viewport.world_3d = get_viewport().world_3d
	return viewport

func _add_rocket_preview(viewport: SubViewport, rocket_id: String, layer_mask: int) -> void:
	var preview_root := Node3D.new()
	viewport.add_child(preview_root)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, 35, -10)
	light.light_energy = 2.0
	light.light_cull_mask = 0xFFFFF
	preview_root.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(1.05, 0.72, 3.0)
	camera.fov = 33.0
	camera.cull_mask = layer_mask
	preview_root.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	camera.make_current()
	var scale_factor := 0.75 if rocket_id == "light" else (1.0 if rocket_id == "medium" else 1.3)
	var vehicle := Node3D.new()
	vehicle.name = "RocketModel_" + rocket_id
	preview_root.add_child(vehicle)
	_add_rocket_cylinder(vehicle, "FirstStage", 0.20 * scale_factor, 0.65 * scale_factor, Vector3(0, -0.18 * scale_factor, 0), Color("c1ccd6"), layer_mask)
	_add_rocket_cylinder(vehicle, "UpperStage", 0.135 * scale_factor, 0.42 * scale_factor, Vector3(0, 0.34 * scale_factor, 0), Color("e2e7eb"), layer_mask)
	_add_rocket_cone(vehicle, "PayloadFairing", 0.14 * scale_factor, 0.27 * scale_factor, Vector3(0, 0.685 * scale_factor, 0), Color("d9a04d"), layer_mask)
	_add_rocket_cylinder(vehicle, "InterstageBand", 0.207 * scale_factor, 0.055 * scale_factor, Vector3(0, 0.145 * scale_factor, 0), Color("687b8a"), layer_mask)
	_add_rocket_cylinder(vehicle, "EngineMount", 0.17 * scale_factor, 0.06 * scale_factor, Vector3(0, -0.50 * scale_factor, 0), Color("697985"), layer_mask)
	for engine_index in range(4 if rocket_id == "heavy" else 1):
		var engine_angle := TAU * float(engine_index) / float(4 if rocket_id == "heavy" else 1)
		var engine_position := Vector3(cos(engine_angle) * 0.08, -0.56, sin(engine_angle) * 0.08) * scale_factor
		_add_rocket_cone(vehicle, "EngineBell_%d" % engine_index, 0.052 * scale_factor, 0.16 * scale_factor, engine_position, Color("465764"), layer_mask)
	_add_rocket_cylinder(vehicle, "AvionicsBand", 0.141 * scale_factor, 0.045 * scale_factor, Vector3(0, 0.45 * scale_factor, 0), Color("d08e45"), layer_mask)
	for i in range(3):
		var angle := TAU * float(i) / 3.0
		_add_rocket_box(vehicle, "Fin_%d" % i, Vector3(0.20, 0.045, 0.07) * scale_factor, Vector3(cos(angle) * 0.20 * scale_factor, -0.46 * scale_factor, sin(angle) * 0.20 * scale_factor), Color("b64f3c"), layer_mask)
	for stripe_index in range(2):
		_add_rocket_cylinder(vehicle, "StageMarking_%d" % stripe_index, 0.204 * scale_factor, 0.018 * scale_factor, Vector3(0, -0.30 * scale_factor + float(stripe_index) * 0.22 * scale_factor, 0), Color("e1a85a"), layer_mask)
	if rocket_id == "heavy":
		for side in [-1.0, 1.0]:
			_add_rocket_cylinder(vehicle, "Booster_%s" % str(side), 0.095 * scale_factor, 0.56 * scale_factor, Vector3(side * 0.27 * scale_factor, -0.19 * scale_factor, 0), Color("8e9eab"), layer_mask)

func _add_rocket_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, layer_mask: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = 20
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.layers = layer_mask
	instance.material_override = _launch_material(color, 0.42)
	parent.add_child(instance)

func _add_rocket_cone(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, layer_mask: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.005
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.layers = layer_mask
	instance.material_override = _launch_material(color, 0.35)
	parent.add_child(instance)

func _add_rocket_box(parent: Node3D, node_name: String, dimensions: Vector3, position: Vector3, color: Color, layer_mask: int) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.layers = layer_mask
	instance.material_override = _launch_material(color, 0.5)
	parent.add_child(instance)

func _launch_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = roughness
	return material

func _launch_card_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var fill := Color("102a40") if selected else PANEL
	if hovered:
		fill = Color("15354c") if selected else PANEL_HOVER
	return _style(fill, ACCENT if selected or hovered else BORDER, 2 if selected else 1, 5)

func _build_orbit_section(panel: PanelContainer) -> void:
	var title := _label("ORBIT SELECTION", 10, ACCENT)
	title.anchor_left = 0.035
	title.anchor_right = 0.97
	title.anchor_top = 0.025
	title.anchor_bottom = 0.09
	panel.add_child(title)
	var preview_host := SubViewportContainer.new()
	preview_host.anchor_left = 0.025
	preview_host.anchor_right = 0.975
	preview_host.anchor_top = 0.105
	preview_host.anchor_bottom = 0.445
	preview_host.stretch = true
	preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(preview_host)
	orbit_preview_viewport = _create_preview_viewport(preview_host, Vector2i(700, 260), 1 << 6)
	orbit_preview_root = Node3D.new()
	orbit_preview_root.name = "OrbitPreviewWorld"
	orbit_preview_viewport.add_child(orbit_preview_root)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-26, 40, -8)
	key.light_energy = 2.0
	key.light_cull_mask = 0xFFFFF
	orbit_preview_root.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.8, -0.8, 2.5)
	fill.light_color = Color("438bc8")
	fill.light_energy = 0.7
	fill.omni_range = 8
	fill.light_cull_mask = 0xFFFFF
	orbit_preview_root.add_child(fill)
	var camera := Camera3D.new()
	camera.position = Vector3(3.2, 2.3, 4.7)
	camera.fov = 38
	camera.cull_mask = 1 << 6
	orbit_preview_root.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.make_current()
	var globe_badge := _label("ORBITAL VIEW  /  SELECT A TRAJECTORY", 8, Color("b7d0e4"))
	globe_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe_badge.anchor_left = 0.80
	globe_badge.anchor_right = 0.975
	globe_badge.anchor_top = 0.80
	globe_badge.anchor_bottom = 0.85
	globe_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(globe_badge)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 4)
	grid.anchor_left = 0.025
	grid.anchor_right = 0.975
	grid.anchor_top = 0.47
	grid.anchor_bottom = 0.785
	panel.add_child(grid)
	for orbit_id in ["leo", "sso", "geo", "lunar", "mars", "deep_space"]:
		var orbit: Dictionary = MissionState.ORBITS[orbit_id]
		var choice := Button.new()
		choice.name = "Orbit_" + orbit_id
		choice.text = orbit["name"]
		choice.tooltip_text = "MISSION-COMPATIBLE ORBIT" if MissionState.is_orbit_compatible(orbit_id) else "NOT COMPATIBLE WITH SELECTED MISSION"
		choice.custom_minimum_size = Vector2(0, 44)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_set_font_size(choice, 10)
		choice.clip_text = true
		choice.add_theme_stylebox_override("normal", _launch_card_style(false, false))
		choice.add_theme_stylebox_override("hover", _launch_card_style(false, true))
		choice.add_theme_stylebox_override("pressed", _launch_card_style(true, true))
		choice.pressed.connect(_on_orbit_selected.bind(orbit_id))
		grid.add_child(choice)
		orbit_buttons[orbit_id] = choice
	orbit_detail_root = Control.new()
	orbit_detail_root.name = "OrbitProfileCard"
	orbit_detail_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Attach to the page rather than PanelContainer: PanelContainer allocates its
	# full child rect to content, which previously placed the profile over buttons.
	orbit_detail_root.anchor_left = 0.525
	orbit_detail_root.anchor_right = 0.79
	orbit_detail_root.anchor_top = 0.66
	orbit_detail_root.anchor_bottom = 0.855
	body.add_child(orbit_detail_root)
	_refresh_orbit_details()
	_refresh_orbit_preview()

func _refresh_orbit_details() -> void:
	for child in orbit_detail_root.get_children():
		orbit_detail_root.remove_child(child)
		child.queue_free()
	var orbit: Dictionary = MissionState.ORBITS.get(MissionState.selected_orbit_id, {})
	var card := _panel()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbit_detail_root.add_child(card)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	if orbit.is_empty():
		var prompt := _label("SELECT AN ORBIT TO REVIEW ITS PROFILE.", 10, MUTED)
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(prompt)
		return
	var title := _label(str(orbit["name"]), 10, ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)
	var metadata := _label("%s  •  %s   |   COMMS %d%%  •  OBS %d%%" % [orbit["altitude"], orbit["period"], orbit["communication_pct"], orbit["observation_pct"]], 9, TEXT)
	metadata.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(metadata)
	var advantage := _label("PURPOSE  /  " + orbit["advantage"], 8, GREEN)
	advantage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(advantage)
	var drawback := _label("TRADEOFF  /  " + orbit["drawback"], 8, Color("e7ad75"))
	drawback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(drawback)

func _refresh_orbit_preview() -> void:
	if not is_instance_valid(orbit_preview_root):
		return
	for child in orbit_preview_root.get_children():
		if child.name in ["OrbitTargetBody", "PlanetAtmosphere", "OrbitalPath"]:
			orbit_preview_root.remove_child(child)
			child.queue_free()
	var orbit: Dictionary = MissionState.ORBITS.get(MissionState.selected_orbit_id, {})
	var body_name: String = orbit.get("body", MissionState.selected_mission.get("target", "EARTH"))
	if body_name == "DEEP SPACE":
		body_name = "EARTH" # Deep-space trajectory leaves from Earth; it is not a planetary target.
	var globe_root := Node3D.new()
	globe_root.name = "OrbitTargetBody"
	orbit_preview_root.add_child(globe_root)
	var nasa_model := PlanetAssetLibrary.instantiate_model(body_name, 1.12)
	if nasa_model == null:
		push_error("NASA planet preview model could not be loaded: " + body_name)
		return
	globe_root.add_child(nasa_model)
	_set_planet_preview_layers(nasa_model, 1 << 6)
	if body_name == "EARTH":
		var preview_clouds := PlanetAssetLibrary.add_earth_cloud_layer(globe_root, nasa_model, 1.12)
		if preview_clouds != null:
			preview_clouds.layers = 1 << 6
	orbit_preview_body = globe_root
	var atmosphere := MeshInstance3D.new()
	atmosphere.name = "PlanetAtmosphere"
	var atmosphere_mesh := SphereMesh.new()
	atmosphere_mesh.radius = 1.20
	atmosphere_mesh.height = 2.4
	atmosphere_mesh.radial_segments = 48
	atmosphere_mesh.rings = 24
	atmosphere.mesh = atmosphere_mesh
	atmosphere.layers = 1 << 6
	var atmosphere_material := StandardMaterial3D.new()
	atmosphere_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var atmosphere_color := Color(0.15, 0.5, 0.92, 0.16)
	if body_name == "MARS":
		atmosphere_color = Color(0.9, 0.32, 0.12, 0.13)
	elif body_name == "THE MOON":
		atmosphere_color = Color(0.7, 0.78, 0.9, 0.04)
	atmosphere_material.albedo_color = atmosphere_color
	atmosphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmosphere.material_override = atmosphere_material
	atmosphere.visible = body_name == "EARTH"
	orbit_preview_root.add_child(atmosphere)
	var radius := 1.55
	if MissionState.selected_orbit_id == "geo": radius = 2.08
	elif MissionState.selected_orbit_id == "sso": radius = 1.68
	elif MissionState.selected_orbit_id == "deep_space": radius = 2.38
	var ring_mesh := ImmediateMesh.new()
	ring_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(121):
		var angle := TAU * float(i) / 120.0
		ring_mesh.surface_add_vertex(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	ring_mesh.surface_end()
	var ring := MeshInstance3D.new()
	ring.name = "OrbitalPath"
	ring.mesh = ring_mesh
	ring.rotation_degrees = Vector3(20, 0, 14) if MissionState.selected_orbit_id == "sso" else Vector3(0, 0, 0)
	ring.layers = 1 << 6
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(0.25, 0.75, 1.0, 0.88)
	ring_material.emission_enabled = true
	ring_material.emission = Color("126ea6")
	ring_material.emission_energy_multiplier = 1.2
	ring.material_override = ring_material
	orbit_preview_root.add_child(ring)

func _set_planet_preview_layers(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		_set_planet_preview_layers(child, layer_mask)

func _on_rocket_selected(rocket_id: String) -> void:
	MissionState.select_rocket(rocket_id)
	for id in rocket_cards:
		var button: Button = rocket_cards[id]
		var selected: bool = str(id) == rocket_id
		button.add_theme_stylebox_override("normal", _launch_card_style(selected, false))
		button.add_theme_stylebox_override("hover", _launch_card_style(selected, true))
	_update_launch_selection_ui()

func _on_orbit_selected(orbit_id: String) -> void:
	MissionState.select_orbit(orbit_id)
	for id in orbit_buttons:
		var button: Button = orbit_buttons[id]
		var selected: bool = str(id) == MissionState.selected_orbit_id
		button.add_theme_stylebox_override("normal", _launch_card_style(selected, false))
		button.add_theme_stylebox_override("hover", _launch_card_style(selected, true))
	_refresh_orbit_details()
	_refresh_orbit_preview()
	_update_launch_selection_ui()

func _update_launch_selection_ui() -> void:
	var summary: Dictionary = MissionState.calculate_launch()
	var rocket: Dictionary = MissionState.ROCKETS.get(MissionState.selected_rocket_id, {})
	var orbit: Dictionary = MissionState.ORBITS.get(MissionState.selected_orbit_id, {})
	if launch_resource_labels.has("budget"):
		launch_resource_labels["budget"]["value"].text = "%s / %s" % [_format_budget(summary["budget_remaining_m"]), _format_budget(summary["mission_budget_m"])]
		launch_resource_labels["budget"]["detail"].text = "SPACECRAFT %s  •  ROCKET %s" % [_format_budget(summary["spacecraft_cost_m"]), _format_budget(summary["rocket_cost_m"])]
		launch_resource_labels["budget"]["value"].add_theme_color_override("font_color", Color("eb8b82") if summary["budget_remaining_m"] < 0 else TEXT)
		launch_resource_labels["capacity"]["value"].text = "%d / %s KG" % [summary["spacecraft_mass_kg"], str(rocket.get("capacity_kg", "—"))]
		launch_resource_labels["capacity"]["detail"].text = "PAYLOAD / " + ("%s" % rocket.get("name", "SELECT ROCKET"))
		var capacity_ok: bool = not rocket.is_empty() and int(summary["spacecraft_mass_kg"]) <= int(rocket["capacity_kg"])
		launch_resource_labels["capacity"]["value"].add_theme_color_override("font_color", Color("eb8b82") if not rocket.is_empty() and not capacity_ok else TEXT)
		if orbit.is_empty():
			launch_resource_labels["orbit"]["value"].text = "SELECT COMPATIBLE ORBIT"
			launch_resource_labels["orbit"]["detail"].text = "COMMS / OBSERVATION / DURATION"
		else:
			launch_resource_labels["orbit"]["value"].text = "COMMS %d%%  /  OBS %d%%" % [orbit["communication_pct"], orbit["observation_pct"]]
			launch_resource_labels["orbit"]["detail"].text = "MISSION DURATION ×%.2f" % orbit["duration_factor"]
	var warning: Label = body.find_child("LaunchWarning", true, false)
	if is_instance_valid(warning):
		if summary["warnings"].is_empty():
			warning.text = "LAUNCH PLAN WITHIN MISSION LIMITS"
			warning.add_theme_color_override("font_color", GREEN)
		else:
			warning.text = "  •  ".join(summary["warnings"])
			warning.add_theme_color_override("font_color", Color("f2b766"))
	if is_instance_valid(launch_next_button):
		launch_next_button.disabled = not summary["valid"]
	for rocket_id in rocket_cards:
		var rocket_button: Button = rocket_cards[rocket_id]
		var rocket_selected: bool = str(rocket_id) == MissionState.selected_rocket_id
		rocket_button.add_theme_stylebox_override("normal", _launch_card_style(rocket_selected, false))
		rocket_button.add_theme_stylebox_override("hover", _launch_card_style(rocket_selected, true))
	for orbit_id in orbit_buttons:
		var orbit_button: Button = orbit_buttons[orbit_id]
		var orbit_selected: bool = str(orbit_id) == MissionState.selected_orbit_id
		orbit_button.disabled = not MissionState.is_orbit_compatible(orbit_id)
		orbit_button.add_theme_stylebox_override("normal", _launch_card_style(orbit_selected, false))
		orbit_button.add_theme_stylebox_override("hover", _launch_card_style(orbit_selected, true))

func _format_duration(days: int) -> String:
	if days >= 365:
		return "%.1f YEARS" % (float(days) / 365.0)
	if days >= 30:
		return "%.1f MONTHS" % (float(days) / 30.0)
	return "%d DAYS" % days

func _continue_launch_selection() -> void:
	var plan := MissionState.save_launch_plan()
	if not plan.is_empty():
		_show_next_stage()

func _show_next_stage() -> void:
	_show_preflight()

func _show_preflight() -> void:
	current_page = "preflight"
	_clear_body()
	var mission: Dictionary = MissionState.launch_plan.get("mission", {})
	var design: Dictionary = MissionState.launch_plan.get("spacecraft_design", {})
	var resources: Dictionary = design.get("resources", {})
	var rocket: Dictionary = MissionState.launch_plan.get("rocket", {})
	var orbit: Dictionary = MissionState.launch_plan.get("orbit", {})
	var summary: Dictionary = MissionState.launch_plan.get("summary", {})
	var preflight: Dictionary = MissionState.evaluate_preflight()
	var heading := _label("FLIGHT READINESS REVIEW", 22, TEXT)
	_set_font_size(heading, 22)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.8
	heading.anchor_top = 0.0
	heading.anchor_bottom = 0.065
	body.add_child(heading)
	var mission_line := _label("MISSION  /  %s     •     PREFLIGHT CHECKS" % mission.get("name", "NO MISSION PLAN"), 10, ACCENT)
	mission_line.anchor_left = 0.025
	mission_line.anchor_right = 0.96
	mission_line.anchor_top = 0.065
	mission_line.anchor_bottom = 0.11
	body.add_child(mission_line)
	var left := _panel()
	left.anchor_left = 0.025
	left.anchor_right = 0.60
	left.anchor_top = 0.14
	left.anchor_bottom = 0.87
	body.add_child(left)
	var left_content := Control.new()
	left_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left.add_child(left_content)
	var left_margin := MarginContainer.new()
	left_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_margin.add_theme_constant_override("margin_left", 22)
	left_margin.add_theme_constant_override("margin_right", 22)
	left_margin.add_theme_constant_override("margin_top", 18)
	left_margin.add_theme_constant_override("margin_bottom", 18)
	left_content.add_child(left_margin)
	var check_stack := VBoxContainer.new()
	check_stack.add_theme_constant_override("separation", 7)
	left_margin.add_child(check_stack)
	check_stack.add_child(_label("SYSTEMS & FLIGHT RULES", 10, ACCENT))
	for check in preflight.get("checks", []):
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 40
		row.add_theme_constant_override("separation", 12)
		var status := _label("●  READY" if check["valid"] else "●  HOLD", 9, GREEN if check["valid"] else Color("eb8b82"))
		status.custom_minimum_size.x = 82
		row.add_child(status)
		var detail_stack := VBoxContainer.new()
		detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_stack.add_theme_constant_override("separation", 1)
		row.add_child(detail_stack)
		detail_stack.add_child(_label(check["name"], 10, TEXT))
		var detail := _label(str(check["detail"]), 9, MUTED)
		detail.clip_text = true
		detail_stack.add_child(detail)
		check_stack.add_child(row)
	var equipment_header := _label("INSTALLED EQUIPMENT", 9, ACCENT)
	check_stack.add_child(equipment_header)
	var equipment_names: Array[String] = []
	for component_id in design.get("components", []):
		if MissionState.COMPONENTS.has(component_id):
			equipment_names.append(MissionState.COMPONENTS[component_id]["name"])
	var equipment := _label("  •  ".join(equipment_names), 9, MUTED)
	equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment.custom_minimum_size.y = 34
	check_stack.add_child(equipment)
	var right := _panel()
	right.anchor_left = 0.62
	right.anchor_right = 0.99
	right.anchor_top = 0.14
	right.anchor_bottom = 0.87
	body.add_child(right)
	var right_margin := MarginContainer.new()
	right_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_margin.add_theme_constant_override("margin_left", 20)
	right_margin.add_theme_constant_override("margin_right", 20)
	right_margin.add_theme_constant_override("margin_top", 18)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	right.add_child(right_margin)
	var summary_stack := VBoxContainer.new()
	summary_stack.add_theme_constant_override("separation", 8)
	right_margin.add_child(summary_stack)
	summary_stack.add_child(_label("MISSION CONFIGURATION", 10, ACCENT))
	var mission_title := _label(mission.get("name", "MISSION"), 18, TEXT)
	mission_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_stack.add_child(mission_title)
	summary_stack.add_child(_detail_row("TARGET", mission.get("target", "—")))
	var target_facts := _planet_facts_panel(str(mission.get("target", "")))
	if target_facts != null:
		summary_stack.add_child(target_facts)
	summary_stack.add_child(_detail_row("SPACECRAFT MASS", "%d / %d KG" % [resources.get("mass_kg", 0), rocket.get("capacity_kg", 0)]))
	summary_stack.add_child(_detail_row("LAUNCH VEHICLE", rocket.get("name", "—")))
	summary_stack.add_child(_detail_row("TRAJECTORY", orbit.get("name", "—")))
	summary_stack.add_child(_detail_row("MISSION DURATION", _format_duration(int(summary.get("duration_days", 0)))))
	summary_stack.add_child(_detail_row("POWER BALANCE", "%d W GEN  /  %d W LOAD" % [resources.get("power_generation_w", 0), resources.get("power_load_w", 0)]))
	summary_stack.add_child(_detail_row("COMMUNICATION LINK", "%d%% QUALITY" % orbit.get("communication_pct", 0)))
	var budget_rule := ColorRect.new()
	budget_rule.color = Color(BORDER, 0.9)
	budget_rule.custom_minimum_size.y = 1
	summary_stack.add_child(budget_rule)
	summary_stack.add_child(_detail_row("TOTAL COMMITTED", _format_budget(summary.get("total_cost_m", 0))))
	var remaining_row := _detail_row("REMAINING FUNDS", _format_budget(summary.get("budget_remaining_m", 0)))
	summary_stack.add_child(remaining_row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_stack.add_child(spacer)
	var disclaimer := _label("SIMPLIFIED GAME MODEL — VALUES ARE BALANCED FOR PLAY, NOT A REAL PHYSICS SIMULATION.", 8, MUTED)
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_stack.add_child(disclaimer)
	var back := Button.new()
	back.text = "←  BACK TO ROCKET & ORBIT"
	back.custom_minimum_size = Vector2(250, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_apply_button_style(back, false)
	back.pressed.connect(_show_rocket_orbit_selection)
	summary_stack.add_child(back)
	var launch := Button.new()
	launch.text = "LAUNCH MISSION  →"
	launch.custom_minimum_size = Vector2(0, 50)
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch.disabled = not preflight.get("valid", false)
	_set_font_size(launch, 12)
	launch.add_theme_stylebox_override("normal", _style(Color("123047"), ACCENT, 1, 4))
	launch.add_theme_stylebox_override("hover", _style(Color("194561"), Color("78d5fa"), 1, 4))
	launch.add_theme_stylebox_override("disabled", _style(Color("0c1723"), Color("1c2a37"), 1, 4))
	launch.add_theme_color_override("font_color", TEXT)
	launch.add_theme_color_override("font_disabled_color", Color("627181"))
	launch.pressed.connect(_launch_mission)
	summary_stack.add_child(launch)
	_animate_page_in()

func _launch_mission() -> void:
	if not MissionState.start_mission_simulation():
		_show_preflight()
		return
	if is_instance_valid(sfx_player):
		sfx_player.stream = _tone_stream(1.2, false, 90.0)
		sfx_player.volume_db = linear_to_db(maxf(0.001, float(MissionState.audio_settings["sfx"]) * 0.48))
		sfx_player.play()
	_show_launch_animation()

func _show_launch_animation() -> void:
	current_page = "launch_sequence"
	_clear_body()
	var panel := _panel()
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.94
	body.add_child(panel)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var margin := _page_margin()
	stack.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	content.add_child(_label("LAUNCH SEQUENCE  /  FLIGHT DIRECTOR'S LOOP", 10, ACCENT))
	var headline := _label("MISSION GO", 25, TEXT)
	_set_font_size(headline, 25)
	content.add_child(headline)
	content.add_child(_label("VEHICLE RELEASED  •  ASCENT TRAJECTORY NOMINAL", 10, GREEN))
	launch_graphic = LaunchSequenceGraphic.new()
	launch_graphic.custom_minimum_size = Vector2(0, 390)
	launch_graphic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	launch_graphic.clip_contents = true
	content.add_child(launch_graphic)
	var phase := _label("T− 00:00  /  LIFTOFF", 11, ACCENT)
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(phase)
	_animate_page_in()
	var tween := create_tween()
	tween.tween_property(launch_graphic, "progress", 1.0, 3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if current_page == "launch_sequence":
		_show_mission_control()

func _show_mission_control() -> void:
	current_page = "mission_control"
	_clear_body()
	simulation_metric_labels.clear()
	simulation_timeline_cards.clear()
	var mission: Dictionary = MissionState.launch_plan.get("mission", {})
	var heading := _label("MISSION CONTROL", 22, TEXT)
	_set_font_size(heading, 22)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.70
	heading.anchor_top = 0.0
	heading.anchor_bottom = 0.055
	body.add_child(heading)
	var mission_line := _label("FLIGHT  /  %s     •     TARGET  /  %s" % [mission.get("name", "MISSION"), mission.get("target", "—")], 10, ACCENT)
	mission_line.anchor_left = 0.025
	mission_line.anchor_right = 0.73
	mission_line.anchor_top = 0.055
	mission_line.anchor_bottom = 0.095
	body.add_child(mission_line)
	var body_facts_button := Button.new()
	body_facts_button.text = "NASA TARGET FACTS"
	body_facts_button.anchor_left = 0.78
	body_facts_button.anchor_right = 0.99
	body_facts_button.anchor_top = 0.052
	body_facts_button.anchor_bottom = 0.102
	_apply_button_style(body_facts_button, false)
	body_facts_button.pressed.connect(_planet_facts_dialog.bind(str(mission.get("target", ""))))
	body.add_child(body_facts_button)
	var timeline := HBoxContainer.new()
	timeline.anchor_left = 0.025
	timeline.anchor_right = 0.99
	timeline.anchor_top = 0.12
	timeline.anchor_bottom = 0.24
	timeline.add_theme_constant_override("separation", 7)
	body.add_child(timeline)
	for phase in MissionState.MISSION_PHASES:
		var card := _panel()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("091827"), BORDER, 1, 4))
		var phase_stack := VBoxContainer.new()
		phase_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		phase_stack.add_theme_constant_override("separation", 3)
		card.add_child(phase_stack)
		var phase_margin := MarginContainer.new()
		phase_margin.add_theme_constant_override("margin_left", 8)
		phase_margin.add_theme_constant_override("margin_right", 8)
		phase_margin.add_theme_constant_override("margin_top", 5)
		phase_margin.add_theme_constant_override("margin_bottom", 5)
		phase_stack.add_child(phase_margin)
		var phase_content := VBoxContainer.new()
		phase_content.add_theme_constant_override("separation", 4)
		phase_margin.add_child(phase_content)
		phase_content.add_child(_label("PHASE %02d" % (simulation_timeline_cards.size() + 1), 8, MUTED))
		var phase_name := _label(phase["name"], 9, TEXT)
		phase_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		phase_name.custom_minimum_size.y = 26
		phase_content.add_child(phase_name)
		var phase_status := _label("PENDING", 8, MUTED)
		phase_content.add_child(phase_status)
		card.set_meta("phase_status", phase_status)
		timeline.add_child(card)
		simulation_timeline_cards.append(card)
	var metric_strip := HBoxContainer.new()
	metric_strip.anchor_left = 0.025
	metric_strip.anchor_right = 0.99
	metric_strip.anchor_top = 0.265
	metric_strip.anchor_bottom = 0.39
	metric_strip.add_theme_constant_override("separation", 8)
	body.add_child(metric_strip)
	for metric in [["energy", "ENERGY RESERVE"], ["generated", "POWER GENERATED"], ["data", "DATA COLLECTED"], ["downlink", "DATA TRANSMITTED"], ["comms", "COMM LINK"]]:
		metric_strip.add_child(_simulation_metric_card(metric[0], metric[1]))
	var craft_panel := _panel()
	craft_panel.anchor_left = 0.025
	craft_panel.anchor_right = 0.49
	craft_panel.anchor_top = 0.415
	craft_panel.anchor_bottom = 0.88
	body.add_child(craft_panel)
	_build_craft_preview(craft_panel)
	var log_panel := _panel()
	log_panel.anchor_left = 0.51
	log_panel.anchor_right = 0.99
	log_panel.anchor_top = 0.415
	log_panel.anchor_bottom = 0.88
	body.add_child(log_panel)
	var log_content := Control.new()
	log_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_panel.add_child(log_content)
	var log_margin := MarginContainer.new()
	log_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_margin.add_theme_constant_override("margin_left", 17)
	log_margin.add_theme_constant_override("margin_right", 17)
	log_margin.add_theme_constant_override("margin_top", 13)
	log_margin.add_theme_constant_override("margin_bottom", 13)
	log_content.add_child(log_margin)
	var log_stack := VBoxContainer.new()
	log_stack.add_theme_constant_override("separation", 7)
	log_margin.add_child(log_stack)
	log_stack.add_child(_label("FLIGHT STATUS & OPERATIONS LOG", 10, ACCENT))
	simulation_phase_label = _label("LAUNCH  /  VEHICLE ASCENT", 16, TEXT)
	log_stack.add_child(simulation_phase_label)
	simulation_progress_bar = ProgressBar.new()
	simulation_progress_bar.custom_minimum_size.y = 14
	simulation_progress_bar.show_percentage = false
	log_stack.add_child(simulation_progress_bar)
	var mission_model_note := _label("Simplified game model — mission values are balanced for play; this is not a real physics simulation.", 8, MUTED)
	mission_model_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_stack.add_child(mission_model_note)
	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_stack.add_child(log_scroll)
	simulation_event_list = VBoxContainer.new()
	simulation_event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	simulation_event_list.add_theme_constant_override("separation", 5)
	log_scroll.add_child(simulation_event_list)
	var controls := HBoxContainer.new()
	controls.anchor_left = 0.025
	controls.anchor_right = 0.99
	controls.anchor_top = 0.90
	controls.anchor_bottom = 0.985
	controls.add_theme_constant_override("separation", 9)
	body.add_child(controls)
	var speed := OptionButton.new()
	speed.custom_minimum_size = Vector2(120, 42)
	for speed_value in [1, 3, 10]:
		speed.add_item("%dx SPEED" % speed_value)
		speed.set_item_metadata(speed.get_item_count() - 1, speed_value)
	speed.select(0)
	speed.item_selected.connect(func(index: int) -> void: MissionState.set_simulation_speed(int(speed.get_item_metadata(index))))
	controls.add_child(speed)
	var date_label := _label("ELAPSED  /  DAY 0 OF %d" % MissionState.mission_simulation.get("total_days", 0), 10, MUTED)
	date_label.name = "SimulationDate"
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(date_label)
	simulation_advance_button = Button.new()
	simulation_advance_button.text = "ADVANCE MISSION  →"
	simulation_advance_button.custom_minimum_size = Vector2(250, 46)
	_set_font_size(simulation_advance_button, 11)
	simulation_advance_button.add_theme_stylebox_override("normal", _style(Color("123047"), ACCENT, 1, 4))
	simulation_advance_button.add_theme_stylebox_override("hover", _style(Color("194561"), Color("78d5fa"), 1, 4))
	simulation_advance_button.pressed.connect(_advance_simulation)
	controls.add_child(simulation_advance_button)
	_rebuild_craft_preview()
	_update_simulation_ui()
	_animate_page_in()

func _simulation_metric_card(key: String, caption: String) -> PanelContainer:
	var card := _panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 1)
	card.add_child(stack)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	stack.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 1)
	margin.add_child(content)
	content.add_child(_label(caption, 8, MUTED))
	var value := _label("—", 13, TEXT)
	_set_font_size(value, 13)
	content.add_child(value)
	var detail := _label("LIVE FLIGHT DATA", 8, ACCENT)
	content.add_child(detail)
	simulation_metric_labels[key] = {"value": value, "detail": detail}
	return card

func _advance_simulation() -> void:
	if MissionState.mission_simulation.get("complete", false):
		_show_mission_report()
		return
	MissionState.advance_mission_simulation()
	_update_simulation_ui()

func _update_simulation_ui() -> void:
	var state: Dictionary = MissionState.mission_simulation
	var plan: Dictionary = MissionState.launch_plan
	var orbit: Dictionary = plan["orbit"]
	var phase_index := int(state.get("phase_index", 0))
	for i in simulation_timeline_cards.size():
		var card: PanelContainer = simulation_timeline_cards[i]
		var phase_status: Label = card.get_meta("phase_status")
		var completed: bool = i < phase_index or (bool(state.get("complete", false)) and i == phase_index)
		var active: bool = i == phase_index and not bool(state.get("complete", false))
		phase_status.text = "COMPLETE" if completed else ("ACTIVE" if active else "PENDING")
		phase_status.add_theme_color_override("font_color", GREEN if completed else (ACCENT if active else MUTED))
		card.add_theme_stylebox_override("panel", _style(Color("102a40") if active else PANEL, ACCENT if active else BORDER, 2 if active else 1, 4))
	if is_instance_valid(simulation_phase_label):
		simulation_phase_label.text = MissionState.MISSION_PHASES[phase_index]["name"] + "  /  " + ("MISSION COMPLETE" if state.get("complete", false) else "FLIGHT OPERATIONS")
	if is_instance_valid(simulation_progress_bar):
		simulation_progress_bar.value = float(state.get("elapsed_days", 0)) / maxf(1.0, float(state.get("total_days", 1))) * 100.0
	var production_rate := float(state.get("energy_generated_wh", 0))
	var use_rate := float(state.get("energy_consumed_wh", 0))
	var comms_days := maxf(1.0, float(state.get("comms_days", 0)))
	var observed_comms := float(state.get("comms_weighted_pct", 0)) / comms_days if float(state.get("comms_days", 0)) > 0.0 else float(orbit.get("communication_pct", 0))
	var values := {
		"energy": ["%d%%" % roundi(float(state.get("energy_percent", 0))), "%d / %d WH STORED" % [roundi(float(state.get("energy_wh", 0))), state.get("energy_capacity_wh", 0)]],
		"generated": ["%s KWH" % _format_kwh(production_rate), "%s KWH CONSUMED" % _format_kwh(use_rate)],
		"data": ["%s GB" % _format_gb(float(state.get("data_collected_gb", 0))), "%d%% SCIENCE TARGET" % roundi(clampf(float(state.get("data_collected_gb", 0)) / maxf(1.0, float(state.get("science_target_gb", 1))) * 100.0, 0, 100))],
		"downlink": ["%s GB" % _format_gb(float(state.get("data_transmitted_gb", 0))), "GROUND DATA RECEIVED"],
		"comms": ["%d%%" % roundi(observed_comms), "AVERAGE LINK QUALITY"]
	}
	for key in simulation_metric_labels:
		simulation_metric_labels[key]["value"].text = values[key][0]
		simulation_metric_labels[key]["detail"].text = values[key][1]
	if is_instance_valid(simulation_event_list):
		for child in simulation_event_list.get_children():
			simulation_event_list.remove_child(child)
			child.queue_free()
		var events: Array = state.get("events", [])
		if events.is_empty():
			simulation_event_list.add_child(_label("All systems nominal. Advance the mission timeline to continue operations.", 10, MUTED))
		else:
			for event in events:
				var event_label := _label("•  " + str(event), 10, Color("f2b766") if str(event).begins_with("LOW POWER") or str(event).begins_with("INSTRUMENT") else TEXT)
				event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				simulation_event_list.add_child(event_label)
		for success in state.get("successes", []):
			var success_label := _label("✓  " + str(success), 10, GREEN)
			success_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			simulation_event_list.add_child(success_label)
	var date_label := body.find_child("SimulationDate", true, false) as Label
	if is_instance_valid(date_label):
		date_label.text = "ELAPSED  /  DAY %d OF %d" % [state.get("elapsed_days", 0), state.get("total_days", 0)]
	if is_instance_valid(simulation_advance_button):
		simulation_advance_button.text = "VIEW MISSION REPORT  →" if state.get("complete", false) else "ADVANCE MISSION  →"

func _format_kwh(watt_hours: float) -> String:
	return "%.1f" % (watt_hours / 1000.0)

func _format_gb(amount: float) -> String:
	if amount >= 1000.0:
		return "%.1fK" % (amount / 1000.0)
	return "%.1f" % amount

func _show_mission_report() -> void:
	current_page = "mission_report"
	_clear_body()
	var report: Dictionary = MissionState.mission_report
	var mission: Dictionary = MissionState.launch_plan.get("mission", {})
	if is_instance_valid(sfx_player) and MissionState.audio_settings["sfx_enabled"]:
		sfx_player.stream = _tone_stream(0.7, false, 880.0 if report.get("success", false) else 235.0)
		sfx_player.volume_db = linear_to_db(maxf(0.001, float(MissionState.audio_settings["sfx"])))
		sfx_player.play()
	var heading := _label("MISSION DEBRIEF", 22, TEXT)
	_set_font_size(heading, 22)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.8
	heading.anchor_top = 0.0
	heading.anchor_bottom = 0.065
	body.add_child(heading)
	var result_color := GREEN if report.get("success", false) else Color("eb8b82")
	var status := _label("MISSION SUCCESS  /  GRADE %d" % report.get("score", 0) if report.get("success", false) else "MISSION INCOMPLETE  /  GRADE %d" % report.get("score", 0), 15, result_color)
	status.anchor_left = 0.025
	status.anchor_right = 0.97
	status.anchor_top = 0.075
	status.anchor_bottom = 0.12
	body.add_child(status)
	var top_metrics := HBoxContainer.new()
	top_metrics.anchor_left = 0.025
	top_metrics.anchor_right = 0.99
	top_metrics.anchor_top = 0.16
	top_metrics.anchor_bottom = 0.40
	top_metrics.add_theme_constant_override("separation", 8)
	body.add_child(top_metrics)
	for metric in [
		["SCIENCE OBJECTIVE", "%d%%" % report.get("science_pct", 0), ACCENT],
		["DATA RECEIVED", "%d GB" % report.get("data_transmitted_gb", 0), GREEN],
		["ENERGY REMAINING", "%d%%" % report.get("energy_pct", 0), TEXT],
		["COMMS QUALITY", "%d%%" % report.get("communication_pct", 0), ACCENT],
		["FLIGHT TIME", _format_duration(report.get("duration_days", 0)), TEXT]
	]:
		var card := _panel()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_metrics.add_child(card)
		var metric_stack := VBoxContainer.new()
		metric_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		metric_stack.add_theme_constant_override("separation", 6)
		card.add_child(metric_stack)
		var metric_margin := MarginContainer.new()
		metric_margin.add_theme_constant_override("margin_left", 12)
		metric_margin.add_theme_constant_override("margin_right", 12)
		metric_margin.add_theme_constant_override("margin_top", 12)
		metric_margin.add_theme_constant_override("margin_bottom", 10)
		metric_stack.add_child(metric_margin)
		var metric_content := VBoxContainer.new()
		metric_content.add_theme_constant_override("separation", 5)
		metric_margin.add_child(metric_content)
		metric_content.add_child(_label(metric[0], 8, MUTED))
		var metric_value := _label(metric[1], 20, metric[2])
		metric_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		metric_content.add_child(metric_value)
	var details_panel := _panel()
	details_panel.anchor_left = 0.025
	details_panel.anchor_right = 0.63
	details_panel.anchor_top = 0.44
	details_panel.anchor_bottom = 0.87
	body.add_child(details_panel)
	var detail_stack := VBoxContainer.new()
	detail_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_stack.add_theme_constant_override("separation", 8)
	details_panel.add_child(detail_stack)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 16)
	detail_margin.add_theme_constant_override("margin_right", 16)
	detail_margin.add_theme_constant_override("margin_top", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	detail_stack.add_child(detail_margin)
	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 7)
	detail_margin.add_child(detail_content)
	detail_content.add_child(_label("MISSION PERFORMANCE", 10, ACCENT))
	detail_content.add_child(_detail_row("SCIENCE COMPLETION", "%d%%" % report.get("science_pct", 0)))
	detail_content.add_child(_detail_row("DATA COLLECTED / SENT", "%d / %d GB" % [report.get("data_collected_gb", 0), report.get("data_transmitted_gb", 0)]))
	detail_content.add_child(_detail_row("ENERGY GENERATED / USED", "%d / %d KWH" % [roundi(float(report.get("energy_generated_wh", 0)) / 1000.0), roundi(float(report.get("energy_used_wh", 0)) / 1000.0)]))
	detail_content.add_child(_detail_row("BUDGET SPENT / REMAINING", "%s / %s" % [_format_budget(report.get("spent_m", 0)), _format_budget(report.get("remaining_m", 0))]))
	detail_content.add_child(_detail_row("REPORTED DATA QUALITY", "%d%%" % report.get("data_pct", 0)))
	detail_content.add_child(_detail_row("RECORDED FAILURES", str(report.get("failures", []).size())))
	var event_panel := _panel()
	event_panel.anchor_left = 0.65
	event_panel.anchor_right = 0.99
	event_panel.anchor_top = 0.44
	event_panel.anchor_bottom = 0.87
	body.add_child(event_panel)
	var event_margin := MarginContainer.new()
	event_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_margin.add_theme_constant_override("margin_left", 15)
	event_margin.add_theme_constant_override("margin_right", 15)
	event_margin.add_theme_constant_override("margin_top", 13)
	event_margin.add_theme_constant_override("margin_bottom", 11)
	event_panel.add_child(event_margin)
	var event_stack := VBoxContainer.new()
	event_stack.add_theme_constant_override("separation", 7)
	event_margin.add_child(event_stack)
	event_stack.add_child(_label("EVENTS & DECISIONS", 10, ACCENT))
	var event_scroll := ScrollContainer.new()
	event_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	event_stack.add_child(event_scroll)
	var event_list := VBoxContainer.new()
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_list.add_theme_constant_override("separation", 5)
	event_scroll.add_child(event_list)
	var report_events: Array = report.get("events", [])
	if report_events.is_empty():
		event_list.add_child(_label("No anomalous events recorded.", 10, MUTED))
	else:
		for event in report_events:
			var event_label := _label("•  " + str(event), 9, Color("f2b766"))
			event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			event_list.add_child(event_label)
	for success in report.get("successes", []):
		var success_label := _label("✓  " + str(success), 9, GREEN)
		success_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_list.add_child(success_label)
	var note := _label("%s  •  %s" % [mission.get("name", "MISSION"), report.get("simplified_model", "SIMPLIFIED GAME MODEL")], 8, MUTED)
	note.anchor_left = 0.025
	note.anchor_right = 0.52
	note.anchor_top = 0.89
	note.anchor_bottom = 0.98
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var planet_data := Button.new()
	planet_data.text = "NASA TARGET DATA"
	planet_data.anchor_left = 0.54
	planet_data.anchor_right = 0.75
	planet_data.anchor_top = 0.895
	planet_data.anchor_bottom = 0.98
	_apply_button_style(planet_data, false)
	planet_data.pressed.connect(_planet_facts_dialog.bind(str(mission.get("target", ""))))
	body.add_child(planet_data)
	var home := Button.new()
	home.text = "RETURN TO COMMAND"
	home.anchor_left = 0.78
	home.anchor_right = 0.99
	home.anchor_top = 0.895
	home.anchor_bottom = 0.98
	_apply_button_style(home, false)
	home.pressed.connect(_show_home)
	body.add_child(home)
	_animate_page_in()

func _show_missions() -> void:
	current_page = "missions"
	_clear_body()
	var heading := _label("MISSION ARCHIVE", 25, TEXT)
	_set_font_size(heading, 25)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.8
	heading.anchor_top = 0.015
	heading.anchor_bottom = 0.085
	body.add_child(heading)
	var panel := _panel()
	panel.anchor_left = 0.025
	panel.anchor_right = 0.975
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.86
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)
	margin.add_child(list)
	if MissionState.mission_history.is_empty():
		var empty := _label("NO COMPLETED MISSIONS YET\nYour completed flight reports will be archived here.", 14, MUTED)
		empty.custom_minimum_size = Vector2(0, 120)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		list.add_child(empty)
	else:
		for i in range(MissionState.mission_history.size() - 1, -1, -1):
			var report: Dictionary = MissionState.mission_history[i]
			var mission: Dictionary = report.get("mission", {})
			var card := Button.new()
			card.custom_minimum_size.y = 76
			card.alignment = HORIZONTAL_ALIGNMENT_LEFT
			card.text = "%s     •     %s     •     %s     •     GRADE %d     •     %s" % [mission.get("name", "MISSION"), mission.get("target", "—"), "SUCCESS" if report.get("success", false) else "INCOMPLETE", report.get("score", 0), str(report.get("completed_at", "DATE UNKNOWN")).replace("T", "  ")]
			_set_font_size(card, 11)
			_apply_button_style(card, false)
			card.pressed.connect(_open_archived_report.bind(i))
			list.add_child(card)
	var back := Button.new()
	back.text = "←  BACK TO COMMAND"
	back.anchor_left = 0.025
	back.anchor_right = 0.24
	back.anchor_top = 0.89
	back.anchor_bottom = 0.98
	_apply_button_style(back, false)
	back.pressed.connect(_show_home)
	body.add_child(back)
	_animate_page_in()

func _open_archived_report(index: int) -> void:
	if index < 0 or index >= MissionState.mission_history.size():
		return
	MissionState.mission_report = MissionState.mission_history[index].duplicate(true)
	MissionState.launch_plan["mission"] = MissionState.mission_report.get("mission", {}).duplicate(true)
	_show_mission_report()

func _open_sandbox() -> void:
	MissionState.sandbox_mode = true
	if MissionState.selected_mission.get("id", "") != "sandbox":
		MissionState.set_selected_mission({
			"id": "sandbox", "name": "FREE DESIGN SANDBOX", "target": "OPEN TEST RANGE",
			"objective": "Configure spacecraft systems freely. No mission will be launched or recorded.",
			"duration_days": 1, "budget_millions": 5000, "data_requirement_gb_day": 0,
			"required_components": []
		})
		MissionState.begin_spacecraft_design()
	else:
		MissionState.calculate_design()
	_show_sandbox()

func _show_sandbox() -> void:
	current_page = "sandbox"
	sandbox_rocket_buttons.clear()
	sandbox_orbit_buttons.clear()
	_clear_body()
	var heading := _label("SANDBOX  /  FREE DESIGN RANGE", 23, TEXT)
	_set_font_size(heading, 23)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.75
	heading.anchor_top = 0.015
	heading.anchor_bottom = 0.085
	body.add_child(heading)
	var info := _label("DESIGN WITHOUT MISSION REQUIREMENTS. No launch is required and sandbox work does not affect your mission archive.", 11, MUTED)
	info.anchor_left = 0.025
	info.anchor_right = 0.92
	info.anchor_top = 0.09
	info.anchor_bottom = 0.16
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var metrics := _panel()
	metrics.anchor_left = 0.025
	metrics.anchor_right = 0.64
	metrics.anchor_top = 0.20
	metrics.anchor_bottom = 0.62
	body.add_child(metrics)
	var metric_stack := VBoxContainer.new()
	metric_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	metric_stack.add_theme_constant_override("separation", 14)
	metrics.add_child(metric_stack)
	var metric_margin := _page_margin()
	metric_stack.add_child(metric_margin)
	var metric_content := VBoxContainer.new()
	metric_content.add_theme_constant_override("separation", 14)
	metric_margin.add_child(metric_content)
	metric_content.add_child(_label("LIVE SPACECRAFT RESOURCES", 10, ACCENT))
	var resources: Dictionary = MissionState.calculate_design()
	for line in ["INSTALLED SYSTEMS  /  %d of 8" % MissionState.active_components.size(), "MASS  /  %d kg" % resources.get("mass_kg", 0), "DESIGN COST  /  %s" % _format_budget(resources.get("cost_m", 0)), "POWER  /  %d W generated  •  %d W load" % [resources.get("power_generation_w", 0), resources.get("power_load_w", 0)], "DATA CAPACITY  /  %d GB per day" % resources.get("data_capacity_gb_day", 0)]:
		metric_content.add_child(_label(line, 13, TEXT))
	var design := Button.new()
	design.text = "OPEN SPACECRAFT DESIGN  →"
	design.anchor_left = 0.025
	design.anchor_right = 0.31
	design.anchor_top = 0.70
	design.anchor_bottom = 0.80
	_apply_button_style(design, false)
	design.pressed.connect(_show_spacecraft_design)
	body.add_child(design)
	var rocket_panel := _panel()
	rocket_panel.anchor_left = 0.68
	rocket_panel.anchor_right = 0.975
	rocket_panel.anchor_top = 0.20
	rocket_panel.anchor_bottom = 0.62
	body.add_child(rocket_panel)
	var rocket_stack := VBoxContainer.new()
	rocket_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rocket_stack.add_theme_constant_override("separation", 12)
	rocket_panel.add_child(rocket_stack)
	var rocket_margin := _page_margin()
	rocket_stack.add_child(rocket_margin)
	var rocket_content := VBoxContainer.new()
	rocket_content.add_theme_constant_override("separation", 12)
	rocket_margin.add_child(rocket_content)
	rocket_content.add_child(_label("LAUNCH VEHICLE TRIAL", 10, ACCENT))
	var rocket_names := ["LIGHT LAUNCH VEHICLE", "MEDIUM LAUNCH VEHICLE", "HEAVY LAUNCH VEHICLE"]
	for rocket_id in MissionState.ROCKETS:
		var rocket: Dictionary = MissionState.ROCKETS[rocket_id]
		var option := Button.new()
		option.text = "%s  •  %d kg  •  %s" % [rocket_names[rocket_names.find(rocket["name"])], rocket["capacity_kg"], _format_budget(rocket["cost_m"])]
		option.custom_minimum_size.y = 42
		_apply_button_style(option, false)
		option.pressed.connect(_sandbox_select_rocket.bind(rocket_id))
		rocket_content.add_child(option)
		sandbox_rocket_buttons[rocket_id] = option
	rocket_content.add_child(_label("TRAJECTORY TRIAL", 10, ACCENT))
	for orbit_id in MissionState.ORBITS:
		var orbit: Dictionary = MissionState.ORBITS[orbit_id]
		var orbit_button := Button.new()
		orbit_button.text = str(orbit["name"])
		orbit_button.custom_minimum_size.y = 32
		_set_font_size(orbit_button, 9)
		_apply_button_style(orbit_button, false)
		orbit_button.pressed.connect(_sandbox_select_orbit.bind(orbit_id))
		rocket_content.add_child(orbit_button)
		sandbox_orbit_buttons[orbit_id] = orbit_button
	_refresh_sandbox_choice_styles()
	var back := Button.new()
	back.text = "←  BACK TO COMMAND"
	back.anchor_left = 0.025
	back.anchor_right = 0.24
	back.anchor_top = 0.89
	back.anchor_bottom = 0.98
	_apply_button_style(back, false)
	back.pressed.connect(_show_home)
	body.add_child(back)
	_animate_page_in()

func _sandbox_select_rocket(rocket_id: String) -> void:
	var rocket: Dictionary = MissionState.ROCKETS[rocket_id]
	sandbox_selected_rocket = rocket_id
	_refresh_sandbox_choice_styles()
	_play_ui_sound()
	_show_toast("TEST VEHICLE  /  %s   •   PAYLOAD %d KG" % [rocket["name"], rocket["capacity_kg"]])

func _sandbox_select_orbit(orbit_id: String) -> void:
	var orbit: Dictionary = MissionState.ORBITS[orbit_id]
	sandbox_selected_orbit = orbit_id
	_refresh_sandbox_choice_styles()
	_play_ui_sound()
	_show_toast("TRAJECTORY PROFILE  /  %s   •   %s" % [orbit["name"], orbit["body"]])

func _refresh_sandbox_choice_styles() -> void:
	for rocket_id in sandbox_rocket_buttons:
		var selected: bool = str(rocket_id) == sandbox_selected_rocket
		var option: Button = sandbox_rocket_buttons[rocket_id]
		option.add_theme_stylebox_override("normal", _launch_card_style(selected, false))
		option.add_theme_stylebox_override("hover", _launch_card_style(selected, true))
	for orbit_id in sandbox_orbit_buttons:
		var selected: bool = str(orbit_id) == sandbox_selected_orbit
		var option: Button = sandbox_orbit_buttons[orbit_id]
		option.add_theme_stylebox_override("normal", _launch_card_style(selected, false))
		option.add_theme_stylebox_override("hover", _launch_card_style(selected, true))

func _show_toast(message: String) -> void:
	var toast := _label(message, 10, ACCENT)
	toast.anchor_left = 0.30
	toast.anchor_right = 0.78
	toast.anchor_top = 0.90
	toast.anchor_bottom = 0.97
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(toast)
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(toast, "modulate:a", 0.0, 0.45)
	tween.tween_callback(toast.queue_free)

func _show_placeholder(page_title: String) -> void:
	current_page = page_title.to_lower().replace(" ", "_")
	_clear_body()
	var card := _panel()
	card.anchor_left = 0.025
	card.anchor_right = 0.72
	card.anchor_top = 0.12
	card.anchor_bottom = 0.78
	body.add_child(card)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)
	var margin := _page_margin()
	content.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 15)
	margin.add_child(stack)
	stack.add_child(_label("MISSION DESK  /  " + page_title, 11, ACCENT))
	var title := _label(page_title, 31, TEXT)
	_set_font_size(title, 31)
	stack.add_child(title)
	stack.add_child(_label("This section is ready for the next phase.", 15, MUTED))
	_add_back_button(stack)
	_animate_page_in()

func _show_settings() -> void:
	current_page = "settings"
	_clear_body()
	var card := _panel()
	card.anchor_left = 0.025
	card.anchor_right = 0.77
	card.anchor_top = 0.07
	card.anchor_bottom = 0.92
	body.add_child(card)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 17)
	card.add_child(content)
	var margin := _page_margin()
	content.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 17)
	margin.add_child(stack)
	stack.add_child(_label("SYSTEM CONFIGURATION", 11, ACCENT))
	var heading := _label("Settings", 29, TEXT)
	_set_font_size(heading, 29)
	stack.add_child(heading)
	var sources_button := Button.new()
	sources_button.text = "NASA DATA & SOURCES   →"
	sources_button.custom_minimum_size.y = 42
	_apply_button_style(sources_button, false)
	sources_button.pressed.connect(_show_data_sources)
	stack.add_child(sources_button)
	stack.add_child(_setting_row("MASTER VOLUME", _audio_control("master")))
	stack.add_child(_setting_row("MUSIC LEVEL", _audio_control("music")))
	stack.add_child(_setting_row("SOUND EFFECTS", _audio_control("sfx")))
	stack.add_child(_setting_row("MUSIC", _audio_toggle("music_enabled", "MUSIC ENABLED")))
	stack.add_child(_setting_row("SOUND EFFECTS", _audio_toggle("sfx_enabled", "EFFECTS ENABLED")))
	stack.add_child(_setting_row("DISPLAY MODE", _fullscreen_control()))
	stack.add_child(_setting_row("RESOLUTION", _resolution_control()))
	_add_back_button(stack)
	var credit := _label("Made by GöktürkNova", 10, Color("91a4b7"))
	credit.anchor_left = 0.70
	credit.anchor_right = 0.96
	credit.anchor_top = 0.92
	credit.anchor_bottom = 0.97
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(credit)
	_animate_page_in()

func _show_data_sources() -> void:
	current_page = "data_sources"
	_clear_body()
	var heading := _label("NASA DATA & SOURCES", 24, TEXT)
	_set_font_size(heading, 24)
	heading.anchor_left = 0.025
	heading.anchor_right = 0.8
	heading.anchor_top = 0.0
	heading.anchor_bottom = 0.065
	body.add_child(heading)
	var subtitle := _label("Trace scientific facts and technical references used by mission planning.", 10, MUTED)
	subtitle.anchor_left = 0.025
	subtitle.anchor_right = 0.96
	subtitle.anchor_top = 0.065
	subtitle.anchor_bottom = 0.105
	body.add_child(subtitle)
	var panel := _panel()
	panel.anchor_left = 0.025
	panel.anchor_right = 0.975
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.86
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	stack.add_child(_label("PLANETARY FACT SHEET  /  REAL METRIC DATA", 10, ACCENT))
	var body_selector := GridContainer.new()
	body_selector.columns = 5
	body_selector.add_theme_constant_override("h_separation", 6)
	body_selector.add_theme_constant_override("v_separation", 5)
	var planetary_bodies: Dictionary = MissionState.nasa_planetary_data.get("bodies", {})
	for body_id in ["mercury", "venus", "earth", "moon", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"]:
		var body_button := Button.new()
		var body_record: Dictionary = planetary_bodies.get(body_id, {})
		body_button.text = str(body_record.get("name", body_id)).to_upper()
		body_button.custom_minimum_size = Vector2(112, 32)
		_apply_button_style(body_button, false)
		body_button.pressed.connect(_select_planetary_facts_body.bind(body_id))
		body_selector.add_child(body_button)
	stack.add_child(body_selector)
	var fact_body: Dictionary = planetary_bodies.get(planetary_facts_body_id, {})
	var fact_display := _planet_facts_panel(str(fact_body.get("name", "Earth")))
	if fact_display != null:
		stack.add_child(fact_display)
	var fact_source := _source_card(
		NASA_PLANETARY_DATASET_NAME,
		"NASA Goddard Space Flight Center / NSSDCA",
		"Used in mission selection, preflight, target facts and mission debrief. Values are transcribed at the displayed source precision; no unit conversions are applied.",
		"REAL METRIC DATA",
		"PAGE UPDATED %s  •  ACCESSED %s" % [MissionState.nasa_planetary_data.get("source_last_updated", "—"), MissionState.nasa_planetary_data.get("accessed_utc_date", "—")],
		NASA_PLANETARY_URL
	)
	stack.add_child(fact_source)
	stack.add_child(_label("JPL HORIZONS  /  OPTIONAL LIVE EPHEMERIS", 10, ACCENT))
	var horizons_card := _panel()
	var horizons_margin := MarginContainer.new()
	horizons_margin.add_theme_constant_override("margin_left", 12)
	horizons_margin.add_theme_constant_override("margin_right", 12)
	horizons_margin.add_theme_constant_override("margin_top", 9)
	horizons_margin.add_theme_constant_override("margin_bottom", 9)
	horizons_card.add_child(horizons_margin)
	var horizons_stack := VBoxContainer.new()
	horizons_stack.add_theme_constant_override("separation", 6)
	horizons_margin.add_child(horizons_stack)
	horizons_stack.add_child(_label("NASA/JPL Horizons API  •  source snapshot is separate from the static Fact Sheet and does not change mission simulation values.", 9, MUTED))
	var query_description := _label("Sun-centered state vectors  /  ecliptic reference plane  /  AU position + AU/day velocity  /  UTC request time.", 8, MUTED)
	query_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	horizons_stack.add_child(query_description)
	var fetch_row := HBoxContainer.new()
	fetch_row.add_theme_constant_override("separation", 8)
	for body_id in ["earth", "moon", "mars"]:
		var fetch_button := Button.new()
		fetch_button.text = "FETCH %s" % str(HORIZONS_BODIES[body_id]["name"]).to_upper()
		fetch_button.custom_minimum_size = Vector2(110, 34)
		_apply_button_style(fetch_button, false)
		fetch_button.pressed.connect(_request_horizons_vectors.bind(body_id))
		fetch_row.add_child(fetch_button)
	horizons_stack.add_child(fetch_row)
	horizons_status = _label("No live or cached Horizons snapshot loaded.", 8, MUTED)
	horizons_stack.add_child(horizons_status)
	horizons_output = RichTextLabel.new()
	horizons_output.custom_minimum_size.y = 88
	horizons_output.fit_content = false
	horizons_output.scroll_active = true
	horizons_output.selection_enabled = true
	horizons_output.add_theme_color_override("default_color", Color("b8c9d9"))
	horizons_output.add_theme_font_size_override("normal_font_size", 10)
	horizons_stack.add_child(horizons_output)
	stack.add_child(horizons_card)
	var horizons_source := _source_card(
		"JPL Horizons System / API",
		"NASA Jet Propulsion Laboratory / Solar System Dynamics",
		"Optional user-triggered Earth, Moon or Mars state-vector snapshot. It is timestamped, labeled with query frame and units, cached locally after success, and never drives the simplified game simulation.",
		"LIVE API REFERENCE  •  NOT A STATIC DATASET",
		"API documentation version 1.3 (2025-06)  •  accessed 2026-11-15",
		"https://ssd-api.jpl.nasa.gov/doc/horizons.html"
	)
	stack.add_child(horizons_source)
	stack.add_child(_label("SMALL SPACECRAFT TECHNOLOGY  /  TECHNICAL REFERENCES", 10, ACCENT))
	stack.add_child(_source_card(NASA_SST_DATASET_NAME + "  /  Power", "NASA Small Spacecraft Systems Virtual Institute", "Design context only: solar arrays use series-connected cell strings and parallel circuits; deployed array size, mass properties and deployment are mission-specific. Battery system usable energy also depends on battery management and thermal controls. In-game W/Wh values remain hypothetical game-balance values.", "TECHNICAL REFERENCE", "Accessed 2026-11-15", NASA_POWER_URL))
	stack.add_child(_source_card(NASA_SST_DATASET_NAME + "  /  Communications", "NASA Small Spacecraft Systems Virtual Institute", "Design context only: links distinguish uplink, downlink and crosslink; higher-rate links trade bandwidth and antenna gain against narrower pointing requirements. The game's link percentages are not sourced NASA performance values.", "TECHNICAL REFERENCE", "Accessed 2026-11-15", NASA_COMMS_URL))
	stack.add_child(_source_card(NASA_SST_DATASET_NAME + "  /  Structures", "NASA Small Spacecraft Systems Virtual Institute", "Design context only: primary structures must meet launch/dispenser interface and mechanical-load constraints; modular low-mass frames have thermal and shielding tradeoffs. The game's masses and costs remain hypothetical.", "TECHNICAL REFERENCE", "Accessed 2026-11-15", NASA_STRUCTURES_URL))
	stack.add_child(_source_card(NASA_SST_DATASET_NAME + "  /  Ground Data Systems & Mission Operations", "NASA Small Spacecraft Systems Virtual Institute", "Design context only: ground architectures handle spacecraft commanding, telemetry and data processing; direct-to-Earth and relay links have different visibility and coverage tradeoffs. The game's communications and event model is simplified.", "TECHNICAL REFERENCE", "Accessed 2026-11-15", NASA_OPERATIONS_URL))
	var disclaimer := _label("MISSION CONTROL is an independent game project. NASA/JPL sources do not imply NASA endorsement. No NASA logo is used.", 8, MUTED)
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(disclaimer)
	var back := Button.new()
	back.text = "←  BACK TO SETTINGS"
	back.custom_minimum_size = Vector2(230, 44)
	_apply_button_style(back, false)
	back.anchor_left = 0.025
	back.anchor_right = 0.27
	back.anchor_top = 0.89
	back.anchor_bottom = 0.98
	back.pressed.connect(_show_settings)
	body.add_child(back)
	_refresh_horizons_display()
	_animate_page_in()

func _source_card(title_text: String, institution: String, usage: String, data_kind: String, accessed: String, source_url: String) -> PanelContainer:
	var card := _panel()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var title := _label(title_text, 10, TEXT)
	stack.add_child(title)
	stack.add_child(_label(institution + "  •  " + data_kind, 8, ACCENT))
	var description := _label(usage, 8, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	stack.add_child(footer)
	footer.add_child(_label(accessed, 7, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var open := Button.new()
	open.text = "OPEN SOURCE"
	open.custom_minimum_size = Vector2(112, 28)
	_apply_button_style(open, false)
	open.pressed.connect(_open_data_source.bind(source_url))
	footer.add_child(open)
	var copy := Button.new()
	copy.text = "COPY LINK"
	copy.custom_minimum_size = Vector2(94, 28)
	_apply_button_style(copy, false)
	copy.pressed.connect(_copy_data_source.bind(source_url))
	footer.add_child(copy)
	return card

func _open_data_source(source_url: String) -> void:
	OS.shell_open(source_url)

func _copy_data_source(source_url: String) -> void:
	DisplayServer.clipboard_set(source_url)
	_show_toast("SOURCE LINK COPIED")

func _select_planetary_facts_body(body_id: String) -> void:
	var bodies: Dictionary = MissionState.nasa_planetary_data.get("bodies", {})
	if bodies.has(body_id):
		planetary_facts_body_id = body_id
		_show_data_sources()

func _horizons_cache_path(body_id: String) -> String:
	return "user://horizons_%s_cache.json" % body_id

func _load_horizons_cache(body_id: String) -> Dictionary:
	var path := _horizons_cache_path(body_id)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _refresh_horizons_display(notice: String = "") -> void:
	if not is_instance_valid(horizons_output) or not is_instance_valid(horizons_status):
		return
	var cache := _load_horizons_cache(horizons_body_id)
	if cache.is_empty():
		var no_cache := "NO CACHED %s SNAPSHOT  /  FETCH REQUIRES AN INTERNET CONNECTION" % str(HORIZONS_BODIES[horizons_body_id]["name"]).to_upper()
		horizons_status.text = notice + "  •  " + no_cache if not notice.is_empty() else no_cache
		horizons_output.text = "JPL Horizons values will appear here after a successful request. The mission remains playable offline."
		return
	var cached_status := "CACHED JPL SNAPSHOT  /  %s  /  REQUESTED UTC %s" % [cache.get("body_name", "BODY"), cache.get("requested_utc", "UNKNOWN")]
	horizons_status.text = notice + "  •  " + cached_status if not notice.is_empty() else cached_status
	horizons_output.text = str(cache.get("result", "No result text in cache."))

func _request_horizons_vectors(body_id: String) -> void:
	if not HORIZONS_BODIES.has(body_id) or horizons_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	horizons_body_id = body_id
	var start_date: Dictionary = Time.get_datetime_dict_from_system(true)
	var stop_date := _utc_datetime_after(start_date, 120)
	var start_stamp := "%04d-%02d-%02d %02d:%02d:%02d" % [start_date["year"], start_date["month"], start_date["day"], start_date["hour"], start_date["minute"], start_date["second"]]
	var stop_stamp := "%04d-%02d-%02d %02d:%02d:%02d" % [stop_date["year"], stop_date["month"], stop_date["day"], stop_date["hour"], stop_date["minute"], stop_date["second"]]
	var target: Dictionary = HORIZONS_BODIES[body_id]
	var url := HORIZONS_API_URL + "?format=json&COMMAND=" + str(target["id"]) + "&OBJ_DATA=NO&MAKE_EPHEM=YES&EPHEM_TYPE=VECTORS&CENTER=%27500%4010%27&START_TIME=%27" + start_stamp.uri_encode() + "%27&STOP_TIME=%27" + stop_stamp.uri_encode() + "%27&STEP_SIZE=%271%20m%27&OUT_UNITS=AU-D&REF_PLANE=ECLIPTIC&VEC_TABLE=2&CSV_FORMAT=YES&TIME_TYPE=UT&TIME_DIGITS=SECONDS"
	horizons_status.text = "REQUESTING NASA/JPL HORIZONS — %s..." % str(target["name"]).to_upper()
	var request_error := horizons_request.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)
	if request_error != OK:
		_refresh_horizons_display("REQUEST COULD NOT START (%s)" % error_string(request_error))

func _utc_datetime_after(start_date: Dictionary, seconds_to_add: int) -> Dictionary:
	var result := start_date.duplicate(true)
	var seconds_of_day := int(result["hour"]) * 3600 + int(result["minute"]) * 60 + int(result["second"]) + seconds_to_add
	if seconds_of_day >= 86400:
		seconds_of_day -= 86400
		var days_in_month := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		var year := int(result["year"])
		if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
			days_in_month[1] = 29
		if int(result["day"]) < int(days_in_month[int(result["month"]) - 1]):
			result["day"] = int(result["day"]) + 1
		elif int(result["month"]) < 12:
			result["month"] = int(result["month"]) + 1
			result["day"] = 1
		else:
			result["year"] = year + 1
			result["month"] = 1
			result["day"] = 1
	result["hour"] = int(seconds_of_day / 3600)
	result["minute"] = int(seconds_of_day % 3600 / 60)
	result["second"] = seconds_of_day % 60
	return result

func _on_horizons_request_completed(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
	var parsed: Variant = null
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and not response_body.is_empty():
		parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if parsed is Dictionary and parsed.has("result") and not parsed.has("error"):
		var target: Dictionary = HORIZONS_BODIES[horizons_body_id]
		var cache := {
			"body_id": horizons_body_id,
			"body_name": target["name"],
			"requested_utc": Time.get_datetime_string_from_system(true, true),
			"api_source": parsed.get("signature", {}).get("source", "NASA/JPL Horizons API"),
			"coordinate_center": "Sun center (Horizons CENTER=500@10)",
			"reference_plane": "Ecliptic",
			"time_scale": "UT",
			"units": "AU positions; AU/day velocities (OUT_UNITS=AU-D)",
			"result": str(parsed["result"])
		}
		var file := FileAccess.open(_horizons_cache_path(horizons_body_id), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(cache, "  "))
		_refresh_horizons_display()
		return
	var fallback := _load_horizons_cache(horizons_body_id)
	if fallback.is_empty():
		_refresh_horizons_display("HORIZONS UNAVAILABLE (HTTP %d / ERROR %d)" % [response_code, result])
	else:
		_refresh_horizons_display("LIVE REQUEST FAILED (HTTP %d / ERROR %d) — SHOWING LAST SUCCESSFUL CACHE" % [response_code, result])

func _audio_control(setting_key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(MissionState.audio_settings[setting_key])
	slider.custom_minimum_size = Vector2(220, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label("%d%%" % roundi(slider.value * 100.0), 12, TEXT)
	value_label.custom_minimum_size.x = 42
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float) -> void:
		MissionState.audio_settings[setting_key] = value
		MissionState.save_audio_settings()
		_update_audio_players()
		value_label.text = "%d%%" % roundi(value * 100.0)
	)
	row.add_child(slider)
	row.add_child(value_label)
	return row

func _audio_toggle(setting_key: String, caption: String) -> Control:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = bool(MissionState.audio_settings[setting_key])
	_set_font_size(toggle, 11)
	toggle.toggled.connect(func(enabled: bool) -> void:
		MissionState.audio_settings[setting_key] = enabled
		MissionState.save_audio_settings()
		_update_audio_players()
	)
	return toggle

func _update_audio_players() -> void:
	if is_instance_valid(music_player):
		music_player.volume_db = linear_to_db(maxf(0.001, float(MissionState.audio_settings["music"])))
		if MissionState.audio_settings["music_enabled"] and not music_player.playing:
			music_player.play()
		elif not MissionState.audio_settings["music_enabled"] and music_player.playing:
			music_player.stop()
	if is_instance_valid(sfx_player):
		sfx_player.volume_db = linear_to_db(maxf(0.001, float(MissionState.audio_settings["sfx"])))

func _fullscreen_control() -> Control:
	var toggle := CheckButton.new()
	toggle.text = "FULLSCREEN"
	toggle.add_theme_color_override("font_color", MUTED)
	toggle.add_theme_color_override("font_hover_color", TEXT)
	_set_font_size(toggle, 13)
	toggle.button_pressed = get_window().mode == Window.MODE_FULLSCREEN
	toggle.toggled.connect(func(enabled: bool) -> void:
		get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
		MissionState.save_audio_settings()
	)
	return toggle

func _resolution_control() -> Control:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(180, 38)
	_set_font_size(option, 13)
	var selected_index := 0
	for i in RESOLUTIONS.size():
		var resolution: Vector2i = RESOLUTIONS[i]
		option.add_item("%d × %d" % [resolution.x, resolution.y])
		option.set_item_metadata(i, resolution)
		if get_window().size == resolution:
			selected_index = i
	option.select(selected_index)
	option.item_selected.connect(func(index: int) -> void:
		var selected_resolution: Vector2i = option.get_item_metadata(index)
		get_window().size = selected_resolution
		MissionState.save_audio_settings()
	)
	return option

func _setting_row(caption: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46
	row.add_theme_constant_override("separation", 20)
	var label := _label(caption, 11, MUTED)
	label.custom_minimum_size = Vector2(190, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(control)
	return row

func _add_back_button(parent: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 3
	parent.add_child(spacer)
	var back := Button.new()
	back.text = "←   BACK TO COMMAND"
	back.custom_minimum_size = Vector2(230, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_apply_button_style(back, false)
	back.pressed.connect(_show_home)
	parent.add_child(back)

func _menu_button(caption: String) -> Button:
	var button := Button.new()
	button.text = "     " + caption + "     ›"
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_font_size(button, 16)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	_apply_button_style(button, true)
	button.pivot_offset = Vector2(220, 32)
	button.mouse_entered.connect(func() -> void:
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(button, "scale", Vector2(1.018, 1.018), 0.14)
	)
	button.mouse_exited.connect(func() -> void:
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(button, "scale", Vector2.ONE, 0.18)
	)
	return button

func _apply_button_style(button: Button, large: bool) -> void:
	button.add_theme_stylebox_override("normal", _style(PANEL, BORDER, 1, 5 if large else 4))
	button.add_theme_stylebox_override("hover", _style(PANEL_HOVER, ACCENT, 1, 5 if large else 4))
	button.add_theme_stylebox_override("pressed", _style(Color("123047"), ACCENT, 2, 5 if large else 4))
	button.add_theme_stylebox_override("focus", _style(PANEL, ACCENT, 1, 5 if large else 4))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _stat_row(caption: String, value: String, value_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 55
	row.add_theme_constant_override("separation", 6)
	var left := _label(caption, 11, MUTED)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var right := _label(value, 23, value_color)
	_set_font_size(right, 23)
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(left)
	row.add_child(right)
	return row

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(PANEL, 0.92), BORDER, 1, 7))
	return panel

func _page_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	return margin

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	_set_font_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _set_font_size(control: Control, base_size: int) -> void:
	control.set_meta("mission_control_font_size", base_size)
	var window_size := Vector2i(1920, 1080)
	if is_inside_tree():
		window_size = get_window().size
	var screen_scale := minf(float(window_size.x) / 1920.0, float(window_size.y) / 1080.0)
	screen_scale = clampf(screen_scale, 0.67, 1.5)
	control.add_theme_font_size_override("font_size", maxi(10, roundi(float(base_size) / screen_scale)))

func _refresh_responsive_typography() -> void:
	if not is_instance_valid(root):
		return
	var pending: Array[Node] = []
	pending.append(root)
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is Control and current.has_meta("mission_control_font_size"):
			_set_font_size(current, int(current.get_meta("mission_control_font_size")))
		for child in current.get_children():
			pending.append(child)

func _style(fill: Color, border: Color, border_size: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_size)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box

func _clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if current_page != "home":
		var backdrop := ColorRect.new()
		backdrop.name = "PageBackdrop"
		backdrop.color = Color(0.003, 0.009, 0.024, 0.95)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(backdrop)
		body.move_child(backdrop, 0)

func _animate_page_in() -> void:
	_refresh_responsive_typography()
	body.modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(body, "modulate:a", 1.0, 0.25)

func heading_wrap_size(container: MarginContainer) -> void:
	container.add_theme_constant_override("margin_top", 1)
	container.add_theme_constant_override("margin_bottom", 2)
