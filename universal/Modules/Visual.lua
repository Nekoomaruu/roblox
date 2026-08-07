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

    return V
end

return Visual
