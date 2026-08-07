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
            teleportTo(Checkpoints[idx])
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
        if msg then notify(msg, 2) end
    end

    -- Playback loop: pause dicek di dua titik (sebelum TP dan saat delay)
    -- supaya pause terasa instan tanpa mematikan thread.
    local function runPlayback()
        if #Checkpoints == 0 then notify("Belum ada checkpoint", 3); return end
        Playing = true
        Paused = false
        PlayThread = task.spawn(function()
            local completed = 0
            while Playing do
                for _, cp in ipairs(Checkpoints) do
                    if not Playing then return end
                    while Paused and Playing do task.wait(0.1) end
                    if not Playing then return end
                    teleportTo(cp)
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
            if not Playing then notify("Belum play", 2); return end
            stopPlayback("Stopped")
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
