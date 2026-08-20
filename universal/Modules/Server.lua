--[[
    Modules/Server.lua
    Tab Server: Anti AFK, Auto Rejoin, Rejoin Now, Server Hop (normal / low player).
]]

local Server = {}

function Server.Init(ctx)
    local Tabs = ctx.Tabs
    local notify = ctx.Utils.notify
    local LocalPlayer = ctx.Services.LocalPlayer
    local HttpService = ctx.Services.HttpService
    local TeleportService = ctx.Services.TeleportService
    local GuiService = ctx.Services.GuiService

    local S = {}

    local AFKBox = Tabs.Server:AddLeftGroupbox("Anti AFK & Rejoin")
    local HopBox = Tabs.Server:AddRightGroupbox("Server Hop")

    -- ---------- Anti AFK ----------
    local AntiAFKConn
    AFKBox:AddToggle("anti_afk", {
        Text = "Anti AFK",
        Default = false,
        Callback = function(v)
            if v then
                if AntiAFKConn then AntiAFKConn:Disconnect() end
                AntiAFKConn = LocalPlayer.Idled:Connect(function()
                    local vu = game:GetService("VirtualUser")
                    pcall(function()
                        vu:CaptureController()
                        vu:ClickButton2(Vector2.new())
                    end)
                end)
                notify("Anti AFK ON", 2)
            else
                if AntiAFKConn then AntiAFKConn:Disconnect(); AntiAFKConn = nil end
            end
        end,
    })

    -- ---------- Auto Rejoin ----------
    local AutoRejoinEnabled = false
    AFKBox:AddToggle("auto_rejoin", {
        Text = "Auto Rejoin (on disconnect)",
        Default = false,
        Callback = function(v) AutoRejoinEnabled = v end,
    })

    -- ErrorMessageChanged = indikator paling reliable untuk disconnect prompt
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if AutoRejoinEnabled and msg and msg ~= "" then
            task.wait(1)
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end
    end)

    AFKBox:AddButton({
        Text = "Rejoin Now",
        Func = function()
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end,
    })

    -- ---------- Server Hop ----------
    -- lowPlayer = true  -> cari server dengan player paling sedikit (max 10 page)
    -- lowPlayer = false -> hop ke server pertama yang belum full
    local function serverHopFiltered(lowPlayer)
        local cursor = ""
        for _ = 1, 10 do
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
                .. "/servers/Public?sortOrder=Asc&limit=100"
            if cursor ~= "" then url = url .. "&cursor=" .. cursor end
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(url))
            end)
            if not ok or not res or not res.data then break end
            local best
            for _, s in ipairs(res.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    if lowPlayer then
                        if not best or s.playing < best.playing then best = s end
                    else
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        end)
                        return
                    end
                end
            end
            if lowPlayer and best then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
                return
            end
            cursor = res.nextPageCursor or ""
            if cursor == "" then break end
        end
        notify("Gagal cari server", 3)
    end

    HopBox:AddButton({
        Text = "Server Hop",
        Func = function() serverHopFiltered(false) end,
    })
    HopBox:AddButton({
        Text = "Server Hop (Low Player)",
        Func = function() serverHopFiltered(true) end,
    })

    -- ---------- Server Hop tambahan ----------
    HopBox:AddButton({
        Text = "Server Hop (Random)",
        Func = function()
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. game.PlaceId
                    .. "/servers/Public?sortOrder=Desc&limit=100"))
            end)
            if not ok or not res or not res.data or #res.data == 0 then
                notify("Gagal ambil list server", 3); return
            end
            local pool = {}
            for _, sv in ipairs(res.data) do
                if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then pool[#pool + 1] = sv end
            end
            if #pool == 0 then notify("Tidak ada server kosong", 3); return end
            local pick = pool[math.random(1, #pool)]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer)
            end)
        end,
    })

    local AutoHop = false
    local AutoHopDelay = 120
    HopBox:AddToggle("auto_hop", {
        Text = "Auto Server Hop (timer)",
        Default = false,
        Callback = function(v) AutoHop = v end,
    })
    HopBox:AddSlider("auto_hop_delay", {
        Text = "Auto Hop Delay",
        Default = 120, Min = 30, Max = 900, Rounding = 0, Suffix = "s",
        Callback = function(v) AutoHopDelay = v end,
    })
    task.spawn(function()
        local t = 0
        while task.wait(1) do
            if AutoHop then
                t = t + 1
                if t >= AutoHopDelay then
                    t = 0
                    serverHopFiltered(true)
                end
            else
                t = 0
            end
        end
    end)

    -- ---------- Utilities ----------
    local UtilBox = Tabs.Server:AddLeftGroupbox("Server Utilities", "server-cog")

    UtilBox:AddButton({
        Text = "Copy JobId",
        Func = function()
            if setclipboard then setclipboard(tostring(game.JobId)) end
            notify("JobId dicopy", 2)
        end,
    }):AddButton({
        Text = "Copy Join Script",
        Func = function()
            local txt = string.format(
                'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)',
                game.PlaceId, tostring(game.JobId))
            if setclipboard then setclipboard(txt) end
            notify("Join script dicopy", 2)
        end,
    })

    UtilBox:AddButton({
        Text = "Copy PlaceId",
        Func = function()
            if setclipboard then setclipboard(tostring(game.PlaceId)) end
            notify("PlaceId dicopy", 2)
        end,
    }):AddButton({
        Text = "Leave Game",
        Func = function() pcall(function() LocalPlayer:Kick("Left via Nekomaru Hub") end) end,
    })

    -- Join server by JobId (buat balik ke server temen)
    local JobInput = UtilBox:AddInput("join_jobid", {
        Text = "JobId",
        Default = "",
        Placeholder = "paste JobId di sini",
        Numeric = false,
        Finished = false,
    })
    UtilBox:AddButton({
        Text = "Join by JobId",
        Func = function()
            local id = JobInput and JobInput.Value
            if not id or id == "" then notify("JobId kosong", 2); return end
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
            end)
        end,
    })

    -- Rejoin otomatis kalau player count di bawah/di atas batas tertentu
    local AutoLeaveFull = false
    UtilBox:AddToggle("auto_leave_full", {
        Text = "Auto Hop kalau server hampir full",
        Default = false,
        Callback = function(v) AutoLeaveFull = v end,
    })
    task.spawn(function()
        local Players = ctx.Services.Players
        while task.wait(5) do
            if AutoLeaveFull and Players.MaxPlayers > 0 then
                if #Players:GetPlayers() >= (Players.MaxPlayers - 1) then
                    notify("Server hampir full, hop...", 3)
                    serverHopFiltered(true)
                end
            end
        end
    end)

    S.serverHopFiltered = serverHopFiltered

    return S
end

return Server
