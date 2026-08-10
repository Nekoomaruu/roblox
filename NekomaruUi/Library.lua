--[[
    NekomaruUI — Roblox Script UI Library
    Version : 1.0.0
    Author  : Nekomaru Hub
    Target  : Delta Executor (juga jalan di Solara / Wave / Xeno / Codex, dsb)

    Pemakaian singkat:
        local Library = loadstring(game:HttpGet("<raw-url>/Library.lua"))()
        local Window  = Library:CreateWindow({ Title = "Nekomaru Hub", SubTitle = "Version 1.0.0" })
        local Tab     = Window:AddTab("Player", "Home")
        local Sec     = Tab:AddSection("Utility Player")
        Sec:AddToggle("Noclip", { Text = "Noclip", Desc = "Tembus tembok", Callback = function(v) end })

    Dokumentasi lengkap: Docs/API.md
]]

--============================================================
-- SERVICES & ENV
--============================================================
local Players           = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local CoreGui            = game:GetService("CoreGui")
local TextService        = game:GetService("TextService")
local HttpService        = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local function env(name)
    local f = rawget(getfenv and getfenv() or _G, name)
    if f == nil then f = rawget(_G, name) end
    return f
end

local gethui_f          = env("gethui")
local getcustomasset_f  = env("getcustomasset") or env("getsynasset") or env("Getcustomasset")
local isfile_f          = env("isfile")
local writefile_f       = env("writefile")
local readfile_f        = env("readfile")
local makefolder_f      = env("makefolder")
local isfolder_f        = env("isfolder")
local delfile_f         = env("delfile")
local listfiles_f       = env("listfiles")
local protectgui        = env("protect_gui") or env("protectgui")

--============================================================
-- LIBRARY ROOT
--============================================================
local Library = {}
Library.__index = Library

Library.Version      = "1.0.0"
Library.Folder       = "NekomaruUI"          -- folder di workspace executor
Library.AssetsFolder = "NekomaruUI/Assets"   -- tempat file .png icon
-- Base URL buat auto-download icon kalau file lokal belum ada.
Library.AssetsBaseURL = "https://raw.githubusercontent.com/Nekoomaruu/NekomaruUI/main/Assets/"

Library.Toggles  = {}   -- [idx] = toggle object   (dipakai SaveManager)
Library.Options  = {}   -- [idx] = element object  (dipakai SaveManager)
Library.Windows  = {}
Library.Unloaded = false
Library.Connections = {}

--============================================================
-- THEME (warna diambil dari referensi: deep navy + cyan + pink)
--============================================================
Library.Theme = {
    Background      = Color3.fromRGB(11, 16, 28),
    Sidebar         = Color3.fromRGB(14, 21, 36),
    Topbar          = Color3.fromRGB(16, 24, 40),
    Card            = Color3.fromRGB(19, 28, 46),
    CardHover       = Color3.fromRGB(25, 36, 58),
    Stroke          = Color3.fromRGB(34, 48, 74),
    Text            = Color3.fromRGB(238, 244, 255),
    SubText         = Color3.fromRGB(139, 156, 182),
    Accent          = Color3.fromRGB(34, 184, 255),   -- cyan
    AccentDark      = Color3.fromRGB(12, 132, 214),
    Accent2         = Color3.fromRGB(255, 45, 120),   -- pink
    Success         = Color3.fromRGB(56, 214, 140),
    Warning         = Color3.fromRGB(255, 186, 66),
    Danger          = Color3.fromRGB(255, 82, 82),
    Off             = Color3.fromRGB(46, 60, 86),
}

--============================================================
-- SMALL HELPERS
--============================================================
local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or Library.Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, all, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft   = UDim.new(0, l or all or 0),
        PaddingRight  = UDim.new(0, r or all or 0),
        PaddingTop    = UDim.new(0, t or all or 0),
        PaddingBottom = UDim.new(0, b or all or 0),
        Parent = parent,
    })
end

local function tween(inst, time, props, style)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Library.Connections, c)
    return c
end

function Library:SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[NekomaruUI] Callback error: " .. tostring(err))
    end
end

--============================================================
-- ICON RESOLVER  (getcustomasset + fallback)
--============================================================
-- Nama icon -> id fallback Roblox (dipakai kalau file .png tidak ada
-- dan tidak bisa didownload).
Library.FallbackIcons = {
    Home        = "rbxassetid://10723407389",
    Info        = "rbxassetid://10723415903",
    Settings    = "rbxassetid://10734950020",
    Close       = "rbxassetid://10747384394",
    Minimize    = "rbxassetid://10734896206",
    Play        = "rbxassetid://10734923549",
    Timer       = "rbxassetid://10734950309",
    Clipboard   = "rbxassetid://10723345540",
    File        = "rbxassetid://10723379338",
    LocalFile   = "rbxassetid://10723379338",
    Open        = "rbxassetid://10723387563",
    Clear       = "rbxassetid://10747384394",
    Arrow       = "rbxassetid://10709790644",
    Discord     = "rbxassetid://10723407389",
    Website     = "rbxassetid://10723345524",
    Error       = "rbxassetid://10723346959",
    Warning     = "rbxassetid://10723346959",
    WarningRed  = "rbxassetid://10723346959",
    teleport    = "rbxassetid://10734884548",
    icon        = "rbxassetid://10723407389",
}

local IconCache = {}

local function ensureFolders()
    if isfolder_f and makefolder_f then
        if not isfolder_f(Library.Folder) then pcall(makefolder_f, Library.Folder) end
        if not isfolder_f(Library.AssetsFolder) then pcall(makefolder_f, Library.AssetsFolder) end
    end
end

