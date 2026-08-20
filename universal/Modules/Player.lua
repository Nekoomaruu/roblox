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
