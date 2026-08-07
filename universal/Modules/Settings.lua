--[[
    Modules/Settings.lua
    Watermark, KeyTab, About, plus ThemeManager & SaveManager (default Obsidian).
    Semua dipanggil via safeMethod supaya versi Obsidian yang beda tidak crash.
]]

local Settings = {}

function Settings.Init(ctx)
    local Library = ctx.Library
    local Tabs = ctx.Tabs
    local safeMethod = ctx.Utils.safeMethod
    local ThemeManager = ctx.ThemeManager
    local SaveManager = ctx.SaveManager

    safeMethod(Library, "SetWatermarkVisibility", true)
    safeMethod(Library, "SetWatermark", "Nekomaru Hub | Teleport Saver")

    Library.KeyTab = Tabs.Settings
    local AboutBox = Tabs.Settings:AddLeftGroupbox("About", "info")
    AboutBox:AddLabel("Teleport Saver by Nekomaru Hub", true)
    AboutBox:AddLabel("Toggle UI: RightShift", true)

    if ThemeManager then
        safeMethod(ThemeManager, "SetLibrary", Library)
        safeMethod(ThemeManager, "SetFolder", "NekomaruHub/TeleportSaver")
        safeMethod(ThemeManager, "ApplyToTab", Tabs.Settings)
    end

    if SaveManager then
        safeMethod(SaveManager, "SetLibrary", Library)
        safeMethod(SaveManager, "IgnoreThemeSettings")
        safeMethod(SaveManager, "SetIgnoreIndexes", {})
        safeMethod(SaveManager, "SetFolder", "NekomaruHub/TeleportSaver")
        safeMethod(SaveManager, "BuildConfigSection", Tabs.Settings)
        safeMethod(SaveManager, "LoadAutoloadConfig")
    end

    return {}
end

return Settings