--- Resolve nama icon jadi Content URL yang bisa dipakai property Image.
--- Urutan: cache -> rbxassetid mentah -> file lokal via getcustomasset
---         -> download ke Assets lalu getcustomasset -> fallback rbxassetid.
function Library:GetIcon(name)
    if not name or name == "" then return "" end
    if typeof(name) == "number" then return "rbxassetid://" .. name end
    if name:match("^rbxassetid://") or name:match("^rbxthumb") or name:match("^http") then return name end
    if IconCache[name] then return IconCache[name] end

    local file = name
    if not file:match("%.png$") and not file:match("%.jpg$") then file = file .. ".png" end
    local path = self.AssetsFolder .. "/" .. file

    if getcustomasset_f and isfile_f then
        -- 1) file sudah ada di workspace executor
        if isfile_f(path) then
            local ok, url = pcall(getcustomasset_f, path)
            if ok and type(url) == "string" then
                IconCache[name] = url
                return url
            end
        end
        -- 2) belum ada -> coba download dari repo
        if writefile_f and self.AssetsBaseURL and self.AssetsBaseURL ~= "" then
            ensureFolders()
            local ok, data = pcall(function()
                return game:HttpGet(self.AssetsBaseURL .. file, true)
            end)
            if ok and type(data) == "string" and #data > 100 then
                local okw = pcall(writefile_f, path, data)
                if okw then
                    local ok2, url = pcall(getcustomasset_f, path)
                    if ok2 and type(url) == "string" then
                        IconCache[name] = url
                        return url
                    end
                end
            end
        end
    end

    -- 3) fallback
    local key = name:gsub("%.png$", ""):gsub("%.jpg$", "")
    local fb = self.FallbackIcons[key] or self.FallbackIcons[key:lower()] or ""
    IconCache[name] = fb
    return fb
end

--- Daftarkan/override fallback icon: Library:SetIcon("fish", "rbxassetid://123")
function Library:SetIcon(name, assetId)
    self.FallbackIcons[name] = assetId
    IconCache[name] = nil
end

--- Pre-download semua icon (opsional, biar smooth waktu buka UI).
function Library:PreloadIcons(list)
    for _, n in ipairs(list or {}) do self:GetIcon(n) end
end

--============================================================
-- SCREENGUI ROOT
--============================================================
local function makeScreenGui()
    local gui = new("ScreenGui", {
        Name = "NekomaruUI_" .. tostring(math.random(1e5, 1e6)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 9999,
    })
    local parented = false
    if gethui_f then
        local ok = pcall(function() gui.Parent = gethui_f() end)
        parented = ok
    end
    if not parented then
        local ok = pcall(function()
            if protectgui then pcall(protectgui, gui) end
            gui.Parent = CoreGui
        end)
        if not ok then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
    return gui
end

--============================================================
-- DRAGGING (mouse + touch)
--============================================================
local function makeDraggable(frame, handle, onEnd)
    handle = handle or frame
    local dragging, dragStart, startPos, inputObj
    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            inputObj = input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onEnd then onEnd(frame.Position) end
                end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input == inputObj or input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--============================================================
-- NOTIFICATIONS
--============================================================
local NotifyHolder

local function ensureNotifyHolder()
    if NotifyHolder and NotifyHolder.Parent then return NotifyHolder end
    local gui = makeScreenGui()
    NotifyHolder = new("Frame", {
        Name = "Notifications",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 300, 1, -32),
        Parent = gui,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = NotifyHolder,
    })
    return NotifyHolder
end

--- Library:Notify("pesan", 3)
--- Library:Notify({ Title = "Judul", Content = "isi", Duration = 4, Icon = "Info", Type = "success" })
function Library:Notify(a, b)
    local opt = {}
    if type(a) == "table" then opt = a else opt = { Content = tostring(a), Duration = b } end
    local title    = opt.Title or "Nekomaru Hub"
    local content  = opt.Content or opt.Text or ""
    local duration = opt.Duration or 3
    local kind     = (opt.Type or "info"):lower()
    local color    = ({
        info = self.Theme.Accent, success = self.Theme.Success,
        warning = self.Theme.Warning, error = self.Theme.Danger,
    })[kind] or self.Theme.Accent

    local holder = ensureNotifyHolder()

    local card = new("Frame", {
        BackgroundColor3 = self.Theme.Card,
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(1, 20, 0, 0),
        BackgroundTransparency = 0,
        ClipsDescendants = true,
        Parent = holder,
    })
    corner(card, 10)
    stroke(card, self.Theme.Stroke)

    new("Frame", {
        BackgroundColor3 = color, BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -16), Position = UDim2.new(0, 6, 0, 8),
        Parent = card,
    }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    local iconId = opt.Icon and self:GetIcon(opt.Icon) or nil
    local left = iconId and 44 or 20
    if iconId and iconId ~= "" then
        new("ImageLabel", {
            BackgroundTransparency = 1, Image = iconId,
            Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 18, 0, 12),
            ImageColor3 = color, Parent = card,
        })
    end

    new("TextLabel", {
        BackgroundTransparency = 1, Text = title,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = self.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, left, 0, 10), Size = UDim2.new(1, -left - 12, 0, 16),
        Parent = card,
    })
    local body = new("TextLabel", {
        BackgroundTransparency = 1, Text = content,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self.Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.new(0, left, 0, 28), Size = UDim2.new(1, -left - 12, 0, 26),
        Parent = card,
    })
    local bounds = TextService:GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(280 - left, 1e4))
    card.Size = UDim2.new(1, 0, 0, math.clamp(34 + bounds.Y, 54, 160))
    body.Size = UDim2.new(1, -left - 12, 0, bounds.Y + 4)

    tween(card, 0.22, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)

    task.delay(duration, function()
        if card and card.Parent then
            tween(card, 0.2, { Position = UDim2.new(1, 20, 0, 0), BackgroundTransparency = 1 })
            task.delay(0.25, function() if card then card:Destroy() end end)
        end
    end)
    return card
