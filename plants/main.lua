local pprint = require('pprint')



local maxBranchesPerTree = 10
local maxChildrenPerBranch = 3






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
#define branches_per_tree ]] .. maxBranchesPerTree .. "\n" .. [[
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



-- Tree Generation -----------------------------------------------------------



function makeSpeciesWord(wordsCount)
  local word = {}
  local continuationsCount = love.math.random(1, 3)

  word.continuation = {}
  for i=1,continuationsCount do
    table.insert(word.continuation, love.math.random(1, wordsCount))
  end

  return word
end



function makeSpecies()
  local tree = {}

  local wordsCount = love.math.random(1, 5)

  for i=1,wordsCount do
    table.insert(tree, makeSpeciesWord(wordsCount))
  end

  return tree
end



function newChildBranch(parentBranch, childIndex)

  local branch = {}
  branch.name = parentBranch.name .. childIndex
  branch.targetNumberOfChildren = 2
  return branch

end


function makeTree(species)

  local rootBranch = {}
  rootBranch.name = "R"
  rootBranch.targetNumberOfChildren = 2

  local growingStart = 1
  local growingEnd = 1
  local branches = { rootBranch }

  while #branches < maxBranchesPerTree do
    for childBranchIndex = 1, maxChildrenPerBranch do
      for branchIndex = growingStart, growingEnd do
        branch = branches[branchIndex]
        if childBranchIndex <= branch.targetNumberOfChildren and #branches < maxBranchesPerTree then
          table.insert(branches, newChildBranch(branch, childBranchIndex))
        end
      end
    end
    growingStart = growingEnd + 1
    growingEnd = #branches
  end

  return branches
end




-- Main -----------------------------------------------------------

function love.load()
    screen = love.graphics.newShader(plantFragmentShader, plantVertexShader)

    species = makeSpecies()
    makeTree(species)
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
