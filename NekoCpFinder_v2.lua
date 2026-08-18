--[[
    Neko Cp Finder  v2.0  (STRICT EDITION)
    UI Library : Obsidian (deividcomsono/Obsidian)
    Executor   : Delta / Solara / Wave / Codex

    PERBAIKAN v2 (anti "Torch lamp" & "Flag" nyasar):
      - Sistem SKOR: tiap kandidat dinilai, hanya yang lolos ambang batas yang masuk.
      - BLACKLIST kata (lamp, torch, tree, pohon, decor, bendera, dsb) + blacklist custom.
      - Filter WAJIB BERNOMOR (opsional, default ON): nama harus punya angka urut.
      - Grup keluarga: cari kumpulan nama sepola (Cp1..Cp20). Grup terbesar dianggap
        checkpoint asli, sisa outlier dibuang otomatis.
      - Dedupe posisi (radius) + dedupe nama duplikat tanpa nomor.
      - Method baru:
          M4 Touch-Connection : part yang punya event Touched aktif (getconnections)
          M5 Leaderstats      : baca nilai Stage/Level/Checkpoint pemain -> validasi jumlah
          M6 Geometri         : part datar, anchored, ukuran mirip "pad" checkpoint
          M7 Sequence Check   : validasi urutan angka & jarak antar checkpoint
--]]

----------------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
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
    Checkpoints = {},
    Rejected = {},
    CurrentIndex = 0,
    Highlights = {},
    Settings = {
        UseName = true,
        UseTag = true,
        UseTouch = true,
        UseLeaderstats = true,
        UseGeometry = false,
        UseSpawn = true,
        StrictMode = true,
        RequireNumber = true,
        BestGroupOnly = true,
        MinScore = 60,
        DedupeRadius = 8,
        CustomKeywords = "",
        CustomBlacklist = "",
        SearchIn = "Workspace",
        AutoDelay = 1.5,
        TeleportOffset = 3,
        MaxResults = 500,
    },
}

-- Kata kunci INTI (bobot tinggi)
local CORE_KEYWORDS = {
    "checkpoint", "checkpoin", "chekpoint", "cekpoin", "cekpoint", "cek point",
    "check point", "kotakcheckpoint", "savepoint", "respawnpoint",
}
-- Kata kunci LEMAH (harus ada angka + skor tambahan)
local WEAK_KEYWORDS = { "cp", "stage", "level", "pos", "point", "spawn" }

-- Kata yang otomatis membuang kandidat
local BLACKLIST = {
    "lamp", "lampu", "torch", "obor", "api", "fire", "light", "tree", "pohon",
    "leaf", "daun", "rock", "batu", "grass", "rumput", "bush", "semak",
    "decor", "dekor", "hias", "cloud", "awan", "water", "air", "wall", "dinding",
    "door", "pintu", "chair", "kursi", "table", "meja", "house", "rumah",
    "npc", "mob", "enemy", "coin", "gem", "chest", "shop", "sound", "music",
    "particle", "effect", "vfx", "bendera", "banner", "sign", "papan",
    "camera", "skybox", "terrain", "baseplate", "kill", "lava", "trap",
}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function notify(text, dur)
    Library:Notify(text, dur or 4)
end

local function splitList(str)
    local out = {}
    for word in tostring(str):gmatch("[^,]+") do
        word = word:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if #word > 0 then table.insert(out, word) end
    end
    return out
end

local function norm(s)
    return tostring(s):lower():gsub("[%s_%-%.]", "")
end

local function getCore()
    local t = {}
    for _, v in ipairs(CORE_KEYWORDS) do table.insert(t, v) end
    for _, v in ipairs(splitList(Neko.Settings.CustomKeywords)) do table.insert(t, v) end
    return t
end

local function getBlacklist()
    local t = {}
    for _, v in ipairs(BLACKLIST) do table.insert(t, v) end
    for _, v in ipairs(splitList(Neko.Settings.CustomBlacklist)) do table.insert(t, v) end
    return t
end

