#define pi 3.1415926535897932384626433832795

varying vec2 v_pos;
uniform Image u_colorMap;



vec4 effect(vec4 _, Image __, vec2 ___, vec2 ____ ) {

    vec2 corners[4];
    corners[0] = vec2(-0.5, -0.5);
    corners[1] = vec2( 0.5, -0.5);
    corners[2] = vec2( 0.5,  0.5);
    corners[3] = vec2(-0.5,  0.5);

    vec3 colors[4];
    colors[0] = vec3(1, 0, 0);
    colors[1] = vec3(0, 1, 0);
    colors[2] = vec3(0, 0, 1);
    colors[3] = vec3(0, 0, 0);

    vec3 color = vec3(0, 0, 0);
    float weights[4];
    float total = 0;
    for (int i = 0; i < 4; i++) {


        float t = 1 + 0.2 * Texel(u_colorMap, v_pos + 0.3 * i).r;


        float w = clamp(t - distance(corners[i], v_pos), 0, 1);
        color += colors[i] * w;
        total += w;
    }



    return vec4(color / total, 1);
}


