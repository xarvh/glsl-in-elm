local export = {}

export.toRgb = function (hh, s, v)
    if hh < 0 or hh > 360 then error("h " .. hh .. " out of range") end
    if s < 0 or s > 1 then error("s " .. s .. " out of range") end
    if v < 0 or v > 1 then error("v " .. v .. " out of range") end

    local h = hh / 360
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    local switch = {
        [0] = { v, t, p },
        [1] = { q, v, p },
        [2] = { p, v, t },
        [3] = { p, q, v },
        [4] = { t, p, v },
        [5] = { v, p, q }
    }

    return switch[i % 6]
end


return export
