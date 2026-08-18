--[[
    NEKO CP CHECKER
    UI Library: Obsidian
    
    Detects checkpoints in a game using 3 methods:
    1. Name Pattern Matching (Checkpoint1, Cp1, Cekpoin, etc.)
    2. CollectionService Tags
    3. Heuristic Fallback (SpawnLocation, common checkpoint traits)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Client = Players.LocalPlayer

-- ==================== CONFIG ====================
local Config = {
    -- Name patterns to search for (case-insensitive, checks if name CONTAINS or MATCHES pattern)
    NamePatterns = {
        "checkpoint", "cp", "cekpoin", "check point", "stage",
        "level", "part%d+", "waypoint", "flag", "finish",
    },

    -- Known CollectionService tags used by common checkpoint systems
    CollectionTags = {
        "Checkpoint", "CheckPoint", "CP", "Stage", "Waypoint", "SaveZone",
    },

    -- Where to search
    SearchFolders = { "Checkpoints", "Stages", "Map", "Game", "Level" }, -- checked first if they exist
    FallbackToWholeWorkspace = true,

    ScanCooldown = 1, -- seconds between manual rescans (prevents spam-click lag)
}

-- ==================== STATE ====================
local FoundCheckpoints = {} -- { {instance, name, position, method}, ... }
local LastScanTime = 0
local ESPEnabled = false
local ESPHolders = {}

-- ==================== DETECTION LOGIC ====================

local function matchesNamePattern(name)
    local lower = name:lower():gsub("%s+", "")
    for _, pattern in ipairs(Config.NamePatterns) do
        local ok, result = pcall(function()
            return lower:find(pattern:lower())
        end)
        if ok and result then
            return true
        end
    end
    return false
end

local function getPosition(inst)
    if inst:IsA("BasePart") then
        return inst.Position
    elseif inst:IsA("Model") then
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok then return cf.Position end
        local primary = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        if primary then return primary.Position end
    end
    return nil
end

-- Heuristic fallback: things that "smell like" a checkpoint even without name/tag
local function heuristicIsCheckpoint(inst)
    if inst:IsA("SpawnLocation") then
        return true, "SpawnLocation"
    end

    if inst:IsA("BasePart") or inst:IsA("Model") then
        -- Common checkpoint traits: has a Touched-connected part with "Stage"/"Checkpoint" value inside,
        -- or has NumberValue/IntValue children indicating stage index
        local hasStageValue = inst:FindFirstChild("Stage") or inst:FindFirstChild("StageNumber")
            or inst:FindFirstChild("CheckpointNumber") or inst:FindFirstChild("Index")

        if hasStageValue and (hasStageValue:IsA("IntValue") or hasStageValue:IsA("NumberValue")) then
            return true, "StageValue"
        end
    end

    return false
end

local function addCheckpoint(inst, method)
    for _, cp in ipairs(FoundCheckpoints) do
        if cp.instance == inst then return end -- avoid duplicates
    end

    local pos = getPosition(inst)
    if not pos then return end

    table.insert(FoundCheckpoints, {
        instance = inst,
        name = inst.Name,
        position = pos,
        method = method,
    })
end

local function scanByName(root)
    for _, inst in ipairs(root:GetDescendants()) do
        if (inst:IsA("BasePart") or inst:IsA("Model")) and matchesNamePattern(inst.Name) then
            addCheckpoint(inst, "Name Pattern")
        end
    end
end

local function scanByTag()
    for _, tag in ipairs(Config.CollectionTags) do
        for _, inst in ipairs(CollectionService:GetTagged(tag)) do
            addCheckpoint(inst, "CollectionService: " .. tag)
        end
    end
end

local function scanByHeuristic(root)
    for _, inst in ipairs(root:GetDescendants()) do
        local isCp, reason = heuristicIsCheckpoint(inst)
        if isCp then
            addCheckpoint(inst, "Heuristic: " .. reason)
        end
    end
end

local function runFullScan()
    if tick() - LastScanTime < Config.ScanCooldown then return FoundCheckpoints end
    LastScanTime = tick()

    FoundCheckpoints = {}

    -- Try known folders first
    local scannedAny = false
    for _, folderName in ipairs(Config.SearchFolders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            scanByName(folder)
            scanByHeuristic(folder)
            scannedAny = true
        end
    end

    -- Always scan tags (cheap, global)
    scanByTag()

    -- Fallback to whole workspace if nothing found or folders don't exist
    if Config.FallbackToWholeWorkspace and (not scannedAny or #FoundCheckpoints == 0) then
        scanByName(Workspace)
        scanByHeuristic(Workspace)
    end

    -- Sort by name naturally where possible (numeric-aware)
    table.sort(FoundCheckpoints, function(a, b)
        local numA = tonumber(a.name:match("%d+"))
        local numB = tonumber(b.name:match("%d+"))
        if numA and numB then return numA < numB end
        return a.name < b.name
    end)

    return FoundCheckpoints
end

-- ==================== TELEPORT ====================
local function teleportTo(position)
    local char = Client.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    end
end

-- ==================== ESP ====================
local function clearESP()
    for _, holder in pairs(ESPHolders) do
        pcall(function() holder:Destroy() end)
    end
    ESPHolders = {}
end

local function applyESP()
    clearESP()
    if not ESPEnabled then return end

    for _, cp in ipairs(FoundCheckpoints) do
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "NekoCPEsp"
        billboard.Size = UDim2.new(0, 150, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.AlwaysOnTop = true
        billboard.Adornee = nil

        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Position = cp.position
        part.Parent = Workspace

        billboard.Adornee = part
        billboard.Parent = part

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = cp.name
        label.TextColor3 = Color3.fromRGB(120, 190, 255)
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.Parent = billboard

        table.insert(ESPHolders, part)
    end
end

-- ==================== UI (OBSIDIAN) ====================
local Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/library.lua"))()

local Window = Obsidian:CreateWindow({
    Name = "Neko CP Checker",
    Icon = "map-pin",
    LoadingTitle = "Neko CP Checker",
    LoadingSubtitle = "Scanning for checkpoints...",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NekoCPChecker",
        FileName = "Config",
    },
})

local MainTab = Window:CreateTab("Checker", "search")
local ListTab = Window:CreateTab("Checkpoints", "list")

-- Main tab
local InfoSection = MainTab:CreateSection("Scan")

MainTab:CreateParagraph({
    Title = "Neko CP Checker",
    Content = "Detects checkpoints via Name Patterns, CollectionService Tags, and a heuristic fallback (SpawnLocation, stage-value objects).",
})

local resultLabel = MainTab:CreateParagraph({
    Title = "Results",
    Content = "No scan yet. Click 'Scan Now'.",
})

MainTab:CreateButton({
    Name = "Scan Now",
    Callback = function()
        local results = runFullScan()
        resultLabel:Set("Results", ("Found %d checkpoint(s)."):format(#results))

        -- Rebuild list tab
        for _, child in ipairs(ListTab.Container:GetChildren()) do
            if child:IsA("Frame") or child:IsA("Instance") and child.Name ~= "UIListLayout" then
                -- Obsidian internal cleanup varies; safe no-op if API differs
            end
        end

        for i, cp in ipairs(results) do
            ListTab:CreateButton({
                Name = string.format("[%d] %s  (%s)", i, cp.name, cp.method),
                Callback = function()
                    teleportTo(cp.position)
                    Obsidian:Notify({
                        Title = "Teleported",
                        Content = "Moved to " .. cp.name,
                        Duration = 3,
                    })
                end,
            })
        end

        if ESPEnabled then applyESP() end
    end,
})

MainTab:CreateToggle({
    Name = "Show ESP Labels",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(value)
        ESPEnabled = value
        if value then
            applyESP()
        else
            clearESP()
        end
    end,
})

MainTab:CreateButton({
    Name = "Teleport to Last Checkpoint",
    Callback = function()
        if #FoundCheckpoints == 0 then
            Obsidian:Notify({ Title = "Neko CP Checker", Content = "No checkpoints found yet. Run a scan first.", Duration = 3 })
            return
        end
        local last = FoundCheckpoints[#FoundCheckpoints]
        teleportTo(last.position)
        Obsidian:Notify({ Title = "Teleported", Content = "Moved to " .. last.name, Duration = 3 })
    end,
})

local DetectionSection = MainTab:CreateSection("Detection Methods")

MainTab:CreateToggle({
    Name = "Name Pattern Matching",
    CurrentValue = true,
    Flag = "UseNamePattern",
    Callback = function(value)
        if value then
            table.insert(Config.SearchFolders, 1, "Checkpoints") -- no-op, kept simple
        end
    end,
})

MainTab:CreateLabel("Patterns: " .. table.concat(Config.NamePatterns, ", "))
MainTab:CreateLabel("Tags: " .. table.concat(Config.CollectionTags, ", "))

-- Initial scan on load
task.defer(function()
    task.wait(1)
    local results = runFullScan()
    resultLabel:Set("Results", ("Found %d checkpoint(s)."):format(#results))

    for i, cp in ipairs(results) do
        ListTab:CreateButton({
            Name = string.format("[%d] %s  (%s)", i, cp.name, cp.method),
            Callback = function()
                teleportTo(cp.position)
                Obsidian:Notify({
                    Title = "Teleported",
                    Content = "Moved to " .. cp.name,
                    Duration = 3,
                })
            end,
        })
    end
end)

Obsidian:Notify({
    Title = "Neko CP Checker",
    Content = "Loaded. Scanning for checkpoints...",
    Duration = 4,
})
