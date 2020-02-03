local plantVertexShader = [[

uniform vec2 u_size;
uniform vec2 u_topLeft;
varying vec2 v_pos;

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    v_pos = (vertex_position.xy - u_topLeft) / u_size - 0.5;

    return transform_projection * vertex_position;
}

]]

local plantFragmentShader = [[
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



/*
 * LOVE stuff
 */

varying vec2 v_pos;
uniform vec2 u_size;
uniform vec2 u_topLeft;
uniform vec2 u_quads[4];

vec4 effect(vec4 _, Image __, vec2 ___, vec2 ____ ) {

    //bool isInside = pointInsideQuad(v_pos

    vec4 screen_colour = vec4(v_pos + 0.0, 0.0, 1.0);

    return screen_colour;
}


]]





function love.load()
    screen = love.graphics.newShader(plantFragmentShader, plantVertexShader)
end

function love.draw()
    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()

    local s = math.floor(0.8 * math.min(ww, wh))
    local x = math.floor(ww / 2 - s / 2)
    local y = math.floor(wh / 2 - s / 2)

    local quad = {
        x - 0, y - 0,
        x + s, y - 0,
        x + s, y + s,
        x - 0, y + s,
    }

    love.graphics.setShader(screen)
    screen:send("u_size", { s, s })
    screen:send("u_topLeft", { x, y })
    --screen:send("u_quads", {0.9, 0.2}, { 0.2, 0.3}, { 0.1, 0.4}, {0.3, 0.5})

    love.graphics.polygon("fill", quad)
end
