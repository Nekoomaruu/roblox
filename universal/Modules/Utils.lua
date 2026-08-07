--[[
    Modules/Utils.lua
    Helper umum yang dipakai lebih dari satu module.
    Semua helper di sini HARUS bebas efek samping saat require.
]]

local Utils = {}

function Utils.Init(ctx)
    local Library = ctx.Library
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer

    local U = {}

    -- pcall wrapper untuk function biasa
    function U.safeCall(fn, ...)
        if typeof(fn) ~= "function" then return false, "not a function" end
        return pcall(fn, ...)
    end

    -- pcall wrapper untuk method (obj:Method(...)), aman kalau method-nya ga ada
    function U.safeMethod(obj, method, ...)
        if obj and typeof(obj[method]) == "function" then
            return pcall(function(...) return obj[method](obj, ...) end, ...)
        end
        return false, "missing method: " .. tostring(method)
    end

    -- Notifikasi Obsidian. Beberapa versi Obsidian pakai signature berbeda,
    -- jadi coba bentuk table dulu lalu fallback ke (text, time).
    function U.notify(text, dur)
        local message = tostring(text)
        local time = dur or 3
        local ok = false
        if Library and typeof(Library.Notify) == "function" then
            ok = pcall(function()
                Library:Notify({
                    Title = "Teleport Saver",
                    Description = message,
                    Content = message,
                    Time = time,
                })
            end)
            if not ok then
                ok = pcall(function()
                    Library:Notify(message, time)
                end)
            end
        end
        if not ok then
            warn("[Teleport Saver] " .. message)
        end
    end

    function U.getRoot()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        return char:FindFirstChild("HumanoidRootPart")
            or char:WaitForChild("HumanoidRootPart", 5)
    end

    function U.getHumanoid()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- Team check dipakai Aimbot + Hitbox
    function U.isFriendly(plr)
        return LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team
    end

    -- Drawing API tidak ada di semua executor -> selalu boleh return nil
    function U.newDraw(class, props)
        if typeof(Drawing) ~= "table" or typeof(Drawing.new) ~= "function" then
            return nil
        end
        local d = Drawing.new(class)
        for k, v in pairs(props) do d[k] = v end
        return d
    end

    -- Daftar nama player lain di server (sorted)
    function U.otherPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        table.sort(names)
        return names
    end

    return U
end

return Utils