end

--============================================================
-- WATERMARK
--============================================================
function Library:SetWatermark(text)
    if not self._watermark then
        local gui = makeScreenGui()
        local f = new("Frame", {
            BackgroundColor3 = self.Theme.Card,
            Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 200, 0, 26),
            Parent = gui,
        })
        corner(f, 8); stroke(f, self.Theme.Stroke)
        local lbl = new("TextLabel", {
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = self.Theme.Text, Size = UDim2.new(1, -16, 1, 0),
            Position = UDim2.new(0, 8, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
            Parent = f,
        })
        self._watermark = { Frame = f, Label = lbl, Gui = gui }
        makeDraggable(f)
    end
    self._watermark.Label.Text = text or ""
    local b = TextService:GetTextSize(text or "", 12, Enum.Font.GothamMedium, Vector2.new(1e4, 20))
    self._watermark.Frame.Size = UDim2.new(0, b.X + 24, 0, 26)
    return self._watermark
end

function Library:SetWatermarkVisibility(v)
    if self._watermark then self._watermark.Frame.Visible = v and true or false end
end

--============================================================
-- ELEMENT FACTORY (dipakai Section)
--============================================================
local Elements = {}

local function register(idx, obj)
    if idx and idx ~= "" then Library.Options[idx] = obj end
end

-- ---------- Label ----------
function Elements.Label(section, text, opt)
    opt = opt or {}
    local lbl = new("TextLabel", {
        BackgroundTransparency = 1, Text = text or "",
        Font = Enum.Font.Gotham, TextSize = 12.5,
        TextColor3 = opt.Color or Library.Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 18),
        Parent = section.Container,
    })
    local function resize()
        local b = TextService:GetTextSize(lbl.Text, 12.5, Enum.Font.Gotham, Vector2.new(section.Container.AbsoluteSize.X - 4, 1e4))
        lbl.Size = UDim2.new(1, 0, 0, math.max(18, b.Y + 2))
    end
    task.defer(resize)
    local api = {}
    function api:SetText(t) lbl.Text = t; resize() end
    api.Instance = lbl
    return api
end

-- ---------- Divider ----------
function Elements.Divider(section)
    local f = new("Frame", {
        BackgroundColor3 = Library.Theme.Stroke, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1), Parent = section.Container,
    })
    return { Instance = f }
end

-- ---------- Base row (card) ----------
local function baseRow(section, height)
    local row = new("Frame", {
        BackgroundColor3 = Library.Theme.Card,
        Size = UDim2.new(1, 0, 0, height or 46),
        Parent = section.Container,
    })
    corner(row, 10)
    stroke(row, Library.Theme.Stroke)
    connect(row.MouseEnter, function() tween(row, 0.12, { BackgroundColor3 = Library.Theme.CardHover }) end)
    connect(row.MouseLeave, function() tween(row, 0.12, { BackgroundColor3 = Library.Theme.Card }) end)
    return row
end

local function rowTexts(row, text, desc, rightPad)
    local hasDesc = desc and desc ~= ""
    local title = new("TextLabel", {
        BackgroundTransparency = 1, Text = text or "",
        Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, hasDesc and 7 or 0),
        Size = UDim2.new(1, -(rightPad or 70), hasDesc and 0 or 1, hasDesc and 18 or 0),
        Parent = row,
    })
    local sub
    if hasDesc then
        sub = new("TextLabel", {
            BackgroundTransparency = 1, Text = desc,
            Font = Enum.Font.Gotham, TextSize = 11.5, TextColor3 = Library.Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.new(0, 14, 0, 25), Size = UDim2.new(1, -(rightPad or 70), 0, 15),
            Parent = row,
        })
    end
    return title, sub
end

-- ---------- Toggle ----------
function Elements.Toggle(section, idx, opt)
    opt = opt or {}
    local value = opt.Default == true
    local row = baseRow(section, (opt.Desc and opt.Desc ~= "") and 52 or 42)
    local title, sub = rowTexts(row, opt.Text or idx, opt.Desc, 70)

    local track = new("Frame", {
        BackgroundColor3 = Library.Theme.Off,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 42, 0, 22),
        Parent = row,
    })
    corner(track, 11)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Position = UDim2.new(0, 3, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 16, 0, 16), Parent = track,
    })
    corner(knob, 8)

    local api = { Type = "Toggle", Value = value, Callback = opt.Callback }

    local function render(fire)
        tween(track, 0.16, { BackgroundColor3 = api.Value and Library.Theme.Accent or Library.Theme.Off })
        tween(knob, 0.16, { Position = api.Value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
        tween(title, 0.16, { TextColor3 = api.Value and Library.Theme.Accent or Library.Theme.Text })
        if fire then Library:SafeCall(api.Callback, api.Value) end
    end

    function api:SetValue(v, silent)
        self.Value = v and true or false
        render(not silent)
    end
    api.Set = api.SetValue
    function api:GetValue() return self.Value end
    function api:OnChanged(fn) self.Callback = fn end

    local btn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), Parent = row })
    connect(btn.MouseButton1Click, function() api:SetValue(not api.Value) end)

    render(false)
    if opt.Default ~= nil and opt.FireOnInit ~= false and value then
        task.defer(function() Library:SafeCall(api.Callback, api.Value) end)
    end

    api.Instance = row
    register(idx, api)
    if idx and idx ~= "" then Library.Toggles[idx] = api end
    return api
end

