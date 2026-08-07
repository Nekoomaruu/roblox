--[[
    Modules/Vehicle.lua
    Vehicle Fly: attach BodyVelocity + BodyGyro ke part vehicle yang lu duduki.
]]

local Vehicle = {}

function Vehicle.Init(ctx)
    local Tabs = ctx.Tabs
    local notify = ctx.Utils.notify
    local LocalPlayer = ctx.Services.LocalPlayer
    local RunService = ctx.Services.RunService
    local UserInputService = ctx.Services.UserInputService

    local V = {}

    local VehBox = Tabs.Vehicle:AddLeftGroupbox("Vehicle Fly")

    local VFlyEnabled = false
    local VFlySpeed   = 100
    local VFlyConn, VFlyBV, VFlyBG, VFlyTarget

    local function findSeatVehicle()
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if not seat then return nil end
        -- naik ke atas ke assembly root (biasanya PrimaryPart / body)
        local model = seat:FindFirstAncestorOfClass("Model")
        if model and model.PrimaryPart then return model.PrimaryPart end
        return seat.AssemblyRootPart or seat
    end

    local function stopVFly()
        if VFlyConn then VFlyConn:Disconnect(); VFlyConn = nil end
        if VFlyBV then VFlyBV:Destroy(); VFlyBV = nil end
        if VFlyBG then VFlyBG:Destroy(); VFlyBG = nil end
        VFlyTarget = nil
    end

    local function startVFly()
        stopVFly()
        local part = findSeatVehicle()
        if not part then notify("Lu belum duduk di vehicle", 3); return end
        VFlyTarget = part
        VFlyBV = Instance.new("BodyVelocity")
        VFlyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        VFlyBV.Velocity = Vector3.zero
        VFlyBV.Parent = part
        VFlyBG = Instance.new("BodyGyro")
        VFlyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        VFlyBG.P = 5000
        VFlyBG.D = 500
        VFlyBG.CFrame = part.CFrame
        VFlyBG.Parent = part

        VFlyConn = RunService.RenderStepped:Connect(function()
            if not VFlyEnabled or not VFlyTarget or not VFlyTarget.Parent then
                stopVFly(); return
            end
            local cam = workspace.CurrentCamera
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
            if dir.Magnitude > 0 then dir = dir.Unit end
            VFlyBV.Velocity = dir * VFlySpeed
            VFlyBG.CFrame = CFrame.new(VFlyTarget.Position, VFlyTarget.Position + cam.CFrame.LookVector)
        end)
    end

    VehBox:AddToggle("vfly_toggle", {
        Text = "Vehicle Fly (WASD + Space/Ctrl)",
        Default = false,
        Callback = function(v)
            VFlyEnabled = v
            if v then startVFly() else stopVFly() end
        end,
    })
    VehBox:AddSlider("vfly_speed", {
        Text = "Speed",
        Default = 100, Min = 20, Max = 1000, Rounding = 0,
        Callback = function(v) VFlySpeed = v end,
    })
    VehBox:AddButton({
        Text = "Re-attach ke vehicle",
        Func = function() if VFlyEnabled then startVFly() end end,
    })

    V.start = startVFly
    V.stop = stopVFly

    return V
end

return Vehicle
