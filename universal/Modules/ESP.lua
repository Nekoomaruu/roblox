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
