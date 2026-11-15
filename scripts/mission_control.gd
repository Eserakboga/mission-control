extends Node3D
const PlanetAssetLibrary = preload("res://scripts/planet_assets.gd")
## NASA model-based first-stage mission visualization.

const PLANET_RADIUS := 3.0
const ORBIT_RADIUS := 5.05
const ORBIT_TILT := deg_to_rad(24.0)

var planet: Node3D
var clouds: MeshInstance3D
var satellite: Node3D
var orbit_line: MeshInstance3D
var camera: Camera3D
var orbit_angle := 0.0
var camera_yaw := -0.52
var camera_pitch := 0.18
var camera_distance := 12.5
var dragging := false

const ATMOSPHERE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;
void fragment(){float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0); ALBEDO=vec3(0.10,0.42,1.0); ALPHA=0.025+rim*0.28;}
"""

const SKY_SHADER := """
shader_type sky;
float hash(vec3 p){p=fract(p*0.3183099+vec3(0.1));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
void sky(){vec3 d=normalize(EYEDIR); vec3 cell=floor(d*360.0); vec3 f=fract(d*360.0)-0.5; float r=hash(cell); float star=step(0.9968,r)*(1.0-smoothstep(0.02,0.20,length(f))); float tw=0.7+0.3*sin(TIME*(1.0+r*4.0)+r*80.0); vec3 neb=vec3(0.008,0.015,0.045)*(0.5+0.5*sin(d.y*24.0+d.x*11.0)); COLOR=vec3(0.0015,0.003,0.012)+neb+vec3(0.68,0.79,1.0)*star*tw*2.0;}
"""

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_planet()
	_setup_orbit_and_satellite()
	_setup_camera()
	_setup_menu()

func _setup_menu() -> void:
	var menu := CanvasLayer.new()
	menu.name = "MissionMenu"
	menu.layer = 10
	menu.set_script(load("res://scripts/ui/mission_menu.gd"))
	add_child(menu)

func _process(delta: float) -> void:
	orbit_angle = fmod(orbit_angle + delta * 0.22, TAU)
	planet.rotate_y(delta * 0.035)
	if is_instance_valid(clouds):
		clouds.rotate_y(delta * 0.045)
	_update_satellite()
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(7.0, camera_distance - 0.7)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(22.0, camera_distance + 0.7)
	elif event is InputEventMouseMotion and dragging:
		camera_yaw -= event.relative.x * 0.005
		camera_pitch = clampf(camera_pitch + event.relative.y * 0.004, -0.85, 0.85)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			dragging = false

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = _shader(SKY_SHADER)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.08
	world.environment = env
	add_child(world)

func _setup_lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "SolarKeyLight"
	key.rotation_degrees = Vector3(-24.0, -38.0, -12.0)
	key.light_color = Color(0.80, 0.88, 1.0)
	key.light_energy = 1.45
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "Earthshine"
	fill.position = Vector3(-5.0, -1.8, 3.0)
	fill.light_color = Color(0.08, 0.22, 0.65)
	fill.light_energy = 0.65
	fill.omni_range = 16.0
	add_child(fill)

func _setup_planet() -> void:
	planet = Node3D.new()
	planet.name = "Earth"
	add_child(planet)
	var earth_model := PlanetAssetLibrary.instantiate_model("EARTH", PLANET_RADIUS)
	if earth_model == null:
		push_error("NASA Earth model could not be loaded from assets/planets.")
		return
	earth_model.name = "NASA_Earth_With_Clouds_Model"
	planet.add_child(earth_model)
	clouds = PlanetAssetLibrary.add_earth_cloud_layer(self, earth_model, PLANET_RADIUS)

	var atmo_mesh := SphereMesh.new()
	atmo_mesh.radius = PLANET_RADIUS * 1.075
	atmo_mesh.height = PLANET_RADIUS * 2.15
	atmo_mesh.radial_segments = 96
	atmo_mesh.rings = 48
	var atmo := MeshInstance3D.new()
	atmo.name = "Atmosphere"
	atmo.mesh = atmo_mesh
	atmo.material_override = _material(ATMOSPHERE_SHADER)
	add_child(atmo)

func _setup_orbit_and_satellite() -> void:
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(181):
		var a := TAU * float(i) / 180.0
		immediate.surface_add_vertex(Vector3(cos(a) * ORBIT_RADIUS, 0.0, sin(a) * ORBIT_RADIUS))
	immediate.surface_end()
	orbit_line = MeshInstance3D.new()
	orbit_line.name = "OrbitalPath"
	orbit_line.mesh = immediate
	orbit_line.position = planet.position
	orbit_line.rotation.x = ORBIT_TILT
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.22, 0.65, 1.0, 0.8)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.emission_enabled = true
	line_mat.emission = Color(0.08, 0.42, 1.0)
	line_mat.emission_energy_multiplier = 1.8
	orbit_line.material_override = line_mat
	add_child(orbit_line)
	satellite = _build_satellite()
	add_child(satellite)
	_update_satellite()

func _build_satellite() -> Node3D:
	var root := Node3D.new()
	root.name = "OrbitalSatellite"
	var body_mat := _std_material(Color(0.72, 0.78, 0.83), 0.72, 0.24)
	var gold_mat := _std_material(Color(0.92, 0.48, 0.12), 0.55, 0.3)
	var panel_mat := _std_material(Color(0.025, 0.11, 0.24), 0.7, 0.25)
	panel_mat.emission_enabled = true
	panel_mat.emission = Color(0.015, 0.07, 0.19)
	_add_box(root, "Bus", Vector3(0.27, 0.24, 0.34), Vector3.ZERO, body_mat)
	_add_box(root, "Instrument", Vector3(0.15, 0.16, 0.12), Vector3(0.0, 0.20, 0.0), gold_mat)
	_add_box(root, "ArrayBoomL", Vector3(0.34, 0.045, 0.055), Vector3(-0.29, 0.0, 0.0), body_mat)
	_add_box(root, "ArrayBoomR", Vector3(0.34, 0.045, 0.055), Vector3(0.29, 0.0, 0.0), body_mat)
	_add_box(root, "SolarArrayL", Vector3(0.62, 0.035, 0.30), Vector3(-0.72, 0.0, 0.0), panel_mat)
	_add_box(root, "SolarArrayR", Vector3(0.62, 0.035, 0.30), Vector3(0.72, 0.0, 0.0), panel_mat)
	var dish := MeshInstance3D.new()
	var dish_mesh := SphereMesh.new()
	dish_mesh.radius = 0.17
	dish_mesh.height = 0.07
	dish_mesh.radial_segments = 24
	dish_mesh.rings = 8
	dish.mesh = dish_mesh
	dish.position = Vector3(0.0, 0.0, 0.23)
	dish.scale = Vector3(1.0, 0.35, 1.0)
	dish.material_override = _std_material(Color(0.84, 0.88, 0.9), 0.72, 0.22)
	root.add_child(dish)
	return root

func _add_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	parent.add_child(instance)

func _update_satellite() -> void:
	if not is_instance_valid(satellite):
		return
	var a := orbit_angle
	var orbit_point := Vector3(cos(a) * ORBIT_RADIUS, 0.0, sin(a) * ORBIT_RADIUS)
	satellite.global_position = planet.global_position + orbit_line.global_basis * orbit_point
	satellite.rotation = Vector3(0.0, a + PI * 0.5, 0.18)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "MissionCamera"
	camera.fov = 42.0
	camera.current = true
	camera.cull_mask = 1
	add_child(camera)
	_update_camera()

func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var direction := Vector3(cos(camera_pitch) * sin(camera_yaw), sin(camera_pitch), cos(camera_pitch) * cos(camera_yaw))
	camera.position = direction * camera_distance
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _shader(source: String) -> Shader:
	var result := Shader.new()
	result.code = source
	return result

func _material(source: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = _shader(source)
	return result

func _std_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result
