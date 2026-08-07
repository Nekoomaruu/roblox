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
        Teleport  = Window:AddTab("Teleport", "map-pin"),
        Player    = Window:AddTab("Player", "user"),
        Visuals   = Window:AddTab("Visuals", "eye"),
        Vehicle   = Window:AddTab("Vehicle", "car"),
        Server    = Window:AddTab("Server", "server"),
        AutoAim   = Window:AddTab("Auto Aim", "crosshair"),
        SelfAlert = Window:AddTab("Self Alert", "shield-alert"),
        Info      = Window:AddTab("Info", "info"),
        Settings  = Window:AddTab("Settings", "settings"),
    }

    return { Window = Window, Tabs = Tabs }
end

return UI
