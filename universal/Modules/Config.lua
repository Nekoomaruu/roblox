--[[
    Modules/Config.lua
    Layer filesystem executor (Delta: writefile/readfile/listfiles/...).
    Format file config = JSON array of {name, x, y, z} — JANGAN diubah,
    config lama user harus tetap kebaca.
]]

local Config = {}

function Config.Init(ctx)
    local HttpService = ctx.Services.HttpService
    local notify = ctx.Utils.notify

    local C = {}

    C.FOLDER = "NekomaruHub/TeleportSaver/Checkpoints"
    C.ROOT_FOLDER = "NekomaruHub/TeleportSaver"

    -- Executor tanpa filesystem tetap boleh jalan, fitur config-nya saja mati
    C.hasFS = (typeof(writefile) == "function")
        and (typeof(readfile) == "function")
        and (typeof(isfile) == "function")
        and (typeof(listfiles) == "function")

    function C.ensureFolder()
        if not C.hasFS then return end
        if typeof(makefolder) == "function" then
            if not (typeof(isfolder) == "function" and isfolder("NekomaruHub")) then
                pcall(makefolder, "NekomaruHub")
            end
            if not (typeof(isfolder) == "function" and isfolder("NekomaruHub/TeleportSaver")) then
                pcall(makefolder, "NekomaruHub/TeleportSaver")
            end
            if not (typeof(isfolder) == "function" and isfolder(C.FOLDER)) then
                pcall(makefolder, C.FOLDER)
            end
        end
    end

    function C.list()
        local out = {}
        if not C.hasFS then return out end
        C.ensureFolder()
        local ok, files = pcall(listfiles, C.FOLDER)
        if not ok or type(files) ~= "table" then return out end
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name then table.insert(out, name) end
        end
        table.sort(out)
        return out
    end

    -- Simpan list checkpoint ke <FOLDER>/<name>.json
    function C.save(name, checkpoints)
        if not C.hasFS then notify("Executor tidak support file", 4); return false end
        if not name or name == "" then notify("Nama config kosong", 3); return false end
        C.ensureFolder()
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(checkpoints)
        end)
        if not ok then notify("Gagal encode JSON", 3); return false end
        local path = C.FOLDER .. "/" .. name .. ".json"
        local ok2, err = pcall(writefile, path, encoded)
        if not ok2 then notify("Gagal save: " .. tostring(err), 4); return false end
        notify("Config '" .. name .. "' disimpan (" .. #checkpoints .. " cp)", 3)
        return true
    end

    function C.load(name)
        if not C.hasFS then return nil end
        local path = C.FOLDER .. "/" .. name .. ".json"
        if not isfile(path) then return nil end
        local ok, data = pcall(readfile, path)
        if not ok then return nil end
        local ok2, decoded = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if not ok2 or type(decoded) ~= "table" then return nil end
        return decoded
    end

    function C.delete(name)
        local path = C.FOLDER .. "/" .. name .. ".json"
        if C.hasFS and isfile(path) and typeof(delfile) == "function" then
            pcall(delfile, path)
            return true
        end
        return false
    end

    C.ensureFolder()

    return C
end

return Config
