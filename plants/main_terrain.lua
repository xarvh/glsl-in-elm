local pprint = require('pprint')
local hsl = require('hsl')


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



local terrainFragmentShader =
    love.filesystem.read('terrain.frag')--:gsub('@@maxBranchesPerTree@@', maxBranchesPerTree)


-- Main -----------------------------------------------------------


function love.load()
    time = 0
    terrainShader = love.graphics.newShader(terrainFragmentShader, plantVertexShader)

    seamlessPlasmaColor = love.graphics.newImage("seamlessPlasmaColor.png")
    seamlessPlasmaColor:setWrap("repeat", "repeat")
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
    local x = 0.05 * ww + 1.01
    local y = 0.05 * wh + 1.01

    local shaderQuad = {
        x - 0, y - 0,
        x + s, y - 0,
        x + s, y + s,
        x - 0, y + s,
    }



    love.graphics.setShader(terrainShader)
    recklessSend(terrainShader, "u_size", { s, s })
    recklessSend(terrainShader, "u_topLeft", { x, y })
    recklessSend(terrainShader, "u_colorMap", seamlessPlasmaColor)
    love.graphics.polygon("fill", shaderQuad)

end