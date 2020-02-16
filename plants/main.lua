local pprint = require('pprint')
local hsl = require('hsl')


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



local plantFragmentShader =
    love.filesystem.read('plant.frag'):gsub('@@maxBranchesPerTree@@', maxBranchesPerTree)


-- Linear --------------------------------------------------------------------


function vec2(x, y)
  local v = {}
  v.x = x
  v.y = y
  return v
end


function vec2add(a, b)
  return vec2(a.x + b.x, a.y + b.y)
end


function vec2sub(a, b)
  return vec2(a.x - b.x, a.y - b.y)
end


function vec2rotate(v, angle)
  local sinA = math.sin(-angle)
  local cosA = math.cos(angle)
  return vec2(v.x * cosA - v.y * sinA, v.x * sinA + v.y * cosA)
end



-- Ranges --------------------------------------------------------------------


function rangeNew(a, b, isInt)
  local r = {}
  r.min = math.min(a, b)
  r.max = math.max(a, b)
  r.isInt = isInt
  return r
end


function rangeRandom(range)
  if range.isInt then
    return love.math.random(range.min, range.max)
  else
    return intervalRandom(range.min, range.max)
  end
end


function rangeSub(range)
  return rangeNew(rangeRandom(range), rangeRandom(range))
end


function intervalRandom(min, max)
  return min + love.math.random() * (max - min)
end


function signRandom()
  if love.math.random(0, 1) == 0 then
    return -1
  end
  return 1
end


-- Tree Generation -----------------------------------------------------------



function makeSpeciesWord(ranges, wordsCount)

  local word = {}
  word.length = rangeSub(ranges.length)
  word.bottomWidth = rangeSub(ranges.bottomWidth)
  word.relativeTopWidth = rangeSub(ranges.relativeTopWidth)
  word.angle = rangeSub(ranges.angle)
  word.verticality = love.math.random(0, 1)

  word.children = {}
  local childrenCount = rangeRandom(ranges.childrenCount)

  for i = 1, childrenCount do
    table.insert(word.children, love.math.random(1, wordsCount))
  end

  return word
end



function speciesNew()

  local ranges = {}
  ranges.length = rangeNew(0.3, 0.9)
  ranges.bottomWidth = rangeNew(0.9, 1.0)
  ranges.relativeTopWidth = rangeNew(0.4, 1)
  ranges.angle = rangeNew(0, 0.25 * math.pi)
  ranges.childrenCount = rangeNew(1, 3, "integer")

  local wordsCount = love.math.random(1, 5)

  local species = {}
  for i = 1, wordsCount do
    table.insert(species, makeSpeciesWord(ranges, wordsCount))
  end

  function randomFoliageHsl()
    return
      { intervalRandom(70, 145)
      , intervalRandom(0.6, 0.9)
      , intervalRandom(0.3, 1.0)
      }
  end

  local a = randomFoliageHsl()
  local b = randomFoliageHsl()

  -- compare Lightnes to put the darker color on the bottom
  if (a[2] > b[2]) then
    b, a = a, b
  end

  species.foliageBottomColor = hsl.toRgb(unpack(a))
  species.foliageTopColor = hsl.toRgb(unpack(b))

  pprint(a, b)

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

  local angle = signRandom() * rangeRandom(word.angle)

  if maybeParent then
    local parent = maybeParent
    branch.origin = parent.tip
    branch.angle = (1 - branch.word.verticality) * parent.angle + angle
    branch.length = parent.length * rangeRandom(word.length)
    branch.bottomWidth = parent.topWidth * rangeRandom(word.bottomWidth)
  else
    branch.origin = vec2(0, 0.5)
    branch.angle = 0.3 * angle
    branch.length = 0.4 * rangeRandom(word.length)
    branch.bottomWidth = 0.04 * rangeRandom(word.bottomWidth)
  end

  local tipOffset = vec2rotate(vec2(0, -branch.length), branch.angle)
  branch.tip = vec2add(branch.origin, tipOffset)
  branch.topWidth = branch.bottomWidth * rangeRandom(word.relativeTopWidth)

  return branch
end



function treeNew(species)

  local rootBranch = branchNew(species[1], nil)

  local growingStart = 1
  local growingEnd = 1
  local branches = { rootBranch }

  while #branches < maxBranchesPerTree do
    for childBranchIndex = 1, maxChildrenPerBranch do
      for branchIndex = growingStart, growingEnd do
        local branch = branches[branchIndex]
        if childBranchIndex <= #(branch.word.children) and #branches < maxBranchesPerTree then
          local wordIndex = branch.word.children[childBranchIndex]
          table.insert(branches, branchNew(species[wordIndex], branch))
        end
      end
    end
    growingStart = growingEnd + 1
    growingEnd = #branches
  end

  branches.species = species

  return branches
end


function branchToQuad(branch)
  local ht = vec2rotate(vec2(0.5 * branch.topWidth, 0), branch.angle)
  local bt = vec2rotate(vec2(0.5 * branch.bottomWidth, 0), branch.angle)

  local a = vec2add(branch.origin, bt)
  local b = vec2sub(branch.origin, bt)
  local c = vec2sub(branch.tip, ht)
  local d = vec2add(branch.tip, ht)

  return { a, b, c, d }
end


-- Main -----------------------------------------------------------


function treeGetBranchQuads(tree)
    local branchQuads = {}
    for i, b in ipairs(tree) do
      local q = branchToQuad(b)
      for d = 1, 4 do
        table.insert(branchQuads, { q[d].x, q[d].y })
      end
    end
    return branchQuads
end


