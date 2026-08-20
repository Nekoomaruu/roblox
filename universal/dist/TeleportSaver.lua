-- Teleport Saver by Nekomaru Hub — bundled build (jangan edit manual)
-- Sumber asli: Main.lua + Modules/*.lua
local _NH_MODULES = {}
_G._NH_MODULES = _NH_MODULES

_NH_MODULES['Services'] = function()
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

end

_NH_MODULES['Utils'] = function()
--[[
    Modules/Utils.lua
    Helper umum yang dipakai lebih dari satu module.
    Semua helper di sini HARUS bebas efek samping saat require.
]]

local Utils = {}

function Utils.Init(ctx)
    local Library = ctx.Library
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer

    local U = {}

    -- pcall wrapper untuk function biasa
    function U.safeCall(fn, ...)
        if typeof(fn) ~= "function" then return false, "not a function" end
        return pcall(fn, ...)
    end

    -- pcall wrapper untuk method (obj:Method(...)), aman kalau method-nya ga ada
    function U.safeMethod(obj, method, ...)
        if obj and typeof(obj[method]) == "function" then
            return pcall(function(...) return obj[method](obj, ...) end, ...)
        end
        return false, "missing method: " .. tostring(method)
    end

    -- Notifikasi Obsidian. Beberapa versi Obsidian pakai signature berbeda,
    -- jadi coba bentuk table dulu lalu fallback ke (text, time).
    function U.notify(text, dur)
        local message = tostring(text)
        local time = dur or 3
        local ok = false
        if Library and typeof(Library.Notify) == "function" then
            ok = pcall(function()
                Library:Notify({
                    Title = "Teleport Saver",
                    Description = message,
                    Content = message,
                    Time = time,
                })
            end)
            if not ok then
                ok = pcall(function()
                    Library:Notify(message, time)
                end)
            end
        end
        if not ok then
            warn("[Teleport Saver] " .. message)
        end
    end

    function U.getRoot()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        return char:FindFirstChild("HumanoidRootPart")
            or char:WaitForChild("HumanoidRootPart", 5)
    end

    function U.getHumanoid()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- Team check dipakai Aimbot + Hitbox
    function U.isFriendly(plr)
        return LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team
    end

    -- Drawing API tidak ada di semua executor -> selalu boleh return nil
    function U.newDraw(class, props)
        if typeof(Drawing) ~= "table" or typeof(Drawing.new) ~= "function" then
            return nil
        end
        local d = Drawing.new(class)
        for k, v in pairs(props) do d[k] = v end
        return d
    end

    -- Daftar nama player lain di server (sorted)
    function U.otherPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        table.sort(names)
        return names
    end

    return U
end

return Utils

end

_NH_MODULES['UI'] = function()
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

end

_NH_MODULES['DefaultCheckpoints'] = function()
--[[
    Modules/DefaultCheckpoints.lua
    Default checkpoint set (Nekomaru). Sumber asli: Assets/checkpoints/drayzen.json
    Jangan reorder — urutan menentukan urutan playback.
]]

return {
    {name = "Cp 1",  x = 15.469063,    y = 9.497742,    z = -1598.967285},
    {name = "Cp 2",  x = 87.780685,    y = 6.497745,    z = -3042.632812},
    {name = "Cp 3",  x = 1754.797363,  y = 11.104048,   z = -3535.545410},
    {name = "Cp 4",  x = 3277.500000,  y = 5.943120,    z = -3569.489746},
    {name = "Cp 5",  x = 5669.683105,  y = 8.006863,    z = -3565.292480},
    {name = "Cp 6",  x = 7221.630859,  y = 103.263344,  z = -3599.664551},
    {name = "Cp 7",  x = 8800.922852,  y = 102.653969,  z = -3535.269043},
    {name = "Cp 8",  x = 9913.882812,  y = 307.473511,  z = -2389.209961},
    {name = "Cp 9",  x = 11024.126953, y = 1060.038452, z = -1308.930664},
    {name = "Cp 10", x = 12059.686523, y = 1067.894531, z = -251.446854},
    {name = "Cp 11", x = 13164.217773, y = 1068.032837, z = 740.711975},
    {name = "Cp 12", x = 14276.607422, y = 1063.595215, z = 1676.717773},
    {name = "Cp 13", x = 15401.033203, y = 1065.981812, z = 3826.154053},
    {name = "Cp 14", x = 16670.724609, y = 1063.746582, z = 4907.466309},
    {name = "Cp 15", x = 17822.035156, y = 2213.294189, z = 6307.186523},
    {name = "Cp 16", x = 20347.822266, y = 2198.618652, z = 7799.891113},
    {name = "Cp 17", x = 23212.689453, y = 1998.634033, z = 6744.273926},
    {name = "Cp 18", x = 26968.410156, y = 694.151978,  z = 7201.645020},
    {name = "Cp 19", x = 29156.607422, y = 904.295959,  z = 9543.301758},
    {name = "Cp 20", x = 33153.335938, y = 1605.746216, z = 12056.666016},
    {name = "Cp 21", x = 34359.132812, y = 2248.129883, z = 13582.433594},
    {name = "Cp 22", x = 34497.972656, y = 2608.306641, z = 11200.817383},
    {name = "Cp 23", x = 37102.699219, y = 2930.830811, z = 10864.043945},
    {name = "Cp 24", x = 38146.652344, y = 2551.550293, z = 11565.506836},
    {name = "Cp 32", x = 42711.695312, y = 3345.781494, z = 12666.801758},
    {name = "Cp 33", x = 53263.000000, y = 5031.329102, z = 17522.923828},
}

end

_NH_MODULES['Config'] = function()
--[[
    Modules/Config.lua
    Layer filesystem executor (Delta: writefile/readfile/listfiles/...).
    Format file config = JSON array of {name, x, y, z} — JANGAN diubah,
    config lama user harus tetap kebaca.
]]

local Config = {}

function Config.Init(ctx)
    local HttpService = ctx.Services.HttpService
    local notify = ctx.Utils.notify

    local C = {}

    C.FOLDER = "NekomaruHub/TeleportSaver/Checkpoints"
    C.ROOT_FOLDER = "NekomaruHub/TeleportSaver"

    -- Executor tanpa filesystem tetap boleh jalan, fitur config-nya saja mati
    C.hasFS = (typeof(writefile) == "function")
        and (typeof(readfile) == "function")
        and (typeof(isfile) == "function")
        and (typeof(listfiles) == "function")

    function C.ensureFolder()
        if not C.hasFS then return end
        if typeof(makefolder) == "function" then
            if not (typeof(isfolder) == "function" and isfolder("NekomaruHub")) then
                pcall(makefolder, "NekomaruHub")
            end
            if not (typeof(isfolder) == "function" and isfolder("NekomaruHub/TeleportSaver")) then
                pcall(makefolder, "NekomaruHub/TeleportSaver")
            end
            if not (typeof(isfolder) == "function" and isfolder(C.FOLDER)) then
                pcall(makefolder, C.FOLDER)
            end
        end
    end

    function C.list()
        local out = {}
        if not C.hasFS then return out end
        C.ensureFolder()
        local ok, files = pcall(listfiles, C.FOLDER)
        if not ok or type(files) ~= "table" then return out end
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name then table.insert(out, name) end
        end
        table.sort(out)
        return out
    end

    -- Simpan list checkpoint ke <FOLDER>/<name>.json
    function C.save(name, checkpoints)
        if not C.hasFS then notify("Executor tidak support file", 4); return false end
        if not name or name == "" then notify("Nama config kosong", 3); return false end
        C.ensureFolder()
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(checkpoints)
        end)
        if not ok then notify("Gagal encode JSON", 3); return false end
        local path = C.FOLDER .. "/" .. name .. ".json"
        local ok2, err = pcall(writefile, path, encoded)
        if not ok2 then notify("Gagal save: " .. tostring(err), 4); return false end
        notify("Config '" .. name .. "' disimpan (" .. #checkpoints .. " cp)", 3)
        return true
    end

    function C.load(name)
        if not C.hasFS then return nil end
        local path = C.FOLDER .. "/" .. name .. ".json"
        if not isfile(path) then return nil end
        local ok, data = pcall(readfile, path)
        if not ok then return nil end
        local ok2, decoded = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if not ok2 or type(decoded) ~= "table" then return nil end
        return decoded
    end

    function C.delete(name)
        local path = C.FOLDER .. "/" .. name .. ".json"
        if C.hasFS and isfile(path) and typeof(delfile) == "function" then
            pcall(delfile, path)
            return true
        end
        return false
    end

    C.ensureFolder()

    return C
end

return Config

end

_NH_MODULES['Teleport'] = function()
--[[
    Modules/Teleport.lua
    Checkpoint manager + playback + UI tab Teleport (termasuk section Config).

    Public (dipakai Main / module lain):
      Teleport.Init(ctx)
      T.Bootstrap()        -> dipanggil paling akhir oleh Main
      T.getCheckpoints()
      T.applyCheckpoints(list)
]]

local Teleport = {}

function Teleport.Init(ctx)
    local Tabs   = ctx.Tabs
    local Utils  = ctx.Utils
    local Cfg    = ctx.Config
    local notify = Utils.notify
    local DEFAULT_CHECKPOINTS = ctx.DefaultCheckpoints
    local ReplicatedStorage = ctx.Services.ReplicatedStorage

    local T = {}

    -- ---------- State ----------
    local Checkpoints = {}   -- {{name, x, y, z}, ...}
    local Playing     = false
    local Paused      = false
    local PlayThread  = nil
    local PlayDelay   = 1.0
    local LoopPlay    = false
    local AutoBasecamp = false
    local LoopCount   = 0    -- 0 = infinite

    -- RemoteFunction game-specific: dipakai Auto Basecamp tiap akhir loop
    local function fireResetCheckpoint()
        pcall(function()
            local args = {}
            ReplicatedStorage.ResetCheckpoint:InvokeServer(unpack(args))
        end)
    end

    local function teleportTo(cp)
        local root = Utils.getRoot()
        if not root then return false end
        root.CFrame = CFrame.new(cp.x, cp.y, cp.z)
        return true
    end

    -- ============================================================
    -- CHECKPOINT SCAN (anti "checkpoint bergeser")
    -- Ide: sebagian game memindahkan/menggeser posisi checkpoint sedikit,
    -- jadi TP tepat ke koordinat lama bisa nggak kena hitbox checkpoint.
    -- Solusi: setelah TP ke koordinat tersimpan, player "diputar"/disebar
    -- ke sekitar titik itu dari radius 1 stud sampai 10 stud (bisa diatur),
    -- supaya hitbox checkpoint tetap ke-trigger walau geser.
    -- ============================================================
    local ScanEnabled   = false
    local ScanOnManual  = true
    local ScanMethod    = "Orbit Spiral"
    local ScanDelay     = 0.05   -- detik per titik scan
    local ScanMinR      = 1
    local ScanMaxR      = 10
    local ScanStepR     = 1
    local ScanPoints    = 8      -- titik per ring (resolusi putaran)
    local ScanYEnabled  = false
    local ScanYRange    = 4      -- +/- stud vertikal
    local ScanYSteps    = 2      -- layer atas & bawah
    local ScanTimeout   = 6      -- detik maksimal per checkpoint (0 = tanpa batas)
    local ScanReturn    = true   -- balik ke titik tengah setelah scan
    local ScanStopOnHit = true   -- berhenti kalau progress (leaderstats) berubah
    local ScanAnchor    = false  -- kunci velocity biar nggak jatuh saat scan
    local ScanCancel    = false  -- flag internal buat motong scan yang jalan
    local ScanBusy      = false  -- true kalau scan manual sedang jalan

    local ScanMethods = {
        "Orbit Spiral",     -- ring 1..10 stud, tiap ring diputar penuh
        "Cross Axis",       -- 4 arah (+X,-X,+Z,-Z) per radius, paling cepat
        "Vertical Sweep",   -- naik-turun dulu di titik tengah, lalu ring
        "Grid Cube",        -- pola grid kotak di sekitar checkpoint
        "Random Jitter",    -- titik acak dalam bola radius max
        "Dwell Hover",      -- diam di titik + micro-move (buat checkpoint statis)
    }

    -- Snapshot progress dari leaderstats (Stage/Checkpoint/Level/dll)
    local function progressSnapshot()
        local plr = ctx.Services.Players.LocalPlayer
        local ls = plr and plr:FindFirstChild("leaderstats")
        if not ls then return nil end
        local parts = {}
        for _, v in ipairs(ls:GetChildren()) do
            table.insert(parts, tostring(v.Name) .. "=" .. tostring(v.Value))
        end
        table.sort(parts)
        return table.concat(parts, "|")
    end

    -- Pindah player ke posisi absolut + tunggu ScanDelay (respect pause/stop)
    local function scanMove(v3)
        local root = Utils.getRoot()
        if not root then return false end
        root.CFrame = CFrame.new(v3)
        if ScanAnchor then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new()
                root.AssemblyAngularVelocity = Vector3.new()
            end)
        end
        local waited = 0
        local d = math.max(0.01, ScanDelay)
        while waited < d do
            if ScanCancel then return false end

            while Paused and Playing do task.wait(0.05) end
            task.wait(0.02)
            waited = waited + 0.02
        end
        return true
    end

    -- Bangun daftar offset (Vector3) sesuai method terpilih
    local function buildOffsets()
        local list = {}
        local minR = math.min(ScanMinR, ScanMaxR)
        local maxR = math.max(ScanMinR, ScanMaxR)
        local stepR = math.max(0.5, ScanStepR)
        local pts = math.max(3, math.floor(ScanPoints))

        if ScanMethod == "Cross Axis" then
            local r = minR
            while r <= maxR do
                table.insert(list, Vector3.new(r, 0, 0))
                table.insert(list, Vector3.new(-r, 0, 0))
                table.insert(list, Vector3.new(0, 0, r))
                table.insert(list, Vector3.new(0, 0, -r))
                r = r + stepR
            end
        elseif ScanMethod == "Grid Cube" then
            local r = minR
            while r <= maxR do
                for gx = -1, 1 do
                    for gz = -1, 1 do
                        if not (gx == 0 and gz == 0) then
                            table.insert(list, Vector3.new(gx * r, 0, gz * r))
                        end
                    end
                end
                r = r + stepR
            end
        elseif ScanMethod == "Random Jitter" then
            local total = pts * math.max(1, math.floor((maxR - minR) / stepR) + 1)
            for _ = 1, total do
                local ang = math.random() * math.pi * 2
                local rad = minR + math.random() * (maxR - minR)
                local y = ScanYEnabled and (math.random() * 2 - 1) * ScanYRange or 0
                table.insert(list, Vector3.new(math.cos(ang) * rad, y, math.sin(ang) * rad))
            end
        elseif ScanMethod == "Dwell Hover" then
            for i = 1, pts do
                local ang = (i / pts) * math.pi * 2
                table.insert(list, Vector3.new(math.cos(ang) * minR, 0, math.sin(ang) * minR))
                table.insert(list, Vector3.new())
            end
        elseif ScanMethod == "Vertical Sweep" then
            local layers = math.max(1, math.floor(ScanYSteps))
            for i = -layers, layers do
                table.insert(list, Vector3.new(0, (i / layers) * ScanYRange, 0))
            end
            local r = minR
            while r <= maxR do
                for i = 1, pts do
                    local ang = (i / pts) * math.pi * 2
                    table.insert(list, Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r))
                end
                r = r + stepR
            end
        else -- Orbit Spiral (default)
            local r = minR
            while r <= maxR do
                for i = 1, pts do
                    local ang = (i / pts) * math.pi * 2
                    local ox, oz = math.cos(ang) * r, math.sin(ang) * r
                    table.insert(list, Vector3.new(ox, 0, oz))
                    if ScanYEnabled then
                        local layers = math.max(1, math.floor(ScanYSteps))
                        for l = 1, layers do
                            local oy = (l / layers) * ScanYRange
                            table.insert(list, Vector3.new(ox, oy, oz))
                            table.insert(list, Vector3.new(ox, -oy, oz))
                        end
                    end
                end
                r = r + stepR
            end
        end
        return list
    end

    -- Scan penuh di sekitar 1 checkpoint. return true kalau selesai normal.
    local function scanAtCheckpoint(cp)
        local center = Vector3.new(cp.x, cp.y, cp.z)
        local before = ScanStopOnHit and progressSnapshot() or nil
        local offsets = buildOffsets()
        local t0 = tick()
        for _, off in ipairs(offsets) do
            if ScanTimeout > 0 and (tick() - t0) >= ScanTimeout then break end
            if not scanMove(center + off) then return false end
            if before then
                local now = progressSnapshot()
                if now and now ~= before then
                    notify("Checkpoint terdeteksi, scan dipotong", 2)
                    break
                end
            end
        end
        if ScanReturn then
            local root = Utils.getRoot()
            if root then root.CFrame = CFrame.new(center) end
        end
        return true
    end


    local function nextDefaultName()
        return string.format("Cp %d", #Checkpoints + 1)
    end

    -- ---------- Checkpoint dropdown ----------
    local CpDropdown  -- forward

    local function refreshCpDropdown(selectFirst)
        local values = {}
        for i, cp in ipairs(Checkpoints) do
            table.insert(values, string.format("%d. %s", i, cp.name))
        end
        if CpDropdown then
            CpDropdown:SetValues(values)
            if selectFirst and #values > 0 then
                CpDropdown:SetValue(values[1])
            elseif #values == 0 then
                CpDropdown:SetValue(nil)
            end
        end
    end

    local function getSelectedIndex()
        if not CpDropdown then return nil end
        local v = CpDropdown.Value
        if not v or v == "" then return nil end
        local idx = tonumber(string.match(v, "^(%d+)%."))
        return idx
    end

    local function applyCheckpoints(list)
        Checkpoints = {}
        for _, cp in ipairs(list) do
            if type(cp) == "table" and cp.x and cp.y and cp.z then
                table.insert(Checkpoints, {
                    name = tostring(cp.name or nextDefaultName()),
                    x = tonumber(cp.x), y = tonumber(cp.y), z = tonumber(cp.z),
                })
            end
        end
        refreshCpDropdown(true)
    end

    -- ============================================================
    -- TELEPORT TAB
    -- ============================================================
    local LeftBox  = Tabs.Teleport:AddLeftGroupbox("Checkpoints")
    local RightBox = Tabs.Teleport:AddRightGroupbox("Playback")
    local CfgBox   = Tabs.Teleport:AddLeftGroupbox("Config")

    -- Input nama cp baru
    local NameInput = LeftBox:AddInput("cp_name", {
        Default = "",
        Placeholder = "Nama cp (kosong = Cp N)",
        Text = "Nama checkpoint",
    })

    LeftBox:AddButton({
        Text = "Save Position",
        Func = function()
            local root = Utils.getRoot()
            if not root then notify("Character belum ada", 3); return end
            local pos = root.Position
            local name = NameInput.Value
            if not name or name == "" then name = nextDefaultName() end
            table.insert(Checkpoints, {
                name = name, x = pos.X, y = pos.Y, z = pos.Z,
            })
            NameInput:SetValue("")
            refreshCpDropdown(#Checkpoints == 1)
            notify("Saved: " .. name, 2)
        end,
    })

    CpDropdown = LeftBox:AddDropdown("cp_list", {
        Values = {},
        Default = 1,
        Multi = false,
        Text = "Pilih checkpoint",
    })

    LeftBox:AddButton({
        Text = "Teleport",
        Func = function()
            local idx = getSelectedIndex()
            if not idx or not Checkpoints[idx] then notify("Pilih cp dulu", 2); return end
            local cp = Checkpoints[idx]
            teleportTo(cp)
            if ScanOnManual and not ScanBusy then
                ScanCancel = false
                ScanBusy = true
                task.spawn(function()
                    scanAtCheckpoint(cp)
                    ScanBusy = false
                end)
            end
        end,
    }):AddButton({
        Text = "Delete",
        Func = function()
            local idx = getSelectedIndex()
            if not idx or not Checkpoints[idx] then notify("Pilih cp dulu", 2); return end
            local rem = table.remove(Checkpoints, idx)
            refreshCpDropdown(true)
            notify("Deleted: " .. rem.name, 2)
        end,
    })

    LeftBox:AddButton({
        Text = "Rename Selected",
        Func = function()
            local idx = getSelectedIndex()
            if not idx or not Checkpoints[idx] then notify("Pilih cp dulu", 2); return end
            local newName = NameInput.Value
            if not newName or newName == "" then notify("Isi nama dulu di input", 3); return end
            Checkpoints[idx].name = newName
            NameInput:SetValue("")
            refreshCpDropdown(false)
            if CpDropdown then CpDropdown:SetValue(string.format("%d. %s", idx, newName)) end
            notify("Renamed", 2)
        end,
    }):AddButton({
        Text = "Clear All",
        Func = function()
            Checkpoints = {}
            refreshCpDropdown(false)
            notify("All checkpoints cleared", 2)
        end,
    })

    -- ---------- Playback ----------
    RightBox:AddSlider("play_delay", {
        Text = "Delay per checkpoint (detik)",
        Default = 1,
        Min = 0,
        Max = 10,
        Rounding = 1,
        Suffix = "s",
        Callback = function(v) PlayDelay = v end,
    })

    RightBox:AddToggle("play_loop", {
        Text = "Loop Play",
        Default = false,
        Callback = function(v) LoopPlay = v end,
    })

    RightBox:AddToggle("auto_basecamp", {
        Text = "Auto Basecamp (Reset tiap akhir loop)",
        Default = false,
        Callback = function(v) AutoBasecamp = v end,
    })

    RightBox:AddInput("loop_count", {
        Default = "0",
        Placeholder = "0 = infinite",
        Text = "Loop Count",
        Numeric = true,
        Finished = true,
        Callback = function(v)
            local n = tonumber(v) or 0
            if n < 0 then n = 0 end
            LoopCount = math.floor(n)
        end,
    })

    local function stopPlayback(msg)
        Playing = false
        Paused = false
        ScanCancel = true
        if msg then notify(msg, 2) end
    end

    -- Playback loop: pause dicek di dua titik (sebelum TP dan saat delay)
    -- supaya pause terasa instan tanpa mematikan thread.
    local function runPlayback()
        if #Checkpoints == 0 then notify("Belum ada checkpoint", 3); return end
        Playing = true
        Paused = false
        ScanCancel = false
        PlayThread = task.spawn(function()
            local completed = 0
            while Playing do
                for _, cp in ipairs(Checkpoints) do
                    if not Playing then return end
                    while Paused and Playing do task.wait(0.1) end
                    if not Playing then return end
                    teleportTo(cp)
                    if ScanEnabled then scanAtCheckpoint(cp) end
                    if not Playing then return end

                    local t = 0
                    while t < PlayDelay do
                        if not Playing then return end
                        while Paused and Playing do task.wait(0.1) end
                        task.wait(0.1)
                        t = t + 0.1
                    end
                end
                if not Playing then return end
                if AutoBasecamp then
                    fireResetCheckpoint()
                    task.wait(0.5)
                end
                completed = completed + 1
                if LoopCount > 0 and completed >= LoopCount then break end
                if not LoopPlay and not AutoBasecamp then break end
            end
            if Playing then
                Playing = false
                notify("Playback selesai (" .. tostring(completed) .. " loop)", 3)
            end
        end)
    end

    RightBox:AddButton({
        Text = "Play",
        Func = function()
            if Playing then notify("Sudah play", 2); return end
            runPlayback()
        end,
    }):AddButton({
        Text = "Pause / Resume",
        Func = function()
            if not Playing then notify("Belum play", 2); return end
            Paused = not Paused
            notify(Paused and "Paused" or "Resumed", 2)
        end,
    })

    RightBox:AddButton({
        Text = "Stop",
        Func = function()
            if not Playing and not ScanBusy then notify("Belum play", 2); return end
            ScanCancel = true
            stopPlayback("Stopped")
        end,
    })

    -- ---------- Checkpoint Scan ----------
    local ScanBox = Tabs.Teleport:AddRightGroupbox("Checkpoint Scan (Anti Geser)")

    ScanBox:AddToggle("scan_enabled", {
        Text = "Enable Scan saat Play",
        Tooltip = "Setelah TP ke checkpoint, player diputar 1-10 stud di sekitarnya biar hitbox checkpoint tetap kena walau posisinya digeser game.",
        Default = false,
        Callback = function(v) ScanEnabled = v end,
    })

    ScanBox:AddToggle("scan_manual", {
        Text = "Scan juga saat Teleport manual",
        Default = true,
        Callback = function(v) ScanOnManual = v end,
    })

    ScanBox:AddDropdown("scan_method", {
        Values = ScanMethods,
        Default = 1,
        Multi = false,
        Text = "Scan Method",
        Callback = function(v) ScanMethod = v end,
    })

    ScanBox:AddSlider("scan_speed", {
        Text = "Scan Speed (delay per titik)",
        Default = 0.05,
        Min = 0.01,
        Max = 0.5,
        Rounding = 2,
        Suffix = "s",
        Callback = function(v) ScanDelay = v end,
    })

    ScanBox:AddSlider("scan_min_r", {
        Text = "Radius Awal",
        Default = 1, Min = 0, Max = 20, Rounding = 1, Suffix = " stud",
        Callback = function(v) ScanMinR = v end,
    })

    ScanBox:AddSlider("scan_max_r", {
        Text = "Radius Akhir",
        Default = 10, Min = 1, Max = 50, Rounding = 1, Suffix = " stud",
        Callback = function(v) ScanMaxR = v end,
    })

    ScanBox:AddSlider("scan_step_r", {
        Text = "Radius Step",
        Default = 1, Min = 0.5, Max = 10, Rounding = 1, Suffix = " stud",
        Callback = function(v) ScanStepR = v end,
    })

    ScanBox:AddSlider("scan_points", {
        Text = "Titik per Ring (resolusi putaran)",
        Default = 8, Min = 3, Max = 32, Rounding = 0,
        Callback = function(v) ScanPoints = v end,
    })

    ScanBox:AddToggle("scan_vertical", {
        Text = "Sertakan offset vertikal (naik/turun)",
        Default = false,
        Callback = function(v) ScanYEnabled = v end,
    })

    ScanBox:AddSlider("scan_y_range", {
        Text = "Jangkauan Vertikal",
        Default = 4, Min = 1, Max = 25, Rounding = 1, Suffix = " stud",
        Callback = function(v) ScanYRange = v end,
    })

    ScanBox:AddSlider("scan_y_steps", {
        Text = "Layer Vertikal",
        Default = 2, Min = 1, Max = 8, Rounding = 0,
        Callback = function(v) ScanYSteps = v end,
    })

    ScanBox:AddSlider("scan_timeout", {
        Text = "Timeout per Checkpoint (0 = off)",
        Default = 6, Min = 0, Max = 30, Rounding = 1, Suffix = "s",
        Callback = function(v) ScanTimeout = v end,
    })

    ScanBox:AddToggle("scan_return", {
        Text = "Balik ke titik tengah setelah scan",
        Default = true,
        Callback = function(v) ScanReturn = v end,
    })

    ScanBox:AddToggle("scan_stop_on_hit", {
        Text = "Auto stop scan kalau progress berubah",
        Tooltip = "Baca leaderstats (Stage/Checkpoint/dll). Kalau nilainya berubah berarti checkpoint kena, scan langsung dipotong biar cepat.",
        Default = true,
        Callback = function(v) ScanStopOnHit = v end,
    })

    ScanBox:AddToggle("scan_anchor", {
        Text = "Anchor velocity saat scan (anti jatuh)",
        Default = false,
        Callback = function(v) ScanAnchor = v end,
    })

    ScanBox:AddButton({
        Text = "Scan Checkpoint Terpilih",
        Func = function()
            if ScanBusy then notify("Scan sedang jalan", 2); return end
            local idx = getSelectedIndex()
            if not idx or not Checkpoints[idx] then notify("Pilih cp dulu", 2); return end
            ScanCancel = false
            ScanBusy = true
            task.spawn(function()
                teleportTo(Checkpoints[idx])
                scanAtCheckpoint(Checkpoints[idx])
                ScanBusy = false
                notify("Scan selesai", 2)
            end)
        end,
    }):AddButton({
        Text = "Stop Scan",
        Func = function()
            ScanCancel = true
            notify("Scan dihentikan", 2)
        end,
    })


    -- ---------- Config (save/load checkpoints) ----------
    local ConfigDropdown

    local function refreshConfigDropdown()
        local list = Cfg.list()
        if ConfigDropdown then
            ConfigDropdown:SetValues(list)
            if #list > 0 then ConfigDropdown:SetValue(list[1]) else ConfigDropdown:SetValue(nil) end
        end
    end

    local ConfigNameInput = CfgBox:AddInput("cfg_name", {
        Default = "",
        Placeholder = "Nama config",
        Text = "Nama config",
    })

    CfgBox:AddButton({
        Text = "Create / Save Config",
        Func = function()
            local name = ConfigNameInput.Value
            if not name or name == "" then notify("Isi nama config", 3); return end
            if Cfg.save(name, Checkpoints) then
                ConfigNameInput:SetValue("")
                refreshConfigDropdown()
                if ConfigDropdown then ConfigDropdown:SetValue(name) end
            end
        end,
    }):AddButton({
        Text = "Refresh List",
        Func = function() refreshConfigDropdown() end,
    })

    ConfigDropdown = CfgBox:AddDropdown("cfg_list", {
        Values = {},
        Default = 1,
        Multi = false,
        Text = "Config tersimpan",
    })

    CfgBox:AddButton({
        Text = "Load Config",
        Func = function()
            local sel = ConfigDropdown and ConfigDropdown.Value
            if not sel or sel == "" then notify("Pilih config dulu", 2); return end
            local data = Cfg.load(sel)
            if not data then notify("Gagal load config", 3); return end
            applyCheckpoints(data)
            notify("Loaded '" .. sel .. "' (" .. #Checkpoints .. " cp)", 3)
        end,
    }):AddButton({
        Text = "Delete Config",
        Func = function()
            local sel = ConfigDropdown and ConfigDropdown.Value
            if not sel or sel == "" then notify("Pilih config dulu", 2); return end
            if Cfg.delete(sel) then
                notify("Deleted config '" .. sel .. "'", 2)
                refreshConfigDropdown()
            else
                notify("Gagal delete", 2)
            end
        end,
    })

    CfgBox:AddButton({
        Text = "Load Default (Nekomaru)",
        Func = function()
            applyCheckpoints(DEFAULT_CHECKPOINTS)
            notify("Default checkpoints loaded (" .. #Checkpoints .. ")", 3)
        end,
    })

    -- ---------- Public API ----------
    T.applyCheckpoints = applyCheckpoints
    T.refreshConfigDropdown = refreshConfigDropdown
    function T.getCheckpoints() return Checkpoints end

    -- Dipanggil Main paling akhir (urutan ini bagian dari behaviour lama):
    -- kalau belum ada config sama sekali, bikin config default dulu.
    function T.Bootstrap()
        refreshConfigDropdown()

        if #Cfg.list() == 0 then
            Cfg.save("Default_Nekomaru_setup", Checkpoints)
            -- overwrite dengan default
            applyCheckpoints(DEFAULT_CHECKPOINTS)
            Cfg.save("Default_Nekomaru_setup", Checkpoints)
            refreshConfigDropdown()
        end

        applyCheckpoints(DEFAULT_CHECKPOINTS)
        notify("Teleport Saver loaded! Default checkpoints ready.", 4)
    end

    return T
end

return Teleport

end

_NH_MODULES['Player'] = function()
--[[
    Modules/Player.lua
    Tab Player: Movement (speed/jump/inf jump/noclip), Misc universal,
    dan Teleport to Player.
]]

local Player = {}

function Player.Init(ctx)
    local Tabs = ctx.Tabs
    local Library = ctx.Library
    local Utils = ctx.Utils
    local notify = Utils.notify
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer
    local RunService = ctx.Services.RunService
    local UserInputService = ctx.Services.UserInputService

    local P = {}

    local MoveBox = Tabs.Player:AddLeftGroupbox("Movement")
    local MiscBox = Tabs.Player:AddRightGroupbox("Misc / Universal", "wrench")

    -- ---------- Misc / Universal ----------
    MiscBox:AddButton({
        Text = "Reset Character",
        Func = function()
            pcall(function() LocalPlayer.Character:BreakJoints() end)
        end,
    })
    MiscBox:AddButton({
        Text = "Reset Camera",
        Func = function()
            pcall(function()
                workspace.CurrentCamera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            end)
        end,
    })

    local AntiFling = false
    MiscBox:AddToggle("anti_fling", {
        Text = "Anti Fling (nolkan velocity aneh)",
        Default = false,
        Callback = function(v) AntiFling = v end,
    })
    task.spawn(function()
        while task.wait(0.1) do
            if AntiFling then
                pcall(function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.AssemblyAngularVelocity.Magnitude > 60 then
                            part.AssemblyAngularVelocity = Vector3.zero
                            part.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                end)
            end
        end
    end)

    -- Anti Void: posisi aman terakhir tetap direkam walau toggle-nya off,
    -- jadi begitu di-on-kan langsung ada titik balik.
    local AntiVoid = false
    MiscBox:AddToggle("anti_void", {
        Text = "Anti Void (TP balik kalau jatuh)",
        Default = false,
        Callback = function(v) AntiVoid = v end,
    })
    task.spawn(function()
        local lastSafe = nil
        while task.wait(0.3) do
            pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                if root.Position.Y > -150 then
                    lastSafe = root.CFrame
                elseif AntiVoid and lastSafe then
                    root.CFrame = lastSafe + Vector3.new(0, 8, 0)
                end
            end)
        end
    end)

    MiscBox:AddToggle("god_mode_ish", {
        Text = "Anti Fall Damage (freeze health)",
        Default = false,
        Callback = function(v)
            if v then
                task.spawn(function()
                    while true do
                        task.wait(0.2)
                        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if not hum then break end
                        if Library and Library.Options and Library.Options["god_mode_ish"] and not Library.Options["god_mode_ish"].Value then break end
                        pcall(function() hum.Health = hum.MaxHealth end)
                    end
                end)
            end
        end,
    })

    local TPBox = Tabs.Player:AddRightGroupbox("Teleport to Player")

    -- ---------- Movement ----------
    local SpeedEnabled   = false
    local SpeedValue     = 16
    local JumpEnabled    = false
    local JumpValue      = 50
    local InfJumpEnabled = false
    local NoClipEnabled  = false

    local getHumanoid = Utils.getHumanoid

    RunService.Heartbeat:Connect(function()
        local hum = getHumanoid()
        if hum then
            if SpeedEnabled then hum.WalkSpeed = SpeedValue end
            if JumpEnabled then
                hum.UseJumpPower = true
                hum.JumpPower = JumpValue
            end
        end
        if NoClipEnabled then
            local c = LocalPlayer.Character
            if c then
                for _, part in ipairs(c:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)

    UserInputService.JumpRequest:Connect(function()
        if InfJumpEnabled then
            local hum = getHumanoid()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)

    MoveBox:AddToggle("speed_toggle", {
        Text = "Enable WalkSpeed",
        Default = false,
        Callback = function(v)
            SpeedEnabled = v
            if not v then
                local hum = getHumanoid()
                if hum then hum.WalkSpeed = 16 end
            end
        end,
    })
    MoveBox:AddSlider("speed_value", {
        Text = "WalkSpeed",
        Default = 32,
        Min = 8, Max = 500, Rounding = 0, Suffix = "",
        Callback = function(v) SpeedValue = v end,
    })

    MoveBox:AddToggle("jump_toggle", {
        Text = "Enable JumpBoost",
        Default = false,
        Callback = function(v)
            JumpEnabled = v
            if not v then
                local hum = getHumanoid()
                if hum then hum.JumpPower = 50 end
            end
        end,
    })
    MoveBox:AddSlider("jump_value", {
        Text = "JumpPower",
        Default = 100,
        Min = 20, Max = 500, Rounding = 0, Suffix = "",
        Callback = function(v) JumpValue = v end,
    })

    MoveBox:AddToggle("inf_jump", {
        Text = "Infinite Jump",
        Default = false,
        Callback = function(v) InfJumpEnabled = v end,
    })

    MoveBox:AddToggle("noclip", {
        Text = "NoClip",
        Default = false,
        Callback = function(v) NoClipEnabled = v end,
    })

    -- ============================================================
    -- Fly (3 method)
    -- ============================================================
    local FlyBox = Tabs.Player:AddLeftGroupbox("Fly", "plane")

    local FlyEnabled  = false
    local FlyMethod   = "CFrame Fly"
    local FlySpeed    = 60
    local FlyVertical = true

    local flyConn, flyBV, flyBG, flyAlign, flyOrient
    local flyKeys = { up = false, down = false }

    local function flyCleanup()
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        for _, obj in ipairs({ flyBV, flyBG, flyAlign, flyOrient }) do
            if obj then pcall(function() obj:Destroy() end) end
        end
        flyBV, flyBG, flyAlign, flyOrient = nil, nil, nil, nil
        local hum = Utils.getHumanoid()
        if hum then
            pcall(function()
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
    end

    -- arah input: keyboard WASD/space/ctrl, mobile pakai MoveDirection
    local function flyDirection()
        local cam = workspace.CurrentCamera
        local root = Utils.getRoot()
        if not cam or not root then return Vector3.zero end
        local dir = Vector3.zero
        local kb = UserInputService.KeyboardEnabled
        if kb then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        end
        if dir.Magnitude == 0 then
            -- mobile / thumbstick: pakai MoveDirection humanoid
            local hum = Utils.getHumanoid()
            if hum and hum.MoveDirection.Magnitude > 0 then
                dir = hum.MoveDirection
            end
        end
        if flyKeys.up then dir = dir + Vector3.new(0, 1, 0) end
        if flyKeys.down then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        if not FlyVertical then dir = Vector3.new(dir.X, 0, dir.Z) end
        return dir
    end

    -- Method 1: CFrame Fly — paling universal, jalan hampir di semua game
    local function startCFrameFly()
        local hum = Utils.getHumanoid()
        if hum then hum.PlatformStand = true end
        flyConn = RunService.RenderStepped:Connect(function(dt)
            local root = Utils.getRoot()
            if not root then return end
            local dir = flyDirection()
            pcall(function()
                root.Velocity = Vector3.zero
                root.CFrame = root.CFrame + dir * (FlySpeed * dt)
            end)
        end)
    end

    -- Method 2: Velocity Fly — pakai BodyVelocity + BodyGyro, halus & anti-jitter
    local function startVelocityFly()
        local root = Utils.getRoot()
        if not root then return end
        local hum = Utils.getHumanoid()
        if hum then hum.PlatformStand = true end
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        flyBG.P = 9000
        flyBG.D = 300
        flyBG.CFrame = root.CFrame
        flyBG.Parent = root
        flyConn = RunService.Heartbeat:Connect(function()
            local r = Utils.getRoot()
            local cam = workspace.CurrentCamera
            if not r or not flyBV then return end
            flyBV.Velocity = flyDirection() * FlySpeed
            if flyBG and cam then
                flyBG.CFrame = CFrame.new(r.Position, r.Position + cam.CFrame.LookVector)
            end
        end)
    end

    -- Method 3: Align Fly — AlignPosition/AlignOrientation, paling aman dari anti-cheat velocity
    local function startAlignFly()
        local root = Utils.getRoot()
        if not root then return end
        local hum = Utils.getHumanoid()
        if hum then hum.PlatformStand = true end
        local att = Instance.new("Attachment")
        att.Name = "NHFlyAtt"
        att.Parent = root
        flyAlign = Instance.new("AlignPosition")
        flyAlign.Attachment0 = att
        flyAlign.Mode = Enum.PositionAlignmentMode.OneAttachment
        flyAlign.MaxForce = 1e9
        flyAlign.MaxVelocity = math.huge
        flyAlign.Responsiveness = 200
        flyAlign.Position = root.Position
        flyAlign.Parent = root
        flyOrient = Instance.new("AlignOrientation")
        flyOrient.Attachment0 = att
        flyOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
        flyOrient.MaxTorque = 1e9
        flyOrient.Responsiveness = 200
        flyOrient.Parent = root
        local target = root.Position
        flyConn = RunService.Heartbeat:Connect(function(dt)
            local r = Utils.getRoot()
            local cam = workspace.CurrentCamera
            if not r or not flyAlign then return end
            local dir = flyDirection()
            if dir.Magnitude > 0 then
                target = target + dir * (FlySpeed * dt)
            end
            -- kalau target kejauhan dari player (nabrak), tarik balik biar ga ketinggalan
            if (target - r.Position).Magnitude > 30 then target = r.Position end
            flyAlign.Position = target
            if flyOrient and cam then
                flyOrient.CFrame = CFrame.new(Vector3.zero, cam.CFrame.LookVector)
            end
        end)
    end

    local function setFly(on)
        flyCleanup()
        if not on then return end
        local root = Utils.getRoot()
        if not root then notify("Character belum ada", 2); return end
        if FlyMethod == "Velocity Fly" then
            startVelocityFly()
        elseif FlyMethod == "Align Fly" then
            startAlignFly()
        else
            startCFrameFly()
        end
    end

    FlyBox:AddToggle("fly_toggle", {
        Text = "Enable Fly",
        Default = false,
        Callback = function(v)
            FlyEnabled = v
            setFly(v)
        end,
    })

    -- keybind F buat toggle fly (keyboard)
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F then
            local tg = Library and Library.Toggles and Library.Toggles["fly_toggle"]
            if tg and tg.SetValue then tg:SetValue(not tg.Value) end
        end
    end)

    FlyBox:AddDropdown("fly_method", {
        Values = { "CFrame Fly", "Velocity Fly", "Align Fly" },
        Default = 1,
        Multi = false,
        Text = "Fly Method",
        Callback = function(v)
            FlyMethod = v
            if FlyEnabled then setFly(true) end
        end,
    })

    FlyBox:AddSlider("fly_speed", {
        Text = "Fly Speed",
        Default = 60, Min = 10, Max = 400, Rounding = 0,
        Callback = function(v) FlySpeed = v end,
    })

    FlyBox:AddToggle("fly_vertical", {
        Text = "Allow Vertical (Space / Ctrl)",
        Default = true,
        Callback = function(v) FlyVertical = v end,
    })

    -- tombol naik/turun buat mobile (Delta)
    FlyBox:AddButton({
        Text = "Hold Up (mobile)",
        Func = function()
            flyKeys.up = true
            task.delay(0.6, function() flyKeys.up = false end)
        end,
    }):AddButton({
        Text = "Hold Down (mobile)",
        Func = function()
            flyKeys.down = true
            task.delay(0.6, function() flyKeys.down = false end)
        end,
    })

    -- re-apply fly setelah respawn
    LocalPlayer.CharacterAdded:Connect(function()
        if FlyEnabled then
            task.wait(1)
            setFly(true)
        end
    end)

    -- ============================================================
    -- Universal / Tools
    -- ============================================================
    local UtilBox = Tabs.Player:AddLeftGroupbox("Universal / Tools", "wrench")

    -- Checkpoint Finder: execute script eksternal (bukan diload di dalam script ini)
    local CP_FINDER_URL = "https://raw.githubusercontent.com/Nekoomaruu/roblox/refs/heads/main/NekoCpFinder_v2.lua"
    UtilBox:AddButton({
        Text = "Checkpoint Finder (execute script)",
        Func = function()
            notify("Menjalankan Checkpoint Finder...", 2)
            task.spawn(function()
                local ok, src = pcall(function() return game:HttpGet(CP_FINDER_URL) end)
                if not ok or type(src) ~= "string" or #src < 50 then
                    notify("Gagal download Checkpoint Finder", 3); return
                end
                local chunk, err = loadstring(src, "NekoCpFinder_v2")
                if not chunk then notify("Syntax error CP Finder: " .. tostring(err), 4); return end
                local ok2, res = pcall(chunk)
                if not ok2 then notify("Error CP Finder: " .. tostring(res), 4) end
            end)
        end,
    })

    -- Freeze / Unfreeze
    local frozenCF = nil
    local FreezeConn
    UtilBox:AddToggle("freeze_char", {
        Text = "Freeze Character",
        Default = false,
        Callback = function(v)
            if FreezeConn then FreezeConn:Disconnect(); FreezeConn = nil end
            if v then
                local root = Utils.getRoot()
                if not root then notify("Character belum ada", 2); return end
                frozenCF = root.CFrame
                FreezeConn = RunService.Heartbeat:Connect(function()
                    local r = Utils.getRoot()
                    if r and frozenCF then
                        r.CFrame = frozenCF
                        r.Velocity = Vector3.zero
                    end
                end)
            end
        end,
    })

    -- Spin
    local SpinConn
    UtilBox:AddToggle("spin_char", {
        Text = "Spin Character",
        Default = false,
        Callback = function(v)
            if SpinConn then SpinConn:Disconnect(); SpinConn = nil end
            if v then
                SpinConn = RunService.Heartbeat:Connect(function(dt)
                    local r = Utils.getRoot()
                    if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(360 * dt), 0) end
                end)
            end
        end,
    })

    -- Click Teleport (klik / tap ke tempat tujuan)
    local ClickTP = false
    UtilBox:AddToggle("click_tp", {
        Text = "Click Teleport (klik ke lokasi)",
        Default = false,
        Callback = function(v) ClickTP = v end,
    })
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not ClickTP or gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            local cam = workspace.CurrentCamera
            local root = Utils.getRoot()
            if not cam or not root then return end
            local pos = input.Position
            local ray = cam:ViewportPointToRay(pos.X, pos.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { LocalPlayer.Character }
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
            if hit then root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 4, 0)) end
        end
    end)

    UtilBox:AddButton({
        Text = "Sit / Stand",
        Func = function()
            local hum = Utils.getHumanoid()
            if hum then hum.Sit = not hum.Sit end
        end,
    }):AddButton({
        Text = "Copy My Position",
        Func = function()
            local root = Utils.getRoot()
            if not root then return end
            local p = root.Position
            local txt = string.format("%.2f, %.2f, %.2f", p.X, p.Y, p.Z)
            if setclipboard then setclipboard(txt) end
            notify("Posisi dicopy: " .. txt, 3)
        end,
    })

    -- ---------- Teleport to Player ----------
    local TPDropdown
    local function refreshTPList()
        local names = Utils.otherPlayerNames()
        if TPDropdown then
            TPDropdown:SetValues(names)
            if #names > 0 then TPDropdown:SetValue(names[1]) else TPDropdown:SetValue(nil) end
        end
    end

    TPDropdown = TPBox:AddDropdown("tp_player_list", {
        Values = {}, Default = 1, Multi = false, Text = "Pilih player",
    })

    TPBox:AddButton({
        Text = "Refresh",
        Func = function() refreshTPList() end,
    }):AddButton({
        Text = "Teleport",
        Func = function()
            local sel = TPDropdown and TPDropdown.Value
            if not sel or sel == "" then notify("Pilih player dulu", 2); return end
            local target = Players:FindFirstChild(sel)
            if not target or not target.Character then notify("Target tidak ada", 2); return end
            local troot = target.Character:FindFirstChild("HumanoidRootPart")
            local myroot = Utils.getRoot()
            if troot and myroot then
                myroot.CFrame = troot.CFrame + Vector3.new(0, 3, 0)
            end
        end,
    })

    P.refreshTPList = refreshTPList

    return P
end

return Player

end

_NH_MODULES['Visual'] = function()
--[[
    Modules/Visual.lua
    Tab Visuals bagian Environment: No Fog, Fullbright, FPS Boost.
    ESP dipisah di Modules/ESP.lua.
]]

local Visual = {}

function Visual.Init(ctx)
    local Tabs = ctx.Tabs
    local notify = ctx.Utils.notify
    local Lighting = ctx.Services.Lighting

    local V = {}

    local FogBox = Tabs.Visuals:AddLeftGroupbox("Environment")
    -- ESP groupbox dibuat di module ESP supaya urutan kolom tetap sama
    ctx.Boxes = ctx.Boxes or {}
    ctx.Boxes.FogBox = FogBox

    -- ---------- No Fog ----------
    local NoFogEnabled = false
    local savedFogEnd, savedFogStart

    local function applyNoFog()
        savedFogEnd = savedFogEnd or Lighting.FogEnd
        savedFogStart = savedFogStart or Lighting.FogStart
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    end
    local function restoreFog()
        if savedFogEnd then Lighting.FogEnd = savedFogEnd end
        if savedFogStart then Lighting.FogStart = savedFogStart end
    end

    -- Beberapa game re-apply fog terus-terusan, jadi kita ikut re-apply
    Lighting.Changed:Connect(function(prop)
        if NoFogEnabled and (prop == "FogEnd" or prop == "FogStart") then
            applyNoFog()
        end
    end)

    FogBox:AddToggle("no_fog", {
        Text = "No Fog",
        Default = false,
        Callback = function(v)
            NoFogEnabled = v
            if v then applyNoFog() else restoreFog() end
        end,
    })

    -- ---------- Fullbright ----------
    local FullbrightOn = false
    local savedLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows = Lighting.GlobalShadows,
    }
    local function applyFullbright()
        pcall(function()
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
            Lighting.GlobalShadows = false
        end)
    end
    FogBox:AddToggle("fullbright", {
        Text = "Fullbright",
        Default = false,
        Callback = function(v)
            FullbrightOn = v
            if v then
                applyFullbright()
            else
                pcall(function()
                    for k, val in pairs(savedLighting) do Lighting[k] = val end
                end)
            end
        end,
    })
    task.spawn(function()
        while task.wait(1) do
            if FullbrightOn then applyFullbright() end
        end
    end)

    -- ---------- FPS Boost / Low graphics ----------
    FogBox:AddButton({
        Text = "FPS Boost (Low Graphics)",
        Func = function()
            pcall(function()
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                Lighting.GlobalShadows = false
                Lighting.Technology = Enum.Technology.Compatibility
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Plastic
                        v.Reflectance = 0
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        v.Transparency = 1
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke")
                        or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Explosion") then
                        v.Enabled = false
                    end
                end
            end)
            notify("FPS Boost diterapkan", 3)
        end,
    })

    -- ---------- Post FX / Camera ----------
    local CamBox = Tabs.Visuals:AddLeftGroupbox("Camera & Post FX", "camera")

    CamBox:AddToggle("no_postfx", {
        Text = "Disable Post FX (blur, bloom, dll)",
        Default = false,
        Callback = function(v)
            pcall(function()
                for _, fx in ipairs(Lighting:GetDescendants()) do
                    if fx:IsA("BlurEffect") or fx:IsA("BloomEffect") or fx:IsA("SunRaysEffect")
                        or fx:IsA("ColorCorrectionEffect") or fx:IsA("DepthOfFieldEffect") then
                        fx.Enabled = not v
                    end
                end
            end)
        end,
    })

    CamBox:AddToggle("no_shadows", {
        Text = "No Shadows",
        Default = false,
        Callback = function(v)
            pcall(function() Lighting.GlobalShadows = not v end)
        end,
    })

    CamBox:AddSlider("cam_fov", {
        Text = "Camera FOV",
        Default = 70, Min = 30, Max = 120, Rounding = 0,
        Callback = function(v)
            pcall(function() workspace.CurrentCamera.FieldOfView = v end)
        end,
    })

    CamBox:AddSlider("clock_time", {
        Text = "Time of Day",
        Default = 14, Min = 0, Max = 24, Rounding = 1,
        Callback = function(v)
            pcall(function() Lighting.ClockTime = v end)
        end,
    })

    CamBox:AddSlider("zoom_distance", {
        Text = "Max Zoom Distance",
        Default = 128, Min = 10, Max = 2000, Rounding = 0,
        Callback = function(v)
            pcall(function() ctx.Services.LocalPlayer.CameraMaxZoomDistance = v end)
        end,
    })

    -- ---------- World ----------
    local WorldBox = Tabs.Visuals:AddLeftGroupbox("World", "globe")

    WorldBox:AddToggle("no_sky", {
        Text = "Clear Sky (hapus skybox custom)",
        Default = false,
        Callback = function(v)
            pcall(function()
                for _, sky in ipairs(Lighting:GetChildren()) do
                    if sky:IsA("Sky") then sky.Parent = v and nil or sky.Parent end
                end
            end)
        end,
    })

    WorldBox:AddToggle("xray", {
        Text = "X-Ray (dinding transparan)",
        Default = false,
        Callback = function(v)
            pcall(function()
                for _, part in ipairs(workspace:GetDescendants()) do
                    if part:IsA("BasePart") and not part:IsDescendantOf(ctx.Services.Players) then
                        local isChar = false
                        for _, pl in ipairs(ctx.Services.Players:GetPlayers()) do
                            if pl.Character and part:IsDescendantOf(pl.Character) then isChar = true; break end
                        end
                        if not isChar then
                            if v then
                                part:SetAttribute("NHOldTrans", part.Transparency)
                                part.Transparency = 0.6
                            else
                                local old = part:GetAttribute("NHOldTrans")
                                if old then part.Transparency = old end
                            end
                        end
                    end
                end
            end)
        end,
    })

    WorldBox:AddButton({
        Text = "Remove Textures & Decals",
        Func = function()
            pcall(function()
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("Decal") or v:IsA("Texture") then v:Destroy() end
                end
            end)
            notify("Texture & decal dihapus", 2)
        end,
    })

    return V
end

return Visual

end

_NH_MODULES['ESP'] = function()
--[[
    Modules/ESP.lua
    ESP berbasis Drawing API (box/tracer/name/distance/health) + Chams (Highlight).
    Semua Drawing dibuat lewat Utils.newDraw -> bisa nil di executor tanpa Drawing,
    jadi setiap akses harus tetap dicek nil.
]]

local ESPModule = {}

function ESPModule.Init(ctx)
    local Tabs = ctx.Tabs
    local Utils = ctx.Utils
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer
    local RunService = ctx.Services.RunService

    local M = {}

    local ESPBox = Tabs.Visuals:AddRightGroupbox("ESP")

    local ESP = {
        Box = false, Tracer = false, Name = false, Distance = false,
        Health = false, Chams = false, TeamCheck = false,
        Color = Color3.fromRGB(255, 60, 60),
    }
    local ESPCache = {}  -- [player] = { drawings..., highlight }

    local Camera = workspace.CurrentCamera
    local newDraw = Utils.newDraw

    local function createESP(plr)
        if ESPCache[plr] then return ESPCache[plr] end
        local box = newDraw("Square", {
            Thickness = 1, Filled = false, Color = ESP.Color, Transparency = 1, Visible = false,
        })
        local tracer = newDraw("Line", { Thickness = 1, Color = ESP.Color, Transparency = 1, Visible = false })
        local nameT  = newDraw("Text", { Size = 14, Center = true, Outline = true, Color = ESP.Color, Visible = false })
        local distT  = newDraw("Text", { Size = 13, Center = true, Outline = true, Color = ESP.Color, Visible = false })
        local hpT    = newDraw("Text", { Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(0,255,0), Visible = false })

        local highlight = Instance.new("Highlight")
        highlight.Name = "NHESPChams"
        highlight.FillColor = ESP.Color
        highlight.OutlineColor = ESP.Color
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Enabled = false
        highlight.Parent = plr.Character

        -- Highlight kehilangan parent tiap respawn -> re-parent
        plr.CharacterAdded:Connect(function(char)
            task.wait(0.3)
            if highlight and highlight.Parent == nil then
                highlight.Parent = char
            end
        end)

        ESPCache[plr] = { box = box, tracer = tracer, name = nameT, dist = distT, hp = hpT, highlight = highlight }
        return ESPCache[plr]
    end

    local function destroyESP(plr)
        local e = ESPCache[plr]
        if not e then return end
        for _, k in ipairs({"box","tracer","name","dist","hp"}) do
            if e[k] then pcall(function() e[k]:Remove() end) end
        end
        if e.highlight then pcall(function() e.highlight:Destroy() end) end
        ESPCache[plr] = nil
    end

    local function hideESP(e)
        if e.box then e.box.Visible = false end
        if e.tracer then e.tracer.Visible = false end
        if e.name then e.name.Visible = false end
        if e.dist then e.dist.Visible = false end
        if e.hp then e.hp.Visible = false end
        if e.highlight then e.highlight.Enabled = false end
    end

    local ESPAny = function() return ESP.Box or ESP.Tracer or ESP.Name or ESP.Distance or ESP.Health or ESP.Chams end

    RunService.RenderStepped:Connect(function()
        if not ESPAny() then
            for _, e in pairs(ESPCache) do hideESP(e) end
            return
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local e = ESPCache[plr] or createESP(plr)
                if e then
                    local char = plr.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local head = char and char:FindFirstChild("Head")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if not (hrp and head and hum and hum.Health > 0) then
                        hideESP(e)
                    elseif ESP.TeamCheck and plr.Team == LocalPlayer.Team then
                        hideESP(e)
                    else
                        local topPos, topVis = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                        local botPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        if topVis then
                            local h = math.abs(topPos.Y - botPos.Y)
                            local w = h / 2
                            if ESP.Box and e.box then
                                e.box.Size = Vector2.new(w, h)
                                e.box.Position = Vector2.new(topPos.X - w/2, topPos.Y)
                                e.box.Color = ESP.Color
                                e.box.Visible = true
                            elseif e.box then e.box.Visible = false end
                            if ESP.Tracer and e.tracer then
                                e.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                e.tracer.To = Vector2.new(topPos.X, botPos.Y)
                                e.tracer.Color = ESP.Color
                                e.tracer.Visible = true
                            elseif e.tracer then e.tracer.Visible = false end
                            if ESP.Name and e.name then
                                e.name.Text = plr.Name
                                e.name.Position = Vector2.new(topPos.X, topPos.Y - 16)
                                e.name.Color = ESP.Color
                                e.name.Visible = true
                            elseif e.name then e.name.Visible = false end
                            if ESP.Distance and e.dist then
                                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                                e.dist.Text = string.format("[%d m]", math.floor(d))
                                e.dist.Position = Vector2.new(topPos.X, botPos.Y + 2)
                                e.dist.Color = ESP.Color
                                e.dist.Visible = true
                            elseif e.dist then e.dist.Visible = false end
                            if ESP.Health and e.hp then
                                e.hp.Text = string.format("HP %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
                                e.hp.Position = Vector2.new(topPos.X, botPos.Y + 16)
                                e.hp.Visible = true
                            elseif e.hp then e.hp.Visible = false end
                            if ESP.Chams and e.highlight then
                                e.highlight.FillColor = ESP.Color
                                e.highlight.OutlineColor = ESP.Color
                                if e.highlight.Parent == nil then e.highlight.Parent = char end
                                e.highlight.Enabled = true
                            elseif e.highlight then e.highlight.Enabled = false end
                        else
                            hideESP(e)
                        end
                    end
                end
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(p) destroyESP(p) end)

    ESPBox:AddToggle("esp_box",     { Text = "Box",      Default = false, Callback = function(v) ESP.Box = v end })
    ESPBox:AddToggle("esp_tracer",  { Text = "Tracer",   Default = false, Callback = function(v) ESP.Tracer = v end })
    ESPBox:AddToggle("esp_name",    { Text = "Name",     Default = false, Callback = function(v) ESP.Name = v end })
    ESPBox:AddToggle("esp_dist",    { Text = "Distance", Default = false, Callback = function(v) ESP.Distance = v end })
    ESPBox:AddToggle("esp_hp",      { Text = "Health",   Default = false, Callback = function(v) ESP.Health = v end })
    ESPBox:AddToggle("esp_chams",   { Text = "Chams",    Default = false, Callback = function(v) ESP.Chams = v end })
    ESPBox:AddToggle("esp_team",    { Text = "Team Check (skip teammate)", Default = false, Callback = function(v) ESP.TeamCheck = v end })
    local EspColorLabel = ESPBox:AddLabel("Color:")
    if EspColorLabel and typeof(EspColorLabel.AddColorPicker) == "function" then
        EspColorLabel:AddColorPicker("esp_color", {
            Default = Color3.fromRGB(255, 60, 60),
            Title = "ESP Color",
            Callback = function(c) ESP.Color = c end,
        })
    end

    M.State = ESP

    return M
end

return ESPModule

end

_NH_MODULES['Server'] = function()
--[[
    Modules/Server.lua
    Tab Server: Anti AFK, Auto Rejoin, Rejoin Now, Server Hop (normal / low player).
]]

local Server = {}

function Server.Init(ctx)
    local Tabs = ctx.Tabs
    local notify = ctx.Utils.notify
    local LocalPlayer = ctx.Services.LocalPlayer
    local HttpService = ctx.Services.HttpService
    local TeleportService = ctx.Services.TeleportService
    local GuiService = ctx.Services.GuiService

    local S = {}

    local AFKBox = Tabs.Server:AddLeftGroupbox("Anti AFK & Rejoin")
    local HopBox = Tabs.Server:AddRightGroupbox("Server Hop")

    -- ---------- Anti AFK ----------
    local AntiAFKConn
    AFKBox:AddToggle("anti_afk", {
        Text = "Anti AFK",
        Default = false,
        Callback = function(v)
            if v then
                if AntiAFKConn then AntiAFKConn:Disconnect() end
                AntiAFKConn = LocalPlayer.Idled:Connect(function()
                    local vu = game:GetService("VirtualUser")
                    pcall(function()
                        vu:CaptureController()
                        vu:ClickButton2(Vector2.new())
                    end)
                end)
                notify("Anti AFK ON", 2)
            else
                if AntiAFKConn then AntiAFKConn:Disconnect(); AntiAFKConn = nil end
            end
        end,
    })

    -- ---------- Auto Rejoin ----------
    local AutoRejoinEnabled = false
    AFKBox:AddToggle("auto_rejoin", {
        Text = "Auto Rejoin (on disconnect)",
        Default = false,
        Callback = function(v) AutoRejoinEnabled = v end,
    })

    -- ErrorMessageChanged = indikator paling reliable untuk disconnect prompt
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if AutoRejoinEnabled and msg and msg ~= "" then
            task.wait(1)
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end
    end)

    AFKBox:AddButton({
        Text = "Rejoin Now",
        Func = function()
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end,
    })

    -- ---------- Server Hop ----------
    -- lowPlayer = true  -> cari server dengan player paling sedikit (max 10 page)
    -- lowPlayer = false -> hop ke server pertama yang belum full
    local function serverHopFiltered(lowPlayer)
        local cursor = ""
        for _ = 1, 10 do
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
                .. "/servers/Public?sortOrder=Asc&limit=100"
            if cursor ~= "" then url = url .. "&cursor=" .. cursor end
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(url))
            end)
            if not ok or not res or not res.data then break end
            local best
            for _, s in ipairs(res.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    if lowPlayer then
                        if not best or s.playing < best.playing then best = s end
                    else
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        end)
                        return
                    end
                end
            end
            if lowPlayer and best then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
                return
            end
            cursor = res.nextPageCursor or ""
            if cursor == "" then break end
        end
        notify("Gagal cari server", 3)
    end

    HopBox:AddButton({
        Text = "Server Hop",
        Func = function() serverHopFiltered(false) end,
    })
    HopBox:AddButton({
        Text = "Server Hop (Low Player)",
        Func = function() serverHopFiltered(true) end,
    })

    -- ---------- Server Hop tambahan ----------
    HopBox:AddButton({
        Text = "Server Hop (Random)",
        Func = function()
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. game.PlaceId
                    .. "/servers/Public?sortOrder=Desc&limit=100"))
            end)
            if not ok or not res or not res.data or #res.data == 0 then
                notify("Gagal ambil list server", 3); return
            end
            local pool = {}
            for _, sv in ipairs(res.data) do
                if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then pool[#pool + 1] = sv end
            end
            if #pool == 0 then notify("Tidak ada server kosong", 3); return end
            local pick = pool[math.random(1, #pool)]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer)
            end)
        end,
    })

    local AutoHop = false
    local AutoHopDelay = 120
    HopBox:AddToggle("auto_hop", {
        Text = "Auto Server Hop (timer)",
        Default = false,
        Callback = function(v) AutoHop = v end,
    })
    HopBox:AddSlider("auto_hop_delay", {
        Text = "Auto Hop Delay",
        Default = 120, Min = 30, Max = 900, Rounding = 0, Suffix = "s",
        Callback = function(v) AutoHopDelay = v end,
    })
    task.spawn(function()
        local t = 0
        while task.wait(1) do
            if AutoHop then
                t = t + 1
                if t >= AutoHopDelay then
                    t = 0
                    serverHopFiltered(true)
                end
            else
                t = 0
            end
        end
    end)

    -- ---------- Utilities ----------
    local UtilBox = Tabs.Server:AddLeftGroupbox("Server Utilities", "server-cog")

    UtilBox:AddButton({
        Text = "Copy JobId",
        Func = function()
            if setclipboard then setclipboard(tostring(game.JobId)) end
            notify("JobId dicopy", 2)
        end,
    }):AddButton({
        Text = "Copy Join Script",
        Func = function()
            local txt = string.format(
                'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)',
                game.PlaceId, tostring(game.JobId))
            if setclipboard then setclipboard(txt) end
            notify("Join script dicopy", 2)
        end,
    })

    UtilBox:AddButton({
        Text = "Copy PlaceId",
        Func = function()
            if setclipboard then setclipboard(tostring(game.PlaceId)) end
            notify("PlaceId dicopy", 2)
        end,
    }):AddButton({
        Text = "Leave Game",
        Func = function() pcall(function() LocalPlayer:Kick("Left via Nekomaru Hub") end) end,
    })

    -- Join server by JobId (buat balik ke server temen)
    local JobInput = UtilBox:AddInput("join_jobid", {
        Text = "JobId",
        Default = "",
        Placeholder = "paste JobId di sini",
        Numeric = false,
        Finished = false,
    })
    UtilBox:AddButton({
        Text = "Join by JobId",
        Func = function()
            local id = JobInput and JobInput.Value
            if not id or id == "" then notify("JobId kosong", 2); return end
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
            end)
        end,
    })

    -- Rejoin otomatis kalau player count di bawah/di atas batas tertentu
    local AutoLeaveFull = false
    UtilBox:AddToggle("auto_leave_full", {
        Text = "Auto Hop kalau server hampir full",
        Default = false,
        Callback = function(v) AutoLeaveFull = v end,
    })
    task.spawn(function()
        local Players = ctx.Services.Players
        while task.wait(5) do
            if AutoLeaveFull and Players.MaxPlayers > 0 then
                if #Players:GetPlayers() >= (Players.MaxPlayers - 1) then
                    notify("Server hampir full, hop...", 3)
                    serverHopFiltered(true)
                end
            end
        end
    end)

    S.serverHopFiltered = serverHopFiltered

    return S
end

return Server

end

_NH_MODULES['Aimbot'] = function()
--[[
    Modules/Aimbot.lua
    Aimlock + FOV circle. Target dipilih tiap frame berdasarkan jarak ke crosshair.
    Hitbox Expander dipisah ke Modules/Hitbox.lua tapi share Utils.isFriendly.
]]

local Aimbot = {}

function Aimbot.Init(ctx)
    local Tabs = ctx.Tabs
    local Utils = ctx.Utils
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer
    local RunService = ctx.Services.RunService
    local UserInputService = ctx.Services.UserInputService

    local Aim = {
        Enabled = false,
        Part = "HumanoidRootPart",
        TeamCheck = false,
        VisibleCheck = false,
        Smoothness = 0,
        UseFOV = true,
        FOV = 120,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 60, 60),
        Prediction = false,
        HoldKey = false,
        MaxDistance = 1000,
        Target = nil,
    }

    local AimCam = workspace.CurrentCamera

    local AimLeft  = Tabs.AutoAim:AddLeftGroupbox("Aimlock", "crosshair")
    local AimRight = Tabs.AutoAim:AddRightGroupbox("Aim FOV", "circle")

    -- ---------- FOV circle ----------
    local FOVCircle = Utils.newDraw("Circle", {
        Thickness = 1,
        NumSides = 60,
        Filled = false,
        Visible = false,
        Transparency = 1,
        Color = Aim.FOVColor,
        Radius = Aim.FOV,
    })

    local isFriendly = Utils.isFriendly

    local function getAimPart(char)
        if not char then return nil end
        local wanted = Aim.Part
        if wanted == "Torso" then
            return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
        end
        return char:FindFirstChild(wanted) or char:FindFirstChild("HumanoidRootPart")
    end

    local function isVisible(part)
        if not Aim.VisibleCheck then return true end
        local ok, res = pcall(function()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { LocalPlayer.Character, part.Parent }
            local origin = AimCam.CFrame.Position
            return workspace:Raycast(origin, part.Position - origin, params)
        end)
        if not ok then return true end
        return res == nil
    end

    local function getClosestTarget()
        local best, bestDist = nil, math.huge
        local center = Vector2.new(AimCam.ViewportSize.X / 2, AimCam.ViewportSize.Y / 2)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local part = getAimPart(char)
                if char and hum and hum.Health > 0 and part then
                    local skip = false
                    if Aim.TeamCheck and isFriendly(plr) then skip = true end
                    if not skip then
                        local sp, on = AimCam:WorldToViewportPoint(part.Position)
                        local dist3d = (AimCam.CFrame.Position - part.Position).Magnitude
                        if on and dist3d <= Aim.MaxDistance then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if (not Aim.UseFOV or d <= Aim.FOV) and d < bestDist and isVisible(part) then
                                best, bestDist = plr, d
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local aimHeld = false
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = false end
    end)

    RunService.RenderStepped:Connect(function()
        AimCam = workspace.CurrentCamera
        if FOVCircle then
            FOVCircle.Visible = Aim.ShowFOV and Aim.Enabled and Aim.UseFOV
            FOVCircle.Radius = Aim.FOV
            FOVCircle.Color = Aim.FOVColor
            local vp = AimCam and AimCam.ViewportSize or Vector2.new(0, 0)
            FOVCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        end

        if not Aim.Enabled then Aim.Target = nil; return end
        if Aim.HoldKey and not aimHeld then Aim.Target = nil; return end

        local target = getClosestTarget()
        Aim.Target = target
        if not target then return end
        local part = getAimPart(target.Character)
        if not part then return end

        local aimPos = part.Position
        if Aim.Prediction then
            aimPos = aimPos + part.Velocity * 0.08
        end

        local goal = CFrame.new(AimCam.CFrame.Position, aimPos)
        if Aim.Smoothness > 0 then
            AimCam.CFrame = AimCam.CFrame:Lerp(goal, math.clamp(1 - (Aim.Smoothness / 100), 0.02, 1))
        else
            AimCam.CFrame = goal
        end
    end)

    AimLeft:AddToggle("aim_enabled", {
        Text = "Aimlock",
        Default = false,
        Callback = function(v) Aim.Enabled = v end,
    })
    AimLeft:AddToggle("aim_hold", {
        Text = "Hold Right Mouse (kalau off = always on)",
        Default = false,
        Callback = function(v) Aim.HoldKey = v end,
    })
    AimLeft:AddDropdown("aim_part", {
        Values = { "Head", "HumanoidRootPart", "Torso", "LeftHand", "RightHand", "LeftFoot", "RightFoot" },
        Default = 2,
        Multi = false,
        Text = "Aim Part",
        Callback = function(v) Aim.Part = v end,
    })
    AimLeft:AddToggle("aim_team", {
        Text = "Team Check (skip teammate)",
        Default = false,
        Callback = function(v) Aim.TeamCheck = v end,
    })
    AimLeft:AddToggle("aim_wall", {
        Text = "Visible Check (wall check)",
        Default = false,
        Callback = function(v) Aim.VisibleCheck = v end,
    })
    AimLeft:AddToggle("aim_pred", {
        Text = "Prediction (target gerak)",
        Default = false,
        Callback = function(v) Aim.Prediction = v end,
    })
    AimLeft:AddSlider("aim_smooth", {
        Text = "Smoothness",
        Default = 0, Min = 0, Max = 95, Rounding = 0, Suffix = "%",
        Callback = function(v) Aim.Smoothness = v end,
    })
    AimLeft:AddSlider("aim_maxdist", {
        Text = "Max Distance",
        Default = 1000, Min = 50, Max = 5000, Rounding = 0,
        Callback = function(v) Aim.MaxDistance = v end,
    })

    AimRight:AddToggle("aim_usefov", {
        Text = "Gunakan FOV (cuma target di dalam lingkaran)",
        Default = true,
        Callback = function(v) Aim.UseFOV = v end,
    })
    AimRight:AddToggle("aim_showfov", {
        Text = "Tampilkan lingkaran FOV",
        Default = true,
        Callback = function(v) Aim.ShowFOV = v end,
    })
    AimRight:AddSlider("aim_fov", {
        Text = "FOV Radius",
        Default = 120, Min = 20, Max = 600, Rounding = 0,
        Callback = function(v) Aim.FOV = v end,
    })
    pcall(function()
        AimRight:AddLabel("FOV Color"):AddColorPicker("aim_fov_color", {
            Default = Color3.fromRGB(255, 60, 60),
            Title = "FOV Color",
            Callback = function(c) Aim.FOVColor = c end,
        })
    end)
    AimRight:AddLabel("Target: -", true)

    return { State = Aim }
end

return Aimbot

end

_NH_MODULES['Hitbox'] = function()
--[[
    Modules/Hitbox.lua
    Hitbox Expander. HitboxOrig menyimpan properti asli tiap part supaya
    bisa direstore penuh ketika toggle dimatikan.
]]

local Hitbox = {}

function Hitbox.Init(ctx)
    local Tabs = ctx.Tabs
    local Utils = ctx.Utils
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer
    local isFriendly = Utils.isFriendly

    local HitboxCfg = {
        Enabled = false,
        Parts = { HumanoidRootPart = true, Head = false, Torso = false, Arms = false, Legs = false },
        Size = 10,
        Transparency = 0.7,
        TeamCheck = false,
        ShowHitbox = true,
    }

    local HitBox = Tabs.AutoAim:AddLeftGroupbox("Hitbox Expander", "box")

    local HitboxOrig = {}   -- [part] = {Size, Transparency, CanCollide, Massless}

    local function partList()
        local list = {}
        if HitboxCfg.Parts.HumanoidRootPart then table.insert(list, "HumanoidRootPart") end
        if HitboxCfg.Parts.Head then table.insert(list, "Head") end
        if HitboxCfg.Parts.Torso then
            table.insert(list, "UpperTorso"); table.insert(list, "LowerTorso"); table.insert(list, "Torso")
        end
        if HitboxCfg.Parts.Arms then
            for _, n in ipairs({"LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","Left Arm","Right Arm"}) do
                table.insert(list, n)
            end
        end
        if HitboxCfg.Parts.Legs then
            for _, n in ipairs({"LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","Left Leg","Right Leg"}) do
                table.insert(list, n)
            end
        end
        return list
    end

    local function restoreHitbox(part)
        local o = HitboxOrig[part]
        if not o then return end
        pcall(function()
            part.Size = o.Size
            part.Transparency = o.Transparency
            part.CanCollide = o.CanCollide
            part.Massless = o.Massless
        end)
        HitboxOrig[part] = nil
    end

    local function restoreAllHitbox()
        for part in pairs(HitboxOrig) do
            restoreHitbox(part)
        end
    end

    task.spawn(function()
        while task.wait(0.2) do
            if not HitboxCfg.Enabled then
                if next(HitboxOrig) then restoreAllHitbox() end
            else
                local names = partList()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        local skip = HitboxCfg.TeamCheck and isFriendly(plr)
                        local char = plr.Character
                        if char and not skip then
                            for _, n in ipairs(names) do
                                local part = char:FindFirstChild(n)
                                if part and part:IsA("BasePart") then
                                    if not HitboxOrig[part] then
                                        HitboxOrig[part] = {
                                            Size = part.Size,
                                            Transparency = part.Transparency,
                                            CanCollide = part.CanCollide,
                                            Massless = part.Massless,
                                        }
                                    end
                                    pcall(function()
                                        part.Size = Vector3.new(HitboxCfg.Size, HitboxCfg.Size, HitboxCfg.Size)
                                        part.Transparency = HitboxCfg.ShowHitbox and HitboxCfg.Transparency or 1
                                        part.CanCollide = false
                                        part.Massless = true
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    HitBox:AddToggle("hb_enabled", {
        Text = "Enable Hitbox Expander",
        Default = false,
        Callback = function(v)
            HitboxCfg.Enabled = v
            if not v then restoreAllHitbox() end
        end,
    })
    HitBox:AddToggle("hb_root", { Text = "HumanoidRootPart", Default = true,  Callback = function(v) HitboxCfg.Parts.HumanoidRootPart = v end })
    HitBox:AddToggle("hb_head", { Text = "Head",             Default = false, Callback = function(v) HitboxCfg.Parts.Head = v end })
    HitBox:AddToggle("hb_torso",{ Text = "Torso",            Default = false, Callback = function(v) HitboxCfg.Parts.Torso = v end })
    HitBox:AddToggle("hb_arms", { Text = "Arms",             Default = false, Callback = function(v) HitboxCfg.Parts.Arms = v end })
    HitBox:AddToggle("hb_legs", { Text = "Legs",             Default = false, Callback = function(v) HitboxCfg.Parts.Legs = v end })
    HitBox:AddSlider("hb_size", {
        Text = "Hitbox Size",
        Default = 10, Min = 1, Max = 60, Rounding = 1,
        Callback = function(v) HitboxCfg.Size = v end,
    })
    HitBox:AddSlider("hb_trans", {
        Text = "Hitbox Transparency",
        Default = 0.7, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) HitboxCfg.Transparency = v end,
    })
    HitBox:AddToggle("hb_show", { Text = "Tampilkan hitbox", Default = true, Callback = function(v) HitboxCfg.ShowHitbox = v end })
    HitBox:AddToggle("hb_team", { Text = "Team Check (skip teammate)", Default = false, Callback = function(v) HitboxCfg.TeamCheck = v end })

    return { State = HitboxCfg, restoreAll = restoreAllHitbox }
end

return Hitbox

end

_NH_MODULES['Alert'] = function()
--[[
    Modules/Alert.lua
    Self Alert: kick / server hop otomatis kalau ada player atau admin di server,
    plus bypass username (whitelist) untuk mode anti-player.
]]

local Alert = {}

function Alert.Init(ctx)
    local Tabs = ctx.Tabs
    local Utils = ctx.Utils
    local notify = Utils.notify
    local Players = ctx.Services.Players
    local LocalPlayer = ctx.Services.LocalPlayer
    local HttpService = ctx.Services.HttpService
    local TeleportService = ctx.Services.TeleportService

    local A = {}

    local AlertBox = Tabs.SelfAlert:AddLeftGroupbox("Self Alert")

    local AlertPlayer = false
    local AlertAdmin = false
    local AlertMethod = "Server Hop" -- or "Kick"
    local AlertTriggered = false

    -- edit sesuai kebutuhan
    local ADMIN_NAMES = {
        -- ["SomeAdmin"] = true,
    }
    local ADMIN_USERIDS = {
        -- [123456] = true,
    }

    local BypassUsernames = {}  -- [lowercase name] = true

    local function isBypassed(plr)
        return BypassUsernames[string.lower(plr.Name)] == true
    end

    local function isAdmin(plr)
        if ADMIN_NAMES[plr.Name] then return true end
        if ADMIN_USERIDS[plr.UserId] then return true end
        return false
    end

    local function kickSelf()
        LocalPlayer:Kick("[Nekomaru Hub] Self Alert triggered")
    end

    -- Server hop sederhana untuk alert (ambil server pertama yang belum full)
    local function serverHop()
        local ok, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId ..
                "/servers/Public?sortOrder=Asc&limit=100"
            ))
        end)
        if ok and servers and servers.data then
            for _, s in ipairs(servers.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    end)
                    return
                end
            end
        end
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end

    -- AlertTriggered = guard biar tidak dobel eksekusi dalam satu sesi alert
    local function doAlert(reason)
        if AlertTriggered then return end
        AlertTriggered = true
        notify("Self Alert: " .. reason, 3)
        task.wait(0.1)
        if AlertMethod == "Kick" then kickSelf() else serverHop() end
    end

    local function scanPlayers()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if AlertAdmin and isAdmin(p) then
                    doAlert("Admin detected: " .. p.Name); return
                end
                if AlertPlayer and not isBypassed(p) then
                    doAlert("Player detected: " .. p.Name); return
                end
            end
        end
    end

    Players.PlayerAdded:Connect(function(p)
        task.wait(0.2)
        if AlertAdmin and isAdmin(p) then doAlert("Admin joined: " .. p.Name); return end
        if AlertPlayer and not isBypassed(p) then doAlert("Player joined: " .. p.Name) end
    end)

    AlertBox:AddToggle("alert_player", {
        Text = "Alert kalau ada player biasa",
        Default = false,
        Callback = function(v)
            AlertPlayer = v
            AlertTriggered = false
            if v then scanPlayers() end
        end,
    })

    AlertBox:AddToggle("alert_admin", {
        Text = "Alert kalau ada admin",
        Default = false,
        Callback = function(v)
            AlertAdmin = v
            AlertTriggered = false
            if v then scanPlayers() end
        end,
    })

    AlertBox:AddDropdown("alert_method", {
        Values = { "Server Hop", "Kick" },
        Default = 1,
        Multi = false,
        Text = "Alert method",
        Callback = function(v) AlertMethod = v end,
    })

    -- ============================================================
    -- Bypass Usernames (Anti-Player exception)
    -- ============================================================
    local BypassBox = Tabs.SelfAlert:AddRightGroupbox("Bypass Username (Anti-Player)")

    local BypassDropdown  -- forward
    local function refreshBypassDropdown()
        local list = {}
        for name, _ in pairs(BypassUsernames) do table.insert(list, name) end
        table.sort(list)
        if BypassDropdown then
            BypassDropdown:SetValues(list)
            if #list > 0 then BypassDropdown:SetValue(list[1]) else BypassDropdown:SetValue(nil) end
        end
    end

    local BypassInput = BypassBox:AddInput("bypass_name_input", {
        Default = "",
        Placeholder = "Masukkan username",
        Text = "Username",
    })

    BypassBox:AddButton({
        Text = "Add Username",
        Func = function()
            local name = BypassInput.Value
            if not name or name == "" then notify("Isi username dulu", 2); return end
            BypassUsernames[string.lower(name)] = true
            BypassInput:SetValue("")
            refreshBypassDropdown()
            notify("Bypass ditambahkan: " .. name, 2)
        end,
    }):AddButton({
        Text = "Remove Selected",
        Func = function()
            local sel = BypassDropdown and BypassDropdown.Value
            if not sel or sel == "" then notify("Pilih username dulu", 2); return end
            BypassUsernames[sel] = nil
            refreshBypassDropdown()
            notify("Bypass dihapus: " .. sel, 2)
        end,
    })

    BypassDropdown = BypassBox:AddDropdown("bypass_list", {
        Values = {},
        Default = 1,
        Multi = false,
        Text = "Daftar bypass",
    })

    BypassBox:AddButton({
        Text = "Clear All Bypass",
        Func = function()
            BypassUsernames = {}
            refreshBypassDropdown()
            notify("Semua bypass dihapus", 2)
        end,
    })

    -- ============================================================
    -- Server player-list bypass (refreshable dari server)
    -- ============================================================
    local BypassServerDropdown
    local function refreshBypassServerList()
        local names = Utils.otherPlayerNames()
        if BypassServerDropdown then
            BypassServerDropdown:SetValues(names)
            if #names > 0 then BypassServerDropdown:SetValue(names[1]) else BypassServerDropdown:SetValue(nil) end
        end
    end

    BypassServerDropdown = BypassBox:AddDropdown("bypass_server_list", {
        Values = {},
        Default = 1,
        Multi = false,
        Text = "Player di server",
    })

    BypassBox:AddButton({
        Text = "Refresh Server List",
        Func = function() refreshBypassServerList() end,
    }):AddButton({
        Text = "Add From Server",
        Func = function()
            local sel = BypassServerDropdown and BypassServerDropdown.Value
            if not sel or sel == "" then notify("Pilih player dulu", 2); return end
            BypassUsernames[string.lower(sel)] = true
            refreshBypassDropdown()
            notify("Bypass ditambahkan: " .. sel, 2)
        end,
    })

    A.serverHop = serverHop
    A.isAdmin = isAdmin

    return A
end

return Alert

end

_NH_MODULES['Info'] = function()
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

end

_NH_MODULES['Changelog'] = function()
--[[
    Modules/Changelog.lua
    Tab Changelog: nampilin riwayat versi script (Added / Changed / Removed / Fixed)
    langsung di dalam UI, biar user ga perlu buka file Docs/CHANGELOG.md.

    Cara nambah entri: tambahin table baru di PALING ATAS list VERSIONS.
    Tipe yang didukung: "Added", "Changed", "Removed", "Fixed".
]]

local Changelog = {}

Changelog.Version = "3.5.0"

Changelog.VERSIONS = {
    {
        Version = "3.5.0",
        Date = "2026-08-19",
        Changes = {
            { "Added", "Fly di tab Player dengan 3 method: CFrame Fly, Velocity Fly, Align Fly (+ speed, vertical, keybind F, tombol up/down mobile)" },
            { "Added", "Groupbox Universal / Tools di tab Player: Freeze, Spin, Click Teleport, Sit/Stand, Copy Position" },
            { "Added", "Button Checkpoint Finder (execute script NekoCpFinder_v2 langsung dari executor)" },
            { "Added", "Server: Hop random, Auto Server Hop timer, Auto hop kalau server hampir full, Copy JobId/PlaceId/Join Script, Join by JobId, Leave Game" },
            { "Added", "Visuals: Disable Post FX, No Shadows, Camera FOV, Time of Day, Max Zoom, Clear Sky, X-Ray, Remove Textures" },
            { "Changed", "Tab Teleport diganti nama jadi Main" },
            { "Removed", "Watermark part \"Nekomaru Hub | Teleport Saver\"" },
            { "Removed", "Tab Vehicle + fitur Vehicle Fly" },
        },
    },
    {
        Version = "3.3.0",
        Date = "2026-08-08",
        Changes = {
            { "Added", "Tab Changelog di dalam script (riwayat versi bisa dibaca langsung di UI)" },
            { "Added", "README.md + Docs/CHANGELOG.md di repository" },
            { "Added", "Tombol Copy Changelog & Copy Discord di tab Changelog" },
        },
    },
    {
        Version = "3.2.0",
        Date = "2026-08-01",
        Changes = {
            { "Changed", "Refactor total: single-file dipecah jadi Main.lua + Modules/*.lua" },
            { "Added", "Build/bundle.py buat generate dist/TeleportSaver.lua (single-file Delta)" },
            { "Added", "Docs/ARCHITECTURE.md dan Docs/RULES.md" },
            { "Changed", "Perilaku, fitur, dan UI tidak diubah sama sekali" },
        },
    },
    {
        Version = "3.1.0",
        Date = "2026-07-28",
        Changes = {
            { "Added", "Tab Auto Aim: Aimlock, smoothness, prediction, wall check, team check" },
            { "Added", "FOV circle (POV lingkaran) dengan radius & warna custom" },
            { "Added", "Hitbox Expander: HRP, Head, Torso, Arms, Legs + size & transparency" },
            { "Added", "Fullbright, FPS Boost (low graphics)" },
            { "Added", "Anti-Fling, Anti-Void, Anti-Fall Damage, Reset Character/Camera" },
            { "Removed", "Leaderboard di tab Info" },
            { "Changed", "Discord jadi satu tombol Join Discord (auto copy link)" },
        },
    },
    {
        Version = "3.0.0",
        Date = "2026-07-27",
        Changes = {
            { "Added", "Tab Info: player info, server info, community" },
            { "Added", "GuiService:SetGameplayPausedNotificationEnabled(false)" },
            { "Fixed", "Script gagal execute: goto/::continue:: dihapus (ga didukung Luau)" },
            { "Fixed", "Pemanggilan API Obsidian yang salah (CreateKeyTab / CreateGroupbox)" },
            { "Fixed", "Nil-guard buat executor tanpa Drawing API" },
        },
    },
    {
        Version = "2.0.0",
        Date = "2026-07-26",
        Changes = {
            { "Added", "Config manager: create, load, delete, refresh config lewat filesystem Delta" },
            { "Added", "26 default checkpoint (Nekomaru default)" },
            { "Added", "ESP, Movement (speed/jump), Vehicle Fly, Rejoin" },
        },
    },
    {
        Version = "1.0.0",
        Date = "2026-07-25",
        Changes = {
            { "Added", "Save checkpoint (auto nama Cp 1, Cp 2, ...) + teleport manual" },
            { "Added", "Play / Pause / Stop playback checkpoint" },
            { "Added", "Delay slider 0.5 - 3 detik dan toggle Loop" },
            { "Added", "Self Alert: deteksi player biasa & admin, method Kick atau Server Hop" },
            { "Added", "UI Obsidian dengan tab Teleport, Self Alert, Settings" },
        },
    },
}

function Changelog.ToText()
    local lines = { "Teleport Saver by Nekomaru Hub - Changelog" }
    for _, v in ipairs(Changelog.VERSIONS) do
        table.insert(lines, "")
        table.insert(lines, "v" .. v.Version .. " (" .. v.Date .. ")")
        for _, c in ipairs(v.Changes) do
            table.insert(lines, "  [" .. c[1] .. "] " .. c[2])
        end
    end
    return table.concat(lines, "\n")
end

function Changelog.Init(ctx)
    local Tabs = ctx.Tabs
    local notify = ctx.Utils.notify

    local COMMUNITY_URL = "https://posronda.my.id/discord"

    local LatestBox = Tabs.Changelog:AddLeftGroupbox("Latest", "sparkles")
    local HistoryBox = Tabs.Changelog:AddRightGroupbox("History", "history")

    local latest = Changelog.VERSIONS[1]
    if latest then
        LatestBox:AddLabel("Version: v" .. latest.Version, true)
        LatestBox:AddLabel("Date: " .. latest.Date, true)
        LatestBox:AddDivider()
        for _, c in ipairs(latest.Changes) do
            LatestBox:AddLabel("[" .. c[1] .. "] " .. c[2], true)
        end
    end

    LatestBox:AddDivider()
    LatestBox:AddButton({
        Text = "Copy Full Changelog",
        Func = function()
            local text = Changelog.ToText()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, text)
                notify("Changelog disalin ke clipboard", 3)
            else
                notify("Executor tidak support setclipboard", 3)
            end
        end,
    })
    LatestBox:AddButton({
        Text = "Join Discord (copy link)",
        Func = function()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, COMMUNITY_URL)
                notify("Link discord disalin: " .. COMMUNITY_URL, 3)
            else
                notify(COMMUNITY_URL, 5)
            end
        end,
    })

    for i, v in ipairs(Changelog.VERSIONS) do
        if i > 1 then
            HistoryBox:AddLabel("v" .. v.Version .. "  (" .. v.Date .. ")", true)
            for _, c in ipairs(v.Changes) do
                HistoryBox:AddLabel("  [" .. c[1] .. "] " .. c[2], true)
            end
            HistoryBox:AddDivider()
        end
    end

    return Changelog
end

return Changelog

end

_NH_MODULES['Settings'] = function()
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

    -- Watermark part "Nekomaru Hub | Teleport Saver" dimatikan (permintaan user)
    safeMethod(Library, "SetWatermarkVisibility", false)

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

end

--[[
    Main.lua — Teleport Saver by Nekomaru Hub
    Entry point. Tugasnya cuma: load Obsidian, bikin Context, lalu Init tiap module
    dengan URUTAN yang tidak boleh diubah (urutan = urutan groupbox di UI).

    Cara require module:
      - Kalau dibundle jadi 1 file (Build/bundle.lua -> dist/TeleportSaver.lua),
        module sudah terdaftar di _NH_MODULES.
      - Kalau dijalanin dari file terpisah, fallback ke readfile("Modules/<Name>.lua").
]]

local REPO_ROOT = "NekomaruHub/TeleportSaver/Repo"

local function nhRequire(name)
    local reg = rawget(_G, "_NH_MODULES")
    if reg and reg[name] then
        local m = reg[name]
        if type(m) == "function" then
            local res = m()
            reg[name] = res
            return res
        end
        return m
    end
    -- fallback: baca dari filesystem executor
    local path = REPO_ROOT .. "/Modules/" .. name .. ".lua"
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(path) then
        local chunk = loadstring(readfile(path), name)
        if chunk then return chunk() end
    end
    error("[Nekomaru Hub] Module tidak ditemukan: " .. tostring(name))
end

-- ============================================================
-- Load Obsidian (Library / ThemeManager / SaveManager)
-- ============================================================
local BASE = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local function loadRemote(url, label)
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if not ok or type(src) ~= "string" or #src < 100 then
        warn("[Nekomaru Hub] Gagal download " .. label)
        return nil
    end
    local chunk, err = loadstring(src, label)
    if not chunk then
        warn("[Nekomaru Hub] Syntax error " .. label .. ": " .. tostring(err))
        return nil
    end
    local ok2, res = pcall(chunk)
    if not ok2 then
        warn("[Nekomaru Hub] Runtime error " .. label .. ": " .. tostring(res))
        return nil
    end
    return res
end

local Library      = loadRemote(BASE .. "Library.lua", "Obsidian Library")
if not Library then
    error("[Nekomaru Hub] Obsidian Library gagal diload, cek koneksi / executor.")
end
local ThemeManager = loadRemote(BASE .. "addons/ThemeManager.lua", "ThemeManager")
local SaveManager  = loadRemote(BASE .. "addons/SaveManager.lua", "SaveManager")

-- ============================================================
-- Context
-- ============================================================
local ctx = {}
ctx.Library      = Library
ctx.ThemeManager = ThemeManager
ctx.SaveManager  = SaveManager

ctx.Services = nhRequire("Services").Init()
ctx.Utils    = nhRequire("Utils").Init(ctx)

local ui = nhRequire("UI").Init(ctx)
ctx.Window = ui.Window
ctx.Tabs   = ui.Tabs

ctx.DefaultCheckpoints = nhRequire("DefaultCheckpoints")
ctx.Config   = nhRequire("Config").Init(ctx)

-- URUTAN INIT — jangan diacak, ini yang menentukan posisi groupbox.
ctx.Teleport = nhRequire("Teleport").Init(ctx)
ctx.Player   = nhRequire("Player").Init(ctx)
ctx.Visual   = nhRequire("Visual").Init(ctx)
ctx.ESP      = nhRequire("ESP").Init(ctx)
ctx.Server   = nhRequire("Server").Init(ctx)
ctx.Aimbot   = nhRequire("Aimbot").Init(ctx)
ctx.Hitbox   = nhRequire("Hitbox").Init(ctx)
ctx.Alert    = nhRequire("Alert").Init(ctx)
ctx.Info      = nhRequire("Info").Init(ctx)
ctx.Changelog = nhRequire("Changelog").Init(ctx)
ctx.Settings = nhRequire("Settings").Init(ctx)

-- Bootstrap terakhir (config dropdown + default checkpoints + notify)
ctx.Teleport.Bootstrap()

return ctx
