--[[
    Modules/Services.lua
    Pusat semua game:GetService(). Module lain TIDAK boleh memanggil
    game:GetService() sendiri, ambil dari ctx.Services.
]]

local Services = {}

function Services.Init()
    local S = {}

    S.Players             = game:GetService("Players")
    S.RunService          = game:GetService("RunService")
    S.TeleportService     = game:GetService("TeleportService")
    S.HttpService         = game:GetService("HttpService")
    S.UserInputService    = game:GetService("UserInputService")
    S.GuiService          = game:GetService("GuiService")
    S.StarterGui          = game:GetService("StarterGui")
    S.ReplicatedStorage   = game:GetService("ReplicatedStorage")
    S.Lighting            = game:GetService("Lighting")
    S.LocalizationService = game:GetService("LocalizationService")

    S.LocalPlayer = S.Players.LocalPlayer

    -- Matiin notifikasi "Gameplay Paused" (biar ga ganggu waktu AFK/tab lain)
    pcall(function()
        S.GuiService:SetGameplayPausedNotificationEnabled(false)
    end)

    return S
end

return Services
