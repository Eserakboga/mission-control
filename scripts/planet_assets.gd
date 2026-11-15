extends RefCounted
## Local NASA planet models and maps used by the menu and launch scene.

const MODEL_PATHS := {
	"EARTH": "res://assets/planets/earth_with_clouds.glb",
	"MARS": "res://assets/planets/mars.glb",
	"THE MOON": "res://assets/planets/moon_lro_small.glb",
	"SATURN": "res://assets/planets/saturn.glb"
}

const MODEL_RADII := {
	"EARTH": 500.0,
	"MARS": 500.0,
	"THE MOON": 1.271864,
	"SATURN": 1165.451
}

const SURFACE_TEXTURE_PATHS := {
	"EARTH": "res://assets/planets/earth_blue_marble.jpg",
	"MARS": "res://assets/planets/mars_global_map.jpg",
	"THE MOON": "res://assets/planets/moon_global_map.jpg"
}

const CLOUD_MASK_PATH := "res://assets/planets/earth_cloud_mask.png"

const SPHERE_DISC_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float ambient_floor = 0.18;
uniform float diffuse_strength = 0.88;
uniform vec3 light_direction = vec3(-0.48, 0.28, 0.83);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r2 = dot(p, p);
	if (r2 >= 1.0) { discard; }
	vec3 n = normalize(vec3(p.x, p.y, sqrt(max(0.0, 1.0 - r2))));
	vec2 map_uv = vec2(atan(n.x, n.z) / 6.28318530718 + 0.5, 0.5 - asin(clamp(n.y, -1.0, 1.0)) / 3.14159265359);
	vec3 surface = texture(TEXTURE, map_uv).rgb;
	float diffuse = ambient_floor + diffuse_strength * max(dot(n, normalize(light_direction)), 0.0);
	float rim = pow(1.0 - max(n.z, 0.0), 3.0);
	vec3 color = surface * diffuse + vec3(0.08, 0.30, 0.52) * rim * 0.42;
	float edge = 1.0 - smoothstep(0.985, 1.0, r2);
	COLOR = vec4(color, edge);
}
"""

static func load_model(body_key: String) -> PackedScene:
	var model_path: String = MODEL_PATHS.get(body_key.to_upper(), "")
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return null
	return load(model_path) as PackedScene

static func instantiate_model(body_key: String, visible_radius: float) -> Node3D:
	var packed_model := load_model(body_key)
	if packed_model == null:
		return null
	var model := packed_model.instantiate() as Node3D
	if model == null:
		return null
	var model_radius: float = MODEL_RADII.get(body_key.to_upper(), 500.0)
	model.scale = Vector3.ONE * (visible_radius / model_radius)
	return model

static func load_surface_texture(body_key: String) -> Texture2D:
	var texture_path: String = SURFACE_TEXTURE_PATHS.get(body_key.to_upper(), "")
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D

static func create_2d_globe(texture: Texture2D, body_key: String = "") -> TextureRect:
	var globe := TextureRect.new()
	globe.name = "PlanetSurfaceDisc"
	globe.texture = texture
	globe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	globe.stretch_mode = TextureRect.STRETCH_SCALE
	globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SPHERE_DISC_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	if body_key.to_upper() == "THE MOON" or body_key.to_upper() == "MOON":
		# The lunar card uses a higher soft fill so the sphere's upper and lower
		# limbs retain visible albedo detail instead of falling into near-black.
		material.set_shader_parameter("ambient_floor", 0.50)
		material.set_shader_parameter("diffuse_strength", 0.48)
		material.set_shader_parameter("light_direction", Vector3(-0.36, 0.28, 0.89))
	globe.material = material
	return globe

static func add_earth_cloud_layer(parent: Node3D, earth_model: Node3D, visible_radius: float) -> MeshInstance3D:
	var source_mesh := _find_mesh_instance(earth_model)
	if source_mesh == null or source_mesh.mesh == null:
		return null
	var layer := MeshInstance3D.new()
	layer.name = "NASACloudLayer"
	layer.mesh = source_mesh.mesh
	layer.scale = Vector3.ONE * (visible_radius * 1.009 / MODEL_RADII["EARTH"])
	layer.material_override = cloud_layer_material()
	parent.add_child(layer)
	return layer

static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null

static func cloud_layer_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode blend_mix, depth_prepass_alpha, cull_back, unshaded;
	uniform sampler2D cloud_mask : source_color, filter_linear_mipmap, repeat_enable;
	varying vec3 cloud_direction;
	void vertex() { cloud_direction = normalize(VERTEX); }
	void fragment() {
		float coverage = texture(cloud_mask, UV).r;
		ALBEDO = vec3(0.90, 0.95, 1.0);
		float polar_fade = 1.0 - smoothstep(0.82, 0.98, abs(cloud_direction.y));
		ALPHA = coverage * polar_fade * 0.20;
	}
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cloud_mask", load(CLOUD_MASK_PATH))
	return material
