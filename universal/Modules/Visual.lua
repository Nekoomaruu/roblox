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
