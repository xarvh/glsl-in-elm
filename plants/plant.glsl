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
    */

    return p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
}


bool pointInsideTri(vec2 p, vec2 a, vec2 b, vec2 c) {

    bool collision = false;

    if (pointProjectionIntersectsSegment(a, b, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(b, c, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(c, a, p)) collision = !collision;

    return collision;
}


bool pointInsideQuad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {

    bool collision = false;

    if (pointProjectionIntersectsSegment(a, b, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(b, c, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(c, d, p)) collision = !collision;
    if (pointProjectionIntersectsSegment(d, a, p)) collision = !collision;

    return collision;
}

