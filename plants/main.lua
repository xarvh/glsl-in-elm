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



-- Ranges --------------------------------------------------------------------

function rangeNew(a, b, isInt)
  local r = {}
  r.min = math.min(a, b)
  r.max = math.max(a, b)
  r.isInt = isInt
  return r
end

function rangeSub(range)
  return rangeNew(rangeRandom(range), rangeRandom(range))
end

function rangeRandom(range)
  if range.isInt then
    return love.math.random(range.min, range.max)
  else
    return range.min + love.math.random() * (range.max - range.min)
  end
end


-- Tree Generation -----------------------------------------------------------



function makeSpeciesWord(ranges, wordsCount)

  local word = {}
  word.length = rangeSub(ranges.length)
  word.bottomWidth = rangeSub(ranges.bottomWidth)
  word.relativeTopWidth = rangeSub(ranges.relativeTopWidth)
  word.angle = rangeSub(ranges.angle)

  word.children = {}
  local childrenCount = rangeRandom(ranges.childrenCount)

  for i=1,childrenCount do
    table.insert(word.children, love.math.random(1, wordsCount))
  end

  return word
end



function makeSpecies()

  local ranges = {}
  ranges.length = rangeNew(0.2, 0.3)
  ranges.bottomWidth = rangeNew(0.03, 0.04)
  ranges.relativeTopWidth = rangeNew(0.5, 1)
  ranges.angle = rangeNew(0, 0)
  ranges.childrenCount = rangeNew(1, 3, "int")

  local wordsCount = love.math.random(1, 5)

  local species = {}
  for i=1,wordsCount do
    table.insert(species, makeSpeciesWord(ranges, wordsCount))
  end

  return species
end



function newChildBranch(parentBranch, childIndex)

  local branch = {}
  branch.name = parentBranch.name .. childIndex
  branch.targetNumberOfChildren = 2
  return branch

end



function branchNew(word, maybeParent)
  local branch = {}

  branch.word = word
  branch.length = rangeRandom(word.length)
  branch.bottomWidth = rangeRandom(word.bottomWidth)
  branch.relativeTopWidth = rangeRandom(word.relativeTopWidth)
  branch.angle = rangeRandom(word.angle)

  return branch
end



function makeTree(species)

  local rootBranch = wordToBranch(species[1], nil)

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
    pprint(species)
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
