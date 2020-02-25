#define pi 3.1415926535897932384626433832795

varying vec2 v_pos;
uniform Image u_colorMap;
uniform Image u_t1;
uniform Image u_t2;
uniform Image u_t3;


struct Terrain {
    vec2 corner;
    vec3 color;
    float noise;
    float solidRadius;
    float maxRadius;
};




float getNearness(Terrain t) {
    return t.solidRadius - distance(t.corner, v_pos);
}



vec4 effect(vec4 _, Image __, vec2 ___, vec2 ____ ) {

    Terrain terrains[4];

    terrains[0].corner = vec2(-0.5, -0.5);
    terrains[1].corner = vec2( 0.5, -0.5);
    terrains[2].corner = vec2( 0.5,  0.5);
    terrains[3].corner = vec2(-0.5,  0.5);

    terrains[0].color = Texel(u_t1, 0.1 * v_pos).rgb;
    terrains[1].color = Texel(u_t2, 0.5 * v_pos).rgb;
    terrains[2].color = Texel(u_t3, 0.9 * v_pos).rgb;
    terrains[3].color = Texel(u_t1, 0.9 * v_pos).rgb;

    terrains[0].noise = Texel(u_colorMap, v_pos).r;
    terrains[1].noise = Texel(u_colorMap, v_pos).g;
    terrains[2].noise = Texel(u_colorMap, v_pos).b;
    terrains[3].noise = Texel(u_colorMap, v_pos).r;

    terrains[0].solidRadius = 0.2;
    terrains[1].solidRadius = 0.2;
    terrains[2].solidRadius = 0.2;
    terrains[3].solidRadius = 0.2;

    terrains[0].maxRadius = 0.9;
    terrains[1].maxRadius = 0.9;
    terrains[2].maxRadius = 0.9;
    terrains[3].maxRadius = 0.9;



    vec3 color = vec3(0, 0, 0);
    float totalWeight = 0;
    for (int i = 1; i < 4; i++) {
      Terrain t = terrains[i];

      float d = distance(t.corner, v_pos) + 0.2 * (t.noise - 0.5);

      if (d < t.solidRadius) {
        return vec4(t.color, 1.0);
      }

      if (d > t.maxRadius) {
        continue;
      }

      float weight = clamp(1 - d, 0, 1);
      color += weight * t.color;
      totalWeight += weight;
    }

    return vec4(color / totalWeight, 1.0);
}


