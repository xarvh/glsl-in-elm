#define pi 3.1415926535897932384626433832795

/*
 * This is a GLSL implementation of http://www.jeffreythompson.org/collision-detection/poly-point.php
 */

bool pointProjectionIntersectsSegment(vec2 a, vec2 b, vec2 p) {

    // if py does not lie between ay and by, we're out
    if ((a.y > p.y) == (b.y > p.y)) {
        return false;
    }

    /* This looks eerily similar to the equation of a line by two points, but I'm not sure why it works here.

       *MAGIC!*

       p.x - a.x   b.x - a.x
       --------- < ---------
       p.y - a.y   b.y - a.y


       Weirdly if I move the (b.y - a.y) to the left to get replace the division with a multiplication
       it behaves weirdly, whether I adjust the comparison op or not.
       I assume that this is related to the sign of (b.y - a.y).
    */

    return (p.x - a.x) < (b.x - a.x) * (p.y - a.y) / (b.y - a.y);
}



bool pointInsideQuad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {

    bool collision = false;

    if (pointProjectionIntersectsSegment(a, b, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(b, c, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(c, d, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(d, a, p)) collision = !collision;

    return collision;
}



/*
 * LOVE stuff
 */
#define branches_per_tree @@maxBranchesPerTree@@
#define vertex_per_branch 4
#define leaves_per_tree branches_per_tree

varying vec2 v_pos;
uniform vec2 u_size;
uniform vec2 u_topLeft;
uniform vec2 u_branches[branches_per_tree * vertex_per_branch];
uniform vec4 u_leaves[leaves_per_tree];

uniform Image u_shape;
uniform Image u_alphaBrush;
uniform Image u_colorMap;

vec4 effect(vec4 _, Image __, vec2 ___, vec2 ____ ) {

    bool isInsideBranch = false;
    vec2 ub[] = u_branches;
    for (int b = 0; b < branches_per_tree * vertex_per_branch; b += vertex_per_branch) {
      if (pointInsideQuad(v_pos, ub[b], ub[b + 1], ub[b + 2], ub[b + 3])) {
        isInsideBranch = true;
        break;
      }
    }

    vec4 branchColor = vec4(0.48, 0.31, 0.2, 1.0);

    vec3 leavesColor;
    bool haveFoliage = false;

    // Use the 3 channels as 3 different textures to reduce repeating
    // artifacts and to smooth the values.
    float t1 = Texel(u_colorMap, 5.4 * v_pos - 3 * ub[3]).r;
    float t2 = Texel(u_colorMap, 8.7 * v_pos - 5 * ub[7]).g;
    float t3 = Texel(u_colorMap, 6.3 * v_pos - 7 * ub[11]).b;

    if (t1 + t2 + t3 > 1.3) {
      for (int l = 0; l < leaves_per_tree; l++) {
        vec4 leaf = u_leaves[l];

        // z, w are width and height
        vec2 p = (v_pos - leaf.xy) / leaf.zw;

        float noise = Texel(u_shape, v_pos).g;
        float threshold = 0.1;

        bool isInsideFoliage = (1 - length(p)) * (0.1 + noise) > threshold;

        if (isInsideFoliage) {
            float v = Texel(u_colorMap, v_pos).g;
            // varying the color with the height gives a bit more of volume to the foliage
            float k = 1.0 - 0.9 * p.y;
            vec3 color = mix(vec3(0.03, 0.23, 0.01), vec3(0.04, 0.56, 0.04), v * k);
            if (!haveFoliage) {
              leavesColor = color;
              haveFoliage = true;
            } else {
              leavesColor = mix(leavesColor, color, Texel(u_shape, p).b);
            }
        }
      }
    }

    if (!haveFoliage) {
      if (isInsideBranch) {
        return branchColor;
      } else {
        // TODO discard
        return vec4(0.1, 0.1, 0.9, 1.0);
      }
    }

    return vec4(leavesColor, 1.0);
}


