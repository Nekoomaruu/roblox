--[[
    NekomaruUI v2.0.0 — Contoh pemakaian (Examples/Universal.lua)
    Jalankan di executor (Delta dsb).
]]

local BASE = "https://raw.githubusercontent.com/Nekoomaruu/roblox/main/NekomaruUi/"

local function loadRemote(path)
	local url = BASE .. path .. "?v=" .. tostring(tick())
	local ok, body = pcall(game.HttpGet, game, url, true)
	if not ok or type(body) ~= "string" or #body < 100 then
		error(("NekomaruUI: gagal download %s (%s)"):format(url, tostring(body)), 0)
	end
	local chunk, err = loadstring(body, "=" .. path)
	if not chunk then
		error("NekomaruUI: syntax error di " .. path .. " -> " .. tostring(err), 0)
	end
	return chunk()
end

local Library = loadRemote("Library.lua")

local Window = Library:CreateWindow({
	Title    = "Nekomaru Hub",
	Subtitle = "Universal Script",
	Size     = UDim2.fromOffset(720, 460),
	ToggleKey = Enum.KeyCode.RightShift,
})

-- ============================ INFO ============================
local Info = Window:AddTab({ Name = "Info", Icon = "info" })
do
	local s = Info:AddSection({ Name = "Welcome" })
	s:AddParagraph({ Name = "Nekomaru Hub", Content = "UI custom pengganti Obsidian. Klik icon.png untuk buka/tutup panel." })
	s:AddLabel({ Text = "Player: " .. game.Players.LocalPlayer.Name })
	s:AddButton({ Name = "Copy Discord", Callback = function()
		if setclipboard then setclipboard("discord.gg/nekomaru") end
		Library:Notify({ Title = "Copied", Content = "Link disalin ke clipboard." })
	end })
end

-- ============================ FISHING ============================
local Fishing = Window:AddTab({ Name = "Fishing", Icon = "fishing" })
do
	local s = Fishing:AddSection({ Name = "Main" })
	s:AddToggle({ Name = "Auto Equip Rod", Flag = "AutoEquipRod", Default = false, Callback = function(v)
		getgenv().AutoEquipRod = v
	end })
	s:AddToggle({ Name = "No Fishing Animations", Flag = "NoFishAnim", Callback = function(v)
		getgenv().NoFishAnim = v
	end })
	s:AddToggle({ Name = "Walk on Water", Flag = "WalkWater", Callback = function(v)
		getgenv().WalkOnWater = v
	end })
	s:AddSlider({ Name = "Cast Delay", Flag = "CastDelay", Min = 0, Max = 5, Rounding = 1, Suffix = "s", Default = 1 })
	s:AddDropdown({ Name = "Rod", Flag = "RodType", Values = { "Basic", "Carbon", "Lucky", "Midas" }, Default = "Basic" })
end

-- ============================ AUTOMATICALLY ============================
local Auto = Window:AddTab({ Name = "Automatically", Icon = "auto" })
do
	local s = Auto:AddSection({ Name = "Farming" })
	s:AddToggle({ Name = "Auto Farm", Flag = "AutoFarm" })
	s:AddToggle({ Name = "Auto Sell", Flag = "AutoSell" })
	s:AddDropdown({ Name = "Targets", Flag = "Targets", Multi = true, Values = { "Fish", "Chest", "Ore" } })
	s:AddProgressBar({ Name = "Session Progress", Default = 0.25 })
end

-- ============================ TELEPORT ============================
local Teleport = Window:AddTab({ Name = "Teleport", Icon = "teleport" })
do
	local s = Teleport:AddSection({ Name = "Places" })
	s:AddInput({ Name = "Place ID", Flag = "PlaceId", Placeholder = "1234567" })
	s:AddButton({ Name = "Teleport", Callback = function()
		Library:Notify({ Title = "Teleport", Content = "Menuju " .. tostring(Library.Flags.PlaceId) })
	end })
end

-- ============================ MENU ============================
local Menu = Window:AddTab({ Name = "Menu", Icon = "settings" })
do
	local s = Menu:AddSection({ Name = "Interface" })
	s:AddDropdown({ Name = "Theme", Values = Library:GetThemeList(), Default = "Nekomaru", Callback = function(v)
		Library:SetTheme(v)
	end })
	s:AddColorPicker({ Name = "Accent", Default = Library.Theme.Accent, Callback = function(c)
		Library:SetAccent(c)
	end })
	s:AddKeybind({ Name = "Toggle UI", Default = Enum.KeyCode.RightShift, Callback = function()
		Window:Toggle()
	end })
	s:AddButton({ Name = "Save Config", Callback = function()
		local ok, info = Library:SaveConfigFile("default")
		Library:Notify({ Title = ok and "Saved" or "Error", Content = tostring(info) })
	end })
	s:AddButton({ Name = "Load Config", Callback = function()
		local ok, info = Library:LoadConfigFile("default")
		Library:Notify({ Title = ok and "Loaded" or "Error", Content = tostring(info) })
	end })
	s:AddButton({ Name = "Unload", Callback = function()
		Library:Unload()
	end })
end

Window:SelectTab(1)
Library:Notify({ Title = "Nekomaru Hub", Content = "Loaded v2.0.0", Duration = 4 })
