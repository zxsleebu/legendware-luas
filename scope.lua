require('betterapi')
ffi = require("ffi")
hooks = require("hooks")

local VClient = hooks.vmt.new(ffi.cast("void*", utils.create_interface("client.dll", "VClient018")))
local unloaded = false

menu.next_line()
menu.add_color_picker("---------- custom scope ----------")

math.round = function(a) return math.floor(a + 0.5) end
function col(r, g, b, a)
    if a == nil then a = 255 end
    return color.new(r, g, b, a)
end
color.alpha = function(s, a)
    return col(s:r(), s:g(), s:b(), math.round(a))
end
color.alp_self = function(s, a) return s:alpha((a * s:a() / 255) * 255) end
local lerp = function(a, b, t)
    return a + (b - a) * t
end

menu.add_color_picker("scope color 1")
menu.add_color_picker("scope color 2")
menu.add_slider_int("scope anim speed", 5, 20)
menu.add_slider_int("scope offset", 0, 300)
menu.add_slider_int("scope size", 0, 400)
menu.add_slider_int("scope weight", 1, 3)

local scoped = false
function FrameStageNotify_hk(stage)
    pcall(function()
        if unloaded then return end
        if stage ~= 5 then return end
        if not engine.is_in_game() then return end
        local lp = entitylist.get_local_player()
        scoped = lp:get_prop_int("CCSPlayer", "m_bIsScoped") == 1
        lp:set_prop_int("CCSPlayer", "m_bIsScoped", 0)
    end)
    return FrameStageNotify_o(stage)
end
FrameStageNotify_o = VClient:hookMethod("void(__stdcall*)(int)", FrameStageNotify_hk, 37)

local ss = {
    x = engine.get_screen_width(),
    y = engine.get_screen_height(),
}
local anim = 0
client.add_callback("on_paint", function()
    if unloaded then return end
    local lp = entitylist.get_local_player()
    if not engine.is_in_game() then return end
    local x, y = ss.x / 2 + 1, ss.y / 2 + 1
    local o = menu.get_int("scope offset") * anim
    local s = menu.get_int("scope size") * anim
    local w = menu.get_int("scope weight") / 2
    local c0 = menu.get_color("scope color 1"):alp_self(anim)
    local c1 = menu.get_color("scope color 2"):alp_self(anim)
    local active = scoped and lp:get_health() > 0
    anim = math.max(lerp(anim, active and 1 or 0, menu.get_int("scope anim speed") * globals.get_frametime()), 0)
    if anim == 0 then return end
    local r = draw.gradientrect
    local r0, g0, b0, a0 = c0:r(), c0:g(), c0:b(), c0:a()
    local r1, g1, b1, a1 = c1:r(), c1:g(), c1:b(), c1:a()

    r(x - o - s, y - w, s, w * 2, r1, g1, b1, a1, r0, g0, b0, a0, true)
    r(x + o - 1, y - w, s, w * 2, r0, g0, b0, a0, r1, g1, b1, a1, true)
    r(x - w, y + o - 1, w * 2, s, r0, g0, b0, a0, r1, g1, b1, a1, false)
    r(x - w, y - o - s, w * 2, s, r1, g1, b1, a1, r0, g0, b0, a0, false)
end)

client.add_callback("unload", function()
    unloaded = true
    VClient:unHookAll()
end)