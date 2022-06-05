function dtab(t)
        if (type(t) ~= "table") then
                print("Not a table")
                return
        end

        for k,v in pairs(t) do
                print(k,v)
        end
end

function printf(...)
        io.write(string.format(...))
end
ESC = string.char(27)
CSI = ESC .. "["

ex = os.execute

cmd = io.popen("luarocks --tree ./rocks --lua-version 5.4 path --lr-path", "r")
lrpath = cmd:read("*a")
rc,sig,code = cmd:close()

if (rc and code == 0) then
        lrpath = lrpath:sub(1,-2) -- chop off newline
        package.path = lrpath .. ";" .. package.path
end


cmd = io.popen("luarocks --tree ./rocks --lua-version 5.4 path --lr-cpath", "r")
lrcpath = cmd:read("*a")
rc,sig,code = cmd:close()

if (rc and code == 0) then
        lrcpath = lrcpath:sub(1,-2) -- chop off newline
        package.cpath = lrcpath .. ";" .. package.cpath
end

quit = os.exit
