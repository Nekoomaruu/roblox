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