local function isBlacklisted(obj)
    local chain = norm(obj.Name)
    local p = obj.Parent
    local depth = 0
    while p and depth < 3 do
        chain = chain .. "|" .. norm(p.Name)
        p = p.Parent
        depth = depth + 1
    end
    -- kata kunci inti pada nama object sendiri mengalahkan blacklist parent
    local selfNorm = norm(obj.Name)
    for _, kw in ipairs(getCore()) do
        if #kw > 3 and selfNorm:find(norm(kw), 1, true) then
            -- tetap tolak kalau nama sendiri jelas dekorasi
            for _, bad in ipairs(getBlacklist()) do
                if selfNorm:find(bad, 1, true) then return true, bad end
            end
            return false
        end
    end
    for _, bad in ipairs(getBlacklist()) do
        if chain:find(bad, 1, true) then return true, bad end
    end
    return false
end

-- prefix + nomor: "Checkpoint 12" -> "checkpoint", 12
local function parseNamePattern(name)
    local n = tostring(name):lower():gsub("[%s_%-%.]+", "")
    local prefix, num = n:match("^(%a+)(%d+)$")
    if prefix then return prefix, tonumber(num) end
    local num2 = n:match("(%d+)")
    return n:gsub("%d", ""), num2 and tonumber(num2) or nil
end

local function extractNumber(name)
    local n = tostring(name):match("(%d+)")
    return n and tonumber(n) or math.huge
end

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

local function hasTouchScript(obj)
    for _, c in ipairs(obj:GetChildren()) do
        if c:IsA("TouchTransmitter") then return true end
        if (c:IsA("Script") or c:IsA("LocalScript") or c:IsA("ModuleScript")) then
            local n = norm(c.Name)
            if n:find("checkpoint") or n:find("stage") or n:find("cekpoin")
                or n:find("touch") or n:find("cp") then
                return true
            end
        end
    end
    return false
end

local function hasTouchConnection(part)
    if typeof(getconnections) ~= "function" then return false end
    local ok, conns = pcall(function() return getconnections(part.Touched) end)
    return ok and conns and #conns > 0
end

local function hasCPAttribute(obj)
    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if not ok or not attrs then return false end
    for key in pairs(attrs) do
        local k = norm(key)
        if k:find("checkpoint") or k:find("stage") or k == "cp" or k:find("cpid") then
            return true, tostring(key)
        end
    end
    return false
end

local function looksLikePad(obj)
    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false end
    local s = part.Size
    -- pad checkpoint biasanya lebar & tipis, anchored
    return part.Anchored and s.Y <= 6 and s.X >= 4 and s.Z >= 4
end

----------------------------------------------------------------------
-- SISTEM SKOR
----------------------------------------------------------------------
-- Return: score (0-100+), alasan
local function scoreCandidate(obj, baseSource)
    local score, reasons = 0, {}
    local nm = norm(obj.Name)
    local prefix, num = parseNamePattern(obj.Name)

    -- 1. Kata kunci inti pada nama
    local coreHit = false
    for _, kw in ipairs(getCore()) do
        if nm:find(norm(kw), 1, true) then coreHit = true break end
    end
    if coreHit then score = score + 55 table.insert(reasons, "kata-inti") end

    -- 2. Kata kunci lemah + WAJIB angka
    if not coreHit then
        for _, kw in ipairs(WEAK_KEYWORDS) do
            if nm:find(kw, 1, true) then
                if num then
                    score = score + 30
                    table.insert(reasons, "kata-lemah+angka")
                else
                    score = score + 5
                end
                break
            end
        end
    end

    -- 3. Format nama rapi "prefix + angka"
    if prefix and num and #prefix >= 2 and nm:match("^%a+%d+$") then
        score = score + 20 table.insert(reasons, "format-rapi")
    elseif num then
        score = score + 8
    end

    -- 4. Sinyal fungsional
    if baseSource == "Tag" then score = score + 45 table.insert(reasons, "tag") end
    if baseSource == "SpawnLocation" then score = score + 50 table.insert(reasons, "spawnlocation") end
    if hasCPAttribute(obj) then score = score + 35 table.insert(reasons, "attribute") end
    if hasTouchScript(obj) then score = score + 25 table.insert(reasons, "script-touch") end

    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
    if part then
        if Neko.Settings.UseTouch and hasTouchConnection(part) then
            score = score + 20 table.insert(reasons, "touched-connection")
        end
        if looksLikePad(obj) then score = score + 10 table.insert(reasons, "bentuk-pad") end
    end

    return score, table.concat(reasons, "+")
