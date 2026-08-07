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
