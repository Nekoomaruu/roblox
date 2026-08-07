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

    S.serverHopFiltered = serverHopFiltered

    return S
end

return Server
