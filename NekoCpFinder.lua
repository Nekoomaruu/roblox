--[[
    Neko Cp Finder
    UI Library : Obsidian (deividcomsono/Obsidian)
    Executor   : Delta / Solara / Wave / Codex (dukungan loadstring + getgenv)

    Fitur:
      - Method 1 : Deteksi checkpoint berdasarkan NAMA (Checkpoint1, Cp1, Cekpoin, Stage 3, dll)
      - Method 2 : Deteksi berdasarkan CollectionService (Tag)
      - Method 3 : Deteksi cerdas (SpawnLocation, TouchTransmitter/script berisi kata checkpoint,
                   Attribute, dan grouping folder yang isinya part berurutan)
      - List hasil + koordinat (X, Y, Z), sort otomatis by nomor stage
      - Teleport ke checkpoint tertentu / Next / Prev
      - Auto Teleport semua checkpoint berurutan (delay bisa diatur)
      - ESP highlight + billboard nama checkpoint
      - Copy koordinat / export semua ke clipboard
--]]

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------------
-- LOAD OBSIDIAN
----------------------------------------------------------------------
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------
local Neko = {
    Checkpoints = {},          -- { {Name=, Object=, Position=Vector3, Order=number, Source=string} }
    CurrentIndex = 0,
    Highlights = {},
    Settings = {
        UseNameMethod = true,
        UseTagMethod = true,
        UseSmartMethod = true,
        CustomKeywords = "",
        SearchIn = "Workspace",  -- Workspace / seluruh game
        AutoDelay = 1.5,
        TeleportOffset = 3,
        MaxResults = 500,
    },
}

-- Kata kunci default (lowercase) untuk method nama
local DEFAULT_KEYWORDS = {
    "checkpoint", "check point", "chekpoint", "cekpoin", "cekpoint", "cp",
    "stage", "level", "spawnpoint", "spawn", "respawn", "flag", "torch",
    "kotakcheckpoint", "post", "pos",
}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function notify(text, dur)
    Library:Notify(text, dur or 4)
end

local function splitKeywords(str)
    local out = {}
    for word in tostring(str):gmatch("[^,]+") do
        word = word:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if #word > 0 then table.insert(out, word) end
    end
    return out
end

local function getKeywords()
    local list = {}
    for _, v in ipairs(DEFAULT_KEYWORDS) do table.insert(list, v) end
    for _, v in ipairs(splitKeywords(Neko.Settings.CustomKeywords)) do
        table.insert(list, v)
    end
    return list
end

-- Ambil angka pertama dari nama, untuk sorting (Checkpoint12 -> 12)
local function extractNumber(name)
    local n = tostring(name):match("(%d+)")
    return n and tonumber(n) or math.huge
end

local function nameMatches(name)
    local lower = tostring(name):lower():gsub("[%s_%-]", "")
    for _, kw in ipairs(getKeywords()) do
        local k = kw:gsub("[%s_%-]", "")
        if #k > 0 and lower:find(k, 1, true) then
            -- "cp" terlalu pendek: wajib diikuti angka agar tidak false positive
            if k == "cp" or k == "pos" then
                if lower:match(k .. "%d") then return true, kw end
            else
                return true, kw
            end
        end
    end
    return false
end

