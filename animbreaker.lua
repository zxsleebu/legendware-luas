ffi = require("ffi")
local nullptr = ffi.new("void*")
ffi.cdef[[
    typedef struct {
        char pad[44];
        int chokedPackets;
    } NetworkChannel_t;
    typedef struct {
        char pad[8];
	    float m_start;
	    float m_end;
        float m_state;
    } m_flposeparameter_t;
    short GetAsyncKeyState(int);
]]
local is_valid_ptr = function(ptr)
    local pointer = ffi.cast("void*", ptr)
    return pointer ~= nullptr and pointer
end
local ffi_interface = function(module, name)
    local ptr = utils.create_interface(module .. ".dll", name)
    return ffi.cast("void***", ptr)
end
local ffi_vmfunc = function(p, t, i)
    local fn = ffi.cast(t, p[0][i])
    return fn and function(...) return fn(p, ...) end or false
end
local unloaded = false

local VClientEntityList = ffi_interface("client", "VClientEntityList003")
local VEngineClient = ffi_interface("engine", "VEngineClient014")

local GetPlayerAddress_Native = ffi_vmfunc(VClientEntityList, "uintptr_t(__thiscall*)(void*, int)", 3)
local GetNetworkChannel_Native = ffi.cast("NetworkChannel_t*(*)(void*)", VEngineClient[0][78])
local GetPoseParameter = ffi.cast('m_flposeparameter_t*(__thiscall*)(void*, int)',
    utils.find_signature("client.dll", "55 8B EC 8B 45 08 57 8B F9 8B 4F 04 85 C9 75 15"))
entity.player = function(s)
    return entitylist.entity_to_player(s)
end

player.address = function(s)
    return GetPlayerAddress_Native(s:get_index())
end
player.studio_hdr = function(s)
    if not s then return end
    local addr = s:address()
    if not addr then return end
    local ptr = addr + 0x2950
    local studio_hdr = ffi.cast('void**', ptr) or error("failed to get studio_hdr")
    studio_hdr = studio_hdr[0] or error("failed to get studio_hdr")
    return studio_hdr
end
player.get_poseparam = function(s, index)
    if not s or not s:address() then return end
    local studio_hdr = s:studio_hdr()
    if not studio_hdr then return end
    local param = GetPoseParameter(studio_hdr, index) or error("failed to get poseparam")
    return param
end
player.set_poseparam = function(s, i, v)
    if not s then return end
    local t = s:get_poseparam(i)
    if not t then return end
    if t.m_start ~= v[1] then t.m_start = v[1] end
    if t.m_end ~= v[2] then t.m_end = v[2] end
    local state = v[3] or ((t.m_start + t.m_end) / 2)
    if t.m_state ~= state then t.m_state = state end
end
player.restore_poseparam = function(s)
    s:set_poseparam(0, {-180, 180})
    s:set_poseparam(12, {-90, 90})
    s:set_poseparam(6, {0, 1, 0})
end
player.in_air = function(s)
    return bit.band(s:get_prop_int("CBasePlayer", "m_fFlags"), 1) == 0
end
math.round = function(a) return math.floor(a + 0.5) end
local TimeToTicks = function (time)
    return math.round(time / globals.get_intervalpertick())
end
local GetNetworkChannel = function()
    local netchan = GetNetworkChannel_Native(VEngineClient)
    if not is_valid_ptr(netchan) then return false end
    return netchan[0]
end

client.add_callback("create_move", function()
    if unloaded then return end
    if menu.get_bool("skeet legs only visible") then
        return menu.set_int("misc.leg_movement", 2)
    end
    local network = GetNetworkChannel()
    if not network then return end
    menu.set_int("misc.leg_movement", network.chokedPackets == 0 and 2 or 1)
end)

menu.next_line()
menu.add_color_picker("----------- animfucker -----------")
menu.add_check_box("skeet legs only visible")
menu.add_check_box("pitch 0 on land")

local pitch_ticks = 0
client.add_callback("on_paint", function()
    if unloaded then return end
    if not engine.is_in_game() then return end
    local lp_index = engine.get_local_player_index()
    if globals.get_tickcount() % 16 == 0 then
        for i = 0, 64 do
            local entity = entitylist.get_player_by_index(i)
            if entity then
                entity = entity:player()
                if entity and entity:get_health() > 0 and i ~= lp_index then
                    entity:restore_poseparam()
                end
            end
        end
    end
    local lp = entitylist.get_local_player()
    if not lp then return end
    lp = lp:player()
    local alive = lp:get_health() > 0
    local in_air = lp:in_air()
    local fakeduck = false--fakeduck_bind:on()
    local tickcount = globals.get_tickcount()
    if alive then
        lp:set_poseparam(0, {-180, -179})
    else
        lp:set_poseparam(0, {-180, 180}) end
    ---@diagnostic disable-next-line: undefined-field
    if in_air or ffi.C.GetAsyncKeyState(32) ~= 0 then
        pitch_ticks = -1
    elseif pitch_ticks < 0 and pitch_ticks > -3 then
        pitch_ticks = pitch_ticks - 1
    elseif pitch_ticks <= -3 then
        pitch_ticks = tickcount + TimeToTicks(0.8)
    end
    if tickcount < pitch_ticks and pitch_ticks > 0
    and not in_air and not fakeduck and alive
    and menu.get_bool("pitch 0 on land") then
        lp:set_poseparam(12, {0.999, 1}) else
        lp:set_poseparam(12, {-90, 90}) end
    if in_air and alive then
        lp:set_poseparam(6, {0.9, 1}) else
        lp:set_poseparam(6, {0, 1, 0}) end
end)

client.add_callback("unload", function()
    unloaded = true
    local lp = entitylist.lp()
    if engine.is_connected() or not lp then return end
    lp:restore_poseparam()
end)