-- ---------- Button ----------
function Elements.Button(section, opt)
    opt = opt or {}
    local row = new("TextButton", {
        BackgroundColor3 = opt.Variant == "accent" and Library.Theme.Accent
                        or opt.Variant == "danger" and Library.Theme.Danger
                        or Library.Theme.Card,
        AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, 38), Parent = section.Container,
    })
    corner(row, 10)
    if not opt.Variant then stroke(row, Library.Theme.Stroke) end

    new("TextLabel", {
        BackgroundTransparency = 1, Text = opt.Text or "Button",
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = opt.Variant and Color3.fromRGB(255, 255, 255) or Library.Theme.Text,
        Size = UDim2.new(1, 0, 1, 0), Parent = row,
    })

    connect(row.MouseButton1Click, function()
        tween(row, 0.08, { Size = UDim2.new(1, -6, 0, 36) })
        task.delay(0.08, function() tween(row, 0.1, { Size = UDim2.new(1, 0, 0, 38) }) end)
        Library:SafeCall(opt.Callback or opt.Func)
    end)

    local api = { Type = "Button", Instance = row }
    function api:SetText(t) row:FindFirstChildOfClass("TextLabel").Text = t end
    return api
end

-- ---------- Slider ----------
function Elements.Slider(section, idx, opt)
    opt = opt or {}
    local min, max = opt.Min or 0, opt.Max or 100
    local rounding = opt.Rounding or 0
    local value = math.clamp(opt.Default or min, min, max)

    local row = baseRow(section, 52)
    local title = new("TextLabel", {
        BackgroundTransparency = 1, Text = opt.Text or idx,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -100, 0, 16), Parent = row,
    })
    local valLbl = new("TextLabel", {
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Library.Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -74, 0, 6), Size = UDim2.new(0, 60, 0, 16), Parent = row,
    })

    local bar = new("Frame", {
        BackgroundColor3 = Library.Theme.Off, BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 34), Size = UDim2.new(1, -28, 0, 6), Parent = row,
    })
    corner(bar, 3)
    local fill = new("Frame", {
        BackgroundColor3 = Library.Theme.Accent, BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0), Parent = bar,
    })
    corner(fill, 3)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 14, 0, 14), Parent = bar,
    })
    corner(knob, 7)

    local api = { Type = "Slider", Value = value, Min = min, Max = max, Callback = opt.Callback }

    local function round(v)
        local m = 10 ^ rounding
        return math.floor(v * m + 0.5) / m
    end

    local function render(fire)
        local a = (api.Value - min) / math.max(max - min, 1e-6)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        valLbl.Text = tostring(api.Value) .. (opt.Suffix or "")
        if fire then Library:SafeCall(api.Callback, api.Value) end
    end

    function api:SetValue(v, silent)
        self.Value = math.clamp(round(tonumber(v) or min), min, max)
        render(not silent)
    end
    api.Set = api.SetValue
    function api:GetValue() return self.Value end
    function api:OnChanged(fn) self.Callback = fn end

    local dragging = false
    local function fromInput(pos)
        local a = math.clamp((pos.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        api:SetValue(min + a * (max - min))
    end
    connect(bar.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; fromInput(i.Position)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromInput(i.Position)
        end
    end)

    api:SetValue(value, true)
    api.Instance = row
    register(idx, api)
    return api
end

-- ---------- Input ----------
function Elements.Input(section, idx, opt)
    opt = opt or {}
    local row = baseRow(section, 52)
    new("TextLabel", {
        BackgroundTransparency = 1, Text = opt.Text or idx,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -28, 0, 16), Parent = row,
    })
    local box = new("TextBox", {
        BackgroundColor3 = Library.Theme.Background, ClearTextOnFocus = false,
        Text = opt.Default or "", PlaceholderText = opt.Placeholder or "...",
        PlaceholderColor3 = Library.Theme.SubText,
        Font = Enum.Font.Gotham, TextSize = 12.5, TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -28, 0, 20),
        Parent = row,
    })
    padding(box, nil, 8, 8)
    corner(box, 6)

    local api = { Type = "Input", Value = box.Text, Callback = opt.Callback }
    function api:SetValue(v, silent)
        self.Value = tostring(v or "")
        box.Text = self.Value
        if not silent then Library:SafeCall(self.Callback, self.Value) end
    end
    api.Set = api.SetValue
    function api:GetValue() return self.Value end
    function api:OnChanged(fn) self.Callback = fn end

    connect(box.FocusLost, function(enter)
        api.Value = box.Text
        if opt.Numeric then
            local n = tonumber(box.Text)
            if not n then box.Text = tostring(api.Value or "") end
        end
        if (not opt.OnEnter) or enter then Library:SafeCall(api.Callback, api.Value) end
    end)

    api.Instance = row
    register(idx, api)
    return api
end