end

----------------------------------------------------------------------
-- KUMPUL KANDIDAT
----------------------------------------------------------------------
local Candidates = {}

local function pushCandidate(obj, source)
    if not obj or not obj.Parent then return end
    if Candidates[obj] then return end
    if not (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("SpawnLocation")) then return end

    local bad, badWord = isBlacklisted(obj)
    if bad and source ~= "Tag" and source ~= "SpawnLocation" then
        table.insert(Neko.Rejected, obj:GetFullName() .. "  [blacklist: " .. tostring(badWord) .. "]")
        return
    end

    local pos = getPosition(obj)
    if not pos then return end

    local score, why = scoreCandidate(obj, source)
    local _, num = parseNamePattern(obj.Name)

    if Neko.Settings.RequireNumber and not num
        and source ~= "SpawnLocation" and source ~= "Tag" then
        table.insert(Neko.Rejected, obj:GetFullName() .. "  [tanpa nomor]")
        return
    end

    if Neko.Settings.StrictMode and score < Neko.Settings.MinScore then
        table.insert(Neko.Rejected, string.format("%s  [skor %d < %d | %s]",
            obj:GetFullName(), score, Neko.Settings.MinScore, why))
        return
    end

    Candidates[obj] = {
        Name = obj.Name,
        Object = obj,
        Position = pos,
        Order = num or extractNumber(obj.Name),
        Number = num,
        Score = score,
        Why = why,
        Source = source,
        Path = obj:GetFullName(),
        Prefix = (select(1, parseNamePattern(obj.Name))),
    }
end

local function getSearchRoot()
    if Neko.Settings.SearchIn == "Seluruh Game" then return game end
    return Workspace
end

