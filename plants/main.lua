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
#define branches_per_tree 2
#define vertex_per_branch 4

varying vec2 v_pos;
uniform vec2 u_size;
uniform vec2 u_topLeft;
uniform vec2 u_branches[branches_per_tree * vertex_per_branch];

vec4 effect(vec4 _, Image __, vec2 ___, vec2 ____ ) {

    bool isInside = false;
    vec2 ub[] = u_branches;
    for (int b = 0; b < branches_per_tree * vertex_per_branch; b += vertex_per_branch) {
      if (pointInsideQuad(v_pos, ub[b], ub[b + 1], ub[b + 2], ub[b + 3])) {
        isInside = true;
        break;
      }
    }

    vec3 color = isInside ? vec3(1.0) : vec3(0.0);

    return vec4(color, 1.0);
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

    local branches = {
      { -0.3, -0.5 }, { 0.6, 0.0 }, { 0.5, 0.5 }, { -0.1, 0.5 },
      { -0.4, -0.4 }, { -0.3, -0.4 }, { -0.3, -0.3 }, { -0.4, -0.3 },
    }

    local shaderQuad = {
        x - 0, y - 0,
        x + s, y - 0,
        x + s, y + s,
        x - 0, y + s,
    }

    love.graphics.setShader(screen)
    screen:send("u_size", { s, s })
    screen:send("u_topLeft", { x, y })
    screen:send("u_branches", unpack(branches))

    love.graphics.polygon("fill", shaderQuad)
end