-- ---------- Dropdown ----------
function Elements.Dropdown(section, idx, opt)
    opt = opt or {}
    local values = opt.Values or opt.Options or {}
    local multi  = opt.Multi == true
    local value  = opt.Default or (multi and {} or values[1])

    local row = baseRow(section, 52)
    new("TextLabel", {
        BackgroundTransparency = 1, Text = opt.Text or idx,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -28, 0, 16), Parent = row,
    })
    local display = new("TextButton", {
        BackgroundColor3 = Library.Theme.Background, AutoButtonColor = false,
        Font = Enum.Font.Gotham, TextSize = 12.5, TextColor3 = Library.Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "",
        Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -28, 0, 20), Parent = row,
    })
    padding(display, nil, 8, 24)
    corner(display, 6)
    new("ImageLabel", {
        BackgroundTransparency = 1, Image = Library:GetIcon("Arrow"),
        ImageColor3 = Library.Theme.SubText, Rotation = 90,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12), Parent = display,
    })

    -- list popup (di dalam row, expand ke bawah)
    local list = new("Frame", {
        BackgroundColor3 = Library.Theme.Background, Visible = false, ClipsDescendants = true,
        Position = UDim2.new(0, 14, 0, 50), Size = UDim2.new(1, -28, 0, 0),
        ZIndex = 5, Parent = row,
    })
    corner(list, 6); stroke(list, Library.Theme.Stroke)
    local scroll = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Library.Theme.Accent,
        Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 6, Parent = list,
    })
    local layout = new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
    padding(scroll, 4)

    local api = { Type = "Dropdown", Value = value, Values = values, Multi = multi, Callback = opt.Callback, Open = false }

    local function textOf()
        if multi then
            local t = {}
            for k, v in pairs(api.Value or {}) do if v then table.insert(t, k) end end
            table.sort(t)
            return #t > 0 and table.concat(t, ", ") or (opt.Placeholder or "None")
        end
        return (api.Value ~= nil and tostring(api.Value)) or (opt.Placeholder or "None")
    end

    local function rebuild()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, v in ipairs(api.Values) do
            local selected = multi and (api.Value and api.Value[v]) or (api.Value == v)
            local item = new("TextButton", {
                BackgroundColor3 = selected and Library.Theme.Accent or Library.Theme.Card,
                BackgroundTransparency = selected and 0 or 0.35,
                AutoButtonColor = false, Text = tostring(v),
                Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Library.Theme.Text,
                Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, ZIndex = 7, Parent = scroll,
            })
            corner(item, 5)
            connect(item.MouseButton1Click, function()
                if multi then
                    api.Value = api.Value or {}
                    api.Value[v] = not api.Value[v] or nil
                else
                    api.Value = v
                    api:Close()
                end
                display.Text = textOf()
                rebuild()
                Library:SafeCall(api.Callback, api.Value)
            end)
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end

    function api:Open_()
        self.Open = true
        local h = math.clamp(#self.Values * 26 + 8, 26, 132)
        list.Visible = true
        tween(list, 0.16, { Size = UDim2.new(1, -28, 0, h) })
        tween(row, 0.16, { Size = UDim2.new(1, 0, 0, 52 + h + 8) })
    end
    function api:Close()
        self.Open = false
        tween(list, 0.14, { Size = UDim2.new(1, -28, 0, 0) })
        tween(row, 0.14, { Size = UDim2.new(1, 0, 0, 52) })
        task.delay(0.15, function() if not api.Open then list.Visible = false end end)
    end
    function api:SetValues(v)
        self.Values = v or {}
        display.Text = textOf()
        rebuild()
        if self.Open then self:Open_() end
    end
    api.Refresh = api.SetValues
    function api:SetValue(v, silent)
        self.Value = v
        display.Text = textOf()
        rebuild()
        if not silent then Library:SafeCall(self.Callback, self.Value) end
    end
    api.Set = api.SetValue
    function api:GetValue() return self.Value end
    function api:OnChanged(fn) self.Callback = fn end

    connect(display.MouseButton1Click, function()
        if api.Open then api:Close() else api:Open_() end
    end)

    display.Text = textOf()
    rebuild()
    api.Instance = row
    register(idx, api)
    return api
end

-- ---------- Keybind ----------
function Elements.Keybind(section, idx, opt)
    opt = opt or {}
    local row = baseRow(section, 42)
    rowTexts(row, opt.Text or idx, opt.Desc, 100)
    local btn = new("TextButton", {
        BackgroundColor3 = Library.Theme.Background, AutoButtonColor = false,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Library.Theme.Accent,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 80, 0, 24), Text = "...", Parent = row,
    })
    corner(btn, 6); stroke(btn, Library.Theme.Stroke)

    local api = { Type = "Keybind", Value = opt.Default, Callback = opt.Callback, Listening = false }

    local function keyName(k)
        if typeof(k) == "EnumItem" then return k.Name end
        return tostring(k or "None")
    end

    function api:SetValue(v, silent)
        if type(v) == "string" and Enum.KeyCode[v] then v = Enum.KeyCode[v] end
        self.Value = v
        btn.Text = keyName(v)
        if not silent then Library:SafeCall(self.Callback, self.Value) end
    end
    api.Set = api.SetValue
    function api:GetValue() return self.Value end
    function api:OnClick(fn) self.Pressed = fn end
    function api:OnChanged(fn) self.Callback = fn end

    connect(btn.MouseButton1Click, function()
        api.Listening = true
        btn.Text = "..."
    end)
    connect(UserInputService.InputBegan, function(input, gpe)
        if api.Listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                api.Listening = false
                api:SetValue(input.KeyCode)
            end
            return
        end
        if gpe then return end
        if api.Value and input.KeyCode == api.Value then
            Library:SafeCall(api.Pressed or opt.Pressed)
        end
    end)

    api:SetValue(opt.Default, true)
    api.Instance = row
    register(idx, api)
    return api
end