----------------------------------------------------------------------
-- METHOD 1 : NAMA
----------------------------------------------------------------------
local function scanByName()
    for _, obj in ipairs(getSearchRoot():GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local nm = norm(obj.Name)
            local hit = false
            for _, kw in ipairs(getCore()) do
                if nm:find(norm(kw), 1, true) then hit = true break end
            end
            if not hit then
                for _, kw in ipairs(WEAK_KEYWORDS) do
                    if nm:find(kw .. "%d") or nm:match("^" .. kw .. "%d+$") then hit = true break end
                end
            end
            if hit then
                -- kalau parent Model juga cocok, ambil parent saja
                local parent = obj.Parent
                if obj:IsA("BasePart") and parent and parent:IsA("Model")
                    and norm(parent.Name):find("c") and Candidates[parent] then
                    -- lewati, parent sudah ada
                else
                    pushCandidate(obj, "Nama")
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- METHOD 2 : COLLECTIONSERVICE (TAG)
----------------------------------------------------------------------
local function scanByTag()
    local ok, tags = pcall(function() return CollectionService:GetAllTags() end)
    if not ok or not tags then return end
    for _, tag in ipairs(tags) do
        local lower = norm(tag)
        local match = false
        for _, kw in ipairs(getCore()) do
            if lower:find(norm(kw), 1, true) then match = true break end
        end
        if not match then
            for _, kw in ipairs(WEAK_KEYWORDS) do
                if #kw > 2 and lower:find(kw, 1, true) then match = true break end
            end
        end
        if match then
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                pushCandidate(obj, "Tag")
            end
        end
    end
end

----------------------------------------------------------------------
-- METHOD 3 : SPAWNLOCATION
----------------------------------------------------------------------
local function scanSpawns()
    for _, obj in ipairs(getSearchRoot():GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            pushCandidate(obj, "SpawnLocation")
        end
    end
end

----------------------------------------------------------------------
-- METHOD 4 : TOUCH CONNECTION (part yang benar-benar punya event Touched)
----------------------------------------------------------------------
local function scanTouch()
    if typeof(getconnections) ~= "function" then return end
    for _, obj in ipairs(getSearchRoot():GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanTouch ~= false then
            local nm = norm(obj.Name)
            local numbered = nm:match("%d")
            if numbered and hasTouchConnection(obj) then
                pushCandidate(obj, "Touch")
            end
        end
    end
end

----------------------------------------------------------------------
-- METHOD 5 : LEADERSTATS (validasi jumlah stage)
----------------------------------------------------------------------
local function getStageCountFromLeaderstats()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local best
    local function scan(container)
        if not container then return end
        for _, v in ipairs(container:GetChildren()) do
            local n = norm(v.Name)
            if (n:find("stage") or n:find("checkpoint") or n:find("level") or n == "cp")
                and (v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("StringValue")) then
                local num = tonumber(v.Value)
                if num then best = math.max(best or 0, num) end
            end
        end
    end
    scan(ls)
    scan(LocalPlayer)
    return best
end

----------------------------------------------------------------------
-- METHOD 6 : GEOMETRI (pad datar anchored, opsional)
----------------------------------------------------------------------
local function scanGeometry()
    for _, obj in ipairs(getSearchRoot():GetDescendants()) do
        if obj:IsA("BasePart") and looksLikePad(obj) and obj.Name:match("%d") then
            pushCandidate(obj, "Geometri")
        end
    end
end

----------------------------------------------------------------------
-- METHOD 7 : FILTER GRUP + SEQUENCE
----------------------------------------------------------------------
local function dedupePosition(list)
    local out = {}
    local r = Neko.Settings.DedupeRadius
    for _, cp in ipairs(list) do
        local dup = false
        for _, kept in ipairs(out) do
            if (kept.Position - cp.Position).Magnitude <= r then
                if cp.Score > kept.Score then
                    kept.Name, kept.Object, kept.Position = cp.Name, cp.Object, cp.Position
                    kept.Score, kept.Source, kept.Path = cp.Score, cp.Source, cp.Path
                end
                dup = true
                break
            end
        end
        if not dup then table.insert(out, cp) end
    end
    return out
end

-- Ambil "keluarga" nama terbesar: prefix sama, nomor unik, minimal 2 anggota
local function bestGroupFilter(list)
    local groups = {}
    for _, cp in ipairs(list) do
        local key = cp.Prefix or "?"
        groups[key] = groups[key] or { items = {}, nums = {}, uniq = 0, score = 0 }
        local g = groups[key]
        table.insert(g.items, cp)
        if cp.Number and not g.nums[cp.Number] then
            g.nums[cp.Number] = true
            g.uniq = g.uniq + 1
        end
        g.score = g.score + cp.Score
    end

    local bestKey, bestVal = nil, -1
    for key, g in pairs(groups) do
        -- nilai grup: banyak nomor unik + rata-rata skor
        local avg = g.score / #g.items
        local val = g.uniq * 10 + avg
        -- bonus besar untuk prefix mengandung kata inti
        for _, kw in ipairs(getCore()) do
            if key:find(norm(kw), 1, true) then val = val + 120 break end
        end
        if g.uniq >= 2 and val > bestVal then
            bestKey, bestVal = key, val
        end
    end

    if not bestKey then return list end

    local out = {}
    for _, cp in ipairs(list) do
        if (cp.Prefix or "?") == bestKey or cp.Source == "Tag" or cp.Source == "SpawnLocation" then
            table.insert(out, cp)
        else
            table.insert(Neko.Rejected, cp.Path .. "  [bukan grup utama: " .. tostring(bestKey) .. "]")
        end
    end
    return out, bestKey
end

-- Buang outlier jarak ekstrem (checkpoint biasanya tidak terpisah ribuan stud dari semua)
local function sequenceFilter(list)
    if #list < 4 then return list end
    local out = {}
    for i, cp in ipairs(list) do
        local nearest = math.huge
        for j, other in ipairs(list) do
            if i ~= j then
                nearest = math.min(nearest, (cp.Position - other.Position).Magnitude)
            end
        end
        if nearest < 4000 then
            table.insert(out, cp)
        else
            table.insert(Neko.Rejected, cp.Path .. "  [terlalu jauh dari checkpoint lain]")
        end
    end
    return #out >= 2 and out or list
end

----------------------------------------------------------------------
-- SCAN UTAMA
----------------------------------------------------------------------
local CheckpointDropdown, ScanLabel, DetailLabel

local function buildLabels()
    local labels = {}
    for i, cp in ipairs(Neko.Checkpoints) do
        labels[i] = string.format("%d. %s [%d, %d, %d] (%d%%)", i, cp.Name,
            math.floor(cp.Position.X), math.floor(cp.Position.Y),
            math.floor(cp.Position.Z), math.min(100, cp.Score))
    end
    return labels
end

local function clearHighlights()
    for _, h in ipairs(Neko.Highlights) do
        pcall(function() h:Destroy() end)
    end
    Neko.Highlights = {}
end

local function refreshUI()
    if CheckpointDropdown then
        local labels = buildLabels()
        CheckpointDropdown:SetValues(labels)
        if #labels > 0 then CheckpointDropdown:SetValue(labels[1]) else CheckpointDropdown:SetValue(nil) end
    end
    if ScanLabel then
        ScanLabel:SetText("Checkpoint valid: " .. #Neko.Checkpoints
            .. "  |  ditolak: " .. #Neko.Rejected)
    end
end

local function doScan()
    Candidates = {}
    Neko.Checkpoints = {}
    Neko.Rejected = {}
    clearHighlights()

    local t0 = os.clock()
    if Neko.Settings.UseName then pcall(scanByName) end
    if Neko.Settings.UseTag then pcall(scanByTag) end
    if Neko.Settings.UseSpawn then pcall(scanSpawns) end
    if Neko.Settings.UseTouch then pcall(scanTouch) end
    if Neko.Settings.UseGeometry then pcall(scanGeometry) end

    local list = {}
    for _, data in pairs(Candidates) do table.insert(list, data) end

    -- urutkan skor tertinggi dulu supaya dedupe menyimpan yang terbaik
    table.sort(list, function(a, b) return a.Score > b.Score end)
    list = dedupePosition(list)

    local groupName
    if Neko.Settings.BestGroupOnly then
        list, groupName = bestGroupFilter(list)
    end
    if Neko.Settings.StrictMode then
        list = sequenceFilter(list)
    end

    table.sort(list, function(a, b)
        local an = a.Number or a.Order or math.huge
        local bn = b.Number or b.Order or math.huge
        if an == bn then return a.Name < b.Name end
        return an < bn
    end)

    if #list > Neko.Settings.MaxResults then
        for i = #list, Neko.Settings.MaxResults + 1, -1 do table.remove(list, i) end
    end
    Neko.Checkpoints = list

    -- validasi dengan leaderstats
    local stageCount = Neko.Settings.UseLeaderstats and getStageCountFromLeaderstats() or nil
    refreshUI()

    if DetailLabel then
        DetailLabel:SetText(string.format("Grup: %s | Leaderstats: %s | Waktu: %.2fs",
            tostring(groupName or "-"),
            stageCount and tostring(stageCount) or "-",
            os.clock() - t0))
    end

    if Toggles.EnableESP and Toggles.EnableESP.Value then Neko.CreateESP() end

    notify(string.format("Neko Cp Finder: %d checkpoint valid (%d ditolak) %.2fs",
        #Neko.Checkpoints, #Neko.Rejected, os.clock() - t0), 5)
end

----------------------------------------------------------------------
-- ESP
----------------------------------------------------------------------
function Neko.CreateESP()
    clearHighlights()
    for i, cp in ipairs(Neko.Checkpoints) do
        local obj = cp.Object
        if obj and obj.Parent then
            pcall(function()
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
                    bb.Size = UDim2.fromOffset(230, 44)
                    bb.StudsOffset = Vector3.new(0, 4, 0)
                    bb.AlwaysOnTop = true
                    bb.Adornee = adornPart
                    bb.Parent = adornPart

                    local lbl = Instance.new("TextLabel")
                    lbl.BackgroundTransparency = 1
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 14
                    lbl.TextColor3 = Color3.fromRGB(255, 170, 220)
                    lbl.TextStrokeTransparency = 0.3
                    lbl.Text = string.format("#%d %s (%d%%)\n%d, %d, %d", i, cp.Name,
                        math.min(100, cp.Score),
                        math.floor(cp.Position.X), math.floor(cp.Position.Y),
                        math.floor(cp.Position.Z))
                    lbl.Parent = bb
                    table.insert(Neko.Highlights, bb)
                end
            end)
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
    Footer = "v2.0 Strict • Obsidian UI • by Neko",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
    Center = true,
    AutoShow = true,
    Size = UDim2.fromOffset(620, 520),
    Resizable = true,
})

local Tabs = {
    Finder = Window:AddTab("Finder", "search"),
    Filter = Window:AddTab("Filter", "filter"),
    Teleport = Window:AddTab("Teleport", "move"),
    Visual = Window:AddTab("Visual", "eye"),
    Settings = Window:AddTab("Settings", "settings"),
}

----------------------------------------------------------------------
-- TAB : FINDER
----------------------------------------------------------------------
local MethodBox = Tabs.Finder:AddLeftGroupbox("Method Deteksi", "list-checks")

MethodBox:AddToggle("MethodName", {
    Text = "M1 — Nama (Checkpoint/Cp+angka)",
    Default = true,
    Callback = function(v) Neko.Settings.UseName = v end,
})
MethodBox:AddToggle("MethodTag", {
    Text = "M2 — CollectionService (Tag)",
    Default = true,
    Callback = function(v) Neko.Settings.UseTag = v end,
})
MethodBox:AddToggle("MethodSpawn", {
    Text = "M3 — SpawnLocation",
    Default = true,
    Callback = function(v) Neko.Settings.UseSpawn = v end,
})
MethodBox:AddToggle("MethodTouch", {
    Text = "M4 — Touch Connection (getconnections)",
    Default = true,
    Tooltip = "Deteksi part yang benar-benar punya event Touched aktif",
    Callback = function(v) Neko.Settings.UseTouch = v end,
})
MethodBox:AddToggle("MethodLeaderstats", {
    Text = "M5 — Validasi Leaderstats (Stage/Level)",
    Default = true,
    Callback = function(v) Neko.Settings.UseLeaderstats = v end,
})
MethodBox:AddToggle("MethodGeometry", {
    Text = "M6 — Geometri pad (bisa noisy)",
    Default = false,
    Callback = function(v) Neko.Settings.UseGeometry = v end,
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
    Tooltip = "Scan ulang dengan filter aktif",
})

local ResultBox = Tabs.Finder:AddRightGroupbox("Hasil", "map-pin")
ScanLabel = ResultBox:AddLabel("Checkpoint valid: 0  |  ditolak: 0")
DetailLabel = ResultBox:AddLabel("Grup: - | Leaderstats: - | Waktu: -", true)

CheckpointDropdown = ResultBox:AddDropdown("CheckpointList", {
    Text = "Daftar Checkpoint",
    Values = {},
    Default = 0,
    AllowNull = true,
    Searchable = true,
    Tooltip = "Format: nomor. nama [X, Y, Z] (akurasi)",
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
        notify("Dicopy: " .. text, 5)
    end,
})

ResultBox:AddButton({
    Text = "Export semua ke clipboard",
    Func = function()
        if #Neko.Checkpoints == 0 then notify("Belum ada hasil scan") return end
        local lines = { "-- Neko Cp Finder v2 Export --", "local Checkpoints = {" }
        for i, cp in ipairs(Neko.Checkpoints) do
            table.insert(lines, string.format(
                '    [%d] = { Name = "%s", Pos = Vector3.new(%.2f, %.2f, %.2f), Score = %d, Source = "%s", Path = "%s" },',
                i, cp.Name, cp.Position.X, cp.Position.Y, cp.Position.Z,
                math.min(100, cp.Score), cp.Source, cp.Path))
        end
        table.insert(lines, "}")
        if setclipboard then setclipboard(table.concat(lines, "\n")) end
        notify("Export " .. #Neko.Checkpoints .. " checkpoint!", 5)
    end,
})

ResultBox:AddButton({
    Text = "Print ditolak ke console (F9)",
    Func = function()
        for i, r in ipairs(Neko.Rejected) do
            print(string.format("[Neko CP][DITOLAK #%d] %s", i, r))
        end
        notify("Cek console (F9): " .. #Neko.Rejected .. " ditolak", 3)
    end,
})

----------------------------------------------------------------------
-- TAB : FILTER
----------------------------------------------------------------------
local FilterBox = Tabs.Filter:AddLeftGroupbox("Ketatkan Hasil", "shield-check")

FilterBox:AddToggle("StrictMode", {
    Text = "Strict Mode (skor + buang outlier)",
    Default = true,
    Callback = function(v) Neko.Settings.StrictMode = v end,
})
FilterBox:AddToggle("RequireNumber", {
    Text = "Wajib punya nomor urut",
    Default = true,
    Tooltip = "Buang 'Torch lamp', 'Flag' dan nama tanpa angka",
    Callback = function(v) Neko.Settings.RequireNumber = v end,
})
FilterBox:AddToggle("BestGroupOnly", {
    Text = "Hanya grup nama terbesar",
    Default = true,
    Tooltip = "Kalau ada CP1..CP20 dan 40 'Torch lamp', hanya CP yang diambil",
    Callback = function(v) Neko.Settings.BestGroupOnly = v end,
})
FilterBox:AddSlider("MinScore", {
    Text = "Ambang skor minimal",
    Default = 60, Min = 20, Max = 120, Rounding = 0,
    Callback = function(v) Neko.Settings.MinScore = v end,
})
FilterBox:AddSlider("DedupeRadius", {
    Text = "Radius dedupe posisi",
    Default = 8, Min = 0, Max = 100, Rounding = 0, Suffix = " studs",
    Callback = function(v) Neko.Settings.DedupeRadius = v end,
})

local WordBox = Tabs.Filter:AddRightGroupbox("Kata Kunci", "type")

WordBox:AddInput("Keywords", {
    Text = "Kata kunci tambahan (dianggap inti)",
    Default = "", Placeholder = "misal: pos, gate, savepoint", Finished = true,
    Callback = function(v) Neko.Settings.CustomKeywords = v end,
})
WordBox:AddInput("Blacklist", {
    Text = "Blacklist tambahan",
    Default = "", Placeholder = "misal: torch, bendera, hiasan", Finished = true,
    Callback = function(v) Neko.Settings.CustomBlacklist = v end,
})
WordBox:AddLabel("Blacklist bawaan: lamp, torch, pohon, bendera, decor, npc, coin, lava, dll", true)

WordBox:AddButton({ Text = "Scan ulang dengan filter ini", Func = function() doScan() end })

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
        local i = math.min(#Neko.Checkpoints, Neko.CurrentIndex + 1)
        teleportTo(i)
    end,
})
TpBox:AddButton({ Text = "Checkpoint Terakhir", Func = function() teleportTo(#Neko.Checkpoints) end })

TpBox:AddSlider("Offset", {
    Text = "Offset Y (studs)",
    Default = 3, Min = 0, Max = 20, Rounding = 1,
    Callback = function(v) Neko.Settings.TeleportOffset = v end,
})

local AutoBox = Tabs.Teleport:AddRightGroupbox("Auto", "repeat")
AutoBox:AddToggle("AutoTeleport", { Text = "Auto Teleport semua checkpoint", Default = false, Risky = true })
AutoBox:AddToggle("LoopAuto", { Text = "Ulangi terus (loop)", Default = false })
AutoBox:AddToggle("SmoothTeleport", { Text = "Smooth teleport (anti-kick ringan)", Default = true })
AutoBox:AddSlider("AutoDelay", {
    Text = "Delay antar checkpoint",
    Default = 1.5, Min = 0.1, Max = 15, Rounding = 1, Suffix = "s",
    Callback = function(v) Neko.Settings.AutoDelay = v end,
})

----------------------------------------------------------------------
-- TAB : VISUAL
----------------------------------------------------------------------
local VisBox = Tabs.Visual:AddLeftGroupbox("ESP", "eye")

VisBox:AddToggle("EnableESP", {
    Text = "Highlight + nama checkpoint",
    Default = false,
    Callback = function(v) if v then Neko.CreateESP() else clearHighlights() end end,
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
    Default = 500, Min = 50, Max = 3000, Rounding = 0,
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
    Default = "RightShift", NoUI = true, Text = "Toggle UI",
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton({
    Text = "Unload Script",
    Func = function() clearHighlights() Library:Unload() end,
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
    notify("Neko Cp Finder v2 (Strict) siap! RightShift = buka/tutup menu.", 6)
end)
