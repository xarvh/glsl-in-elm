#define pi 3.1415926535897932384626433832795



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





#define TERRAIN_WIDTH @@TERRAIN_WIDTH@@
#define TERRAIN_HEIGHT @@TERRAIN_HEIGHT@@
#define TERRAIN_TYPES_COUNT @@TERRAIN_TYPES_COUNT@@
#define TERRAIN_TEXTURES_COUNT @@TERRAIN_TEXTURES_COUNT@@



struct TerrainType {
    int colorTextureIndex;
    float colorTextureScale;

    int noiseTextureIndex;
    float noiseTextureScale;
};
    //int boundaries[TERRAIN_TYPES_COUNT];



varying vec2 v_world_position;

uniform int u_terrain_map[TERRAIN_WIDTH * TERRAIN_HEIGHT];
uniform TerrainType u_terrains[TERRAIN_TYPES_COUNT];
uniform Image u_textures[TERRAIN_TEXTURES_COUNT];
uniform float u_time;



struct Corner {
    vec2 position;
    //TerrainType terrain;
    float solidRadius;
    vec3 color;
};



vec3 getTerrainColor() {

    Corner corners[4];

    // This is the junction point between the four tiles
    vec2 junction_center = floor(v_world_position + 0.5);

    vec2 pos = v_world_position - junction_center;

    // And these are the 4 corners we use as base for the interpolation
    corners[0].position = vec2(-0.5, -0.5);
    corners[1].position = vec2( 0.5, -0.5);
    corners[2].position = vec2( 0.5,  0.5);
    corners[3].position = vec2(-0.5,  0.5);


    for (int i = 0; i < 4; i++) {
      vec2 p = junction_center + corners[i].position;

      int tileIndex = 0;
      tileIndex += int(clamp(p.x, 0, TERRAIN_WIDTH - 1));
      tileIndex += int(clamp(p.y, 0, TERRAIN_HEIGHT - 1)) * TERRAIN_WIDTH;
      TerrainType t = u_terrains[u_terrain_map[tileIndex]];

      // TODO this is ugly
      vec4 noise_v = Texel(u_textures[0], v_world_position * t.noiseTextureScale);
      float noise;
      if (t.noiseTextureIndex == 0) noise = noise_v.r;
      else if (t.noiseTextureIndex == 1) noise = noise_v.g;
      else noise = noise_v.b;

      // TODO if animated multiply by `0.6 + 0.4 * sin(0.7 * u_time)`
      corners[i].solidRadius = clamp(0.49 * (0.4 + 0.6 * noise), 0, 0.49);

      corners[i].color = Texel(u_textures[t.colorTextureIndex], v_world_position * t.colorTextureScale).rgb;
    }


    /*
    for (int i = 0; i < 4; i++) {
      if (distance(corners[i].position, pos) < corners[i].solidRadius) {
        if (i == 0) return vec3(1, 0, 0);
        if (i == 1) return vec3(0, 1, 0);
        if (i == 2) return vec3(0, 0, 1);
        if (i == 3) return vec3(1, 0, 1);
      }
    }
    */



    vec3 colorAccumulator = vec3(0, 0, 0.002);
    float totalWeight = 0.01;
    for (int oIndex = 0; oIndex < 4; oIndex++) {

      // Origin point of the interpolation
      Corner origin = corners[oIndex];

      // TODO dIndex = oIndex + 1
      for (int dIndex = 0; dIndex < 4; dIndex++) if (dIndex != oIndex) {

          // Destination point of the interpolation
          Corner dest = corners[dIndex];

          vec2 o = intersecateRectWithRadius(origin.position, dest.position, origin.solidRadius);
          vec2 d = intersecateRectWithRadius(dest.position, origin.position, dest.solidRadius);

          // We project v_pos over the OD segment to figure out how to mix origin and dest colors.
          // When the projection lies between O and D its values should go from 0 (O) to 1 (D).
          float normalizedProjection = dot(pos - o, d - o) / dot(d - o, d - o);


          vec3 interpolatedColor = mix(origin.color, dest.color, clamp(normalizedProjection, 0, 1));

          // The interpolated color will be interpolated *again* together with the colors from the other destinations
          // We base the interpolation weight on the distance between v_pos and OD.
          float di = distanceBetweenPointAndSegment(pos, o, d);
          float weight = 1 - di;

          /*
          if (oIndex == 0 && dIndex == 1 && abs(normalizedProjection - 0.5) < 0.03 ) {
            colorAccumulator += weight * vec3(1, 1, 1);
            totalWeight += weight;
          } else {
          */
            colorAccumulator += interpolatedColor * weight;
            totalWeight += weight;
          //}
      }
    }

    return colorAccumulator / totalWeight;
}



vec4 effect(vec4 _, Image __, vec2 ___, vec2 ____ ) {
    return vec4(getTerrainColor(), 1.0);
    //return vec4(u_terrains[2].colorTextureScale + 0.000001 * u_terrains[2].colorTextureIndex);
}