-- ---------- ColorPicker (RGB sliders sederhana) ----------
function Elements.ColorPicker(section, idx, opt)
    opt = opt or {}
    local col = opt.Default or Color3.fromRGB(255, 255, 255)
    local row = baseRow(section, 42)
    rowTexts(row, opt.Text or idx, opt.Desc, 70)

    local preview = new("TextButton", {
        BackgroundColor3 = col, AutoButtonColor = false, Text = "",
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 40, 0, 22), Parent = row,
    })
    corner(preview, 6); stroke(preview, Library.Theme.Stroke)

    local panel = new("Frame", {
        BackgroundColor3 = Library.Theme.Background, Visible = false,
        Position = UDim2.new(0, 14, 0, 44), Size = UDim2.new(1, -28, 0, 76), Parent = row,
    })
    corner(panel, 6); stroke(panel, Library.Theme.Stroke)

    local api = { Type = "ColorPicker", Value = col, Callback = opt.Callback, Open = false }

    local channels = { { "R", Color3.fromRGB(255, 80, 80) }, { "G", Color3.fromRGB(80, 220, 120) }, { "B", Color3.fromRGB(80, 160, 255) } }
    local bars = {}
    for i, ch in ipairs(channels) do
        local y = 10 + (i - 1) * 22
        new("TextLabel", {
            BackgroundTransparency = 1, Text = ch[1], Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = ch[2], Position = UDim2.new(0, 8, 0, y), Size = UDim2.new(0, 14, 0, 14), Parent = panel,
        })
        local bar = new("Frame", {
            BackgroundColor3 = Library.Theme.Off, BorderSizePixel = 0,
            Position = UDim2.new(0, 28, 0, y + 5), Size = UDim2.new(1, -44, 0, 5), Parent = panel,
        })
        corner(bar, 3)
        local fill = new("Frame", { BackgroundColor3 = ch[2], BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = bar })
        corner(fill, 3)
        bars[i] = { bar = bar, fill = fill }
    end

    local function render(fire)
        preview.BackgroundColor3 = api.Value
        local comp = { api.Value.R, api.Value.G, api.Value.B }
        for i, b in ipairs(bars) do b.fill.Size = UDim2.new(comp[i], 0, 1, 0) end
        if fire then Library:SafeCall(api.Callback, api.Value) end
    end

    for i, b in ipairs(bars) do
        local dragging = false
        local function set(pos)
            local a = math.clamp((pos.X - b.bar.AbsolutePosition.X) / math.max(b.bar.AbsoluteSize.X, 1), 0, 1)
            local c = { api.Value.R, api.Value.G, api.Value.B }
            c[i] = a
            api.Value = Color3.new(c[1], c[2], c[3])
            render(true)
        end
        connect(b.bar.InputBegan, function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true; set(inp.Position)
            end
        end)
        connect(UserInputService.InputEnded, function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        connect(UserInputService.InputChanged, function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then set(inp.Position) end
        end)
    end

    connect(preview.MouseButton1Click, function()
        api.Open = not api.Open
        panel.Visible = api.Open
        tween(row, 0.16, { Size = UDim2.new(1, 0, 0, api.Open and 130 or 42) })
    end)

    function api:SetValue(v, silent)
        self.Value = v
        render(not silent)
    end
    api.Set = api.SetValue
    function api:GetValue() return self.Value end
    function api:OnChanged(fn) self.Callback = fn end

    render(false)
    api.Instance = row
    register(idx, api)
    return api
end

-- ---------- Paragraph ----------
function Elements.Paragraph(section, opt)
    opt = opt or {}
    local row = baseRow(section, 60)
    local title = new("TextLabel", {
        BackgroundTransparency = 1, Text = opt.Title or "",
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 16), Parent = row,
    })
    local body = new("TextLabel", {
        BackgroundTransparency = 1, Text = opt.Content or opt.Text or "",
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Library.Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.new(0, 14, 0, 27), Size = UDim2.new(1, -28, 0, 20), Parent = row,
    })
    local function resize()
        local w = math.max(row.AbsoluteSize.X - 28, 60)
        local b = TextService:GetTextSize(body.Text, 12, Enum.Font.Gotham, Vector2.new(w, 1e4))
        body.Size = UDim2.new(1, -28, 0, b.Y + 2)
        row.Size = UDim2.new(1, 0, 0, 36 + b.Y)
    end
    task.defer(resize)
    local api = { Type = "Paragraph", Instance = row }
    function api:SetTitle(t) title.Text = t end
    function api:SetContent(t) body.Text = t; resize() end
    return api
end

--============================================================
-- SECTION
--============================================================
local Section = {}
Section.__index = Section

local function createSection(tab, name, opt)
    opt = opt or {}
    local self = setmetatable({}, Section)
    self.Window = tab.Window
    self.Tab = tab

    local holder = new("Frame", {
        BackgroundColor3 = Library.Theme.Sidebar,
        BackgroundTransparency = opt.Transparent and 1 or 0.35,
        Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.Y,
        Parent = tab.Page,
    })
    corner(holder, 12)
    if not opt.Transparent then stroke(holder, Library.Theme.Stroke, 1, 0.4) end
    padding(holder, 12)

    if name and name ~= "" then
        new("TextLabel", {
            BackgroundTransparency = 1, Text = "[ " .. name .. " ]",
            Font = Enum.Font.GothamBold, TextSize = 12.5, TextColor3 = Library.Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18), LayoutOrder = -1, Parent = holder,
        })
    end

    new("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder,
    })

    self.Instance  = holder
    self.Container = holder
    return self
end

function Section:AddToggle(idx, opt)      return Elements.Toggle(self, idx, opt) end
function Section:AddButton(opt)           return Elements.Button(self, opt) end
function Section:AddSlider(idx, opt)      return Elements.Slider(self, idx, opt) end
function Section:AddInput(idx, opt)       return Elements.Input(self, idx, opt) end
function Section:AddDropdown(idx, opt)    return Elements.Dropdown(self, idx, opt) end
function Section:AddKeybind(idx, opt)     return Elements.Keybind(self, idx, opt) end
function Section:AddColorPicker(idx, opt) return Elements.ColorPicker(self, idx, opt) end
function Section:AddLabel(text, opt)      return Elements.Label(self, text, opt) end
function Section:AddParagraph(opt)        return Elements.Paragraph(self, opt) end
function Section:AddDivider()             return Elements.Divider(self) end
-- alias gaya Obsidian
Section.AddCheckbox = Section.AddToggle

