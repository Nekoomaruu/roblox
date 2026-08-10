--[[
    NekomaruUI — ThemeManager
    Ganti preset warna UI (accent, background, dll) + simpan pilihan theme.
]]

local function env(n) return rawget(_G, n) or (getfenv and rawget(getfenv(), n)) end
local isfile_f    = env("isfile")
local writefile_f = env("writefile")
local readfile_f  = env("readfile")

local ThemeManager = {}
ThemeManager.Folder = "NekomaruUI/Configs"
ThemeManager.Library = nil

ThemeManager.Themes = {
    ["Nekomaru (Default)"] = {
        Background = Color3.fromRGB(11, 16, 28),
        Sidebar    = Color3.fromRGB(14, 21, 36),
        Topbar     = Color3.fromRGB(16, 24, 40),
        Card       = Color3.fromRGB(19, 28, 46),
        CardHover  = Color3.fromRGB(25, 36, 58),
        Stroke     = Color3.fromRGB(34, 48, 74),
        Accent     = Color3.fromRGB(34, 184, 255),
        Accent2    = Color3.fromRGB(255, 45, 120),
    },
    ["Sakura"] = {
        Background = Color3.fromRGB(24, 12, 20),
        Sidebar    = Color3.fromRGB(31, 16, 26),
        Topbar     = Color3.fromRGB(35, 18, 30),
        Card       = Color3.fromRGB(42, 22, 36),
        CardHover  = Color3.fromRGB(54, 28, 46),
        Stroke     = Color3.fromRGB(74, 38, 62),
        Accent     = Color3.fromRGB(255, 105, 160),
        Accent2    = Color3.fromRGB(255, 190, 120),
    },
    ["Midnight"] = {
        Background = Color3.fromRGB(10, 10, 14),
        Sidebar    = Color3.fromRGB(14, 14, 20),
        Topbar     = Color3.fromRGB(16, 16, 22),
        Card       = Color3.fromRGB(22, 22, 30),
        CardHover  = Color3.fromRGB(30, 30, 40),
        Stroke     = Color3.fromRGB(44, 44, 58),
        Accent     = Color3.fromRGB(140, 120, 255),
        Accent2    = Color3.fromRGB(90, 200, 250),
    },
    ["Emerald"] = {
        Background = Color3.fromRGB(9, 20, 17),
        Sidebar    = Color3.fromRGB(12, 27, 23),
        Topbar     = Color3.fromRGB(14, 31, 26),
        Card       = Color3.fromRGB(18, 40, 34),
        CardHover  = Color3.fromRGB(24, 52, 44),
        Stroke     = Color3.fromRGB(32, 70, 60),
        Accent     = Color3.fromRGB(56, 214, 140),
        Accent2    = Color3.fromRGB(180, 240, 120),
    },
}

function ThemeManager:SetLibrary(lib) self.Library = lib end
function ThemeManager:SetFolder(f) self.Folder = f end

--- Terapkan theme. Elemen yang sudah dibuat akan diwarnai ulang sebisanya;
--- untuk hasil paling rapi, panggil sebelum bikin Window.
function ThemeManager:ApplyTheme(name)
    local theme = self.Themes[name]
    if not theme then return false end
    self.Library:SetTheme(theme)
    self.Current = name

    -- refresh instance yang sudah ada
    for _, w in ipairs(self.Library.Windows) do
        if w.Main then
            w.Main.BackgroundColor3 = theme.Background
            for _, d in ipairs(w.Main:GetDescendants()) do
                if d:IsA("UIStroke") then d.Color = theme.Stroke end
            end
        end
    end
    return true
end

function ThemeManager:SaveDefault(name)
    if writefile_f then pcall(writefile_f, self.Folder .. "/settings/theme.txt", name) end
end

function ThemeManager:LoadDefault()
    local p = self.Folder .. "/settings/theme.txt"
    if isfile_f and isfile_f(p) then
        local n = readfile_f(p)
        if self.Themes[n] then self:ApplyTheme(n) end
    end
end

function ThemeManager:BuildThemeSection(tab)
    local Library = self.Library
    local section = tab:AddSection("Theme")
    local names = {}
    for k in pairs(self.Themes) do table.insert(names, k) end
    table.sort(names)

    local dd = section:AddDropdown("ThemeManager_ThemeList", {
        Text = "UI Theme", Values = names, Default = self.Current or "Nekomaru (Default)",
        Callback = function(v) self:ApplyTheme(v) end,
    })
    section:AddButton({ Text = "Set as Default Theme", Callback = function()
        self:SaveDefault(dd.Value)
        Library:Notify({ Title = "Theme", Content = "Default theme: " .. tostring(dd.Value), Type = "success" })
    end })
    section:AddColorPicker("ThemeAccent", {
        Text = "Custom Accent", Default = Library.Theme.Accent,
        Callback = function(c) Library:SetTheme({ Accent = c }) end,
    })
    return section
end

return ThemeManager
