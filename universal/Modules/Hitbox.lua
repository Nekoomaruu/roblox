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