--============================================================
-- TAB
--============================================================
local Tab = {}
Tab.__index = Tab

function Tab:AddSection(name, opt) return createSection(self, name, opt) end
Tab.AddGroupbox = Tab.AddSection

function Tab:Select() self.Window:SelectTab(self.Name) end

--============================================================
-- WINDOW
--============================================================
local Window = {}
Window.__index = Window

function Library:CreateWindow(opt)
    opt = opt or {}
    ensureFolders()

    local self = setmetatable({}, Window)
    self.Library    = Library
    self.Title      = opt.Title or "Nekomaru Hub"
    self.SubTitle   = opt.SubTitle or opt.Footer or ("Version " .. Library.Version)
    self.Tabs       = {}
    self.TabOrder   = {}
    self.Minimized  = false
    self.Visible    = true
    self.ToggleKey  = opt.ToggleKeybind or Enum.KeyCode.RightShift

    local size = opt.Size or UDim2.new(0, 600, 0, 400)
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled and not opt.Size then
        size = UDim2.new(0, 520, 0, 330)
    end

    local gui = makeScreenGui()
    self.Gui = gui

    -- ---- Main frame ----
    local main = new("Frame", {
        BackgroundColor3 = Library.Theme.Background,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = opt.Position or UDim2.new(0.5, 0, 0.5, 0),
        Size = size, ClipsDescendants = true, Parent = gui,
    })
    corner(main, 14)
    stroke(main, Library.Theme.Stroke, 1.5)
    self.Main = main

    -- ---- Topbar ----
    local top = new("Frame", {
        BackgroundColor3 = Library.Theme.Topbar, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40), Parent = main,
    })
    corner(top, 14)
    new("Frame", {  -- nutup rounding bawah topbar
        BackgroundColor3 = Library.Theme.Topbar, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10), Parent = top,
    })

    local titleX = 14
    if opt.Icon then
        new("ImageLabel", {
            BackgroundTransparency = 1, Image = Library:GetIcon(opt.Icon),
            Position = UDim2.new(0, 12, 0.5, -10), Size = UDim2.new(0, 20, 0, 20), Parent = top,
        })
        titleX = 40
    end

    local titleLbl = new("TextLabel", {
        BackgroundTransparency = 1, Text = self.Title,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Library.Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, titleX, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), Parent = top,
    })
    self.TitleLabel = titleLbl
    local subLbl = new("TextLabel", {
        BackgroundTransparency = 1, Text = "  |  " .. self.SubTitle,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Library.Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, titleX + TextService:GetTextSize(self.Title, 14, Enum.Font.GothamBold, Vector2.new(1e4, 20)).X, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0), Parent = top,
    })
    self.SubTitleLabel = subLbl

    local function topButton(order, iconName, color, cb)
        local b = new("TextButton", {
            BackgroundTransparency = 1, Text = "", AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8 - (order - 1) * 30, 0.5, 0),
            Size = UDim2.new(0, 26, 0, 26), Parent = top,
        })
        local img = new("ImageLabel", {
            BackgroundTransparency = 1, Image = Library:GetIcon(iconName),
            ImageColor3 = Library.Theme.SubText,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 16, 0, 16), Parent = b,
        })
        connect(b.MouseEnter, function() tween(img, 0.12, { ImageColor3 = color }) end)
        connect(b.MouseLeave, function() tween(img, 0.12, { ImageColor3 = Library.Theme.SubText }) end)
        connect(b.MouseButton1Click, cb)
        return b
    end

    topButton(1, "Close", Library.Theme.Danger, function() self:Destroy() end)
    topButton(2, "Minimize", Library.Theme.Accent, function() self:Minimize() end)

    makeDraggable(main, top)

    -- ---- Sidebar ----
    local side = new("Frame", {
        BackgroundColor3 = Library.Theme.Sidebar, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(0, 148, 1, -40), Parent = main,
    })
    local sideScroll = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = Library.Theme.Accent,
        Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(0, 0, 0, 0), Parent = side,
    })
    padding(sideScroll, 8)
    local sideLayout = new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sideScroll })
    connect(sideLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        sideScroll.CanvasSize = UDim2.new(0, 0, 0, sideLayout.AbsoluteContentSize.Y + 16)
    end)
    self.Sidebar = sideScroll

    -- ---- Content ----
    local content = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 148, 0, 40), Size = UDim2.new(1, -148, 1, -40), Parent = main,
    })
    self.Content = content

    local header = new("TextLabel", {
        BackgroundTransparency = 1, Text = "",
        Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 18, 0, 8), Size = UDim2.new(1, -36, 0, 30), Parent = content,
    })
    self.Header = header

    -- ---- Minimized icon ----
    local iconBtn = new("ImageButton", {
        BackgroundColor3 = Library.Theme.Topbar, Visible = false,
        Position = opt.IconPosition or UDim2.new(0, 20, 0, 90),
        Size = UDim2.new(0, 48, 0, 48),
        Image = Library:GetIcon(opt.MinimizeIcon or opt.Icon or "icon"),
        ImageTransparency = 0, AutoButtonColor = false, Parent = gui,
    })
    corner(iconBtn, 24)
    stroke(iconBtn, Library.Theme.Accent, 1.5)
    padding(iconBtn, 8)
    self.IconButton = iconBtn

    local dragged = false
    makeDraggable(iconBtn, iconBtn, function() dragged = true; task.delay(0.1, function() dragged = false end) end)
    connect(iconBtn.MouseButton1Click, function()
        if dragged then return end
        self:Maximize()
    end)

    -- ---- Toggle keybind ----
    connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == self.ToggleKey then self:Toggle() end
    end)

    Library.Windows[#Library.Windows + 1] = self
    if opt.AutoShow == false then main.Visible = false; self.Visible = false end
    return self
end

function Window:AddTab(name, icon)
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name   = name
    tab.Icon   = icon

    -- sidebar button
    local btn = new("TextButton", {
        BackgroundColor3 = Library.Theme.Card, BackgroundTransparency = 1,
        AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, 34), Parent = self.Sidebar,
    })
    corner(btn, 8)
    local indicator = new("Frame", {
        BackgroundColor3 = Library.Theme.Accent, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 3, 0, 0), Parent = btn,
    })
    corner(indicator, 2)

    local x = 10
    local img
    if icon then
        img = new("ImageLabel", {
            BackgroundTransparency = 1, Image = Library:GetIcon(icon),
            ImageColor3 = Library.Theme.SubText,
            Position = UDim2.new(0, 10, 0.5, -8), Size = UDim2.new(0, 16, 0, 16), Parent = btn,
        })
        x = 34
    end
    local lbl = new("TextLabel", {
        BackgroundTransparency = 1, Text = "| " .. name,
        Font = Enum.Font.GothamMedium, TextSize = 12.5, TextColor3 = Library.Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(1, -x - 6, 1, 0), Parent = btn,
    })

    -- page
    local page = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Library.Theme.Accent,
        Position = UDim2.new(0, 14, 0, 42), Size = UDim2.new(1, -28, 1, -54),
        CanvasSize = UDim2.new(0, 0, 0, 0), Parent = self.Content,
    })
    local pl = new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
    padding(page, nil, 0, 6, 0, 8)
    connect(pl:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        page.CanvasSize = UDim2.new(0, 0, 0, pl.AbsoluteContentSize.Y + 16)
    end)

    tab.Button, tab.Label, tab.Image, tab.Page, tab.Indicator = btn, lbl, img, page, indicator

    connect(btn.MouseButton1Click, function() self:SelectTab(name) end)
    connect(btn.MouseEnter, function()
        if self.Current ~= name then tween(btn, 0.12, { BackgroundTransparency = 0.6 }) end
    end)
    connect(btn.MouseLeave, function()
        if self.Current ~= name then tween(btn, 0.12, { BackgroundTransparency = 1 }) end
    end)

    self.Tabs[name] = tab
    table.insert(self.TabOrder, name)
    if #self.TabOrder == 1 then self:SelectTab(name) end
    return tab
