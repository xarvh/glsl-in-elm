local pprint = require('pprint')
local hsl = require('hsl')


local plantVertexShader = [[

uniform vec2 u_size;
uniform vec2 u_topLeft;
varying vec2 v_world_position;

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    vec2 normalized_position = (vertex_position.xy - u_topLeft) / u_size - 0.5;

    v_world_position = (normalized_position + 0.5) * 4;

    return transform_projection * vertex_position;
}

]]



local terrainFragmentShader =
    love.filesystem.read('terrain.frag')
      :gsub('@@TERRAIN_WIDTH@@', 4)
      :gsub('@@TERRAIN_HEIGHT@@', 4)
      :gsub('@@TERRAIN_TEXTURES_COUNT@@', 4)
      :gsub('@@TERRAIN_TYPES_COUNT@@', 4)



terrains = {{
    colorTextureIndex = 1,
    colorTextureScale = 0.25,

    noiseTextureIndex = 0,
    noiseTextureScale = 1,
}, {
    colorTextureIndex = 2,
    colorTextureScale = 0.25,

    noiseTextureIndex = 1,
    noiseTextureScale = 1,
}, {
    colorTextureIndex = 1,
    colorTextureScale = 0.5,

    noiseTextureIndex = 0,
    noiseTextureScale = 0.5,
}, {
    colorTextureIndex = 1,
    colorTextureScale = 0.5,

    noiseTextureIndex = 0,
    noiseTextureScale = 0.5,
}}

terrainMap = {
  0, 0, 0, 0,
  0, 1, 1, 0,
  0, 0, 1, 0,
  0, 0, 0, 0,
}




-- Main -----------------------------------------------------------


function love.load()
    time = 0
    terrainShader = love.graphics.newShader(terrainFragmentShader, plantVertexShader)

    seamlessPlasmaColor = love.graphics.newImage("seamlessPlasmaColor.png")
    seamlessPlasmaColor:setWrap("repeat", "repeat")


    t1 = love.graphics.newImage("burnt_sand.png")
    t1:setWrap("repeat", "repeat")

    t2 = love.graphics.newImage("burnt_sand_light.png")
    t2:setWrap("repeat", "repeat")

    t3 = love.graphics.newImage("burnt_sand_lighter.png")
    t3:setWrap("repeat", "repeat")


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


    local s = math.floor(0.9 * math.min(ww, wh))
    local x = 0.05 * ww + 1.01
    local y = 0.05 * wh + 1.01

    local shaderQuad = {
        x - 0, y - 0,
        x + s, y - 0,
        x + s, y + s,
        x - 0, y + s,
    }



    love.graphics.setShader(terrainShader)
    -- Vertex Shader
    recklessSend(terrainShader, "u_size", { s, s })
    recklessSend(terrainShader, "u_topLeft", { x, y })

    -- Frag Shader
    recklessSend(terrainShader, "u_terrain_map", unpack(terrainMap))

    for i, terrain in ipairs(terrains) do
      n = "[" .. (i - 1) .. "]"
      for k, v in pairs(terrain) do
        recklessSend(terrainShader, "u_terrains" .. n .. "." .. k, v);
      end
    end

    recklessSend(terrainShader, "u_textures", seamlessPlasmaColor, t1, t2, t3 )
    recklessSend(terrainShader, "u_time", time)
    love.graphics.polygon("fill", shaderQuad)

end
