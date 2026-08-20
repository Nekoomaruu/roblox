--[[
    Modules/UI.lua
    Bikin Window + semua Tab. Urutan tab = urutan tampil di UI, jangan diacak.
]]

local UI = {}

function UI.Init(ctx)
    local Library = ctx.Library

    local Window = Library:CreateWindow({
        Title = "Teleport Saver",
        Footer = "By Nekomaru Hub",
        ToggleKeybind = Enum.KeyCode.RightShift,
        Center = true,
        AutoShow = true,
    })

    local Tabs = {
        Main      = Window:AddTab("Main", "map-pin"),
        Player    = Window:AddTab("Player", "user"),
        Visuals   = Window:AddTab("Visuals", "eye"),
        Server    = Window:AddTab("Server", "server"),
        AutoAim   = Window:AddTab("Auto Aim", "crosshair"),
        SelfAlert = Window:AddTab("Self Alert", "shield-alert"),
        Info      = Window:AddTab("Info", "info"),
        Changelog = Window:AddTab("Changelog", "scroll-text"),
        Settings  = Window:AddTab("Settings", "settings"),
    }

    -- alias: module Teleport masih pakai Tabs.Teleport
    Tabs.Teleport = Tabs.Main

    return { Window = Window, Tabs = Tabs }
end

return UI
