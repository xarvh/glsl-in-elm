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

    vec3 leavesColorAccum = vec3(0, 0, 0);
    float leavesAlphaAccum = 0;
    int leavesCount = 0;
    for (int l = 1; l < leaves_per_tree; l++) {
    //for (int l = 1; l < 2; l++) {
      vec4 leaf = u_leaves[l];

      // z, w are width and height
      vec2 p = (v_pos - leaf.xy) / leaf.zw;

      float noise = Texel(u_shape, v_pos).g;
      float threshold = 0.1;

      bool isInsideFoliage = (1 - length(p)) * (0.1 + noise) > threshold;

      if (isInsideFoliage) {
          float v = Texel(u_colorMap, v_pos).g;
          float k = 1.0 - 0.3 * p.y;
          leavesColorAccum += mix(vec3(0.04, 0.37, 0.07), vec3(0.04, 0.56, 0.04), v * k);
          leavesAlphaAccum += 0.9;
          leavesCount += 1;
      }
    }


    vec4 leavesColor = vec4(leavesColorAccum / leavesAlphaAccum, leavesAlphaAccum / leavesCount);

    if (leavesCount == 0) {
      if (isInsideBranch) {
        return branchColor;
      } else {
        return vec4(0.1, 0.1, 0.9, 1.0);
      }
    }

    if (isInsideBranch) {
      return mix(branchColor, leavesColor, leavesAlphaAccum / leavesCount);
    }

    return leavesColor;
}