-- Dapatkan posisi dari instance apapun
local function getPosition(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local ok, cf = pcall(function() return obj:GetPivot() end)
        if ok and cf then return cf.Position end
        local part = obj:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.Position end
    elseif obj:IsA("Attachment") then
        return obj.WorldPosition
    elseif obj:IsA("Folder") then
        local part = obj:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.Position end
    end
    return nil
end

local function alreadyAdded(obj)
    for _, cp in ipairs(Neko.Checkpoints) do
        if cp.Object == obj then return true end
    end
    return false
end

local function addCheckpoint(obj, source)
    if not obj or alreadyAdded(obj) then return end
    if #Neko.Checkpoints >= Neko.Settings.MaxResults then return end
    local pos = getPosition(obj)
    if not pos then return end
    table.insert(Neko.Checkpoints, {
        Name = obj.Name,
        Object = obj,
        Position = pos,
        Order = extractNumber(obj.Name),
        Source = source,
        Path = obj:GetFullName(),
    })
end

local function getSearchRoot()
    if Neko.Settings.SearchIn == "Seluruh Game" then
        return game
    end
    return Workspace
end

----------------------------------------------------------------------
-- METHOD 1 : NAMA
----------------------------------------------------------------------
local function scanByName()
    local root = getSearchRoot()
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local ok = nameMatches(obj.Name)
            if ok then
                -- Kalau Model punya nama cocok, ambil model-nya saja (bukan tiap part)
                if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model")
                    and nameMatches(obj.Parent.Name) then
                    -- skip, parent sudah/akan ditambahkan
                else
                    addCheckpoint(obj, "Nama")
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- METHOD 2 : COLLECTIONSERVICE (TAG)
----------------------------------------------------------------------
local function scanByTag()
    local tags = CollectionService:GetAllTags()
    for _, tag in ipairs(tags) do
        local lower = tag:lower():gsub("[%s_%-]", "")
        local match = false
        for _, kw in ipairs(getKeywords()) do
            local k = kw:gsub("[%s_%-]", "")
            if #k > 2 and lower:find(k, 1, true) then match = true break end
        end
        if match then
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                addCheckpoint(obj, "Tag: " .. tag)
            end
        end
    end
end

----------------------------------------------------------------------
-- METHOD 3 : SMART DETECT
----------------------------------------------------------------------
local function scanSmart()
    local root = getSearchRoot()

    -- 3a. SpawnLocation = checkpoint bawaan Roblox
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            addCheckpoint(obj, "SpawnLocation")
        end
    end

    -- 3b. Attribute yang mengandung kata checkpoint/stage
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local ok, attrs = pcall(function() return obj:GetAttributes() end)
            if ok and attrs then
                for key in pairs(attrs) do
                    local k = tostring(key):lower()
                    if k:find("checkpoint") or k:find("stage") or k:find("cp") then
                        addCheckpoint(obj, "Attribute: " .. tostring(key))
                        break
                    end
                end
            end
        end
    end

    -- 3c. Part yang punya script/TouchTransmitter dengan nama mengandung checkpoint
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TouchTransmitter") or obj:IsA("Script") or obj:IsA("LocalScript") then
            local n = obj.Name:lower()
            if n:find("checkpoint") or n:find("stage") or n:find("cekpoin") then
                local parent = obj.Parent
                if parent and (parent:IsA("BasePart") or parent:IsA("Model")) then
                    addCheckpoint(parent, "Script Detect")
                end
            end
        end
    end

    -- 3d. Folder yang isinya part berurutan angka (>=3 anak) -> kandidat checkpoint
    for _, folder in ipairs(root:GetDescendants()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            local numbered, total = 0, 0
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("BasePart") or child:IsA("Model") then
                    total = total + 1
                    if child.Name:match("^%a*%s*%d+$") then numbered = numbered + 1 end
                end
            end
            if total >= 3 and numbered >= 3 and numbered >= total * 0.7 then
                for _, child in ipairs(folder:GetChildren()) do
                    if (child:IsA("BasePart") or child:IsA("Model"))
                        and child.Name:match("%d+") then
                        addCheckpoint(child, "Pola Folder: " .. folder.Name)
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- SCAN UTAMA
----------------------------------------------------------------------
local CheckpointDropdown -- forward declare

local function sortCheckpoints()
    table.sort(Neko.Checkpoints, function(a, b)
        if a.Order == b.Order then return a.Name < b.Name end
        return a.Order < b.Order
    end)
end

local function buildLabels()
    local labels = {}
    for i, cp in ipairs(Neko.Checkpoints) do
        labels[i] = string.format("%d. %s [%d, %d, %d]", i, cp.Name,
            math.floor(cp.Position.X), math.floor(cp.Position.Y), math.floor(cp.Position.Z))
    end
    return labels
end

local ScanLabel

local function refreshUI()
    if CheckpointDropdown then
        local labels = buildLabels()
        CheckpointDropdown:SetValues(labels)
        if #labels > 0 then
            CheckpointDropdown:SetValue(labels[1])
        else
            CheckpointDropdown:SetValue(nil)
        end
    end
    if ScanLabel then
        ScanLabel:SetText("Total checkpoint ditemukan: " .. #Neko.Checkpoints)
    end
end

local function clearHighlights()
    for _, h in ipairs(Neko.Highlights) do
        pcall(function() h:Destroy() end)
    end
    Neko.Highlights = {}
end

local function doScan()
    Neko.Checkpoints = {}
    clearHighlights()

    local t0 = os.clock()
    if Neko.Settings.UseNameMethod then pcall(scanByName) end
    if Neko.Settings.UseTagMethod then pcall(scanByTag) end
    if Neko.Settings.UseSmartMethod then pcall(scanSmart) end
    sortCheckpoints()
    refreshUI()

    if Toggles.EnableESP and Toggles.EnableESP.Value then
        Neko.CreateESP()
    end

    notify(string.format("Neko Cp Finder: %d checkpoint ditemukan (%.2fs)",
        #Neko.Checkpoints, os.clock() - t0), 5)
end

----------------------------------------------------------------------
-- ESP
----------------------------------------------------------------------
function Neko.CreateESP()
    clearHighlights()
    for i, cp in ipairs(Neko.Checkpoints) do
        local obj = cp.Object
        if obj and obj.Parent then
            local ok = pcall(function()
                local hl = Instance.new("Highlight")
                hl.Name = "NekoCP_HL"
                hl.FillColor = Color3.fromRGB(255, 105, 180)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.55
                hl.Adornee = obj
                hl.Parent = obj
                table.insert(Neko.Highlights, hl)

                local adornPart = obj:IsA("BasePart") and obj
                    or obj:FindFirstChildWhichIsA("BasePart", true)
                if adornPart then
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "NekoCP_BB"
                    bb.Size = UDim2.fromOffset(220, 40)
                    bb.StudsOffset = Vector3.new(0, 4, 0)
                    bb.AlwaysOnTop = true
                    bb.Adornee = adornPart
                    bb.Parent = adornPart

                    local lbl = Instance.new("TextLabel")
                    lbl.BackgroundTransparency = 1
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextScaled = false
                    lbl.TextSize = 14
                    lbl.TextColor3 = Color3.fromRGB(255, 170, 220)
                    lbl.TextStrokeTransparency = 0.3
                    lbl.Text = string.format("#%d %s\n%d, %d, %d", i, cp.Name,
                        math.floor(cp.Position.X), math.floor(cp.Position.Y),
                        math.floor(cp.Position.Z))
                    lbl.Parent = bb
                    table.insert(Neko.Highlights, bb)
                end
            end)
            if not ok then end
        end
    end
end

----------------------------------------------------------------------
-- TELEPORT
----------------------------------------------------------------------
local function getRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function teleportTo(index, smooth)
    local cp = Neko.Checkpoints[index]
    if not cp then notify("Checkpoint tidak valid!") return end
    local root = getRoot()
    if not root then notify("Karakter belum siap!") return end

    -- refresh posisi (kalau checkpoint bergerak)
    local pos = getPosition(cp.Object) or cp.Position
    cp.Position = pos
    local target = CFrame.new(pos + Vector3.new(0, Neko.Settings.TeleportOffset, 0))

    if smooth then
        local dist = (root.Position - target.Position).Magnitude
        local tw = TweenService:Create(root,
            TweenInfo.new(math.clamp(dist / 120, 0.15, 3), Enum.EasingStyle.Linear),
            { CFrame = target })
        tw:Play()
        tw.Completed:Wait()
    else
        root.CFrame = target
    end

    Neko.CurrentIndex = index
    notify(string.format("Teleport ke %s (%d/%d)", cp.Name, index, #Neko.Checkpoints), 3)
end

local function getSelectedIndex()
    local val = Options.CheckpointList and Options.CheckpointList.Value
    if not val then return Neko.CurrentIndex > 0 and Neko.CurrentIndex or 1 end
    local idx = tostring(val):match("^(%d+)%.")
    return idx and tonumber(idx) or 1
end

----------------------------------------------------------------------
-- AUTO TELEPORT LOOP
----------------------------------------------------------------------
task.spawn(function()
    while true do
        if Toggles.AutoTeleport and Toggles.AutoTeleport.Value and #Neko.Checkpoints > 0 then
            for i = 1, #Neko.Checkpoints do
                if not (Toggles.AutoTeleport and Toggles.AutoTeleport.Value) then break end
                teleportTo(i, Toggles.SmoothTeleport and Toggles.SmoothTeleport.Value)
                task.wait(Neko.Settings.AutoDelay)
            end
            if Toggles.AutoTeleport and Toggles.AutoTeleport.Value
                and not (Toggles.LoopAuto and Toggles.LoopAuto.Value) then
                Toggles.AutoTeleport:SetValue(false)
                notify("Auto Teleport selesai!", 4)
            end
        end
        task.wait(0.25)
    end
end)

----------------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Neko Cp Finder",
    Footer = "v1.0 • Obsidian UI • by Neko",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
    Center = true,
    AutoShow = true,
    Size = UDim2.fromOffset(600, 500),
    Resizable = true,
})

local Tabs = {
    Finder = Window:AddTab("Finder", "search"),
    Teleport = Window:AddTab("Teleport", "move"),
    Visual = Window:AddTab("Visual", "eye"),
    Settings = Window:AddTab("Settings", "settings"),
}

----------------------------------------------------------------------
-- TAB : FINDER
----------------------------------------------------------------------
local MethodBox = Tabs.Finder:AddLeftGroupbox("Method Deteksi", "list-checks")

MethodBox:AddToggle("MethodName", {
    Text = "Method 1 — Nama (Checkpoint/Cp/Cekpoin)",
    Default = true,
    Tooltip = "Cari part & model yang namanya mengandung kata kunci checkpoint",
    Callback = function(v) Neko.Settings.UseNameMethod = v end,
})

MethodBox:AddToggle("MethodTag", {
    Text = "Method 2 — CollectionService (Tag)",
    Default = true,
    Tooltip = "Cari object yang punya tag mengandung kata checkpoint/stage",
    Callback = function(v) Neko.Settings.UseTagMethod = v end,
})

MethodBox:AddToggle("MethodSmart", {
    Text = "Method 3 — Smart Detect",
    Default = true,
    Tooltip = "SpawnLocation, Attribute, Script Touch, & pola folder berurutan",
    Callback = function(v) Neko.Settings.UseSmartMethod = v end,
})

MethodBox:AddInput("Keywords", {
    Text = "Kata kunci tambahan",
    Default = "",
    Placeholder = "misal: pos, bendera, gate",
    Numeric = false,
    Finished = true,
    Callback = function(v) Neko.Settings.CustomKeywords = v end,
})

MethodBox:AddDropdown("ScanScope", {
    Text = "Area pencarian",
    Values = { "Workspace", "Seluruh Game" },
    Default = 1,
    Callback = function(v) Neko.Settings.SearchIn = v end,
})

MethodBox:AddButton({
    Text = "SCAN CHECKPOINT",
    Func = function() doScan() end,
    DoubleClick = false,
    Tooltip = "Mulai scan sesuai method yang aktif",
})

local ResultBox = Tabs.Finder:AddRightGroupbox("Hasil", "map-pin")

ScanLabel = ResultBox:AddLabel("Total checkpoint ditemukan: 0")

CheckpointDropdown = ResultBox:AddDropdown("CheckpointList", {
    Text = "Daftar Checkpoint",
    Values = {},
    Default = 0,
    AllowNull = true,
    Searchable = true,
    Tooltip = "Format: nomor. nama [X, Y, Z]",
})

ResultBox:AddButton({
    Text = "Teleport ke pilihan",
    Func = function()
        teleportTo(getSelectedIndex(), Toggles.SmoothTeleport and Toggles.SmoothTeleport.Value)
    end,
})

ResultBox:AddButton({
    Text = "Copy koordinat pilihan",
    Func = function()
        local cp = Neko.Checkpoints[getSelectedIndex()]
        if not cp then notify("Belum ada checkpoint dipilih") return end
        local text = string.format("%s = Vector3.new(%.2f, %.2f, %.2f) -- %s",
            cp.Name, cp.Position.X, cp.Position.Y, cp.Position.Z, cp.Source)
        if setclipboard then setclipboard(text) end
        notify("Koordinat dicopy: " .. text, 5)
    end,
})

ResultBox:AddButton({
    Text = "Export semua ke clipboard",
    Func = function()
        if #Neko.Checkpoints == 0 then notify("Belum ada hasil scan") return end
        local lines = { "-- Neko Cp Finder Export --", "local Checkpoints = {" }
        for i, cp in ipairs(Neko.Checkpoints) do
            table.insert(lines, string.format(
                '    [%d] = { Name = "%s", Pos = Vector3.new(%.2f, %.2f, %.2f), Source = "%s", Path = "%s" },',
                i, cp.Name, cp.Position.X, cp.Position.Y, cp.Position.Z, cp.Source, cp.Path))
        end
        table.insert(lines, "}")
        local out = table.concat(lines, "\n")
        if setclipboard then setclipboard(out) end
        notify("Export " .. #Neko.Checkpoints .. " checkpoint ke clipboard!", 5)
    end,
})

ResultBox:AddButton({
    Text = "Print ke console (F9)",
    Func = function()
        for i, cp in ipairs(Neko.Checkpoints) do
            print(string.format("[Neko CP] #%d %s | %s | %.1f, %.1f, %.1f | %s",
                i, cp.Name, cp.Source, cp.Position.X, cp.Position.Y, cp.Position.Z, cp.Path))
        end
        notify("Cek console (F9)", 3)
    end,
})

----------------------------------------------------------------------
-- TAB : TELEPORT
----------------------------------------------------------------------
local TpBox = Tabs.Teleport:AddLeftGroupbox("Manual", "move-3d")

TpBox:AddButton({ Text = "Checkpoint Pertama", Func = function() teleportTo(1) end })
TpBox:AddButton({
    Text = "Checkpoint Sebelumnya",
    Func = function()
        local i = math.max(1, (Neko.CurrentIndex > 0 and Neko.CurrentIndex or 1) - 1)
        teleportTo(i)
    end,
})
TpBox:AddButton({
    Text = "Checkpoint Berikutnya",
    Func = function()
        local i = math.min(#Neko.Checkpoints, (Neko.CurrentIndex) + 1)
        teleportTo(i)
    end,
})
TpBox:AddButton({
    Text = "Checkpoint Terakhir",
    Func = function() teleportTo(#Neko.Checkpoints) end,
})

TpBox:AddSlider("Offset", {
    Text = "Offset Y (studs)",
    Default = 3,
    Min = 0,
    Max = 20,
    Rounding = 1,
    Callback = function(v) Neko.Settings.TeleportOffset = v end,
})

local AutoBox = Tabs.Teleport:AddRightGroupbox("Auto", "repeat")

AutoBox:AddToggle("AutoTeleport", {
    Text = "Auto Teleport semua checkpoint",
    Default = false,
    Risky = true,
})
AutoBox:AddToggle("LoopAuto", { Text = "Ulangi terus (loop)", Default = false })
AutoBox:AddToggle("SmoothTeleport", {
    Text = "Smooth teleport (anti-kick ringan)",
    Default = true,
    Tooltip = "Gerak pelan pakai tween daripada langsung lompat",
})
AutoBox:AddSlider("AutoDelay", {
    Text = "Delay antar checkpoint",
    Default = 1.5,
    Min = 0.1,
    Max = 15,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) Neko.Settings.AutoDelay = v end,
})

----------------------------------------------------------------------
-- TAB : VISUAL
----------------------------------------------------------------------
local VisBox = Tabs.Visual:AddLeftGroupbox("ESP", "eye")

VisBox:AddToggle("EnableESP", {
    Text = "Highlight + nama checkpoint",
    Default = false,
    Callback = function(v)
        if v then Neko.CreateESP() else clearHighlights() end
    end,
})

VisBox:AddButton({ Text = "Refresh ESP", Func = function()
    if Toggles.EnableESP.Value then Neko.CreateESP() end
end })

VisBox:AddButton({ Text = "Hapus semua ESP", Func = clearHighlights })

----------------------------------------------------------------------
-- TAB : SETTINGS
----------------------------------------------------------------------
local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddSlider("MaxResults", {
    Text = "Batas hasil scan",
    Default = 500,
    Min = 50,
    Max = 3000,
    Rounding = 0,
    Callback = function(v) Neko.Settings.MaxResults = v end,
})

MenuGroup:AddToggle("KeybindMenuOpen", {
    Text = "Tampilkan keybind menu",
    Default = false,
    Callback = function(v) Library.KeybindFrame.Visible = v end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom cursor",
    Default = true,
    Callback = function(v) Library.ShowCustomCursor = v end,
})
MenuGroup:AddDropdown("NotificationSide", {
    Text = "Posisi notifikasi",
    Values = { "Left", "Right" },
    Default = "Right",
    Callback = function(v) Library:SetNotifySide(v) end,
})
MenuGroup:AddLabel("Toggle UI"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Toggle UI",
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton({
    Text = "Unload Script",
    Func = function()
        clearHighlights()
        Library:Unload()
    end,
    DoubleClick = true,
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("NekoCpFinder")
SaveManager:SetFolder("NekoCpFinder/configs")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

Library:OnUnload(function()
    clearHighlights()
    Library.Unloaded = true
end)

----------------------------------------------------------------------
-- AUTO SCAN PERTAMA
----------------------------------------------------------------------
task.spawn(function()
    task.wait(1)
    doScan()
    notify("Neko Cp Finder siap! Tekan RightShift untuk buka/tutup menu.", 6)
end)
