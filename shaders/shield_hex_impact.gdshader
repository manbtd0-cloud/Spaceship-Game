shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 shield_color : source_color = vec4(0.12, 0.72, 1.0, 1.0);
uniform vec3 impact_direction = vec3(0.0, 0.0, -1.0);
uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float shield_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float full_shell : hint_range(0.0, 1.0) = 0.0;
uniform float hex_scale = 12.0;

varying vec3 local_vertex;

void vertex() {
    local_vertex = VERTEX;
}

float hex_edges(vec2 point) {
    vec2 p = point * hex_scale;
    vec2 q = vec2(p.x * 1.1547005, p.y + p.x * 0.5773503);
    vec2 cell = abs(fract(q) - 0.5);
    return smoothstep(0.36, 0.49, max(cell.x, cell.y));
}

void fragment() {
    vec3 n = normalize(local_vertex);
    vec3 weights = pow(abs(n), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    float hex = hex_edges(n.yz) * weights.x
        + hex_edges(n.xz) * weights.y
        + hex_edges(n.xy) * weights.z;
    float incidence = max(dot(n, normalize(impact_direction)), 0.0);
    float core = pow(incidence, 64.0);
    float halo = pow(incidence, 10.0);
    float focus = max(core, halo * 0.52);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
    float reveal = mix(focus, 1.0, full_shell);
    float cell_energy = mix(0.34, 1.0, hex);
    ALBEDO = shield_color.rgb;
    EMISSION = shield_color.rgb * (1.8 + 5.2 * energy + 2.5 * core);
    ALPHA = energy * reveal * cell_energy
        * (0.46 + 0.54 * rim) * (0.58 + 0.42 * shield_ratio);
}