end

function Window:SelectTab(name)
    local tab = self.Tabs[name]
    if not tab then return end
    for n, t in pairs(self.Tabs) do
        local on = (n == name)
        t.Page.Visible = on
        tween(t.Button, 0.14, { BackgroundTransparency = on and 0 or 1 })
        tween(t.Label, 0.14, { TextColor3 = on and Library.Theme.Accent or Library.Theme.SubText })
        if t.Image then tween(t.Image, 0.14, { ImageColor3 = on and Library.Theme.Accent or Library.Theme.SubText }) end
        tween(t.Indicator, 0.16, { Size = UDim2.new(0, 3, 0, on and 18 or 0) })
    end
    self.Current = name
    self.Header.Text = name
end

function Window:Minimize()
    self.Minimized = true
    self.Main.Visible = false
    self.IconButton.Visible = true
    self.IconButton.Size = UDim2.new(0, 10, 0, 10)
    tween(self.IconButton, 0.2, { Size = UDim2.new(0, 48, 0, 48) }, Enum.EasingStyle.Back)
end

function Window:Maximize()
    self.Minimized = false
    self.IconButton.Visible = false
    self.Main.Visible = true
    self.Visible = true
    self.Main.Size = UDim2.new(self.Main.Size.X.Scale, self.Main.Size.X.Offset, self.Main.Size.Y.Scale, self.Main.Size.Y.Offset)
end
Window.Restore = Window.Maximize

function Window:Toggle(state)
    if state == nil then state = not (self.Main.Visible or self.IconButton.Visible) end
    if state then
        if self.Minimized then self.IconButton.Visible = true else self.Main.Visible = true end
        self.Visible = true
    else
        self.Main.Visible = false
        self.IconButton.Visible = false
        self.Visible = false
    end
end

function Window:SetTitle(t)
    self.Title = t
    if self.TitleLabel then self.TitleLabel.Text = t end
end

function Window:SetSubTitle(t)
    self.SubTitle = t
    if self.SubTitleLabel then self.SubTitleLabel.Text = "  |  " .. t end
end

function Window:Notify(...) return Library:Notify(...) end

function Window:Destroy()
    if self.Gui then self.Gui:Destroy() end
    for i, w in ipairs(Library.Windows) do
        if w == self then table.remove(Library.Windows, i) break end
    end
end
Window.Unload = Window.Destroy

--============================================================
-- LIBRARY LEVEL UTIL
--============================================================
function Library:Toggle(state)
    for _, w in ipairs(self.Windows) do w:Toggle(state) end
end

function Library:Unload()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    for i = #self.Windows, 1, -1 do self.Windows[i]:Destroy() end
    if self._watermark then self._watermark.Gui:Destroy(); self._watermark = nil end
    if NotifyHolder then NotifyHolder.Parent:Destroy(); NotifyHolder = nil end
    self.Toggles, self.Options = {}, {}
    self.Unloaded = true
    if self.OnUnload then pcall(self.OnUnload) end
end
Library.Destroy = Library.Unload

--- Ganti warna accent runtime (dipakai ThemeManager).
function Library:SetTheme(tbl)
    for k, v in pairs(tbl or {}) do self.Theme[k] = v end
end

return Library
