local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

local function log(level, messagefmt, ...)
    minetest.log(level, ("%s %s"):format(modname, messagefmt:format(...)))
end

local settings = {
    timeout = tonumber(minetest.settings:get(("%s.timeout"):format(modname)) or 30),
}

local current_requests = {}

barter_request = {
    modname = modname,
    modpath = modpath,
    version = 20210815.0,
    log=log,
    settings = settings,
    current_requests = current_requests,
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

local function check_privilege(listname,playername,meta)
        if listname == "pl1" then
                if playername ~= meta:get_string("pl1") then
                        return false
                elseif meta:get_int("pl1step") ~= 1 then
                        return false
                end
        end
        if listname == "pl2" then
                if playername ~= meta:get_string("pl2") then
                        return false
                elseif meta:get_int("pl2step") ~= 1 then
                        return false
                end
        end
        return true
end

local function update_formspec(meta)
    formspec = formspec.main
    local function pl_formspec(n)
        if meta:get_int(n.."step")==0 then
            formspec = formspec .. formspec[n].start
        else
            formspec = formspec .. formspec[n].player(meta:get_string(n))
            if meta:get_int(n.."step") == 1 then
                    formspec = formspec .. formspec[n].accept1
            elseif meta:get_int(n.."step") == 2 then
                    formspec = formspec .. formspec[n].accept2
            end
        end
    end
    pl_formspec("pl1")
    pl_formspec("pl2")
    meta:set_string("formspec",formspec)
end

local function give_inventory(inv,list,playername)
    local player = minetest.get_player_by_name(playername)
    if player then
        for k,v in ipairs(inv:get_list(list)) do
            if player:get_inventory():room_for_item("main",v) then
                player:get_inventory():add_item("main",v)
            else
                minetest.add_item(player:get_pos(),v)
            end
            inv:remove_item(list,v)
        end
    end
end

local function cancel(meta)
    give_inventory(meta:get_inventory(),"pl1",meta:get_string("pl1"))
    give_inventory(meta:get_inventory(),"pl2",meta:get_string("pl2"))
    meta:set_string("pl1","")
    meta:set_string("pl2","")
    meta:set_int("pl1step",0)
    meta:set_int("pl2step",0)
    meta:set_int("clean",1)
    meta:set_int("timer",0)
end


local function timeout_check(requester, requestee, deadline)
    local args = current_requests[requestee] or {}
    local requester2, deadline2 = unpack(args)
    if requester == requester2 and deadline == deadline2 then
        current_requests[requestee] = nil
    end
end

minetest.register_chatcommand("barter", {
    params = "with <playername> | accept | refuse",
    description = "barter with other players",
    func = function(invoker, params)
        local other_name
        _, _, other_name = string.find("with (%w+)")
        if other_name then
            if current_requests[other_name] then
                minetest.chat_send_player(invoker, ("%s is already trading!"):format(other_name))
                return
            end

            local other_player = minetest.get_player_by_name(other_name)
            if other_player then
                local deadline = os.time() + settings.timeout
                current_requests[other_name] = { invoker, deadline }
                minetest.chat_send_player(other_name, (
                    "%s has request to trade with you. " ..
                    "type '/barter accept' to accept, " ..
                    "or '/barter refuse' to refuse."):format(invoker)
                )
                minetest.after(settings.timeout, timeout_check, invoker, other_name, deadline)

            else
                minetest.chat_send_player(invoker, ("%s is not online right now."):format(other_name))
            end

        elseif params == "accept" then
            local requester, _ = unpack(current_requests[invoker])
            error("TODO")

        elseif params == "refuse" then
            if current_requests[invoker] then
                local requester, _ = unpack(current_requests[invoker])
                minetest.chat_send_player(requester, ("%s refuses to trade with you right now"):format(invoker))
                minetest.chat_send_player(invoker, ("refused trade with %s"):format(requester))
            end
            current_requests[invoker] = nil
        end
    end
})
