--[[
    Contoh integrasi NekomaruUI ke Universal Script (Nekomaru Hub).
    Semua UI di sini, logic tinggal dipanggil dari callback.
]]

local BASE = "https://raw.githubusercontent.com/Nekoomaruu/roblox/main/NekomaruUi/"

local function loadRemote(path)
    local url = BASE .. path .. "?v=1.1.0"
    local ok, source = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok then
        error(("[NekomaruUI] Gagal download %s\nURL: %s\nError: %s")
            :format(path, url, tostring(source)), 0)
    end

    local chunk, compileError = loadstring(source)
    if not chunk then
        error(("[NekomaruUI] Gagal compile %s: %s"):format(path, tostring(compileError)), 0)
    end
    return chunk()
end

local Library      = loadRemote("Library.lua")
local SaveManager  = loadRemote("Addons/SaveManager.lua")
local ThemeManager = loadRemote("Addons/ThemeManager.lua")

Library:SetAnimation({ Enabled = true, Fast = 0.12, Normal = 0.20, Slow = 0.28 })

SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:SetFolder("NekomaruHub/Universal")
ThemeManager:SetFolder("NekomaruHub/Universal")
ThemeManager:LoadDefault()

local Window = Library:CreateWindow({
    Title = "Nekomaru Hub",
    SubTitle = "Universal | v1.0.6",
    Icon = "icon",
    Size = UDim2.new(0, 620, 0, 420),
    ToggleKeybind = Enum.KeyCode.RightShift,
})

local Tabs = {
    Teleport  = Window:AddTab("Teleport", "teleport"),
    Player    = Window:AddTab("Player", "Home"),
    Visuals   = Window:AddTab("Visuals", "Open"),
    Vehicle   = Window:AddTab("Vehicle", "Play"),
    Server    = Window:AddTab("Server", "Timer"),
    AutoAim   = Window:AddTab("Auto Aim", "WarningRed"),
    SelfAlert = Window:AddTab("Self Alert", "Warning"),
    Info      = Window:AddTab("Info", "Info"),
    Settings  = Window:AddTab("Settings", "Settings"),
}

-- ============ TELEPORT ============
local tp = Tabs.Teleport:AddSection("Checkpoint")
tp:AddButton({ Text = "Save Checkpoint", Variant = "accent", Callback = function()
    Library:Notify({ Title = "Teleport", Content = "Checkpoint disimpan", Type = "success" })
end })
local cpList = tp:AddDropdown("CheckpointList", { Text = "Checkpoint", Values = { "Cp 1", "Cp 2", "Cp 3" } })
tp:AddButton({ Text = "Teleport ke Checkpoint", Callback = function()
    print("teleport ->", cpList.Value)
end })

local play = Tabs.Teleport:AddSection("Playback")
play:AddSlider("PlayDelay", { Text = "Delay", Min = 0.5, Max = 3, Default = 1, Rounding = 1, Suffix = "s" })
play:AddToggle("PlayLoop", { Text = "Loop", Desc = "Ulang playback dari awal" })
play:AddButton({ Text = "Play", Variant = "accent", Callback = function() end })
play:AddButton({ Text = "Stop", Variant = "danger", Callback = function() end })

-- ============ PLAYER ============
local ply = Tabs.Player:AddSection("Utility Player")
ply:AddToggle("Noclip", { Text = "Noclip", Desc = "Tembus tembok", Callback = function(v) print("noclip", v) end })
ply:AddToggle("InfJump", { Text = "Infinite Jump", Desc = "Lompat tanpa batas" })
ply:AddSlider("WalkSpeed", { Text = "Walk Speed", Min = 16, Max = 200, Default = 16, Callback = function(v)
    local c = game.Players.LocalPlayer.Character
    if c and c:FindFirstChildOfClass("Humanoid") then c.Humanoid.WalkSpeed = v end
end })

-- ============ SETTINGS ============
local s = Tabs.Settings:AddSection("Interface")
s:AddKeybind("ToggleUI", { Text = "Toggle UI", Default = Enum.KeyCode.RightShift })
s:AddToggle("Watermark", { Text = "Watermark", Default = true, Callback = function(v)
    if v then Library:SetWatermark("Nekomaru Hub | Universal") end
    Library:SetWatermarkVisibility(v)
end })
s:AddButton({ Text = "Unload Script", Variant = "danger", Callback = function() Library:Unload() end })

ThemeManager:BuildThemeSection(Tabs.Settings)
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Library:SetWatermark("Nekomaru Hub | Universal v1.0.6")
Library:Notify({ Title = "Nekomaru Hub", Content = "Script berhasil diload!", Type = "success", Icon = "Info" })
