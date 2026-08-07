--[[
    Modules/Alert.lua
    Self Alert: kick / server hop otomatis kalau ada player atau admin di server,
    plus bypass username (whitelist) untuk mode anti-player.
]]

local Alert = {}

function Alert.Init(ctx)
    local Tabs = ctx.Tabs
    local Utils = ctx.Utils
    local notify = Utils.notify
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer
    local HttpService = ctx.Services.HttpService
    local TeleportService = ctx.Services.TeleportService

    local A = {}

    local AlertBox = Tabs.SelfAlert:AddLeftGroupbox("Self Alert")

    local AlertPlayer = false
    local AlertAdmin = false
    local AlertMethod = "Server Hop" -- or "Kick"
    local AlertTriggered = false

    -- edit sesuai kebutuhan
    local ADMIN_NAMES = {
        -- ["SomeAdmin"] = true,
    }
    local ADMIN_USERIDS = {
        -- [123456] = true,
    }

    local BypassUsernames = {}  -- [lowercase name] = true

    local function isBypassed(plr)
        return BypassUsernames[string.lower(plr.Name)] == true
    end

    local function isAdmin(plr)
        if ADMIN_NAMES[plr.Name] then return true end
        if ADMIN_USERIDS[plr.UserId] then return true end
        return false
    end

    local function kickSelf()
        LocalPlayer:Kick("[Nekomaru Hub] Self Alert triggered")
    end

    -- Server hop sederhana untuk alert (ambil server pertama yang belum full)
    local function serverHop()
        local ok, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId ..
                "/servers/Public?sortOrder=Asc&limit=100"
            ))
        end)
        if ok and servers and servers.data then
            for _, s in ipairs(servers.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    end)
                    return
                end
            end
        end
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end

    -- AlertTriggered = guard biar tidak dobel eksekusi dalam satu sesi alert
    local function doAlert(reason)
        if AlertTriggered then return end
        AlertTriggered = true
        notify("Self Alert: " .. reason, 3)
        task.wait(0.1)
        if AlertMethod == "Kick" then kickSelf() else serverHop() end
    end

    local function scanPlayers()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if AlertAdmin and isAdmin(p) then
                    doAlert("Admin detected: " .. p.Name); return
                end
                if AlertPlayer and not isBypassed(p) then
                    doAlert("Player detected: " .. p.Name); return
                end
            end
        end
    end

    Players.PlayerAdded:Connect(function(p)
        task.wait(0.2)
        if AlertAdmin and isAdmin(p) then doAlert("Admin joined: " .. p.Name); return end
        if AlertPlayer and not isBypassed(p) then doAlert("Player joined: " .. p.Name) end
    end)

    AlertBox:AddToggle("alert_player", {
        Text = "Alert kalau ada player biasa",
        Default = false,
        Callback = function(v)
            AlertPlayer = v
            AlertTriggered = false
            if v then scanPlayers() end
        end,
    })

    AlertBox:AddToggle("alert_admin", {
        Text = "Alert kalau ada admin",
        Default = false,
        Callback = function(v)
            AlertAdmin = v
            AlertTriggered = false
            if v then scanPlayers() end
        end,
    })

    AlertBox:AddDropdown("alert_method", {
        Values = { "Server Hop", "Kick" },
        Default = 1,
        Multi = false,
        Text = "Alert method",
        Callback = function(v) AlertMethod = v end,
    })

    -- ============================================================
    -- Bypass Usernames (Anti-Player exception)
    -- ============================================================
    local BypassBox = Tabs.SelfAlert:AddRightGroupbox("Bypass Username (Anti-Player)")

    local BypassDropdown  -- forward
    local function refreshBypassDropdown()
        local list = {}
        for name, _ in pairs(BypassUsernames) do table.insert(list, name) end
        table.sort(list)
        if BypassDropdown then
            BypassDropdown:SetValues(list)
            if #list > 0 then BypassDropdown:SetValue(list[1]) else BypassDropdown:SetValue(nil) end
        end
    end

    local BypassInput = BypassBox:AddInput("bypass_name_input", {
        Default = "",
        Placeholder = "Masukkan username",
        Text = "Username",
    })

    BypassBox:AddButton({
        Text = "Add Username",
        Func = function()
            local name = BypassInput.Value
            if not name or name == "" then notify("Isi username dulu", 2); return end
            BypassUsernames[string.lower(name)] = true
            BypassInput:SetValue("")
            refreshBypassDropdown()
            notify("Bypass ditambahkan: " .. name, 2)
        end,
    }):AddButton({
        Text = "Remove Selected",
        Func = function()
            local sel = BypassDropdown and BypassDropdown.Value
            if not sel or sel == "" then notify("Pilih username dulu", 2); return end
            BypassUsernames[sel] = nil
            refreshBypassDropdown()
            notify("Bypass dihapus: " .. sel, 2)
        end,
    })

    BypassDropdown = BypassBox:AddDropdown("bypass_list", {
        Values = {},
        Default = 1,
        Multi = false,
        Text = "Daftar bypass",
    })

    BypassBox:AddButton({
        Text = "Clear All Bypass",
        Func = function()
            BypassUsernames = {}
            refreshBypassDropdown()
            notify("Semua bypass dihapus", 2)
        end,
    })

    -- ============================================================
    -- Server player-list bypass (refreshable dari server)
    -- ============================================================
    local BypassServerDropdown
    local function refreshBypassServerList()
        local names = Utils.otherPlayerNames()
        if BypassServerDropdown then
            BypassServerDropdown:SetValues(names)
            if #names > 0 then BypassServerDropdown:SetValue(names[1]) else BypassServerDropdown:SetValue(nil) end
        end
    end

    BypassServerDropdown = BypassBox:AddDropdown("bypass_server_list", {
        Values = {},
        Default = 1,
        Multi = false,
        Text = "Player di server",
    })

    BypassBox:AddButton({
        Text = "Refresh Server List",
        Func = function() refreshBypassServerList() end,
    }):AddButton({
        Text = "Add From Server",
        Func = function()
            local sel = BypassServerDropdown and BypassServerDropdown.Value
            if not sel or sel == "" then notify("Pilih player dulu", 2); return end
            BypassUsernames[string.lower(sel)] = true
            refreshBypassDropdown()
            notify("Bypass ditambahkan: " .. sel, 2)
        end,
    })

    A.serverHop = serverHop
    A.isAdmin = isAdmin

    return A
end

return Alert
