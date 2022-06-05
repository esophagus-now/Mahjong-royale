require "startup"
ez,whence = require "ezserv"
print("Using ezserv from ", whence)

request_acks = false

s = assert(ez.start_server(80))
s:accept()

function shuffle(seq)
    for i = #seq,1,-1 do
        -- select random element from 1..i inclusive
        -- then swap it with element i
        local r = math.random(i)
        local tmp = seq[r]
        seq[r] = seq[i]
        seq[i] = tmp
    end

    return seq
end

valid_tile = {}
for i = 1,9 do
    valid_tile[i] = tostring(i) .. "m"
    valid_tile[i+10] = tostring(i) .. "p"
    valid_tile[i+20] = tostring(i) .. "s"
    if (i < 8) then
        valid_tile[i+30] = tostring(i) .. "z"
    end
end

function mk_init_wall()
    local ret = {}
    for i = 1,9 do
        for _,suit in ipairs{0,10,20} do
            for j = 1,4 do
                table.insert(ret, suit + i)
            end
        end
        if (i < 8) then
            for j = 1,4 do
                table.insert(ret, 30 + i)
            end
        end
    end

    return shuffle(ret)
end

gamestate_mt = {
    __tostring = function(s)
        local ret = "player1={"
        local delim = ""
        for _,v in ipairs(s.players[1].hand) do
            ret = ret .. delim .. valid_tile[v]
            delim = ","
        end
        return ret .. "}"
    end
}

function new_game_state()
    local ret = {}
    ret.wall = mk_init_wall()
    ret.players = {}
    for i = 1,4 do
        ret.players[i] = {
            hand = {},
            called = {},
            socket = nil -- Just written here to remind me
        }
        for j = 1,13 do
            table.insert(ret.players[i].hand, ret.wall[13*(i-1)+j])
        end
        table.sort(ret.players[i].hand)
    end

    ret.wall_pos = 54
    ret.tiles_left = 136 - 53 - 14
    ret.num_kans = 0
    ret.current_player = 1

    return setmetatable(ret, gamestate_mt)
end

open_games = {}

function player_controller(ws)
    function y_recv()
        print(">PC> Issuing a recv on ", ws)
        ws:recv()
        return coroutine.yield()
    end

    ws:send("/role/Waiting for version code...")
    
    print(">PC> Waiting for version...", ws)
    local version = y_recv()
    print(">PC> Client version " .. tostring(version) .. " connected on", ws)

    ws:send("/role/Enter room code")

    print(">PC> Waiting for room...", ws)
    local room = y_recv()
    

    local game = open_games[room]
    if (game == nil) then
        game = new_game_state()
        open_games[room] = game
    end

    while true do
        local game = new_game_state()
        ws:send("/table/" .. tostring(game) .. "")
        ws:send("/role/Type anything to continue...")
        local data = y_recv()
        if (data == "dc") then break end
    end
end
ws_sessions = {}

filemap = {
    ["/"] = "index.html",
    ["/index.html"] = "index.html",
    ["/index.htm"] = "index.html",
    ["/index"] = "index.html",
    ["/hello.js"] = "hello.js"
}

print("------------BEGIN------------")

if (stop_server == nil) then
    stop_server = false
end

while not stop_server do
    ev,src = assert(s:next_event())
    print("ev.type = ", ev.type)
    status,msg = pcall( function()
        if (ev.type == "connect") then
            print("is upgrade: ", tostring(ev.is_upgrade))
            if (ev.is_upgrade) then
                local cr = coroutine.wrap(player_controller)
                ws_sessions[src] = cr
                cr(src)
            else
                s:accept()
                src:recv()
            end
        elseif (ev.type == "request") then
            print("Request:", ev.method, ev.target)
            print("Request body = [" .. ev.data .. "]")
            print("Is upgrade: ", tostring(ev.is_upgrade));
            if (ev.is_upgrade) then
                print("upgrade requested")
                src:upgrade()
            else
                local filename = filemap[ev.target]
                --print("Using filename", tostring(filename))
                local status,f = pcall(function()
                    local fp = io.open(filename, "rb")
                    return fp:read("*a")
                end)
                if (status == true) then
                    -- A new event on src will only be generated if
                    -- the write fails
                    f = f:gsub("world", "from lua")
                    src:send(f, request_acks)
                else
                    src:send(ez.http.not_found)
                end
                src:recv()
            end
        elseif (ev.type == "data") then
            print("Received websocket data from", tostring(src))
            print("data = [" .. ev.data .. "]")
    
            if (ev.data == "super secret string") then
                --FIXME: need better way to shut down server
                print("Quitting server")
                stop_server = true
            end

            local cr = ws_sessions[src]
            assert(cr, "Received data but websocket not bound to any open player controller")
            local status, msg = pcall(cr,ev.data)
            if (not status) then
                print("Player controller hit an error:")
                print(msg)
                ws_sessions[src] = nil
            end
        elseif (ev.type == "error") then
            print("ezserv reported an error:", ev.message)
            print("The source was:", tostring(src))
            ws_sessions[src] = nil
        end
        print("--------------------------------")
    end)

    if (not status) then
        print("Lua error while handling event:", msg)
        break
    end
end