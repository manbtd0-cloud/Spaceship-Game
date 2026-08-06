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
    return smoothstep(0.38, 0.49, max(cell.x, cell.y));
}

void fragment() {
    vec3 n = normalize(local_vertex);
    vec3 weights = pow(abs(n), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    float hex = hex_edges(n.yz) * weights.x
        + hex_edges(n.xz) * weights.y
        + hex_edges(n.xy) * weights.z;
    float focus = pow(max(dot(n, normalize(impact_direction)), 0.0), 30.0);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
    float reveal = mix(focus, 1.0, full_shell);
    ALBEDO = shield_color.rgb;
    EMISSION = shield_color.rgb * (1.5 + 4.0 * energy);
    ALPHA = energy * reveal * (0.24 + 0.76 * hex)
        * (0.35 + 0.65 * rim) * (0.55 + 0.45 * shield_ratio);
}
