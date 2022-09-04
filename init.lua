local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

local S = minetest.get_translator(modname)

local function log(level, messagefmt, ...)
    minetest.log(level, ("%s %s"):format(modname, messagefmt:format(...)))
end

local settings = {
    timeout = tonumber(minetest.settings:get(("%s.timeout"):format(modname)) or 30),
}

local current_requests = {}
local active_trades = {}

barter_request = {
    modname = modname,
    modpath = modpath,
    version = 20210815.0,
    log=log,
    settings = settings,
    current_requests = current_requests,
    active_trades = active_trades,
    S = S,
}

local formspec = {
    main = "size[8,9]"..
            "list[current_name;pl1;0,0;3,4;]"..
            "list[current_name;pl2;5,0;3,4;]"..
            "list[current_player;main;0,5;8,4;]",
    pl1 = {
        start = "button[0,4;3,1;pl1_start;" .. S("Start") .. "]",
        player = function(name) return "label[0,4;"..name.."]" end,
        accept1 = "button[2.9,1;1.2,1;pl1_accept1;" .. S("Confirm") .. "]"..
                "button[2.9,2;1.2,1;pl1_cancel;" .. S("Cancel") .. "]",
        accept2 = "button[2.9,1;1.2,1;pl1_accept2;" .. S("Exchange") .. "]"..
                "button[2.9,2;1.2,1;pl1_cancel;" .. S("Cancel") .. "]",
    },
    pl2 = {
        start = "button[5,4;3,1;pl2_start;" .. S("Start") .. "]",
        player = function(name) return "label[5,4;"..name.."]" end,
        accept1 = "button[3.9,1;1.2,1;pl2_accept1;" .. S("Confirm") .. "]"..
                "button[3.9,2;1.2,1;pl2_cancel;" .. S("Cancel") .. "]",
        accept2 = "button[3.9,1;1.2,1;pl2_accept2;" .. S("Exchange") .. "]"..
                "button[3.9,2;1.2,1;pl2_cancel;" .. S("Cancel") .. "]",
    },
}

local function timeout_check(requester, requestee, deadline)
    local args = current_requests[requestee] or {}
    local requester2, deadline2 = unpack(args)
    if requester == requester2 and deadline == deadline2 then
        current_requests[requestee] = nil
    end
end

local function initiate(requester, requestee)
    if current_requests[requestee] then
        minetest.chat_send_player(requester, S(("%s is already trading!"):format(requestee)))
        return
    end

    local other_player = minetest.get_player_by_name(requestee)
    if other_player then
        local deadline = os.time() + settings.timeout
        current_requests[requestee] = { requester, deadline }
        minetest.chat_send_player(requestee, S((
            "%s has request to trade with you. " ..
            "type '/barter accept' to accept, " ..
            "or '/barter refuse' to refuse."):format(requester))
        )
        minetest.after(settings.timeout, timeout_check, requester, requestee, deadline)

    else
        minetest.chat_send_player(requester, S(("%s is not online right now."):format(requestee)))
    end
end

local function refuse(invoker)
    if current_requests[invoker] then
        local requester, _ = unpack(current_requests[invoker])
        minetest.chat_send_player(requester, S(("%s refuses to trade with you right now"):format(invoker)))
        minetest.chat_send_player(invoker, S(("refused trade with %s"):format(requester)))
    end
    current_requests[invoker] = nil
end

minetest.register_chatcommand("barter", {
    params = "with <playername> | accept | refuse",
    description = S("barter with other players"),
    func = function(invoker, params)
        local other_name
        _, _, other_name = string.find("with (%w+)")
        if other_name then
            initiate(invoker, other_name)

        elseif params == "accept" then
            local requester, _ = unpack(current_requests[invoker])
            error("TODO")

        elseif params == "refuse" then
            refuse(invoker)

        end
    end
})
