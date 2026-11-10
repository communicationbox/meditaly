extends Node3D
## Cielo, sole e mare.

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float depth = VERTEX.z - v.z / v.w;
	depth = max(depth, 0.0);
	vec2 cell = floor(wpos.xz);
	float w1 = sin(cell.x * 0.35 + TIME * 1.1) * cos(cell.y * 0.28 - TIME * 0.8);
	float w2 = sin((cell.x + cell.y) * 0.13 + TIME * 0.5);
	float wave = w1 * 0.5 + w2 * 0.5;
	vec3 shallow = vec3(0.10, 0.62, 0.66);
	vec3 deep = vec3(0.02, 0.20, 0.42);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 4.5, depth));
	col += vec3(0.02, 0.04, 0.05) * wave;
	float foam = smoothstep(0.9 + wave * 0.4, 0.2, depth);
	ALBEDO = mix(col, vec3(0.9, 0.95, 0.95), foam * 0.7);
	ALPHA = mix(0.62, 1.0, smoothstep(0.0, 4.5, depth));  // al largo opaco: niente fondale del mondo in trasparenza
	ROUGHNESS = 0.18;
	SPECULAR = 0.55;
	NORMAL = normalize((VIEW_MATRIX * vec4(wave * 0.05, 1.0, w2 * 0.05, 0.0)).xyz);
}
"""


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 420.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 0.6
	add_child(sun)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.46, 0.80)
	sm.sky_horizon_color = Color(0.80, 0.86, 0.92)
	sm.ground_bottom_color = Color(0.03, 0.20, 0.36)
	sm.ground_horizon_color = Color(0.72, 0.82, 0.90)
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.74, 0.72, 0.72)
	e.ambient_light_energy = 0.62
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 1.3
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_hdr_threshold = 1.15
	e.fog_enabled = true
	e.fog_light_color = Color(0.72, 0.82, 0.92)
	e.fog_density = 0.00022 / Defs.MAP_SCALE
	e.fog_aerial_perspective = 0.4
	we.environment = e
	add_child(we)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000) * Defs.MAP_SCALE
	sea.mesh = pm
	sea.position = Vector3(Defs.WX / 2.0, Defs.SEA + 0.3, Defs.WZ / 2.0)
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
