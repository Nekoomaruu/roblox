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
