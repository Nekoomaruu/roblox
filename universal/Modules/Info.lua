--[[
    Modules/Info.lua
    Tab Info: player info, server info, community link, plus live updater 1s
    dan FPS counter sendiri (RenderStepped).
]]

local Info = {}

function Info.Init(ctx)
    local Tabs = ctx.Tabs
    local Utils = ctx.Utils
    local notify = Utils.notify
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer
    local RunService = ctx.Services.RunService
    local TeleportService = ctx.Services.TeleportService

    local COMMUNITY_URL = "https://posronda.my.id/discord"

    local PlayerInfoBox = Tabs.Info:AddLeftGroupbox("Player Info", "user")
    local ServerInfoBox = Tabs.Info:AddLeftGroupbox("Server Info", "server")
    local CommunityBox  = Tabs.Info:AddRightGroupbox("Community", "link")

    -- ---------- Player Info ----------
    local lblPName = PlayerInfoBox:AddLabel("Name: -", true)
    local lblPDisp = PlayerInfoBox:AddLabel("Display: -", true)
    local lblPId   = PlayerInfoBox:AddLabel("UserId: -", true)
    local lblPAcc  = PlayerInfoBox:AddLabel("Account Age: -", true)
    local lblPTeam = PlayerInfoBox:AddLabel("Team: -", true)
    local lblPHP   = PlayerInfoBox:AddLabel("Health: -", true)
    local lblPPos  = PlayerInfoBox:AddLabel("Position: -", true)
    local lblPPing = PlayerInfoBox:AddLabel("Ping: -", true)
    local lblPFPS  = PlayerInfoBox:AddLabel("FPS: -", true)

    PlayerInfoBox:AddButton({
        Text = "Copy My Position",
        Func = function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then notify("Character belum ada", 2); return end
            local p = root.Position
            local str = string.format("%.3f, %.3f, %.3f", p.X, p.Y, p.Z)
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, str)
                notify("Position disalin: " .. str, 3)
            else
                notify(str, 4)
            end
        end,
    })

    PlayerInfoBox:AddButton({
        Text = "Copy UserId",
        Func = function()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, tostring(LocalPlayer.UserId))
                notify("UserId disalin", 2)
            else
                notify(tostring(LocalPlayer.UserId), 3)
            end
        end,
    })

    -- ---------- Server Info ----------
    local lblSPlace   = ServerInfoBox:AddLabel("PlaceId: " .. tostring(game.PlaceId), true)
    local lblSJob     = ServerInfoBox:AddLabel("JobId: " .. tostring(game.JobId ~= "" and game.JobId or "-"), true)
    local lblSPlayers = ServerInfoBox:AddLabel("Players: -", true)
    local lblSUptime  = ServerInfoBox:AddLabel("Server Uptime: -", true)
    local lblSRegion  = ServerInfoBox:AddLabel("Region: -", true)

    ServerInfoBox:AddButton({
        Text = "Copy JobId",
        Func = function()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, tostring(game.JobId))
                notify("JobId disalin", 2)
            else
                notify(tostring(game.JobId), 3)
            end
        end,
    }):AddButton({
        Text = "Rejoin Server",
        Func = function()
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end,
    })

    -- ---------- Community ----------
    CommunityBox:AddButton({
        Text = "Join Discord",
        Func = function()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, COMMUNITY_URL)
                notify("Link Discord udah dicopy, tinggal paste di browser!", 4)
            else
                notify(COMMUNITY_URL, 6)
            end
        end,
    })
    CommunityBox:AddLabel("Script: Teleport Saver", true)
    CommunityBox:AddLabel("By: Nekomaru Hub", true)
    CommunityBox:AddLabel("UI: Obsidian Library", true)

    -- ---------- Live updater ----------
    local infoStart = tick()
    local fpsFrames, fpsAcc, fpsCurrent = 0, 0, 0
    RunService.RenderStepped:Connect(function(dt)
        fpsFrames = fpsFrames + 1
        fpsAcc = fpsAcc + dt
        if fpsAcc >= 0.5 then
            fpsCurrent = math.floor(fpsFrames / fpsAcc + 0.5)
            fpsFrames, fpsAcc = 0, 0
        end
    end)

    task.spawn(function()
        while task.wait(1) do
            local ok = pcall(function()
                lblPName:SetText("Name: " .. LocalPlayer.Name)
                lblPDisp:SetText("Display: " .. LocalPlayer.DisplayName)
                lblPId:SetText("UserId: " .. tostring(LocalPlayer.UserId))
                lblPAcc:SetText("Account Age: " .. tostring(LocalPlayer.AccountAge) .. " hari")
                lblPTeam:SetText("Team: " .. (LocalPlayer.Team and LocalPlayer.Team.Name or "-"))

                local char = LocalPlayer.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if hum then
                    lblPHP:SetText(string.format("Health: %d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth)))
                else
                    lblPHP:SetText("Health: -")
                end
                if root then
                    local p = root.Position
                    lblPPos:SetText(string.format("Position: %.1f, %.1f, %.1f", p.X, p.Y, p.Z))
                else
                    lblPPos:SetText("Position: -")
                end

                local ping = "-"
                pcall(function()
                    local stats = game:GetService("Stats")
                    local pingVal = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                    ping = string.format("%d ms", math.floor(pingVal))
                end)
                lblPPing:SetText("Ping: " .. ping)
                lblPFPS:SetText("FPS: " .. tostring(fpsCurrent))

                local list = Players:GetPlayers()
                lblSPlayers:SetText(string.format("Players: %d / %d", #list, Players.MaxPlayers))
                local up = tick() - infoStart
                local h = math.floor(up / 3600)
                local m = math.floor((up % 3600) / 60)
                local s = math.floor(up % 60)
                lblSUptime:SetText(string.format("Server Uptime (session): %02d:%02d:%02d", h, m, s))
                local region = "-"
                pcall(function()
                    region = ctx.Services.LocalizationService.RobloxLocaleId or "-"
                end)
                lblSRegion:SetText("Region: " .. tostring(region))
            end)
            if not ok then end
        end
    end)

    return { CommunityURL = COMMUNITY_URL }
end

return Info