function treeGetLeaves(tree)
    local leaves = {}
    for i, b in ipairs(tree) do
      local w = 0.8 * math.max(b.bottomWidth, b.length)
      local h = 6.0 * math.min(b.bottomWidth, b.length)
      table.insert(leaves, { b.tip.x, b.tip.y, w, h })
    end
    return leaves
end




function love.load()
    time = 0
    plantShader = love.graphics.newShader(plantFragmentShader, plantVertexShader)

    seamlessPlasmaColor = love.graphics.newImage("seamlessPlasmaColor.png")
    seamlessPlasmaColor:setWrap("repeat", "repeat")
    foliageAlpha = love.graphics.newImage("foliageBrush2.png")
    foliageAlpha:setWrap("repeat", "repeat")
    seamlessPlasma1 = love.graphics.newImage("seamlessPlasma1.png")
    seamlessPlasma1:setWrap("repeat", "repeat")

    species = speciesNew()

    trees = {}
    for i = 1, 9 do
      local tree = treeNew(species)
      tree.branchQuads = treeGetBranchQuads(tree)
      tree.leaves = treeGetLeaves(tree)
      table.insert(trees, tree)
    end



    local leafType = {}
    for tIndex = 0, 5 do
      local t = {}
      table.insert(leafType, t)

      t.r = intervalRandom(0.1, 0.4)
      t.g = intervalRandom(0.2, 1.0)
      t.b = intervalRandom(0.1, 0.3)

      t.w = 0.01 --intervalRandom(0.005, 0.02)
      t.h = t.w --intervalRandom(0.04, 0.12)
      t.a = intervalRandom(0.3, 0.6) * math.pi
    end


    leaves = {}
    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()

    for leafIndex = 1, 12500 do
        local leaf = {}
        local t = leafType[love.math.random(1, #leafType)]

        leaf.r = t.r
        leaf.g = t.g
        leaf.b = t.b

        leaf.x = love.math.random() * ww
        leaf.y = love.math.random() * ww

        leaf.w = t.w * ww
        leaf.h = t.h * ww
        leaf.angle = signRandom() * t.a

        table.insert(leaves, leaf)
    end

    --[[
    local w = 50
    local h = 50
    for i = 0, 300 do
      local rect = {}

      rect.r = 0.0 + 0.5 * love.math.random()
      rect.g = 0.5 + 0.5 * love.math.random()
      rect.b = 0.2 + 0.2 * love.math.random()
      rect.w = w
      rect.h = h
      rect.angle = math.pi * love.math.random()
      table.insert(rects, rect)
    end
    --]]


end





function love.update( dt )
    time = time + dt
end



local recklessErrors = {}

function recklessSend(shader, name, ...)
  local status, err = pcall(shader.send, shader, name, unpack({...}))
  if not status then
    if not recklessErrors[err] then
      recklessErrors[err] = true
      print('------------- reckless:')
      print(err)
    end
  end
end


function love.draw()

    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()

    local s = math.floor(0.3 * math.min(ww, wh))

    for i = 0, 2 do
      for j = 0, 2 do
        local x = 0.05 * ww + 1.01 * s * i
        local y = 0.05 * wh + 1.01 * s * j

        local shaderQuad = {
            x - 0, y - 0,
            x + s, y - 0,
            x + s, y + s,
            x - 0, y + s,
        }

        local tree = trees[i + j * 3 + 1]
        love.graphics.setShader(plantShader)
        recklessSend(plantShader, "u_size", { s, s })
        recklessSend(plantShader, "u_topLeft", { x, y })
        recklessSend(plantShader, "u_branches", unpack(tree.branchQuads))
        recklessSend(plantShader, "u_leaves", unpack(tree.leaves))

        --recklessSend(plantShader, "u_alphaBrush", foliageAlpha)
        recklessSend(plantShader, "u_colorMap", seamlessPlasmaColor)
        recklessSend(plantShader, "u_shape", seamlessPlasma1)

        recklessSend(plantShader, "u_topColor", tree.species.foliageTopColor)
        recklessSend(plantShader, "u_bottomColor", tree.species.foliageBottomColor)

        love.graphics.polygon("fill", shaderQuad)

        --[[
        for bIndex, b in ipairs(tree) do
          local ww = b.bottomWidth * s
          local hh = b.length * s
          local xx = x + (0.5 + b.tip.x) * s - ww
          local yy = y + (0.5 + b.tip.y) * s - hh
          love.graphics.setShader()
          love.graphics.draw(foliageImage, xx, yy, ww / foliageImage:getWidth(), hh / foliageImage:getHeight())
        end
        --]]


      end
    end



    --[[
    for i = 0, 60 do
      love.graphics.push()
        love.graphics.setShader() --unpack(rgb))

        local rgb = hsl.toRgb(i * 6, 0.9, 0.95)
        love.graphics.setColor(unpack(rgb))

        love.graphics.origin()
        love.graphics.translate(40 + i * 10, 180)
        --love.graphics.rotate( r.angle )
        --love.graphics.translate(-r.w / 2, -r.h / 2)
        love.graphics.rectangle("fill", 0, 0, 40, 40)
      love.graphics.pop()
    end
    --]]





    --[=[
    for i, r in ipairs(leaves) do
      love.graphics.push()
        love.graphics.setColor(r.r, r.g, r.b)
        love.graphics.origin()
        love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
        love.graphics.rotate( r.angle )
        love.graphics.translate(-r.w / 2, -r.h / 2)
        love.graphics.rectangle("fill", 0, 0, r.w, r.h)
      love.graphics.pop()
    end
    --]=]




end
