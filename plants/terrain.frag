#define pi 3.1415926535897932384626433832795

varying vec2 v_pos;
uniform Image u_colorMap;
uniform Image u_t1;
uniform Image u_t2;
uniform Image u_t3;
uniform float time;


struct Terrain {
    vec2 corner;
    vec3 color;
    float noise;
    float solidRadius;
};




float getNearness(Terrain t) {
    return t.solidRadius - distance(t.corner, v_pos);
}





/*
    Find the point on the segment AB with distance `radius` from A.
 */
vec2 intersecateRectWithRadius(vec2 a, vec2 b, float radius) {
    return a + (b - a) * radius / distance(a, b);
}



float distanceBetweenPointAndSegment(vec2 p, vec2 v, vec2 w) {
    // copied from https://stackoverflow.com/a/1501725/1454980
    float l2 = dot(v - w, v - w);
    if (l2 == 0.0) return distance(p, v);
    float t = max(0, min(1, dot(p - v, w - v) / l2));
    vec2 projection = v + t * (w - v);
    return distance(p, projection);
}




vec4 effect(vec4 _, Image __, vec2 ___, vec2 ____ ) {

    Terrain terrains[4];

    terrains[0].corner = vec2(-0.5, -0.5);
    terrains[1].corner = vec2( 0.5, -0.5);
    terrains[2].corner = vec2( 0.5,  0.5);
    terrains[3].corner = vec2(-0.5,  0.5);

    terrains[0].color = vec3(1, 0, 0);
    terrains[1].color = vec3(0, 1, 0);
    terrains[2].color = vec3(0, 0, 1);
    terrains[3].color = vec3(1, 0, 0);

    /*
    terrains[0].color = Texel(u_t1, 0.1 * v_pos).rgb;
    terrains[1].color = Texel(u_t2, 0.5 * v_pos).rgb;
    terrains[2].color = Texel(u_t3, 0.9 * v_pos).rgb;
    terrains[3].color = Texel(u_t1, 0.9 * v_pos).rgb;
    */

    terrains[0].noise = Texel(u_colorMap, v_pos).r;
    terrains[1].noise = Texel(u_colorMap, v_pos).g;
    terrains[2].noise = Texel(u_colorMap, v_pos).b;
    terrains[3].noise = Texel(u_colorMap, v_pos).r;

    terrains[0].solidRadius = 0.49;
    terrains[1].solidRadius = 0.49;
    terrains[2].solidRadius = 0.49;
    terrains[3].solidRadius = 0.49;




    vec3 colorAccumulator = vec3(0, 0, 0.002);
    float totalWeight = 0.01;
    for (int oIndex = 0; oIndex < 4; oIndex++) {

      // Origin point of the interpolation
      Terrain origin = terrains[oIndex];

      for (int dIndex = 0; dIndex < 4; dIndex++) if (dIndex != oIndex) {

          // Destination point of the interpolation
          Terrain dest = terrains[dIndex];

          vec2 o = intersecateRectWithRadius(origin.corner, dest.corner, origin.solidRadius);
          vec2 d = intersecateRectWithRadius(dest.corner, origin.corner, dest.solidRadius);


          /*
          if (oIndex == 1 && distance(o, v_pos) < 0.01) {
            colorAccumulator = vec3(1);
            totalWeight = 1;
          }
          */




          // We project v_pos over the OD segment to figure out how to mix origin and dest colors.
          // When the projection lies between O and D its values should go from 0 (O) to 1 (D).
          float normalizedProjection = dot(v_pos - o, d - o) / dot(d - o, d - o);

          vec3 interpolatedColor = mix(origin.color, dest.color, clamp(normalizedProjection, 0, 1));

          // The interpolated color will be interpolated *again* together with the colors from the other destinations
          // We base the interpolation weight on the distance between v_pos and OD.
          float di = distanceBetweenPointAndSegment(v_pos, o, d);
          float weight = 1 - di;

          colorAccumulator += interpolatedColor * weight;
          totalWeight += weight;
      }
    }

    return vec4(colorAccumulator / totalWeight, 1.0);
}


