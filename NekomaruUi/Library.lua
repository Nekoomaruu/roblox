--[[
	╔══════════════════════════════════════════════════════════════════════╗
	║                                                                      ║
	║   ███╗   ██╗███████╗██╗  ██╗ ██████╗ ███╗   ███╗ █████╗ ██████╗ ██╗   ║
	║   ████╗  ██║██╔════╝██║ ██╔╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║   ║
	║   ██╔██╗ ██║█████╗  █████╔╝ ██║   ██║██╔████╔██║███████║██████╔╝██║   ║
	║   ██║╚██╗██║██╔══╝  ██╔═██╗ ██║   ██║██║╚██╔╝██║██╔══██║██╔══██╗██║   ║
	║   ██║ ╚████║███████╗██║  ██╗╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██╗  ║
	║   ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═╝  ║
	║                                                                      ║
	║   NekomaruUI  ·  v2.0.0  ·  Roblox Script UI Library                 ║
	║   Author : Nekoomaruu                                                ║
	║   Repo   : https://github.com/Nekoomaruu/roblox/tree/main/NekomaruUi ║
	║   License: MIT                                                       ║
	║                                                                      ║
	╚══════════════════════════════════════════════════════════════════════╝

	NekomaruUI adalah UI library standalone (mirip Rayfield / Obsidian) yang
	dirancang khusus untuk executor Delta, tetapi kompatibel juga dengan
	Solara, Xeno, Wave, Codex, Krnl, Fluxus, Synapse, Script-Ware, dsb.

	Fitur utama
	-----------
	· Desain "glass navy + cyan" mengikuti referensi (Chloe-X style)
	· Full smooth animation (spring/tween) pada semua interaksi
	· Sidebar icon + label, topbar, search, status bar, resize handle
	· Minimize ke floating `icon.png` — klik untuk buka/tutup jendela
	· Element lengkap:
	    Section, Label, Paragraph, Divider, Button, ButtonGroup, Toggle,
	    Slider, Input, Dropdown (single & multi), Keybind, ColorPicker,
	    ProgressBar, Image, Textbox besar, Table/List, TabBox
	· Notifikasi bertumpuk dengan progress bar
	· Watermark FPS / Ping / Waktu
	· Tooltip, Blur background, Sound feedback, Ripple effect
	· 8 theme bawaan + custom theme + ThemeManager
	· SaveManager (config JSON) + auto-load
	· Icon lokal via `getcustomasset` dengan fallback download dari GitHub

	Cara pakai singkat
	------------------
		local Library = loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/Nekoomaruu/roblox/main/NekomaruUi/Library.lua", true
		))()

		local Window = Library:CreateWindow({
			Title    = "Nekomaru Hub",
			SubTitle = "Universal · v1.0",
			Size     = UDim2.fromOffset(760, 500),
			Theme    = "Chloe",
		})

	Lihat README.md dan Docs/API.md untuk dokumentasi lengkap.
]]

--=============================================================================
-- SECTION 0 · SERVICES & ENVIRONMENT
--=============================================================================

local CoreGui              = game:GetService("CoreGui")
local Players              = game:GetService("Players")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local RunService           = game:GetService("RunService")
local HttpService          = game:GetService("HttpService")
local TextService          = game:GetService("TextService")
local Lighting             = game:GetService("Lighting")
local GuiService           = game:GetService("GuiService")
local StarterGui           = game:GetService("StarterGui")
local Stats                = game:GetService("Stats")
local ContentProvider      = game:GetService("ContentProvider")

local LocalPlayer          = Players.LocalPlayer
local Mouse                = LocalPlayer and LocalPlayer:GetMouse()
local Camera               = workspace.CurrentCamera

--=============================================================================
-- SECTION 1 · EXECUTOR SHIMS
--=============================================================================
-- Executor berbeda memakai nama fungsi berbeda. Semua akses ke API executor
-- dibungkus di sini supaya library tetap jalan walau fungsi tidak tersedia.

local Shim = {}

local function safeGet(name)
	local ok, value = pcall(function()
		return (getgenv and getgenv()[name]) or rawget(getfenv(), name)
	end)
	if ok then
		return value
	end
	return nil
end

Shim.identifyexecutor  = safeGet("identifyexecutor") or safeGet("getexecutorname")
Shim.getcustomasset    = safeGet("getcustomasset") or safeGet("getsynasset")
	or (safeGet("syn") and safeGet("syn").request and nil)
Shim.isfile            = safeGet("isfile")
Shim.isfolder          = safeGet("isfolder")
Shim.makefolder        = safeGet("makefolder")
Shim.writefile         = safeGet("writefile")
Shim.readfile          = safeGet("readfile")
Shim.delfile           = safeGet("delfile")
Shim.listfiles         = safeGet("listfiles")
Shim.appendfile        = safeGet("appendfile")
Shim.request           = safeGet("request") or safeGet("http_request")
	or (safeGet("http") and safeGet("http").request)
Shim.setclipboard      = safeGet("setclipboard") or safeGet("toclipboard")
Shim.protectgui        = safeGet("protect_gui") or safeGet("protectgui")
Shim.gethui            = safeGet("gethui")
Shim.setfpscap         = safeGet("setfpscap")
Shim.queueteleport     = safeGet("queue_on_teleport") or safeGet("queueonteleport")

if Shim.getcustomasset == nil then
	local synModule = safeGet("syn")
	if typeof(synModule) == "table" and typeof(rawget(synModule, "getcustomasset")) == "function" then
		Shim.getcustomasset = synModule.getcustomasset
	end
end

local ExecutorName = "Unknown"
do
	local ok, name = pcall(function()
		return Shim.identifyexecutor and Shim.identifyexecutor() or "Unknown"
	end)
	if ok and typeof(name) == "string" and #name > 0 then
		ExecutorName = name
	end
end

local IsDelta = string.find(string.lower(ExecutorName), "delta") ~= nil

--=============================================================================
-- SECTION 2 · LIBRARY TABLE & VERSION
--=============================================================================

local Library = {}
Library.__index = Library

Library.Version        = "2.0.0"
Library.Name           = "NekomaruUI"
Library.Author         = "Nekoomaruu"
Library.Executor       = ExecutorName
Library.IsDelta        = IsDelta

-- Repo tempat Assets/*.png disimpan (case sensitive!)
Library.Repo           = "Nekoomaruu/roblox"
Library.Branch         = "main"
Library.Folder         = "NekomaruUi"
Library.AssetsBaseURL  = string.format(
	"https://raw.githubusercontent.com/%s/%s/%s/Assets/",
	"Nekoomaruu/roblox", "main", "NekomaruUi"
)

-- Folder workspace executor tempat cache icon & config
Library.WorkspaceFolder = "NekomaruUI"
Library.AssetsFolder    = "NekomaruUI/Assets"
Library.ConfigFolder    = "NekomaruUI/Configs"
Library.ThemeFolder     = "NekomaruUI/Themes"

Library.Windows        = {}
Library.Notifications  = {}
Library.Connections    = {}
Library.Signals        = {}
Library.Flags          = {}
Library.Options        = {}
Library.Objects        = {}      -- semua object yang mengikuti theme
Library.Tooltips       = {}
Library.Unloaded       = false
Library.Toggled        = true
Library.ToggleKey      = Enum.KeyCode.RightShift
Library.MinimizeKey    = Enum.KeyCode.RightControl
Library.CanDrag        = true
Library.UseAcrylic     = true
Library.AcrylicEnabled = false
Library.SoundEnabled   = true
Library.TooltipEnabled = true
Library.DPIScale       = 1
Library.ScreenGui      = nil
Library.ActiveWindow   = nil

--=============================================================================
-- SECTION 3 · ANIMATION PROFILE
--=============================================================================

Library.Animation = {
	Enabled     = true,
	Speed       = 1,               -- pengali global (0.5 = 2x lebih cepat)
	Open        = 0.45,
	Close       = 0.28,
	Minimize    = 0.35,
	Tab         = 0.30,
	Hover       = 0.16,
	Press       = 0.09,
	Toggle      = 0.22,
	Slider      = 0.10,
	Dropdown    = 0.24,
	Notify      = 0.38,
	Fade        = 0.22,
	Easing      = Enum.EasingStyle.Quint,
	Direction   = Enum.EasingDirection.Out,
	SpringStyle = Enum.EasingStyle.Back,
}

function Library:SetAnimation(config)
	config = config or {}
	for key, value in pairs(config) do
		if Library.Animation[key] ~= nil or typeof(value) == "number" then
			Library.Animation[key] = value
		end
	end
	return Library.Animation
end

function Library:ToggleAnimations(state)
	Library.Animation.Enabled = state and true or false
end

--=============================================================================
-- SECTION 4 · THEME PRESETS
--=============================================================================
-- Palet utama diambil dari referensi: navy gelap transparan + aksen cyan.

local Themes = {}

Themes.Chloe = {
	Name              = "Chloe",
	Accent            = Color3.fromRGB(34, 211, 238),
	AccentDark        = Color3.fromRGB(14, 165, 190),
	AccentGlow        = Color3.fromRGB(90, 240, 255),
	Background        = Color3.fromRGB(11, 19, 32),
	BackgroundAlt     = Color3.fromRGB(14, 24, 40),
	Sidebar           = Color3.fromRGB(9, 16, 28),
	Topbar            = Color3.fromRGB(12, 21, 35),
	Section           = Color3.fromRGB(16, 28, 45),
	Element           = Color3.fromRGB(20, 34, 54),
	ElementHover      = Color3.fromRGB(26, 43, 66),
	ElementActive     = Color3.fromRGB(31, 52, 78),
	Border            = Color3.fromRGB(31, 52, 78),
	BorderLight       = Color3.fromRGB(44, 71, 102),
	Text              = Color3.fromRGB(238, 246, 255),
	SubText           = Color3.fromRGB(148, 172, 199),
	DimText           = Color3.fromRGB(99, 122, 148),
	Placeholder       = Color3.fromRGB(84, 105, 130),
	Success           = Color3.fromRGB(52, 211, 153),
	Warning           = Color3.fromRGB(251, 191, 36),
	Danger            = Color3.fromRGB(248, 113, 113),
	Info              = Color3.fromRGB(96, 165, 250),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Themes.Midnight = {
	Name              = "Midnight",
	Accent            = Color3.fromRGB(129, 140, 248),
	AccentDark        = Color3.fromRGB(93, 105, 220),
	AccentGlow        = Color3.fromRGB(165, 180, 252),
	Background        = Color3.fromRGB(13, 14, 24),
	BackgroundAlt     = Color3.fromRGB(17, 19, 32),
	Sidebar           = Color3.fromRGB(10, 11, 20),
	Topbar            = Color3.fromRGB(15, 17, 28),
	Section           = Color3.fromRGB(20, 22, 38),
	Element           = Color3.fromRGB(25, 28, 46),
	ElementHover      = Color3.fromRGB(33, 37, 58),
	ElementActive     = Color3.fromRGB(41, 45, 70),
	Border            = Color3.fromRGB(38, 42, 66),
	BorderLight       = Color3.fromRGB(56, 61, 90),
	Text              = Color3.fromRGB(240, 240, 250),
	SubText           = Color3.fromRGB(160, 165, 195),
	DimText           = Color3.fromRGB(110, 115, 145),
	Placeholder       = Color3.fromRGB(95, 100, 130),
	Success           = Color3.fromRGB(74, 222, 128),
	Warning           = Color3.fromRGB(250, 204, 21),
	Danger            = Color3.fromRGB(244, 114, 182),
	Info              = Color3.fromRGB(125, 211, 252),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Themes.Sakura = {
	Name              = "Sakura",
	Accent            = Color3.fromRGB(244, 114, 182),
	AccentDark        = Color3.fromRGB(211, 84, 152),
	AccentGlow        = Color3.fromRGB(251, 170, 210),
	Background        = Color3.fromRGB(26, 15, 24),
	BackgroundAlt     = Color3.fromRGB(33, 19, 30),
	Sidebar           = Color3.fromRGB(22, 12, 20),
	Topbar            = Color3.fromRGB(29, 17, 27),
	Section           = Color3.fromRGB(38, 22, 35),
	Element           = Color3.fromRGB(46, 27, 42),
	ElementHover      = Color3.fromRGB(58, 34, 53),
	ElementActive     = Color3.fromRGB(70, 41, 64),
	Border            = Color3.fromRGB(64, 38, 58),
	BorderLight       = Color3.fromRGB(90, 54, 82),
	Text              = Color3.fromRGB(253, 242, 248),
	SubText           = Color3.fromRGB(206, 168, 190),
	DimText           = Color3.fromRGB(150, 118, 138),
	Placeholder       = Color3.fromRGB(132, 102, 120),
	Success           = Color3.fromRGB(134, 239, 172),
	Warning           = Color3.fromRGB(253, 224, 71),
	Danger            = Color3.fromRGB(248, 113, 113),
	Info              = Color3.fromRGB(147, 197, 253),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Themes.Emerald = {
	Name              = "Emerald",
	Accent            = Color3.fromRGB(52, 211, 153),
	AccentDark        = Color3.fromRGB(16, 163, 116),
	AccentGlow        = Color3.fromRGB(110, 240, 195),
	Background        = Color3.fromRGB(10, 22, 20),
	BackgroundAlt     = Color3.fromRGB(13, 28, 26),
	Sidebar           = Color3.fromRGB(8, 18, 17),
	Topbar            = Color3.fromRGB(11, 24, 22),
	Section           = Color3.fromRGB(15, 33, 30),
	Element           = Color3.fromRGB(19, 41, 38),
	ElementHover      = Color3.fromRGB(25, 52, 48),
	ElementActive     = Color3.fromRGB(31, 63, 58),
	Border            = Color3.fromRGB(28, 58, 53),
	BorderLight       = Color3.fromRGB(42, 82, 75),
	Text              = Color3.fromRGB(236, 253, 245),
	SubText           = Color3.fromRGB(150, 190, 178),
	DimText           = Color3.fromRGB(102, 138, 128),
	Placeholder       = Color3.fromRGB(88, 120, 112),
	Success           = Color3.fromRGB(74, 222, 128),
	Warning           = Color3.fromRGB(250, 204, 21),
	Danger            = Color3.fromRGB(248, 113, 113),
	Info              = Color3.fromRGB(103, 232, 249),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Themes.Sunset = {
	Name              = "Sunset",
	Accent            = Color3.fromRGB(251, 146, 60),
	AccentDark        = Color3.fromRGB(217, 119, 40),
	AccentGlow        = Color3.fromRGB(253, 186, 116),
	Background        = Color3.fromRGB(26, 17, 14),
	BackgroundAlt     = Color3.fromRGB(33, 22, 18),
	Sidebar           = Color3.fromRGB(22, 14, 11),
	Topbar            = Color3.fromRGB(29, 19, 15),
	Section           = Color3.fromRGB(38, 25, 20),
	Element           = Color3.fromRGB(47, 31, 25),
	ElementHover      = Color3.fromRGB(59, 39, 31),
	ElementActive     = Color3.fromRGB(71, 47, 37),
	Border            = Color3.fromRGB(65, 43, 34),
	BorderLight       = Color3.fromRGB(92, 61, 48),
	Text              = Color3.fromRGB(255, 247, 237),
	SubText           = Color3.fromRGB(205, 174, 152),
	DimText           = Color3.fromRGB(148, 122, 104),
	Placeholder       = Color3.fromRGB(130, 108, 92),
	Success           = Color3.fromRGB(134, 239, 172),
	Warning           = Color3.fromRGB(253, 224, 71),
	Danger            = Color3.fromRGB(248, 113, 113),
	Info              = Color3.fromRGB(147, 197, 253),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Themes.Monochrome = {
	Name              = "Monochrome",
	Accent            = Color3.fromRGB(226, 232, 240),
	AccentDark        = Color3.fromRGB(160, 170, 185),
	AccentGlow        = Color3.fromRGB(255, 255, 255),
	Background        = Color3.fromRGB(15, 15, 17),
	BackgroundAlt     = Color3.fromRGB(19, 19, 22),
	Sidebar           = Color3.fromRGB(12, 12, 14),
	Topbar            = Color3.fromRGB(17, 17, 20),
	Section           = Color3.fromRGB(23, 23, 27),
	Element           = Color3.fromRGB(29, 29, 34),
	ElementHover      = Color3.fromRGB(38, 38, 44),
	ElementActive     = Color3.fromRGB(47, 47, 54),
	Border            = Color3.fromRGB(43, 43, 50),
	BorderLight       = Color3.fromRGB(62, 62, 72),
	Text              = Color3.fromRGB(245, 245, 248),
	SubText           = Color3.fromRGB(163, 163, 173),
	DimText           = Color3.fromRGB(115, 115, 125),
	Placeholder       = Color3.fromRGB(100, 100, 110),
	Success           = Color3.fromRGB(163, 230, 53),
	Warning           = Color3.fromRGB(250, 204, 21),
	Danger            = Color3.fromRGB(239, 68, 68),
	Info              = Color3.fromRGB(148, 163, 184),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Themes.Ocean = {
	Name              = "Ocean",
	Accent            = Color3.fromRGB(56, 189, 248),
	AccentDark        = Color3.fromRGB(14, 145, 200),
	AccentGlow        = Color3.fromRGB(125, 211, 252),
	Background        = Color3.fromRGB(8, 20, 36),
	BackgroundAlt     = Color3.fromRGB(11, 26, 46),
	Sidebar           = Color3.fromRGB(6, 16, 30),
	Topbar            = Color3.fromRGB(9, 22, 40),
	Section           = Color3.fromRGB(13, 31, 54),
	Element           = Color3.fromRGB(17, 39, 66),
	ElementHover      = Color3.fromRGB(22, 49, 82),
	ElementActive     = Color3.fromRGB(28, 60, 98),
	Border            = Color3.fromRGB(26, 55, 90),
	BorderLight       = Color3.fromRGB(38, 78, 124),
	Text              = Color3.fromRGB(240, 249, 255),
	SubText           = Color3.fromRGB(145, 180, 212),
	DimText           = Color3.fromRGB(98, 128, 158),
	Placeholder       = Color3.fromRGB(84, 112, 140),
	Success           = Color3.fromRGB(45, 212, 191),
	Warning           = Color3.fromRGB(251, 191, 36),
	Danger            = Color3.fromRGB(251, 113, 133),
	Info              = Color3.fromRGB(129, 212, 250),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Themes.Blood = {
	Name              = "Blood",
	Accent            = Color3.fromRGB(239, 68, 68),
	AccentDark        = Color3.fromRGB(185, 40, 40),
	AccentGlow        = Color3.fromRGB(252, 120, 120),
	Background        = Color3.fromRGB(20, 11, 12),
	BackgroundAlt     = Color3.fromRGB(26, 14, 15),
	Sidebar           = Color3.fromRGB(16, 9, 10),
	Topbar            = Color3.fromRGB(23, 12, 13),
	Section           = Color3.fromRGB(31, 17, 18),
	Element           = Color3.fromRGB(39, 21, 22),
	ElementHover      = Color3.fromRGB(50, 27, 28),
	ElementActive     = Color3.fromRGB(61, 33, 34),
	Border            = Color3.fromRGB(56, 30, 31),
	BorderLight       = Color3.fromRGB(80, 43, 44),
	Text              = Color3.fromRGB(254, 242, 242),
	SubText           = Color3.fromRGB(200, 158, 158),
	DimText           = Color3.fromRGB(145, 112, 112),
	Placeholder       = Color3.fromRGB(126, 98, 98),
	Success           = Color3.fromRGB(134, 239, 172),
	Warning           = Color3.fromRGB(253, 224, 71),
	Danger            = Color3.fromRGB(248, 113, 113),
	Info              = Color3.fromRGB(147, 197, 253),
	Shadow            = Color3.fromRGB(0, 0, 0),
	Transparency      = 0.06,
	GlassTransparency = 0.25,
}

Library.Themes = Themes
Library.Theme  = table.clone(Themes.Chloe)

function Library:GetThemes()
	local list = {}
	for name in pairs(Themes) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

--=============================================================================
-- SECTION 5 · ICON REGISTRY
--=============================================================================
-- Semua icon lokal berasal dari folder Assets. Saat runtime, file akan
-- di-download (sekali) ke workspace executor lalu di-load memakai
-- getcustomasset(path) -> content URL yang bisa dipakai ImageLabel.Image.

local IconFiles = {
	icon        = "icon.png",
	logo        = "icon.png",
	home        = "Home.png",
	info        = "Info.png",
	settings    = "Settings.png",
	setting     = "Settings.png",
	close       = "Close.png",
	minimize    = "Minimize.png",
	arrow       = "Arrow.png",
	clear       = "Clear.png",
	clipboard   = "Clipboard.png",
	discord     = "Discord.png",
	error       = "Error.png",
	file        = "File.png",
	localfile   = "LocalFile.png",
	open        = "Open.png",
	play        = "Play.png",
	timer       = "Timer.png",
	warning     = "Warning.png",
	warningred  = "WarningRed.png",
	website     = "Website.png",
	alert       = "alert.png",
	car         = "car.png",
	crosshair   = "crosshair.png",
	eye         = "eye.png",
	fish        = "fish.png",
	pin         = "pin.png",
	server      = "server.png",
	teleport    = "teleport.png",
	user        = "user.png",
}

-- Fallback ke asset id Roblox bila file lokal gagal (mis. tanpa filesystem).
local IconFallback = {
	icon      = "rbxassetid://10723407389",
	home      = "rbxassetid://10723407389",
	info      = "rbxassetid://10723345544",
	settings  = "rbxassetid://10734950020",
	close     = "rbxassetid://10747384394",
	minimize  = "rbxassetid://10734896206",
	arrow     = "rbxassetid://10709790948",
	search    = "rbxassetid://10734943674",
	check     = "rbxassetid://10709790644",
	user      = "rbxassetid://10747373176",
	play      = "rbxassetid://10723346959",
	timer     = "rbxassetid://10734898355",
	eye       = "rbxassetid://10723345787",
	pin       = "rbxassetid://10723387563",
	teleport  = "rbxassetid://10723415903",
	fish      = "rbxassetid://10723345787",
	server    = "rbxassetid://10734938347",
	car       = "rbxassetid://10723345254",
	crosshair = "rbxassetid://10734884548",
	alert     = "rbxassetid://10723345544",
	discord   = "rbxassetid://10734902899",
	clipboard = "rbxassetid://10734884392",
	file      = "rbxassetid://10723374466",
	website   = "rbxassetid://10734947145",
	warning   = "rbxassetid://10723345544",
}

local IconCache = {}

local function ensureFolder(path)
	if not (Shim.isfolder and Shim.makefolder) then
		return false
	end
	local ok = pcall(function()
		if not Shim.isfolder(path) then
			Shim.makefolder(path)
		end
	end)
	return ok
end

local function httpGetBinary(url)
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and typeof(body) == "string" and #body > 0 then
		return body
	end
	if Shim.request then
		local ok2, response = pcall(Shim.request, { Url = url, Method = "GET" })
		if ok2 and typeof(response) == "table" and response.Body and #response.Body > 0 then
			return response.Body
		end
	end
	return nil
end

--- Ambil content URL dari sebuah icon.
-- @param name string  key di IconFiles, nama file (mis. "fish.png"),
--                     rbxassetid://..., atau URL http(s)
function Library:GetIcon(name)
	if typeof(name) ~= "string" or name == "" then
		return ""
	end

	if string.match(name, "^rbxassetid://") or string.match(name, "^rbxasset://") then
		return name
	end

	local key = string.lower(name)
	if IconCache[key] then
		return IconCache[key]
	end

	local fileName = IconFiles[key]
	if not fileName then
		if string.match(name, "%.png$") or string.match(name, "%.jpg$") then
			fileName = name
		end
	end

	-- URL langsung -> download dulu supaya bisa jadi custom asset
	local remoteURL
	if string.match(name, "^https?://") then
		remoteURL  = name
		fileName   = string.match(name, "([^/]+)$") or "remote.png"
	elseif fileName then
		remoteURL = Library.AssetsBaseURL .. fileName
	end

	if fileName and Shim.getcustomasset and Shim.isfile and Shim.writefile then
		ensureFolder(Library.WorkspaceFolder)
		ensureFolder(Library.AssetsFolder)

		local localPath = Library.AssetsFolder .. "/" .. fileName
		local exists = false
		pcall(function()
			exists = Shim.isfile(localPath)
		end)

		if not exists and remoteURL then
			local data = httpGetBinary(remoteURL)
			if data then
				pcall(function()
					Shim.writefile(localPath, data)
				end)
				pcall(function()
					exists = Shim.isfile(localPath)
				end)
			end
		end

		if exists then
			local ok, asset = pcall(Shim.getcustomasset, localPath)
			if ok and typeof(asset) == "string" and #asset > 0 then
				IconCache[key] = asset
				return asset
			end
		end
	end

	local fallback = IconFallback[key] or IconFallback.info or ""
	IconCache[key] = fallback
	return fallback
end

function Library:PreloadIcons(list)
	task.spawn(function()
		for _, name in ipairs(list or {}) do
			Library:GetIcon(name)
		end
	end)
end

function Library:ClearIconCache()
	table.clear(IconCache)
end

--=============================================================================
-- SECTION 6 · UTILITIES
--=============================================================================

local Utility = {}
Library.Utility = Utility

function Utility.Lerp(a, b, t)
	return a + (b - a) * t
end

function Utility.Round(value, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(value * mult + 0.5) / mult
end

function Utility.Clamp(value, min, max)
	return math.clamp(value, min, max)
end

function Utility.Map(value, inMin, inMax, outMin, outMax)
	if inMax - inMin == 0 then
		return outMin
	end
	return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
end

function Utility.DeepCopy(source)
	if typeof(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = Utility.DeepCopy(value)
	end
	return copy
end

function Utility.Merge(base, override)
	local result = Utility.DeepCopy(base)
	for key, value in pairs(override or {}) do
		result[key] = value
	end
	return result
end

function Utility.Contains(list, value)
	for index, item in ipairs(list or {}) do
		if item == value then
			return true, index
		end
	end
	return false, nil
end

function Utility.Count(dictionary)
	local total = 0
	for _ in pairs(dictionary or {}) do
		total += 1
	end
	return total
end

function Utility.Keys(dictionary)
	local list = {}
	for key in pairs(dictionary or {}) do
		table.insert(list, key)
	end
	return list
end

function Utility.TrimString(text)
	return (string.gsub(tostring(text), "^%s*(.-)%s*$", "%1"))
end

function Utility.StartsWith(text, prefix)
	return string.sub(string.lower(text), 1, #prefix) == string.lower(prefix)
end

function Utility.Search(text, query)
	if query == nil or query == "" then
		return true
	end
	return string.find(string.lower(tostring(text)), string.lower(query), 1, true) ~= nil
end

function Utility.FormatNumber(number)
	local formatted = tostring(number)
	local k
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

function Utility.KeyName(key)
	if typeof(key) == "EnumItem" then
		if key.EnumType == Enum.UserInputType then
			if key == Enum.UserInputType.MouseButton1 then return "MB1" end
			if key == Enum.UserInputType.MouseButton2 then return "MB2" end
			if key == Enum.UserInputType.MouseButton3 then return "MB3" end
			return string.gsub(key.Name, "Button", "")
		end
		local name = key.Name
		name = string.gsub(name, "^Left", "L")
		name = string.gsub(name, "^Right", "R")
		return name
	end
	return "None"
end

function Utility.GetTextSize(text, size, font, bounds)
	local ok, result = pcall(function()
		return TextService:GetTextSize(
			tostring(text),
			size,
			font,
			bounds or Vector2.new(math.huge, math.huge)
		)
	end)
	if ok then
		return result
	end
	return Vector2.new(#tostring(text) * size * 0.5, size)
end

--=============================================================================
-- SECTION 7 · INSTANCE FACTORY
--=============================================================================

local function Create(className, properties, children)
	local instance = Instance.new(className)
	for property, value in pairs(properties or {}) do
		if property ~= "Parent" then
			pcall(function()
				instance[property] = value
			end)
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if properties and properties.Parent then
		instance.Parent = properties.Parent
	end
	return instance
end

Library.Create = Create

local function Corner(parent, radius)
	return Create("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent       = parent,
	})
end

local function Stroke(parent, color, thickness, transparency)
	return Create("UIStroke", {
		Color            = color or Library.Theme.Border,
		Thickness        = thickness or 1,
		Transparency     = transparency or 0,
		ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
		Parent           = parent,
	})
end

local function Padding(parent, top, bottom, left, right)
	return Create("UIPadding", {
		PaddingTop    = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		PaddingLeft   = UDim.new(0, left or top or 0),
		PaddingRight  = UDim.new(0, right or left or top or 0),
		Parent        = parent,
	})
end

local function ListLayout(parent, padding, direction, sortOrder)
	return Create("UIListLayout", {
		Padding          = UDim.new(0, padding or 6),
		FillDirection    = direction or Enum.FillDirection.Vertical,
		SortOrder        = sortOrder or Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent           = parent,
	})
end

local function Gradient(parent, colorA, colorB, rotation, transparency)
	return Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, colorA),
			ColorSequenceKeypoint.new(1, colorB),
		}),
		Rotation     = rotation or 0,
		Transparency = transparency or NumberSequence.new(0),
		Parent       = parent,
	})
end

local function Shadow(parent, size, transparency)
	return Create("ImageLabel", {
		Name                   = "Shadow",
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromScale(0.5, 0.5),
		Size                   = UDim2.new(1, size or 40, 1, size or 40),
		Image                  = "rbxassetid://6015897843",
		ImageColor3            = Color3.fromRGB(0, 0, 0),
		ImageTransparency      = transparency or 0.45,
		ScaleType              = Enum.ScaleType.Slice,
		SliceCenter            = Rect.new(49, 49, 450, 450),
		ZIndex                 = 0,
		Parent                 = parent,
	})
end

Library.Corner     = Corner
Library.Stroke     = Stroke
Library.Padding    = Padding
Library.ListLayout = ListLayout
Library.Gradient   = Gradient
Library.Shadow     = Shadow

--=============================================================================
-- SECTION 8 · TWEEN HELPERS
--=============================================================================

local ActiveTweens = setmetatable({}, { __mode = "k" })

local function Tween(instance, duration, properties, style, direction, callback)
	if not instance or not instance.Parent and not instance:IsA("ScreenGui") then
		-- masih boleh berjalan; parent bisa saja diset setelah ini
	end

	local anim = Library.Animation
	local time = (duration or anim.Fade) * (anim.Speed or 1)

	if not anim.Enabled then
		for property, value in pairs(properties) do
			pcall(function()
				instance[property] = value
			end)
		end
		if callback then
			task.spawn(callback)
		end
		return nil
	end

	local info = TweenInfo.new(
		math.max(time, 0.01),
		style or anim.Easing,
		direction or anim.Direction
	)

	local existing = ActiveTweens[instance]
	if existing then
		for property in pairs(properties) do
			local running = existing[property]
			if running then
				pcall(function()
					running:Cancel()
				end)
				existing[property] = nil
			end
		end
	else
		ActiveTweens[instance] = {}
	end

	local tween = TweenService:Create(instance, info, properties)
	for property in pairs(properties) do
		ActiveTweens[instance][property] = tween
	end

	if callback then
		tween.Completed:Connect(function()
			callback()
		end)
	end

	tween:Play()
	return tween
end

local function TweenSpring(instance, duration, properties, callback)
	return Tween(
		instance,
		duration,
		properties,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out,
		callback
	)
end

Library.Tween       = Tween
Library.TweenSpring = TweenSpring

--=============================================================================
-- SECTION 9 · SIGNAL / CONNECTION MANAGER
--=============================================================================

local function Connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Library.Connections, connection)
	return connection
end

Library.Connect = Connect

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self._handlers, handler)
	local index = #self._handlers
	return {
		Disconnect = function()
			self._handlers[index] = nil
		end,
	}
end

function Signal:Fire(...)
	for _, handler in pairs(self._handlers) do
		if handler then
			task.spawn(handler, ...)
		end
	end
end

Library.Signal = Signal

--=============================================================================
-- SECTION 10 · SOUND & HAPTICS
--=============================================================================

local Sounds = {
	Click    = "rbxassetid://6042053626",
	Hover    = "rbxassetid://6042053626",
	Toggle   = "rbxassetid://6042053626",
	Notify   = "rbxassetid://4590662766",
	Error    = "rbxassetid://550209561",
	Open     = "rbxassetid://452267918",
}

function Library:PlaySound(name, volume)
	if not Library.SoundEnabled then
		return
	end
	local id = Sounds[name] or name
	if typeof(id) ~= "string" then
		return
	end
	task.spawn(function()
		local sound = Create("Sound", {
			SoundId  = id,
			Volume   = volume or 0.25,
			Parent   = Library.ScreenGui or CoreGui,
		})
		pcall(function()
			sound:Play()
		end)
		task.delay(3, function()
			pcall(function()
				sound:Destroy()
			end)
		end)
	end)
end

--=============================================================================
-- SECTION 11 · SCREENGUI ROOT
--=============================================================================

local function protect(gui)
	if Shim.gethui then
		local ok = pcall(function()
			gui.Parent = Shim.gethui()
		end)
		if ok then
			return
		end
	end
	if Shim.protectgui then
		pcall(Shim.protectgui, gui)
	end
	local ok = pcall(function()
		gui.Parent = CoreGui
	end)
	if not ok then
		gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end
end

function Library:GetScreenGui()
	if Library.ScreenGui and Library.ScreenGui.Parent then
		return Library.ScreenGui
	end

	local gui = Create("ScreenGui", {
		Name              = "NekomaruUI_" .. tostring(math.random(100000, 999999)),
		ResetOnSpawn      = false,
		IgnoreGuiInset    = true,
		DisplayOrder      = 9999,
		ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
	})
	protect(gui)

	Library.ScreenGui = gui
	return gui
end

--=============================================================================
-- SECTION 12 · ACRYLIC / BLUR BACKGROUND
--=============================================================================

local BlurEffect

function Library:SetBlur(enabled, size)
	if enabled then
		if not BlurEffect or not BlurEffect.Parent then
			BlurEffect = Create("BlurEffect", {
				Name   = "NekomaruUIBlur",
				Size   = 0,
				Parent = Lighting,
			})
		end
		Tween(BlurEffect, 0.4, { Size = size or 14 })
		Library.AcrylicEnabled = true
	elseif BlurEffect then
		Tween(BlurEffect, 0.3, { Size = 0 }, nil, nil, function()
			if BlurEffect then
				pcall(function()
					BlurEffect:Destroy()
				end)
				BlurEffect = nil
			end
		end)
		Library.AcrylicEnabled = false
	end
end

--=============================================================================
-- SECTION 13 · THEME APPLICATION
--=============================================================================

-- Setiap object visual didaftarkan dengan "role" agar theme bisa diganti live.
local function Register(instance, property, role)
	table.insert(Library.Objects, {
		Instance = instance,
		Property = property,
		Role     = role,
	})
	if Library.Theme[role] then
		pcall(function()
			instance[property] = Library.Theme[role]
		end)
	end
	return instance
end

Library.Register = Register

function Library:SetTheme(theme, animated)
	local resolved

	if typeof(theme) == "string" then
		resolved = Themes[theme]
		if not resolved then
			for name, preset in pairs(Themes) do
				if string.lower(name) == string.lower(theme) then
					resolved = preset
					break
				end
			end
		end
	elseif typeof(theme) == "table" then
		resolved = Utility.Merge(Themes.Chloe, theme)
	end

	if not resolved then
		return false
	end

	Library.Theme = Utility.DeepCopy(resolved)

	for index = #Library.Objects, 1, -1 do
		local entry = Library.Objects[index]
		local instance = entry.Instance
		if not instance or not instance.Parent then
			if not (instance and instance:IsA("ScreenGui")) then
				table.remove(Library.Objects, index)
				continue
			end
		end
		local color = Library.Theme[entry.Role]
		if color then
			if animated ~= false and typeof(color) == "Color3" then
				Tween(instance, 0.25, { [entry.Property] = color })
			else
				pcall(function()
					instance[entry.Property] = color
				end)
			end
		end
	end

	if Library.OnThemeChanged then
		task.spawn(Library.OnThemeChanged, Library.Theme)
	end

	return true
end

function Library:AddCustomTheme(name, palette)
	Themes[name] = Utility.Merge(Themes.Chloe, palette or {})
	Themes[name].Name = name
	return Themes[name]
end
--=============================================================================
-- SECTION 14 · INTERACTION HELPERS
--=============================================================================

--- Efek ripple ketika elemen diklik.
local function Ripple(button, color)
	if not Library.Animation.Enabled then
		return
	end

	local position = UserInputService:GetMouseLocation()
	local absolutePosition = button.AbsolutePosition
	local absoluteSize = button.AbsoluteSize

	local relativeX = position.X - absolutePosition.X
	local relativeY = position.Y - absolutePosition.Y - 36

	local circle = Create("Frame", {
		Name                   = "Ripple",
		BackgroundColor3       = color or Library.Theme.Accent,
		BackgroundTransparency = 0.75,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromOffset(relativeX, relativeY),
		Size                   = UDim2.fromOffset(0, 0),
		ZIndex                 = (button.ZIndex or 1) + 1,
		Parent                 = button,
	})
	Corner(circle, 999)

	local target = math.max(absoluteSize.X, absoluteSize.Y) * 2

	Tween(circle, 0.45, {
		Size                   = UDim2.fromOffset(target, target),
		BackgroundTransparency = 1,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
		pcall(function()
			circle:Destroy()
		end)
	end)
end

Library.Ripple = Ripple

--- Hover highlight otomatis untuk elemen interaktif.
local function Hoverable(instance, normalRole, hoverRole, extra)
	local normalColor = function()
		return Library.Theme[normalRole] or instance.BackgroundColor3
	end
	local hoverColor = function()
		return Library.Theme[hoverRole] or Library.Theme.ElementHover
	end

	Connect(instance.MouseEnter, function()
		Tween(instance, Library.Animation.Hover, { BackgroundColor3 = hoverColor() })
		if extra and extra.OnEnter then
			extra.OnEnter()
		end
	end)

	Connect(instance.MouseLeave, function()
		Tween(instance, Library.Animation.Hover, { BackgroundColor3 = normalColor() })
		if extra and extra.OnLeave then
			extra.OnLeave()
		end
	end)
end

Library.Hoverable = Hoverable

--- Efek "tekan" (scale down sedikit) untuk button.
local function Pressable(button, scaleObject)
	local scale = scaleObject
	if not scale then
		scale = Create("UIScale", { Scale = 1, Parent = button })
	end

	Connect(button.MouseButton1Down, function()
		Tween(scale, Library.Animation.Press, { Scale = 0.97 })
	end)
	Connect(button.MouseButton1Up, function()
		Tween(scale, Library.Animation.Press, { Scale = 1 })
	end)
	Connect(button.MouseLeave, function()
		Tween(scale, Library.Animation.Press, { Scale = 1 })
	end)

	return scale
end

Library.Pressable = Pressable

--- Membuat sebuah frame bisa di-drag lewat handle.
local function MakeDraggable(handle, target, onDragEnd)
	local dragging = false
	local dragStart, startPosition

	Connect(handle.InputBegan, function(input)
		if not Library.CanDrag then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging      = true
			dragStart     = input.Position
			startPosition = target.Position

			local connection
			connection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if onDragEnd then
						onDragEnd(target.Position)
					end
					connection:Disconnect()
				end
			end)
		end
	end)

	Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			local goal = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
			-- Drag mengikuti kursor secara instan supaya terasa responsif,
			-- animasi tetap halus lewat tween super pendek.
			Tween(target, 0.06, { Position = goal }, Enum.EasingStyle.Linear)
		end
	end)
end

Library.MakeDraggable = MakeDraggable

--- Membuat window bisa di-resize dari pojok kanan bawah.
local function MakeResizable(handle, target, minSize, maxSize, onResize)
	local resizing = false
	local startPosition, startSize

	Connect(handle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			resizing      = true
			startPosition = input.Position
			startSize     = target.Size

			local connection
			connection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
					if onResize then
						onResize(target.AbsoluteSize)
					end
					connection:Disconnect()
				end
			end)
		end
	end)

	Connect(UserInputService.InputChanged, function(input)
		if not resizing then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - startPosition
			local width  = math.clamp(startSize.X.Offset + delta.X, minSize.X, maxSize.X)
			local height = math.clamp(startSize.Y.Offset + delta.Y, minSize.Y, maxSize.Y)
			target.Size = UDim2.fromOffset(width, height)
			if onResize then
				onResize(Vector2.new(width, height))
			end
		end
	end)
end

Library.MakeResizable = MakeResizable

--=============================================================================
-- SECTION 15 · TOOLTIP
--=============================================================================

local TooltipFrame, TooltipLabel

local function BuildTooltip()
	if TooltipFrame and TooltipFrame.Parent then
		return
	end

	TooltipFrame = Create("Frame", {
		Name                   = "Tooltip",
		BackgroundColor3       = Library.Theme.Section,
		BackgroundTransparency = 0.05,
		BorderSizePixel        = 0,
		Size                   = UDim2.fromOffset(0, 26),
		Visible                = false,
		ZIndex                 = 9999,
		Parent                 = Library:GetScreenGui(),
	})
	Corner(TooltipFrame, 6)
	Register(TooltipFrame, "BackgroundColor3", "Section")
	local stroke = Stroke(TooltipFrame, Library.Theme.Border, 1)
	Register(stroke, "Color", "Border")

	TooltipLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
		Font                   = Enum.Font.Gotham,
		Text                   = "",
		TextColor3             = Library.Theme.SubText,
		TextSize               = 12,
		ZIndex                 = 10000,
		Parent                 = TooltipFrame,
	})
	Register(TooltipLabel, "TextColor3", "SubText")
	Padding(TooltipLabel, 0, 0, 8, 8)
end

local function AttachTooltip(instance, text)
	if not text or text == "" then
		return
	end

	Connect(instance.MouseEnter, function()
		if not Library.TooltipEnabled then
			return
		end
		BuildTooltip()
		TooltipLabel.Text = text
		local size = Utility.GetTextSize(text, 12, Enum.Font.Gotham)
		TooltipFrame.Size    = UDim2.fromOffset(size.X + 18, 26)
		TooltipFrame.Visible = true
		TooltipFrame.BackgroundTransparency = 1
		TooltipLabel.TextTransparency       = 1
		Tween(TooltipFrame, 0.15, { BackgroundTransparency = 0.05 })
		Tween(TooltipLabel, 0.15, { TextTransparency = 0 })
	end)

	Connect(instance.MouseLeave, function()
		if TooltipFrame then
			Tween(TooltipFrame, 0.12, { BackgroundTransparency = 1 })
			Tween(TooltipLabel, 0.12, { TextTransparency = 1 }, nil, nil, function()
				if TooltipFrame then
					TooltipFrame.Visible = false
				end
			end)
		end
	end)
end

Library.AttachTooltip = AttachTooltip

Connect(UserInputService.InputChanged, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	if TooltipFrame and TooltipFrame.Visible then
		local location = UserInputService:GetMouseLocation()
		TooltipFrame.Position = UDim2.fromOffset(location.X + 16, location.Y + 4)
	end
end)

--=============================================================================
-- SECTION 16 · NOTIFICATION SYSTEM
--=============================================================================

local NotificationHolder

local function BuildNotificationHolder()
	if NotificationHolder and NotificationHolder.Parent then
		return NotificationHolder
	end

	NotificationHolder = Create("Frame", {
		Name                   = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(1, 1),
		Position               = UDim2.new(1, -18, 1, -18),
		Size                   = UDim2.fromOffset(310, 620),
		ZIndex                 = 9000,
		Parent                 = Library:GetScreenGui(),
	})

	Create("UIListLayout", {
		Padding             = UDim.new(0, 10),
		SortOrder           = Enum.SortOrder.LayoutOrder,
		VerticalAlignment   = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent              = NotificationHolder,
	})

	return NotificationHolder
end

local NotificationIcons = {
	info    = "info",
	success = "play",
	warning = "warning",
	error   = "error",
	default = "info",
}

--- Menampilkan notifikasi.
-- @param config table {Title, Content/Description, Duration, Type, Icon, Buttons}
function Library:Notify(config)
	if typeof(config) == "string" then
		config = { Title = "NekomaruUI", Content = config }
	end
	config = config or {}

	local holder    = BuildNotificationHolder()
	local title     = config.Title or "Notification"
	local content   = config.Content or config.Description or config.Text or ""
	local duration  = config.Duration or config.Time or 5
	local kind      = string.lower(config.Type or "info")
	local theme     = Library.Theme

	local accentColor = theme.Accent
	if kind == "success" then
		accentColor = theme.Success
	elseif kind == "warning" then
		accentColor = theme.Warning
	elseif kind == "error" then
		accentColor = theme.Danger
	end

	local contentSize = Utility.GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(240, math.huge))
	local height = math.clamp(52 + contentSize.Y, 62, 220)

	local frame = Create("Frame", {
		Name                   = "Notification",
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.04,
		BorderSizePixel        = 0,
		Size                   = UDim2.fromOffset(300, height),
		Position               = UDim2.fromOffset(340, 0),
		ClipsDescendants       = true,
		ZIndex                 = 9001,
		Parent                 = holder,
	})
	Corner(frame, 10)
	local frameStroke = Stroke(frame, theme.Border, 1)

	Shadow(frame, 26, 0.6)

	Create("Frame", {
		Name             = "Accent",
		BackgroundColor3 = accentColor,
		BorderSizePixel  = 0,
		Size             = UDim2.new(0, 3, 1, -16),
		Position         = UDim2.fromOffset(0, 8),
		ZIndex           = 9002,
		Parent           = frame,
	})

	local iconImage = Create("ImageLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(16, 14),
		Size                   = UDim2.fromOffset(18, 18),
		Image                  = Library:GetIcon(config.Icon or NotificationIcons[kind] or "info"),
		ImageColor3            = accentColor,
		ZIndex                 = 9002,
		Parent                 = frame,
	})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(44, 12),
		Size                   = UDim2.new(1, -60, 0, 20),
		Font                   = Enum.Font.GothamBold,
		Text                   = title,
		TextColor3             = theme.Text,
		TextSize               = 13,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 9002,
		Parent                 = frame,
	})

	if content ~= "" then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position               = UDim2.fromOffset(44, 32),
			Size                   = UDim2.new(1, -58, 0, contentSize.Y),
			Font                   = Enum.Font.Gotham,
			Text                   = content,
			TextColor3             = theme.SubText,
			TextSize               = 12,
			TextWrapped            = true,
			TextXAlignment         = Enum.TextXAlignment.Left,
			TextYAlignment         = Enum.TextYAlignment.Top,
			ZIndex                 = 9002,
			Parent                 = frame,
		})
	end

	local progress = Create("Frame", {
		Name             = "Progress",
		BackgroundColor3 = accentColor,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0, 0, 1, 0),
		Size             = UDim2.new(1, 0, 0, 2),
		ZIndex           = 9003,
		Parent           = frame,
	})

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Tween(frame, Library.Animation.Notify, {
			Position               = UDim2.fromOffset(340, 0),
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quint, Enum.EasingDirection.In, function()
			pcall(function()
				frame:Destroy()
			end)
		end)
	end

	local closeButton = Create("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(1, 0),
		Position               = UDim2.new(1, -10, 0, 10),
		Size                   = UDim2.fromOffset(20, 20),
		Text                   = "",
		ZIndex                 = 9004,
		Parent                 = frame,
	})
	Create("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromScale(0.5, 0.5),
		Size                   = UDim2.fromOffset(11, 11),
		Image                  = Library:GetIcon("close"),
		ImageColor3            = theme.DimText,
		ZIndex                 = 9004,
		Parent                 = closeButton,
	})
	Connect(closeButton.MouseButton1Click, close)

	-- Animasi masuk
	Tween(frame, Library.Animation.Notify, { Position = UDim2.fromOffset(0, 0) },
		Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Tween(frameStroke, 0.3, { Color = accentColor })
	task.delay(0.4, function()
		if frameStroke and frameStroke.Parent then
			Tween(frameStroke, 0.6, { Color = theme.Border })
		end
	end)

	Library:PlaySound(kind == "error" and "Error" or "Notify", 0.2)

	if duration > 0 then
		Tween(progress, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
		task.delay(duration, close)
	else
		progress.Visible = false
	end

	return {
		Close = close,
		Frame = frame,
		SetTitle = function(_, newTitle)
			local label = frame:FindFirstChildWhichIsA("TextLabel")
			if label then
				label.Text = newTitle
			end
		end,
	}
end

--=============================================================================
-- SECTION 17 · WATERMARK
--=============================================================================

local Watermark = {
	Frame   = nil,
	Label   = nil,
	Enabled = false,
	Text    = "NekomaruUI",
	Custom  = nil,
}

Library.Watermark = Watermark

function Library:SetWatermark(text)
	Watermark.Custom = text
	if Watermark.Label then
		Watermark.Label.Text = text
	end
end

function Library:SetWatermarkVisibility(state)
	Watermark.Enabled = state and true or false

	if state and (not Watermark.Frame or not Watermark.Frame.Parent) then
		local frame = Create("Frame", {
			Name                   = "Watermark",
			BackgroundColor3       = Library.Theme.Section,
			BackgroundTransparency = 0.08,
			BorderSizePixel        = 0,
			Position               = UDim2.fromOffset(18, 18),
			Size                   = UDim2.fromOffset(230, 30),
			ZIndex                 = 8000,
			Parent                 = Library:GetScreenGui(),
		})
		Corner(frame, 8)
		Register(frame, "BackgroundColor3", "Section")
		local stroke = Stroke(frame, Library.Theme.Border, 1)
		Register(stroke, "Color", "Border")

		Create("Frame", {
			BackgroundColor3 = Library.Theme.Accent,
			BorderSizePixel  = 0,
			Size             = UDim2.new(0, 3, 1, -12),
			Position         = UDim2.fromOffset(0, 6),
			ZIndex           = 8001,
			Parent           = frame,
		})

		local label = Create("TextLabel", {
			BackgroundTransparency = 1,
			Position               = UDim2.fromOffset(12, 0),
			Size                   = UDim2.new(1, -24, 1, 0),
			Font                   = Enum.Font.GothamMedium,
			Text                   = Watermark.Custom or "NekomaruUI",
			TextColor3             = Library.Theme.Text,
			TextSize               = 12,
			TextXAlignment         = Enum.TextXAlignment.Left,
			ZIndex                 = 8001,
			Parent                 = frame,
		})
		Register(label, "TextColor3", "Text")

		Watermark.Frame = frame
		Watermark.Label = label

		MakeDraggable(frame, frame)

		task.spawn(function()
			local lastUpdate = 0
			local frames, fps = 0, 60
			while Watermark.Enabled and not Library.Unloaded do
				local delta = RunService.RenderStepped:Wait()
				frames += 1
				lastUpdate += delta
				if lastUpdate >= 1 then
					fps = frames
					frames = 0
					lastUpdate = 0

					local ping = 0
					pcall(function()
						ping = math.floor(
							Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
						)
					end)

					if Watermark.Custom then
						label.Text = Watermark.Custom
					else
						label.Text = string.format(
							"NekomaruUI  |  %d fps  |  %d ms  |  %s",
							fps, ping, os.date("%H:%M:%S")
						)
					end

					local size = Utility.GetTextSize(label.Text, 12, Enum.Font.GothamMedium)
					Tween(frame, 0.2, { Size = UDim2.fromOffset(size.X + 30, 30) })
				end
			end
		end)
	elseif Watermark.Frame then
		Watermark.Frame.Visible = state and true or false
	end
end

--=============================================================================
-- SECTION 18 · GLOBAL KEY HANDLING
--=============================================================================

local KeybindCallbacks = {}

Connect(UserInputService.InputBegan, function(input, processed)
	if Library.Unloaded then
		return
	end

	for _, entry in pairs(KeybindCallbacks) do
		if entry.Key and input.KeyCode == entry.Key and not processed then
			task.spawn(entry.Callback, input)
		elseif entry.Key and input.UserInputType == entry.Key then
			task.spawn(entry.Callback, input)
		end
	end

	if processed then
		return
	end

	if input.KeyCode == Library.ToggleKey then
		Library:Toggle()
	elseif input.KeyCode == Library.MinimizeKey and Library.ActiveWindow then
		Library.ActiveWindow:ToggleMinimize()
	end
end)

function Library:BindKey(id, key, callback)
	KeybindCallbacks[id] = { Key = key, Callback = callback }
end

function Library:UnbindKey(id)
	KeybindCallbacks[id] = nil
end

function Library:SetToggleKey(key)
	Library.ToggleKey = key
end

function Library:Toggle(state)
	if state == nil then
		state = not Library.Toggled
	end
	Library.Toggled = state

	for _, window in ipairs(Library.Windows) do
		if state then
			window:Show()
		else
			window:Hide()
		end
	end
end
--=============================================================================
-- SECTION 19 · WINDOW
--=============================================================================

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

Library.WindowClass  = Window
Library.TabClass     = Tab
Library.SectionClass = Section

--- Membuat window utama.
-- @param config table {
--   Title, SubTitle, Icon, Size, Position, Theme, Center, AutoShow,
--   ToggleKey, MinimizeKey, Resizable, Blur, Footer, TabWidth
-- }
function Library:CreateWindow(config)
	config = config or {}

	local theme = Library.Theme
	if config.Theme then
		Library:SetTheme(config.Theme, false)
		theme = Library.Theme
	end

	local screenGui = Library:GetScreenGui()

	local self = setmetatable({}, Window)
	self.Title        = config.Title or "NekomaruUI"
	self.SubTitle     = config.SubTitle or config.Subtitle or ("v" .. Library.Version)
	self.Icon         = config.Icon or "icon"
	self.Tabs         = {}
	self.TabOrder     = 0
	self.ActiveTab    = nil
	self.Minimized    = false
	self.Visible      = false
	self.Resizable    = config.Resizable ~= false
	self.TabWidth     = config.TabWidth or 168
	self.SearchQuery  = ""
	self.Destroyed    = false

	local size = config.Size or UDim2.fromOffset(780, 520)
	if typeof(size) == "Vector2" then
		size = UDim2.fromOffset(size.X, size.Y)
	end
	self.WindowSize = size

	Library.ToggleKey   = config.ToggleKey or Library.ToggleKey
	Library.MinimizeKey = config.MinimizeKey or Library.MinimizeKey

	-------------------------------------------------------------------------
	-- Root holder (untuk shadow + scale animation)
	-------------------------------------------------------------------------
	local holder = Create("Frame", {
		Name                   = "WindowHolder",
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = config.Position or UDim2.fromScale(0.5, 0.5),
		Size                   = size,
		Visible                = false,
		ZIndex                 = 10,
		Parent                 = screenGui,
	})
	self.Holder = holder

	local scale = Create("UIScale", { Scale = 0.92, Parent = holder })
	self.Scale = scale

	Shadow(holder, 60, 0.55)

	-------------------------------------------------------------------------
	-- Main frame
	-------------------------------------------------------------------------
	local main = Create("Frame", {
		Name                   = "Main",
		BackgroundColor3       = theme.Background,
		BackgroundTransparency = 0.04,
		BorderSizePixel        = 0,
		Size                   = UDim2.fromScale(1, 1),
		ClipsDescendants       = true,
		ZIndex                 = 11,
		Parent                 = holder,
	})
	Corner(main, 12)
	Register(main, "BackgroundColor3", "Background")
	self.Main = main

	local mainStroke = Stroke(main, theme.Border, 1.2)
	Register(mainStroke, "Color", "Border")

	-- Gradient halus supaya terlihat "glass"
	Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 225, 240)),
		}),
		Rotation = 90,
		Parent   = main,
	})

	-------------------------------------------------------------------------
	-- Topbar
	-------------------------------------------------------------------------
	local topbar = Create("Frame", {
		Name                   = "Topbar",
		BackgroundColor3       = theme.Topbar,
		BackgroundTransparency = 0.15,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 46),
		ZIndex                 = 13,
		Parent                 = main,
	})
	Register(topbar, "BackgroundColor3", "Topbar")
	self.Topbar = topbar

	Create("Frame", {
		Name             = "TopbarLine",
		BackgroundColor3 = theme.Border,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0, 0, 1, 0),
		Size             = UDim2.new(1, 0, 0, 1),
		ZIndex           = 14,
		Parent           = topbar,
	})

	-- Logo (icon.png)
	local logoButton = Create("ImageButton", {
		Name                   = "Logo",
		BackgroundColor3       = theme.Element,
		BackgroundTransparency = 0.25,
		BorderSizePixel        = 0,
		Position               = UDim2.fromOffset(12, 9),
		Size                   = UDim2.fromOffset(28, 28),
		Image                  = Library:GetIcon(self.Icon),
		ScaleType              = Enum.ScaleType.Fit,
		ZIndex                 = 15,
		AutoButtonColor        = false,
		Parent                 = topbar,
	})
	Corner(logoButton, 8)
	Register(logoButton, "BackgroundColor3", "Element")
	self.LogoButton = logoButton
	AttachTooltip(logoButton, "Klik untuk minimize ke icon")

	local titleLabel = Create("TextLabel", {
		Name                   = "Title",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(50, 7),
		Size                   = UDim2.new(0, 260, 0, 18),
		Font                   = Enum.Font.GothamBold,
		Text                   = self.Title,
		TextColor3             = theme.Text,
		TextSize               = 14,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 15,
		Parent                 = topbar,
	})
	Register(titleLabel, "TextColor3", "Text")
	self.TitleLabel = titleLabel

	local subTitleLabel = Create("TextLabel", {
		Name                   = "SubTitle",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(50, 24),
		Size                   = UDim2.new(0, 260, 0, 14),
		Font                   = Enum.Font.Gotham,
		Text                   = self.SubTitle,
		TextColor3             = theme.DimText,
		TextSize               = 11,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 15,
		Parent                 = topbar,
	})
	Register(subTitleLabel, "TextColor3", "DimText")
	self.SubTitleLabel = subTitleLabel

	-- Search box
	local searchBox = Create("Frame", {
		Name                   = "Search",
		BackgroundColor3       = theme.Element,
		BackgroundTransparency = 0.2,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(1, 0.5),
		Position               = UDim2.new(1, -96, 0.5, 0),
		Size                   = UDim2.fromOffset(180, 28),
		ZIndex                 = 15,
		Parent                 = topbar,
	})
	Corner(searchBox, 8)
	Register(searchBox, "BackgroundColor3", "Element")
	local searchStroke = Stroke(searchBox, theme.Border, 1)

	Create("ImageLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(8, 7),
		Size                   = UDim2.fromOffset(14, 14),
		Image                  = Library:GetIcon("eye"),
		ImageColor3            = theme.DimText,
		ZIndex                 = 16,
		Parent                 = searchBox,
	})

	local searchInput = Create("TextBox", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(28, 0),
		Size                   = UDim2.new(1, -36, 1, 0),
		Font                   = Enum.Font.Gotham,
		PlaceholderText        = "Cari fitur...",
		PlaceholderColor3      = theme.Placeholder,
		Text                   = "",
		TextColor3             = theme.Text,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ClearTextOnFocus       = false,
		ZIndex                 = 16,
		Parent                 = searchBox,
	})
	Register(searchInput, "TextColor3", "Text")
	self.SearchInput = searchInput

	Connect(searchInput.Focused, function()
		Tween(searchStroke, 0.2, { Color = theme.Accent })
	end)
	Connect(searchInput.FocusLost, function()
		Tween(searchStroke, 0.2, { Color = Library.Theme.Border })
	end)
	Connect(searchInput:GetPropertyChangedSignal("Text"), function()
		self.SearchQuery = searchInput.Text
		self:ApplySearch(searchInput.Text)
	end)

	-- Tombol minimize & close
	local function makeTopButton(iconName, offsetX, tooltip, danger)
		local button = Create("TextButton", {
			BackgroundColor3       = theme.Element,
			BackgroundTransparency = 0.35,
			BorderSizePixel        = 0,
			AnchorPoint            = Vector2.new(1, 0.5),
			Position               = UDim2.new(1, offsetX, 0.5, 0),
			Size                   = UDim2.fromOffset(28, 28),
			Text                   = "",
			AutoButtonColor        = false,
			ZIndex                 = 15,
			Parent                 = topbar,
		})
		Corner(button, 8)

		local image = Create("ImageLabel", {
			BackgroundTransparency = 1,
			AnchorPoint            = Vector2.new(0.5, 0.5),
			Position               = UDim2.fromScale(0.5, 0.5),
			Size                   = UDim2.fromOffset(13, 13),
			Image                  = Library:GetIcon(iconName),
			ImageColor3            = theme.SubText,
			ZIndex                 = 16,
			Parent                 = button,
		})

		Connect(button.MouseEnter, function()
			Tween(button, Library.Animation.Hover, {
				BackgroundTransparency = 0,
				BackgroundColor3       = danger and Library.Theme.Danger or Library.Theme.ElementHover,
			})
			Tween(image, Library.Animation.Hover, { ImageColor3 = Library.Theme.Text })
		end)
		Connect(button.MouseLeave, function()
			Tween(button, Library.Animation.Hover, {
				BackgroundTransparency = 0.35,
				BackgroundColor3       = Library.Theme.Element,
			})
			Tween(image, Library.Animation.Hover, { ImageColor3 = Library.Theme.SubText })
		end)

		AttachTooltip(button, tooltip)
		return button, image
	end

	local minimizeButton = makeTopButton("minimize", -46, "Minimize (ke icon)")
	local closeButton    = makeTopButton("close", -12, "Tutup UI", true)

	Connect(minimizeButton.MouseButton1Click, function()
		Library:PlaySound("Click", 0.15)
		self:Minimize()
	end)
	Connect(closeButton.MouseButton1Click, function()
		Library:PlaySound("Click", 0.15)
		self:Close()
	end)
	Connect(logoButton.MouseButton1Click, function()
		Library:PlaySound("Click", 0.15)
		self:Minimize()
	end)

	MakeDraggable(topbar, holder)

	-------------------------------------------------------------------------
	-- Sidebar
	-------------------------------------------------------------------------
	local sidebar = Create("Frame", {
		Name                   = "Sidebar",
		BackgroundColor3       = theme.Sidebar,
		BackgroundTransparency = 0.1,
		BorderSizePixel        = 0,
		Position               = UDim2.fromOffset(0, 46),
		Size                   = UDim2.new(0, self.TabWidth, 1, -46),
		ZIndex                 = 12,
		Parent                 = main,
	})
	Register(sidebar, "BackgroundColor3", "Sidebar")
	self.Sidebar = sidebar

	Create("Frame", {
		Name             = "SidebarLine",
		BackgroundColor3 = theme.Border,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(1, 0),
		Position         = UDim2.new(1, 0, 0, 0),
		Size             = UDim2.new(0, 1, 1, 0),
		ZIndex           = 13,
		Parent           = sidebar,
	})

	local tabList = Create("ScrollingFrame", {
		Name                   = "TabList",
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Position               = UDim2.fromOffset(0, 8),
		Size                   = UDim2.new(1, 0, 1, -66),
		CanvasSize             = UDim2.new(),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollBarThickness     = 2,
		ScrollBarImageColor3   = theme.Accent,
		ScrollBarImageTransparency = 0.4,
		ZIndex                 = 13,
		Parent                 = sidebar,
	})
	ListLayout(tabList, 4)
	Padding(tabList, 4, 8, 8, 8)
	self.TabList = tabList

	-- Indicator aktif (garis cyan yang bergerak halus)
	local indicator = Create("Frame", {
		Name             = "Indicator",
		BackgroundColor3 = theme.Accent,
		BorderSizePixel  = 0,
		Position         = UDim2.fromOffset(0, 12),
		Size             = UDim2.fromOffset(3, 0),
		ZIndex           = 16,
		Parent           = sidebar,
	})
	Corner(indicator, 2)
	Register(indicator, "BackgroundColor3", "Accent")
	self.Indicator = indicator

	-- Footer sidebar (player info)
	local footer = Create("Frame", {
		Name                   = "Footer",
		BackgroundColor3       = theme.Element,
		BackgroundTransparency = 0.4,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(0, 1),
		Position               = UDim2.new(0, 8, 1, -8),
		Size                   = UDim2.new(1, -16, 0, 44),
		ZIndex                 = 13,
		Parent                 = sidebar,
	})
	Corner(footer, 9)
	Register(footer, "BackgroundColor3", "Element")

	local avatar = Create("ImageLabel", {
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0,
		BorderSizePixel        = 0,
		Position               = UDim2.fromOffset(7, 7),
		Size                   = UDim2.fromOffset(30, 30),
		Image                  = Library:GetIcon("user"),
		ImageColor3            = theme.SubText,
		ZIndex                 = 14,
		Parent                 = footer,
	})
	Corner(avatar, 8)

	task.spawn(function()
		if not LocalPlayer then
			return
		end
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				LocalPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and content then
			avatar.Image       = content
			avatar.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(44, 6),
		Size                   = UDim2.new(1, -52, 0, 16),
		Font                   = Enum.Font.GothamMedium,
		Text                   = LocalPlayer and LocalPlayer.DisplayName or "Player",
		TextColor3             = theme.Text,
		TextSize               = 12,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 14,
		Parent                 = footer,
	})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(44, 22),
		Size                   = UDim2.new(1, -52, 0, 14),
		Font                   = Enum.Font.Gotham,
		Text                   = ExecutorName,
		TextColor3             = theme.DimText,
		TextSize               = 10,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 14,
		Parent                 = footer,
	})

	-------------------------------------------------------------------------
	-- Content container
	-------------------------------------------------------------------------
	local container = Create("Frame", {
		Name                   = "Container",
		BackgroundColor3       = theme.BackgroundAlt,
		BackgroundTransparency = 0.35,
		BorderSizePixel        = 0,
		Position               = UDim2.fromOffset(self.TabWidth + 1, 46),
		Size                   = UDim2.new(1, -self.TabWidth - 1, 1, -46),
		ClipsDescendants       = true,
		ZIndex                 = 12,
		Parent                 = main,
	})
	Register(container, "BackgroundColor3", "BackgroundAlt")
	self.Container = container

	-- Header halaman aktif
	local pageHeader = Create("Frame", {
		Name                   = "PageHeader",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 44),
		ZIndex                 = 13,
		Parent                 = container,
	})

	local pageIcon = Create("ImageLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(16, 14),
		Size                   = UDim2.fromOffset(16, 16),
		Image                  = Library:GetIcon("home"),
		ImageColor3            = theme.Accent,
		ZIndex                 = 14,
		Parent                 = pageHeader,
	})
	Register(pageIcon, "ImageColor3", "Accent")
	self.PageIcon = pageIcon

	local pageTitle = Create("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(40, 12),
		Size                   = UDim2.new(1, -56, 0, 20),
		Font                   = Enum.Font.GothamBold,
		Text                   = "",
		TextColor3             = theme.Text,
		TextSize               = 15,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 14,
		Parent                 = pageHeader,
	})
	Register(pageTitle, "TextColor3", "Text")
	self.PageTitle = pageTitle

	Create("Frame", {
		BackgroundColor3 = theme.Border,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0, 12, 1, 0),
		Size             = UDim2.new(1, -24, 0, 1),
		BackgroundTransparency = 0.4,
		ZIndex           = 14,
		Parent           = pageHeader,
	})

	local pageHolder = Create("Frame", {
		Name                   = "Pages",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(0, 44),
		Size                   = UDim2.new(1, 0, 1, -66),
		ClipsDescendants       = true,
		ZIndex                 = 13,
		Parent                 = container,
	})
	self.PageHolder = pageHolder

	-------------------------------------------------------------------------
	-- Status bar
	-------------------------------------------------------------------------
	local statusBar = Create("Frame", {
		Name                   = "StatusBar",
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0, 1),
		Position               = UDim2.new(0, 0, 1, 0),
		Size                   = UDim2.new(1, 0, 0, 22),
		ZIndex                 = 14,
		Parent                 = container,
	})

	local statusLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(16, 0),
		Size                   = UDim2.new(1, -32, 1, 0),
		Font                   = Enum.Font.Gotham,
		Text                   = config.Footer or ("NekomaruUI v" .. Library.Version .. "  ·  " .. ExecutorName),
		TextColor3             = theme.DimText,
		TextSize               = 10,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 15,
		Parent                 = statusBar,
	})
	Register(statusLabel, "TextColor3", "DimText")
	self.StatusLabel = statusLabel

	function self:SetStatus(text)
		statusLabel.Text = text
	end

	-------------------------------------------------------------------------
	-- Resize handle
	-------------------------------------------------------------------------
	if self.Resizable then
		local resize = Create("TextButton", {
			Name                   = "Resize",
			BackgroundTransparency = 1,
			AnchorPoint            = Vector2.new(1, 1),
			Position               = UDim2.fromScale(1, 1),
			Size                   = UDim2.fromOffset(18, 18),
			Text                   = "",
			ZIndex                 = 20,
			Parent                 = main,
		})

		Create("ImageLabel", {
			BackgroundTransparency = 1,
			AnchorPoint            = Vector2.new(0.5, 0.5),
			Position               = UDim2.fromScale(0.5, 0.5),
			Size                   = UDim2.fromOffset(10, 10),
			Rotation               = -45,
			Image                  = Library:GetIcon("arrow"),
			ImageColor3            = theme.DimText,
			ImageTransparency      = 0.3,
			ZIndex                 = 21,
			Parent                 = resize,
		})

		MakeResizable(resize, holder, Vector2.new(560, 380), Vector2.new(1200, 800), function(newSize)
			container.Size  = UDim2.new(1, -self.TabWidth - 1, 1, -46)
			self.WindowSize = UDim2.fromOffset(newSize.X, newSize.Y)
		end)
	end

	-------------------------------------------------------------------------
	-- Floating icon (minimize target)
	-------------------------------------------------------------------------
	local floating = Create("ImageButton", {
		Name                   = "FloatingIcon",
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.05,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = config.IconPosition or UDim2.new(0, 70, 0.5, 0),
		Size                   = UDim2.fromOffset(52, 52),
		Image                  = "",
		AutoButtonColor        = false,
		Visible                = false,
		ZIndex                 = 30,
		Parent                 = screenGui,
	})
	Corner(floating, 14)
	Register(floating, "BackgroundColor3", "Section")
	local floatingStroke = Stroke(floating, theme.Accent, 1.4, 0.35)
	Register(floatingStroke, "Color", "Accent")
	Shadow(floating, 34, 0.5)
	self.FloatingIcon = floating

	local floatingScale = Create("UIScale", { Scale = 0.6, Parent = floating })
	self.FloatingScale = floatingScale

	local floatingImage = Create("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromScale(0.5, 0.5),
		Size                   = UDim2.fromOffset(32, 32),
		Image                  = Library:GetIcon(self.Icon),
		ScaleType              = Enum.ScaleType.Fit,
		ZIndex                 = 31,
		Parent                 = floating,
	})
	self.FloatingImage = floatingImage

	-- Ring glow berputar pelan
	local ring = Create("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromScale(0.5, 0.5),
		Size                   = UDim2.fromOffset(70, 70),
		Image                  = "rbxassetid://6015897843",
		ImageColor3            = theme.Accent,
		ImageTransparency      = 0.75,
		ScaleType              = Enum.ScaleType.Slice,
		SliceCenter            = Rect.new(49, 49, 450, 450),
		ZIndex                 = 29,
		Parent                 = floating,
	})
	Register(ring, "ImageColor3", "Accent")

	AttachTooltip(floating, "Klik untuk buka/tutup " .. self.Title)

	local dragged = false
	MakeDraggable(floating, floating, function()
		dragged = true
		task.delay(0.15, function()
			dragged = false
		end)
	end)

	Connect(floating.MouseEnter, function()
		Tween(floatingScale, 0.18, { Scale = 1.1 }, Enum.EasingStyle.Back)
		Tween(floatingStroke, 0.18, { Transparency = 0 })
	end)
	Connect(floating.MouseLeave, function()
		Tween(floatingScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(floatingStroke, 0.18, { Transparency = 0.35 })
	end)
	Connect(floating.MouseButton1Click, function()
		if dragged then
			return
		end
		Library:PlaySound("Click", 0.15)
		self:ToggleMinimize()
	end)

	-- Animasi idle: ring bernapas pelan
	task.spawn(function()
		while not self.Destroyed and not Library.Unloaded do
			if floating.Visible and Library.Animation.Enabled then
				Tween(ring, 1.2, { ImageTransparency = 0.55, Size = UDim2.fromOffset(78, 78) },
					Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(1.2)
				Tween(ring, 1.2, { ImageTransparency = 0.8, Size = UDim2.fromOffset(66, 66) },
					Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(1.2)
			else
				task.wait(0.5)
			end
		end
	end)

	table.insert(Library.Windows, self)
	Library.ActiveWindow = self

	if config.Blur then
		Library:SetBlur(true, 12)
	end

	if config.AutoShow ~= false then
		task.defer(function()
			self:Open()
		end)
	end

	return self
end

--=============================================================================
-- SECTION 20 · WINDOW METHODS
--=============================================================================

function Window:Open()
	if self.Destroyed then
		return
	end

	self.Visible   = true
	self.Minimized = false

	self.Holder.Visible = true
	self.Main.BackgroundTransparency = 1
	self.Scale.Scale = 0.9

	Tween(self.Scale, Library.Animation.Open, { Scale = 1 },
		Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Tween(self.Main, Library.Animation.Open * 0.6, { BackgroundTransparency = 0.04 })

	-- fade-in isi window
	for _, descendant in ipairs(self.Main:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local target = descendant.TextTransparency
			descendant.TextTransparency = 1
			Tween(descendant, Library.Animation.Open * 0.8, { TextTransparency = target })
		elseif descendant:IsA("ImageLabel") and descendant.Name ~= "Shadow" then
			local target = descendant.ImageTransparency
			descendant.ImageTransparency = 1
			Tween(descendant, Library.Animation.Open * 0.8, { ImageTransparency = target })
		end
	end

	if self.FloatingIcon.Visible then
		Tween(self.FloatingScale, Library.Animation.Minimize, { Scale = 0.5 },
			Enum.EasingStyle.Back, Enum.EasingDirection.In, function()
				self.FloatingIcon.Visible = false
			end)
	end

	Library:PlaySound("Open", 0.2)
end

function Window:Minimize()
	if self.Minimized or self.Destroyed then
		return
	end

	self.Minimized = true

	Tween(self.Scale, Library.Animation.Minimize, { Scale = 0.85 },
		Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(self.Main, Library.Animation.Minimize, { BackgroundTransparency = 1 },
		nil, nil, function()
			if self.Minimized then
				self.Holder.Visible = false
			end
		end)

	self.FloatingIcon.Visible = true
	self.FloatingScale.Scale  = 0.5
	Tween(self.FloatingScale, Library.Animation.Minimize, { Scale = 1 },
		Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function Window:Maximize()
	if not self.Minimized or self.Destroyed then
		return
	end
	self:Open()
end

function Window:ToggleMinimize()
	if self.Minimized then
		self:Maximize()
	else
		self:Minimize()
	end
end

function Window:Show()
	if self.Minimized then
		self.FloatingIcon.Visible = true
	else
		self:Open()
	end
end

function Window:Hide()
	self.Visible = false
	Tween(self.Scale, Library.Animation.Close, { Scale = 0.9 },
		Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(self.Main, Library.Animation.Close, { BackgroundTransparency = 1 },
		nil, nil, function()
			self.Holder.Visible = false
		end)
	self.FloatingIcon.Visible = false
end

function Window:Close()
	self:Minimize()
end

function Window:Destroy()
	self.Destroyed = true
	Tween(self.Scale, 0.2, { Scale = 0.85 })
	Tween(self.Main, 0.2, { BackgroundTransparency = 1 }, nil, nil, function()
		pcall(function()
			self.Holder:Destroy()
		end)
	end)
	pcall(function()
		self.FloatingIcon:Destroy()
	end)
end

function Window:SetTitle(text)
	self.Title = text
	self.TitleLabel.Text = text
end

function Window:SetSubTitle(text)
	self.SubTitle = text
	self.SubTitleLabel.Text = text
end

function Window:SetIcon(icon)
	self.Icon = icon
	local resolved = Library:GetIcon(icon)
	self.LogoButton.Image   = resolved
	self.FloatingImage.Image = resolved
end

function Window:SetSize(size)
	if typeof(size) == "Vector2" then
		size = UDim2.fromOffset(size.X, size.Y)
	end
	self.WindowSize = size
	Tween(self.Holder, 0.3, { Size = size })
end

--- Filter elemen berdasarkan teks pencarian pada topbar.
function Window:ApplySearch(query)
	query = Utility.TrimString(query or "")

	for _, tab in ipairs(self.Tabs) do
		for _, section in ipairs(tab.Sections) do
			local visibleCount = 0
			for _, element in ipairs(section.Elements) do
				local match = query == ""
					or Utility.Search(element.Name or "", query)
					or Utility.Search(element.Description or "", query)
				if element.Frame then
					element.Frame.Visible = match
				end
				if match then
					visibleCount += 1
				end
			end
			if section.Frame then
				section.Frame.Visible = visibleCount > 0
			end
		end
	end
end
--=============================================================================
-- SECTION 21 · TAB
--=============================================================================

--- Menambah tab baru pada window.
-- @param config {Name/Title, Icon, Description, Columns}
function Window:AddTab(config)
	if typeof(config) == "string" then
		config = { Name = config }
	end
	config = config or {}

	local theme = Library.Theme
	local self_ = self

	local tab = setmetatable({}, Tab)
	tab.Window      = self
	tab.Name        = config.Name or config.Title or "Tab"
	tab.Icon        = config.Icon or "home"
	tab.Description = config.Description or ""
	tab.Sections    = {}
	tab.Elements    = {}
	tab.Columns     = config.Columns or 1

	self.TabOrder += 1
	tab.Order = self.TabOrder

	-------------------------------------------------------------------------
	-- Tombol tab di sidebar
	-------------------------------------------------------------------------
	local button = Create("TextButton", {
		Name                   = "Tab_" .. tab.Name,
		BackgroundColor3       = theme.Element,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 34),
		Text                   = "",
		AutoButtonColor        = false,
		LayoutOrder            = tab.Order,
		ClipsDescendants       = true,
		ZIndex                 = 14,
		Parent                 = self.TabList,
	})
	Corner(button, 8)
	tab.Button = button

	local icon = Create("ImageLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(10, 9),
		Size                   = UDim2.fromOffset(16, 16),
		Image                  = Library:GetIcon(tab.Icon),
		ImageColor3            = theme.DimText,
		ZIndex                 = 15,
		Parent                 = button,
	})
	tab.IconLabel = icon

	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(34, 0),
		Size                   = UDim2.new(1, -44, 1, 0),
		Font                   = Enum.Font.GothamMedium,
		Text                   = tab.Name,
		TextColor3             = theme.SubText,
		TextSize               = 12,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 15,
		Parent                 = button,
	})
	tab.Label = label

	Connect(button.MouseEnter, function()
		if self_.ActiveTab ~= tab then
			Tween(button, Library.Animation.Hover, { BackgroundTransparency = 0.5,
				BackgroundColor3 = Library.Theme.ElementHover })
			Tween(label, Library.Animation.Hover, { TextColor3 = Library.Theme.Text })
			Tween(icon, Library.Animation.Hover, { ImageColor3 = Library.Theme.Text })
		end
	end)
	Connect(button.MouseLeave, function()
		if self_.ActiveTab ~= tab then
			Tween(button, Library.Animation.Hover, { BackgroundTransparency = 1 })
			Tween(label, Library.Animation.Hover, { TextColor3 = Library.Theme.SubText })
			Tween(icon, Library.Animation.Hover, { ImageColor3 = Library.Theme.DimText })
		end
	end)
	Connect(button.MouseButton1Click, function()
		Library:PlaySound("Click", 0.12)
		Ripple(button)
		self_:SelectTab(tab)
	end)

	-------------------------------------------------------------------------
	-- Halaman konten
	-------------------------------------------------------------------------
	local page = Create("ScrollingFrame", {
		Name                   = "Page_" .. tab.Name,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Size                   = UDim2.fromScale(1, 1),
		CanvasSize             = UDim2.new(),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollBarThickness     = 3,
		ScrollBarImageColor3   = theme.Accent,
		ScrollBarImageTransparency = 0.35,
		Visible                = false,
		ZIndex                 = 13,
		Parent                 = self.PageHolder,
	})
	Padding(page, 12, 18, 14, 14)
	tab.Page = page

	if tab.Columns > 1 then
		Create("UIGridLayout", {
			CellSize          = UDim2.new(0.5, -8, 0, 0),
			CellPadding       = UDim2.fromOffset(12, 12),
			SortOrder         = Enum.SortOrder.LayoutOrder,
			FillDirectionMaxCells = tab.Columns,
			Parent            = page,
		})
	else
		ListLayout(page, 10)
	end

	table.insert(self.Tabs, tab)

	if not self.ActiveTab then
		self:SelectTab(tab)
	end

	return tab
end

Window.CreateTab = Window.AddTab

--- Pindah tab dengan animasi slide + fade.
function Window:SelectTab(target)
	if typeof(target) == "number" then
		target = self.Tabs[target]
	elseif typeof(target) == "string" then
		for _, tab in ipairs(self.Tabs) do
			if tab.Name == target then
				target = tab
				break
			end
		end
	end

	if typeof(target) ~= "table" or target == self.ActiveTab then
		return
	end

	local previous = self.ActiveTab
	self.ActiveTab = target

	-- Reset visual tab lain
	for _, tab in ipairs(self.Tabs) do
		local active = tab == target
		Tween(tab.Button, Library.Animation.Tab, {
			BackgroundTransparency = active and 0.15 or 1,
			BackgroundColor3       = active and Library.Theme.ElementActive or Library.Theme.Element,
		})
		Tween(tab.Label, Library.Animation.Tab, {
			TextColor3 = active and Library.Theme.Text or Library.Theme.SubText,
		})
		Tween(tab.IconLabel, Library.Animation.Tab, {
			ImageColor3 = active and Library.Theme.Accent or Library.Theme.DimText,
		})
	end

	-- Indicator geser halus
	local buttonPos = target.Button.AbsolutePosition.Y - self.Sidebar.AbsolutePosition.Y
	Tween(self.Indicator, Library.Animation.Tab, {
		Position = UDim2.fromOffset(0, buttonPos + 8),
		Size     = UDim2.fromOffset(3, 18),
	}, Enum.EasingStyle.Quint)

	-- Header
	self.PageTitle.Text = target.Name
	self.PageIcon.Image = Library:GetIcon(target.Icon)

	-- Transisi halaman
	if previous and previous.Page then
		local oldPage = previous.Page
		Tween(oldPage, Library.Animation.Tab * 0.6, {
			Position = UDim2.fromOffset(-24, 0),
		}, Enum.EasingStyle.Quint, Enum.EasingDirection.In, function()
			oldPage.Visible  = false
			oldPage.Position = UDim2.fromOffset(0, 0)
		end)
	end

	target.Page.Visible  = true
	target.Page.Position = UDim2.fromOffset(28, 0)
	Tween(target.Page, Library.Animation.Tab, { Position = UDim2.fromOffset(0, 0) },
		Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	-- Elemen muncul bertahap (stagger)
	if Library.Animation.Enabled then
		task.spawn(function()
			local index = 0
			for _, section in ipairs(target.Sections) do
				if section.Frame and section.Frame.Visible then
					index += 1
					local frame = section.Frame
					local sectionScale = frame:FindFirstChildOfClass("UIScale")
						or Create("UIScale", { Scale = 1, Parent = frame })
					sectionScale.Scale = 0.97
					task.delay(index * 0.03, function()
						Tween(sectionScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
					end)
				end
			end
		end)
	end

	if self.SearchQuery ~= "" then
		self:ApplySearch(self.SearchQuery)
	end
end

function Tab:Select()
	self.Window:SelectTab(self)
end

function Tab:SetName(name)
	self.Name = name
	self.Label.Text = name
end

function Tab:SetIcon(icon)
	self.Icon = icon
	self.IconLabel.Image = Library:GetIcon(icon)
end

--=============================================================================
-- SECTION 22 · SECTION (GROUPBOX)
--=============================================================================

--- Menambah section (kotak grup) di dalam tab.
function Tab:AddSection(config)
	if typeof(config) == "string" then
		config = { Name = config }
	end
	config = config or {}

	local theme = Library.Theme

	local section = setmetatable({}, Section)
	section.Tab      = self
	section.Window   = self.Window
	section.Name     = config.Name or config.Title or "Section"
	section.Elements = {}

	local frame = Create("Frame", {
		Name                   = "Section_" .. section.Name,
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.25,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 40),
		AutomaticSize          = Enum.AutomaticSize.Y,
		LayoutOrder            = #self.Sections + 1,
		ZIndex                 = 14,
		Parent                 = self.Page,
	})
	Corner(frame, 10)
	Register(frame, "BackgroundColor3", "Section")
	local stroke = Stroke(frame, theme.Border, 1, 0.2)
	Register(stroke, "Color", "Border")
	section.Frame = frame

	Create("UIScale", { Scale = 1, Parent = frame })

	local header = Create("TextLabel", {
		Name                   = "Header",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(14, 10),
		Size                   = UDim2.new(1, -28, 0, 18),
		Font                   = Enum.Font.GothamBold,
		Text                   = section.Name,
		TextColor3             = theme.Text,
		TextSize               = 13,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 15,
		Parent                 = frame,
	})
	Register(header, "TextColor3", "Text")
	section.Header = header

	if config.Description and config.Description ~= "" then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position               = UDim2.fromOffset(14, 28),
			Size                   = UDim2.new(1, -28, 0, 14),
			Font                   = Enum.Font.Gotham,
			Text                   = config.Description,
			TextColor3             = theme.DimText,
			TextSize               = 11,
			TextXAlignment         = Enum.TextXAlignment.Left,
			ZIndex                 = 15,
			Parent                 = frame,
		})
	end

	local body = Create("Frame", {
		Name                   = "Body",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(0, config.Description and 46 or 32),
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		ZIndex                 = 15,
		Parent                 = frame,
	})
	ListLayout(body, 6)
	Padding(body, 0, 12, 12, 12)
	section.Body = body

	-- Auto-resize frame mengikuti body
	Connect(body:GetPropertyChangedSignal("AbsoluteSize"), function()
		local offset = (config.Description and 46 or 32)
		frame.Size = UDim2.new(1, 0, 0, body.AbsoluteSize.Y + offset)
	end)

	table.insert(self.Sections, section)
	return section
end

Tab.CreateSection = Tab.AddSection
Tab.AddGroupbox   = Tab.AddSection

function Section:SetName(name)
	self.Name = name
	self.Header.Text = name
end

--=============================================================================
-- SECTION 23 · ELEMENT BASE
--=============================================================================

--- Membuat container standar untuk sebuah element.
local function BaseElement(section, config, height)
	local theme = Library.Theme

	local frame = Create("Frame", {
		Name                   = "Element",
		BackgroundColor3       = theme.Element,
		BackgroundTransparency = 0.35,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, height or 34),
		LayoutOrder            = #section.Elements + 1,
		ZIndex                 = 16,
		ClipsDescendants       = true,
		Parent                 = section.Body,
	})
	Corner(frame, 8)
	Register(frame, "BackgroundColor3", "Element")

	local label = Create("TextLabel", {
		Name                   = "Label",
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(12, 0),
		Size                   = UDim2.new(1, -70, 1, 0),
		Font                   = Enum.Font.Gotham,
		Text                   = config.Name or config.Title or "Element",
		TextColor3             = theme.Text,
		TextSize               = 12,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 17,
		Parent                 = frame,
	})
	Register(label, "TextColor3", "Text")

	if config.Tooltip or config.Description then
		AttachTooltip(frame, config.Tooltip or config.Description)
	end

	return frame, label
end

Library.BaseElement = BaseElement

local function RegisterFlag(element, flag, value)
	if flag then
		Library.Flags[flag]   = value
		Library.Options[flag] = element
	end
end

--=============================================================================
-- SECTION 24 · LABEL / PARAGRAPH / DIVIDER
--=============================================================================

function Section:AddLabel(config)
	if typeof(config) == "string" then
		config = { Text = config }
	end
	config = config or {}

	local theme = Library.Theme
	local text  = config.Text or config.Name or ""

	local label = Create("TextLabel", {
		Name                   = "Label",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 18),
		Font                   = Enum.Font.Gotham,
		Text                   = text,
		TextColor3             = config.Color or theme.SubText,
		TextSize               = config.TextSize or 12,
		TextWrapped            = true,
		AutomaticSize          = Enum.AutomaticSize.Y,
		TextXAlignment         = Enum.TextXAlignment.Left,
		LayoutOrder            = #self.Elements + 1,
		ZIndex                 = 16,
		Parent                 = self.Body,
	})

	local element = {
		Type  = "Label",
		Name  = text,
		Frame = label,
		SetText = function(_, newText)
			label.Text = newText
		end,
		Set = function(_, newText)
			label.Text = newText
		end,
	}

	table.insert(self.Elements, element)
	return element
end

function Section:AddParagraph(config)
	config = config or {}
	local theme = Library.Theme

	local frame = Create("Frame", {
		Name                   = "Paragraph",
		BackgroundColor3       = theme.Element,
		BackgroundTransparency = 0.4,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 20),
		AutomaticSize          = Enum.AutomaticSize.Y,
		LayoutOrder            = #self.Elements + 1,
		ZIndex                 = 16,
		Parent                 = self.Body,
	})
	Corner(frame, 8)
	Register(frame, "BackgroundColor3", "Element")
	Padding(frame, 10, 10, 12, 12)

	local list = ListLayout(frame, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder

	local title = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 16),
		Font                   = Enum.Font.GothamBold,
		Text                   = config.Title or config.Name or "Title",
		TextColor3             = theme.Text,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		LayoutOrder            = 1,
		ZIndex                 = 17,
		Parent                 = frame,
	})
	Register(title, "TextColor3", "Text")

	local content = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 14),
		AutomaticSize          = Enum.AutomaticSize.Y,
		Font                   = Enum.Font.Gotham,
		Text                   = config.Content or config.Text or "",
		TextColor3             = theme.SubText,
		TextSize               = 11,
		TextWrapped            = true,
		TextXAlignment         = Enum.TextXAlignment.Left,
		LayoutOrder            = 2,
		ZIndex                 = 17,
		Parent                 = frame,
	})
	Register(content, "TextColor3", "SubText")

	local element = {
		Type  = "Paragraph",
		Name  = title.Text,
		Description = content.Text,
		Frame = frame,
		SetTitle = function(_, value)
			title.Text = value
		end,
		SetContent = function(_, value)
			content.Text = value
		end,
	}

	table.insert(self.Elements, element)
	return element
end

function Section:AddDivider()
	local theme = Library.Theme
	local frame = Create("Frame", {
		Name                   = "Divider",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 8),
		LayoutOrder            = #self.Elements + 1,
		ZIndex                 = 16,
		Parent                 = self.Body,
	})

	local line = Create("Frame", {
		BackgroundColor3       = theme.Border,
		BackgroundTransparency = 0.3,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(0, 0.5),
		Position               = UDim2.new(0, 0, 0.5, 0),
		Size                   = UDim2.new(1, 0, 0, 1),
		ZIndex                 = 16,
		Parent                 = frame,
	})
	Register(line, "BackgroundColor3", "Border")

	local element = { Type = "Divider", Name = "", Frame = frame }
	table.insert(self.Elements, element)
	return element
end

--=============================================================================
-- SECTION 25 · BUTTON
--=============================================================================

function Section:AddButton(config)
	config = config or {}
	local theme = Library.Theme

	local button = Create("TextButton", {
		Name                   = "Button",
		BackgroundColor3       = theme.Element,
		BackgroundTransparency = 0.2,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 34),
		Font                   = Enum.Font.GothamMedium,
		Text                   = config.Name or config.Title or "Button",
		TextColor3             = theme.Text,
		TextSize               = 12,
		AutoButtonColor        = false,
		ClipsDescendants       = true,
		LayoutOrder            = #self.Elements + 1,
		ZIndex                 = 16,
		Parent                 = self.Body,
	})
	Corner(button, 8)
	Register(button, "BackgroundColor3", "Element")
	Register(button, "TextColor3", "Text")
	local stroke = Stroke(button, theme.Border, 1, 0.4)

	Pressable(button)
	Connect(button.MouseEnter, function()
		Tween(button, Library.Animation.Hover, {
			BackgroundColor3       = Library.Theme.ElementHover,
			BackgroundTransparency = 0,
		})
		Tween(stroke, Library.Animation.Hover, { Color = Library.Theme.Accent, Transparency = 0.2 })
	end)
	Connect(button.MouseLeave, function()
		Tween(button, Library.Animation.Hover, {
			BackgroundColor3       = Library.Theme.Element,
			BackgroundTransparency = 0.2,
		})
		Tween(stroke, Library.Animation.Hover, { Color = Library.Theme.Border, Transparency = 0.4 })
	end)

	local callback = config.Callback or config.Func or function() end

	Connect(button.MouseButton1Click, function()
		Ripple(button)
		Library:PlaySound("Click", 0.15)
		local ok, err = pcall(callback)
		if not ok then
			Library:Notify({
				Title = "Callback Error",
				Content = tostring(err),
				Type = "error",
			})
		end
	end)

	if config.Tooltip then
		AttachTooltip(button, config.Tooltip)
	end

	local element = {
		Type  = "Button",
		Name  = button.Text,
		Frame = button,
		SetText = function(_, text)
			button.Text = text
		end,
		Fire = function()
			task.spawn(callback)
		end,
	}

	table.insert(self.Elements, element)
	return element
end

--- Beberapa tombol dalam satu baris.
function Section:AddButtonGroup(config)
	config = config or {}
	local buttons = config.Buttons or {}
	local theme   = Library.Theme

	local holder = Create("Frame", {
		Name                   = "ButtonGroup",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 32),
		LayoutOrder            = #self.Elements + 1,
		ZIndex                 = 16,
		Parent                 = self.Body,
	})

	Create("UIListLayout", {
		Padding             = UDim.new(0, 6),
		FillDirection       = Enum.FillDirection.Horizontal,
		SortOrder           = Enum.SortOrder.LayoutOrder,
		Parent              = holder,
	})

	local count = math.max(#buttons, 1)

	for index, info in ipairs(buttons) do
		local button = Create("TextButton", {
			BackgroundColor3       = theme.Element,
			BackgroundTransparency = 0.2,
			BorderSizePixel        = 0,
			Size                   = UDim2.new(1 / count, -6 + 6 / count, 1, 0),
			Font                   = Enum.Font.GothamMedium,
			Text                   = info.Name or info.Title or ("Button " .. index),
			TextColor3             = theme.Text,
			TextSize               = 12,
			AutoButtonColor        = false,
			ClipsDescendants       = true,
			LayoutOrder            = index,
			ZIndex                 = 17,
			Parent                 = holder,
		})
		Corner(button, 8)
		Register(button, "BackgroundColor3", "Element")
		Pressable(button)
		Hoverable(button, "Element", "ElementHover")

		local callback = info.Callback or function() end
		Connect(button.MouseButton1Click, function()
			Ripple(button)
			Library:PlaySound("Click", 0.15)
			pcall(callback)
		end)
	end

	local element = { Type = "ButtonGroup", Name = config.Name or "Buttons", Frame = holder }
	table.insert(self.Elements, element)
	return element
end

--=============================================================================
-- SECTION 26 · TOGGLE
--=============================================================================

function Section:AddToggle(config)
	config = config or {}
	local theme = Library.Theme

	local frame, label = BaseElement(self, config, 34)

	local track = Create("Frame", {
		Name                   = "Track",
		BackgroundColor3       = theme.Border,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(1, 0.5),
		Position               = UDim2.new(1, -12, 0.5, 0),
		Size                   = UDim2.fromOffset(38, 20),
		ZIndex                 = 17,
		Parent                 = frame,
	})
	Corner(track, 10)

	local knob = Create("Frame", {
		Name             = "Knob",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0, 0.5),
		Position         = UDim2.new(0, 3, 0.5, 0),
		Size             = UDim2.fromOffset(14, 14),
		ZIndex           = 18,
		Parent           = track,
	})
	Corner(knob, 8)

	local glow = Create("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.fromScale(0.5, 0.5),
		Size                   = UDim2.new(1, 22, 1, 22),
		Image                  = "rbxassetid://6015897843",
		ImageColor3            = theme.Accent,
		ImageTransparency      = 1,
		ScaleType              = Enum.ScaleType.Slice,
		SliceCenter            = Rect.new(49, 49, 450, 450),
		ZIndex                 = 16,
		Parent                 = track,
	})

	local hitbox = Create("TextButton", {
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
		Text                   = "",
		ZIndex                 = 19,
		Parent                 = frame,
	})

	local value    = config.Default or config.Value or false
	local callback = config.Callback or function() end
	local flag     = config.Flag or config.Name

	local toggle = {
		Type        = "Toggle",
		Name        = config.Name or "Toggle",
		Description = config.Description,
		Frame       = frame,
		Value       = value,
		Flag        = flag,
	}

	function toggle:SetValue(newValue, silent)
		newValue = newValue and true or false
		self.Value = newValue
		Library.Flags[flag or self.Name] = newValue

		Tween(track, Library.Animation.Toggle, {
			BackgroundColor3 = newValue and Library.Theme.Accent or Library.Theme.Border,
		})
		Tween(knob, Library.Animation.Toggle, {
			Position = newValue and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			Size     = UDim2.fromOffset(14, 14),
		}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Tween(label, Library.Animation.Toggle, {
			TextColor3 = newValue and Library.Theme.Text or Library.Theme.SubText,
		})
		Tween(frame, Library.Animation.Toggle, {
			BackgroundTransparency = newValue and 0.1 or 0.35,
		})
		Tween(glow, 0.25, { ImageTransparency = newValue and 0.75 or 1 })

		if not silent then
			task.spawn(function()
				local ok, err = pcall(callback, newValue)
				if not ok then
					Library:Notify({ Title = "Toggle Error", Content = tostring(err), Type = "error" })
				end
			end)
		end
	end

	toggle.Set = toggle.SetValue

	function toggle:GetValue()
		return self.Value
	end

	function toggle:Toggle()
		self:SetValue(not self.Value)
	end

	Connect(hitbox.MouseButton1Click, function()
		Library:PlaySound("Toggle", 0.14)
		toggle:SetValue(not toggle.Value)
	end)

	Hoverable(frame, "Element", "ElementHover")

	toggle:SetValue(value, true)
	RegisterFlag(toggle, flag, value)
	table.insert(self.Elements, toggle)

	if config.Default ~= nil and config.FireOnInit then
		task.spawn(callback, value)
	end

	return toggle
end
--=============================================================================
-- SECTION 27 · SLIDER
--=============================================================================

function Section:AddSlider(config)
	config = config or {}
	local theme = Library.Theme

	local min      = config.Min or config.Minimum or 0
	local max      = config.Max or config.Maximum or 100
	local rounding = config.Rounding or config.Decimals or 0
	local suffix   = config.Suffix or ""
	local callback = config.Callback or function() end
	local flag     = config.Flag or config.Name
	local value    = math.clamp(config.Default or config.Value or min, min, max)

	local frame, label = BaseElement(self, config, 46)
	label.Size     = UDim2.new(1, -90, 0, 20)
	label.Position = UDim2.fromOffset(12, 6)

	local valueLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(1, 0),
		Position               = UDim2.new(1, -12, 0, 6),
		Size                   = UDim2.fromOffset(80, 20),
		Font                   = Enum.Font.GothamBold,
		Text                   = tostring(value) .. suffix,
		TextColor3             = theme.Accent,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Right,
		ZIndex                 = 17,
		Parent                 = frame,
	})
	Register(valueLabel, "TextColor3", "Accent")

	local track = Create("Frame", {
		BackgroundColor3 = theme.Border,
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 12, 0, 32),
		Size             = UDim2.new(1, -24, 0, 6),
		ZIndex           = 17,
		Parent           = frame,
	})
	Corner(track, 3)

	local fill = Create("Frame", {
		BackgroundColor3 = theme.Accent,
		BorderSizePixel  = 0,
		Size             = UDim2.fromScale(0, 1),
		ZIndex           = 18,
		Parent           = track,
	})
	Corner(fill, 3)
	Register(fill, "BackgroundColor3", "Accent")

	local knob = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Position         = UDim2.fromScale(0, 0.5),
		Size             = UDim2.fromOffset(12, 12),
		ZIndex           = 19,
		Parent           = track,
	})
	Corner(knob, 6)

	local hitbox = Create("TextButton", {
		BackgroundTransparency = 1,
		Position               = UDim2.new(0, 0, 0, 24),
		Size                   = UDim2.new(1, 0, 0, 22),
		Text                   = "",
		ZIndex                 = 20,
		Parent                 = frame,
	})

	local slider = {
		Type        = "Slider",
		Name        = config.Name or "Slider",
		Description = config.Description,
		Frame       = frame,
		Value       = value,
		Flag        = flag,
		Min         = min,
		Max         = max,
	}

	function slider:SetValue(newValue, silent)
		newValue = Utility.Round(math.clamp(newValue, min, max), rounding)
		self.Value = newValue
		Library.Flags[flag or self.Name] = newValue

		local alpha = (newValue - min) / math.max(max - min, 1e-6)
		Tween(fill, Library.Animation.Slider, { Size = UDim2.fromScale(alpha, 1) })
		Tween(knob, Library.Animation.Slider, { Position = UDim2.fromScale(alpha, 0.5) })
		valueLabel.Text = tostring(newValue) .. suffix

		if not silent then
			task.spawn(function()
				pcall(callback, newValue)
			end)
		end
	end

	slider.Set = slider.SetValue

	function slider:GetValue()
		return self.Value
	end

	local dragging = false
	local function updateFromInput(input)
		local relative = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
		slider:SetValue(min + (max - min) * math.clamp(relative, 0, 1))
	end

	Connect(hitbox.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Tween(knob, 0.15, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
			updateFromInput(input)
		end
	end)

	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				Tween(knob, 0.15, { Size = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back)
			end
		end
	end)

	Connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input)
		end
	end)

	Hoverable(frame, "Element", "ElementHover")
	slider:SetValue(value, true)
	RegisterFlag(slider, flag, value)
	table.insert(self.Elements, slider)
	return slider
end

--=============================================================================
-- SECTION 28 · INPUT (TEXTBOX)
--=============================================================================

function Section:AddInput(config)
	config = config or {}
	local theme = Library.Theme

	local frame, label = BaseElement(self, config, 34)
	label.Size = UDim2.new(0.42, -12, 1, 0)

	local box = Create("Frame", {
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.1,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(1, 0.5),
		Position               = UDim2.new(1, -10, 0.5, 0),
		Size                   = UDim2.new(0.55, -10, 0, 24),
		ZIndex                 = 17,
		Parent                 = frame,
	})
	Corner(box, 6)
	Register(box, "BackgroundColor3", "Section")
	local stroke = Stroke(box, theme.Border, 1, 0.3)

	local input = Create("TextBox", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(8, 0),
		Size                   = UDim2.new(1, -16, 1, 0),
		Font                   = Enum.Font.Gotham,
		PlaceholderText        = config.Placeholder or "...",
		PlaceholderColor3      = theme.Placeholder,
		Text                   = config.Default or "",
		TextColor3             = theme.Text,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ClearTextOnFocus       = config.ClearOnFocus or false,
		ZIndex                 = 18,
		Parent                 = box,
	})
	Register(input, "TextColor3", "Text")

	local callback = config.Callback or function() end
	local flag     = config.Flag or config.Name

	local element = {
		Type        = "Input",
		Name        = config.Name or "Input",
		Description = config.Description,
		Frame       = frame,
		Value       = input.Text,
		Flag        = flag,
	}

	function element:SetValue(text, silent)
		input.Text = tostring(text)
		self.Value = input.Text
		Library.Flags[flag or self.Name] = input.Text
		if not silent then
			task.spawn(function()
				pcall(callback, input.Text)
			end)
		end
	end

	element.Set = element.SetValue

	Connect(input.Focused, function()
		Tween(stroke, 0.2, { Color = Library.Theme.Accent, Transparency = 0 })
	end)

	Connect(input.FocusLost, function(enter)
		Tween(stroke, 0.2, { Color = Library.Theme.Border, Transparency = 0.3 })
		element.Value = input.Text
		Library.Flags[flag or element.Name] = input.Text
		if enter or not config.OnEnter then
			task.spawn(function()
				pcall(callback, input.Text)
			end)
		end
	end)

	Hoverable(frame, "Element", "ElementHover")
	RegisterFlag(element, flag, input.Text)
	table.insert(self.Elements, element)
	return element
end

--=============================================================================
-- SECTION 29 · DROPDOWN (single & multi)
--=============================================================================

function Section:AddDropdown(config)
	config = config or {}
	local theme = Library.Theme

	local values   = config.Values or config.Options or {}
	local multi    = config.Multi or config.MultiSelect or false
	local callback = config.Callback or function() end
	local flag     = config.Flag or config.Name

	local frame, label = BaseElement(self, config, 34)
	frame.ClipsDescendants = true
	label.Size = UDim2.new(0.4, -12, 0, 34)
	label.TextYAlignment = Enum.TextYAlignment.Center

	local display = Create("TextButton", {
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.1,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(1, 0),
		Position               = UDim2.new(1, -10, 0, 5),
		Size                   = UDim2.new(0.57, -10, 0, 24),
		Font                   = Enum.Font.Gotham,
		Text                   = "",
		TextColor3             = theme.SubText,
		TextSize               = 12,
		AutoButtonColor        = false,
		ZIndex                 = 18,
		Parent                 = frame,
	})
	Corner(display, 6)
	Register(display, "BackgroundColor3", "Section")
	local stroke = Stroke(display, theme.Border, 1, 0.3)

	local displayText = Create("TextLabel", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(8, 0),
		Size                   = UDim2.new(1, -28, 1, 0),
		Font                   = Enum.Font.Gotham,
		Text                   = "-",
		TextColor3             = theme.SubText,
		TextSize               = 12,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		TextXAlignment         = Enum.TextXAlignment.Left,
		ZIndex                 = 19,
		Parent                 = display,
	})
	Register(displayText, "TextColor3", "SubText")

	local arrow = Create("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(1, 0.5),
		Position               = UDim2.new(1, -8, 0.5, 0),
		Size                   = UDim2.fromOffset(11, 11),
		Image                  = Library:GetIcon("arrow"),
		ImageColor3            = theme.DimText,
		Rotation               = 90,
		ZIndex                 = 19,
		Parent                 = display,
	})

	local listHolder = Create("Frame", {
		BackgroundTransparency = 1,
		Position               = UDim2.fromOffset(0, 36),
		Size                   = UDim2.new(1, 0, 0, 0),
		ClipsDescendants       = true,
		ZIndex                 = 18,
		Parent                 = frame,
	})

	local list = Create("ScrollingFrame", {
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.1,
		BorderSizePixel        = 0,
		Position               = UDim2.new(0, 10, 0, 0),
		Size                   = UDim2.new(1, -20, 1, -6),
		CanvasSize             = UDim2.new(),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollBarThickness     = 2,
		ScrollBarImageColor3   = theme.Accent,
		ZIndex                 = 19,
		Parent                 = listHolder,
	})
	Corner(list, 6)
	Register(list, "BackgroundColor3", "Section")
	ListLayout(list, 2)
	Padding(list, 4, 4, 4, 4)

	local dropdown = {
		Type        = "Dropdown",
		Name        = config.Name or "Dropdown",
		Description = config.Description,
		Frame       = frame,
		Flag        = flag,
		Multi       = multi,
		Values      = values,
		Value       = multi and {} or nil,
		Open        = false,
	}

	local optionButtons = {}

	local function refreshDisplay()
		if multi then
			local selected = {}
			for name, state in pairs(dropdown.Value or {}) do
				if state then
					table.insert(selected, name)
				end
			end
			table.sort(selected)
			displayText.Text = #selected > 0 and table.concat(selected, ", ") or "None"
		else
			displayText.Text = dropdown.Value ~= nil and tostring(dropdown.Value) or "None"
		end
	end

	local function isSelected(option)
		if multi then
			return dropdown.Value and dropdown.Value[option] == true
		end
		return dropdown.Value == option
	end

	local function paintOptions()
		for option, button in pairs(optionButtons) do
			local active = isSelected(option)
			Tween(button, 0.18, {
				BackgroundTransparency = active and 0 or 1,
				BackgroundColor3       = active and Library.Theme.Accent or Library.Theme.Element,
			})
			local text = button:FindFirstChildOfClass("TextLabel")
			if text then
				Tween(text, 0.18, {
					TextColor3 = active and Library.Theme.Background or Library.Theme.SubText,
				})
			end
		end
	end

	function dropdown:SetValue(newValue, silent)
		if multi then
			local map = {}
			if typeof(newValue) == "table" then
				for key, item in pairs(newValue) do
					if typeof(key) == "string" then
						map[key] = item and true or false
					else
						map[item] = true
					end
				end
			end
			self.Value = map
		else
			self.Value = newValue
		end

		Library.Flags[flag or self.Name] = self.Value
		refreshDisplay()
		paintOptions()

		if not silent then
			task.spawn(function()
				pcall(callback, self.Value)
			end)
		end
	end

	dropdown.Set = dropdown.SetValue

	function dropdown:GetValue()
		return self.Value
	end

	local function buildOptions()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		table.clear(optionButtons)

		for index, option in ipairs(dropdown.Values) do
			local button = Create("TextButton", {
				BackgroundColor3       = theme.Element,
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				Size                   = UDim2.new(1, 0, 0, 24),
				Text                   = "",
				AutoButtonColor        = false,
				LayoutOrder            = index,
				ZIndex                 = 20,
				Parent                 = list,
			})
			Corner(button, 5)

			Create("TextLabel", {
				BackgroundTransparency = 1,
				Position               = UDim2.fromOffset(8, 0),
				Size                   = UDim2.new(1, -16, 1, 0),
				Font                   = Enum.Font.Gotham,
				Text                   = tostring(option),
				TextColor3             = theme.SubText,
				TextSize               = 12,
				TextXAlignment         = Enum.TextXAlignment.Left,
				ZIndex                 = 21,
				Parent                 = button,
			})

			optionButtons[option] = button

			Connect(button.MouseButton1Click, function()
				Library:PlaySound("Click", 0.12)
				if multi then
					local map = dropdown.Value or {}
					map[option] = not map[option]
					dropdown:SetValue(map)
				else
					dropdown:SetValue(option)
					dropdown:SetOpen(false)
				end
			end)
		end

		paintOptions()
	end

	function dropdown:SetValues(newValues)
		self.Values = newValues or {}
		buildOptions()
		refreshDisplay()
	end

	dropdown.Refresh = dropdown.SetValues

	function dropdown:SetOpen(state)
		self.Open = state
		local rows   = math.min(#self.Values, 6)
		local height = state and (rows * 26 + 14) or 0

		Tween(frame, Library.Animation.Dropdown, {
			Size = UDim2.new(1, 0, 0, 34 + height),
		}, Enum.EasingStyle.Quint)
		Tween(listHolder, Library.Animation.Dropdown, {
			Size = UDim2.new(1, 0, 0, height),
		}, Enum.EasingStyle.Quint)
		Tween(arrow, Library.Animation.Dropdown, {
			Rotation = state and 270 or 90,
		})
		Tween(stroke, 0.2, {
			Color = state and Library.Theme.Accent or Library.Theme.Border,
		})
	end

	Connect(display.MouseButton1Click, function()
		dropdown:SetOpen(not dropdown.Open)
	end)

	buildOptions()

	if config.Default ~= nil then
		dropdown:SetValue(config.Default, true)
	else
		refreshDisplay()
	end

	Hoverable(frame, "Element", "ElementHover")
	RegisterFlag(dropdown, flag, dropdown.Value)
	table.insert(self.Elements, dropdown)
	return dropdown
end

--=============================================================================
-- SECTION 30 · KEYBIND
--=============================================================================

function Section:AddKeybind(config)
	config = config or {}
	local theme = Library.Theme

	local frame, label = BaseElement(self, config, 34)
	local callback = config.Callback or function() end
	local flag     = config.Flag or config.Name

	local button = Create("TextButton", {
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.1,
		BorderSizePixel        = 0,
		AnchorPoint            = Vector2.new(1, 0.5),
		Position               = UDim2.new(1, -10, 0.5, 0),
		Size                   = UDim2.fromOffset(74, 24),
		Font                   = Enum.Font.GothamMedium,
		Text                   = Utility.KeyName(config.Default),
		TextColor3             = theme.SubText,
		TextSize               = 11,
		AutoButtonColor        = false,
		ZIndex                 = 18,
		Parent                 = frame,
	})
	Corner(button, 6)
	Register(button, "BackgroundColor3", "Section")
	local stroke = Stroke(button, theme.Border, 1, 0.3)

	local keybind = {
		Type        = "Keybind",
		Name        = config.Name or "Keybind",
		Description = config.Description,
		Frame       = frame,
		Value       = config.Default,
		Flag        = flag,
		Mode        = config.Mode or "Toggle",
		Listening   = false,
	}

	local id = "keybind_" .. tostring(math.random(1, 1e9))

	function keybind:SetValue(key, silent)
		self.Value = key
		button.Text = Utility.KeyName(key)
		Library.Flags[flag or self.Name] = key

		Library:UnbindKey(id)
		if key then
			Library:BindKey(id, key, function()
				task.spawn(function()
					pcall(callback, key)
				end)
			end)
		end

		if not silent then
			task.spawn(function()
				pcall(config.OnChanged or function() end, key)
			end)
		end
	end

	keybind.Set = keybind.SetValue

	Connect(button.MouseButton1Click, function()
		keybind.Listening = true
		button.Text = "..."
		Tween(stroke, 0.2, { Color = Library.Theme.Accent, Transparency = 0 })

		local connection
		connection = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					keybind:SetValue(nil)
				else
					keybind:SetValue(input.KeyCode)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then
				keybind:SetValue(input.UserInputType)
			else
				return
			end

			keybind.Listening = false
			Tween(stroke, 0.2, { Color = Library.Theme.Border, Transparency = 0.3 })
			connection:Disconnect()
		end)
	end)

	Hoverable(frame, "Element", "ElementHover")
	keybind:SetValue(config.Default, true)
	RegisterFlag(keybind, flag, config.Default)
	table.insert(self.Elements, keybind)
	return keybind
end

--=============================================================================
-- SECTION 31 · COLORPICKER
--=============================================================================

function Section:AddColorPicker(config)
	config = config or {}
	local theme = Library.Theme

	local frame, label = BaseElement(self, config, 34)
	frame.ClipsDescendants = true

	local callback = config.Callback or function() end
	local flag     = config.Flag or config.Name
	local color    = config.Default or config.Color or Library.Theme.Accent

	local preview = Create("TextButton", {
		BackgroundColor3 = color,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(1, 0),
		Position         = UDim2.new(1, -10, 0, 7),
		Size             = UDim2.fromOffset(38, 20),
		Text             = "",
		AutoButtonColor  = false,
		ZIndex           = 18,
		Parent           = frame,
	})
	Corner(preview, 6)
	Stroke(preview, theme.BorderLight, 1, 0.4)

	local panel = Create("Frame", {
		BackgroundColor3       = theme.Section,
		BackgroundTransparency = 0.05,
		BorderSizePixel        = 0,
		Position               = UDim2.fromOffset(10, 38),
		Size                   = UDim2.new(1, -20, 0, 0),
		ClipsDescendants       = true,
		ZIndex                 = 18,
		Parent                 = frame,
	})
	Corner(panel, 8)
	Register(panel, "BackgroundColor3", "Section")

	local hue, saturation, brightness = Color3.toHSV(color)

	local saturationMap = Create("ImageLabel", {
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel  = 0,
		Position         = UDim2.fromOffset(10, 10),
		Size             = UDim2.new(1, -44, 0, 78),
		Image            = "rbxassetid://4155801252",
		ZIndex           = 19,
		Parent           = panel,
	})
	Corner(saturationMap, 6)

	local cursor = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Size             = UDim2.fromOffset(8, 8),
		ZIndex           = 21,
		Parent           = saturationMap,
	})
	Corner(cursor, 4)
	Stroke(cursor, Color3.fromRGB(0, 0, 0), 1, 0.5)

	local hueBar = Create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint     = Vector2.new(1, 0),
		Position        = UDim2.new(1, -10, 0, 10),
		Size            = UDim2.fromOffset(18, 78),
		ZIndex          = 19,
		Parent          = panel,
	})
	Corner(hueBar, 5)
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hueBar,
	})

	local hueCursor = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Position         = UDim2.fromScale(0.5, 0),
		Size             = UDim2.new(1, 4, 0, 3),
		ZIndex           = 21,
		Parent           = hueBar,
	})
	Corner(hueCursor, 2)

	local picker = {
		Type        = "ColorPicker",
		Name        = config.Name or "Color",
		Description = config.Description,
		Frame       = frame,
		Value       = color,
		Flag        = flag,
		Open        = false,
	}

	local function refresh(silent)
		local newColor = Color3.fromHSV(hue, saturation, brightness)
		picker.Value = newColor
		Library.Flags[flag or picker.Name] = newColor

		Tween(preview, 0.15, { BackgroundColor3 = newColor })
		saturationMap.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		cursor.Position    = UDim2.fromScale(saturation, 1 - brightness)
		hueCursor.Position = UDim2.fromScale(0.5, hue)

		if not silent then
			task.spawn(function()
				pcall(callback, newColor)
			end)
		end
	end

	function picker:SetValue(newColor, silent)
		if typeof(newColor) ~= "Color3" then
			return
		end
		hue, saturation, brightness = Color3.toHSV(newColor)
		refresh(silent)
	end

	picker.Set = picker.SetValue

	function picker:SetOpen(state)
		self.Open = state
		Tween(frame, Library.Animation.Dropdown, {
			Size = UDim2.new(1, 0, 0, state and 140 or 34),
		}, Enum.EasingStyle.Quint)
		Tween(panel, Library.Animation.Dropdown, {
			Size = UDim2.new(1, -20, 0, state and 98 or 0),
		}, Enum.EasingStyle.Quint)
	end

	Connect(preview.MouseButton1Click, function()
		picker:SetOpen(not picker.Open)
	end)

	local draggingMap, draggingHue = false, false

	Connect(saturationMap.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingMap = true
		end
	end)
	Connect(hueBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingHue = true
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingMap, draggingHue = false, false
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if draggingMap then
			local relativeX = (input.Position.X - saturationMap.AbsolutePosition.X) / saturationMap.AbsoluteSize.X
			local relativeY = (input.Position.Y - saturationMap.AbsolutePosition.Y) / saturationMap.AbsoluteSize.Y
			saturation = math.clamp(relativeX, 0, 1)
			brightness = 1 - math.clamp(relativeY, 0, 1)
			refresh()
		elseif draggingHue then
			local relativeY = (input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y
			hue = math.clamp(relativeY, 0, 1)
			refresh()
		end
	end)

	Hoverable(frame, "Element", "ElementHover")
	refresh(true)
	RegisterFlag(picker, flag, picker.Value)
	table.insert(self.Elements, picker)
	return picker
end

--=============================================================================
-- SECTION 32 · PROGRESS BAR
--=============================================================================

function Section:AddProgressBar(config)
	config = config or {}
	local theme = Library.Theme

	local frame, label = BaseElement(self, config, 42)
	label.Size     = UDim2.new(1, -90, 0, 20)
	label.Position = UDim2.fromOffset(12, 4)

	local percentLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(1, 0),
		Position               = UDim2.new(1, -12, 0, 4),
		Size                   = UDim2.fromOffset(60, 20),
		Font                   = Enum.Font.GothamBold,
		Text                   = "0%",
		TextColor3             = theme.Accent,
		TextSize               = 12,
		TextXAlignment         = Enum.TextXAlignment.Right,
		ZIndex                 = 17,
		Parent                 = frame,
	})
	Register(percentLabel, "TextColor3", "Accent")

	local track = Create("Frame", {
		BackgroundColor3 = theme.Border,
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 12, 0, 28),
		Size             = UDim2.new(1, -24, 0, 6),
		ZIndex           = 17,
		Parent           = frame,
	})
	Corner(track, 3)

	local fill = Create("Frame", {
		BackgroundColor3 = theme.Accent,
		BorderSizePixel  = 0,
		Size             = UDim2.fromScale(0, 1),
		ZIndex           = 18,
		Parent           = track,
	})
	Corner(fill, 3)
	Register(fill, "BackgroundColor3", "Accent")

	local element = {
		Type  = "ProgressBar",
		Name  = config.Name or "Progress",
		Frame = frame,
		Value = 0,
	}

	function element:SetValue(alpha)
		alpha = math.clamp(alpha, 0, 1)
		self.Value = alpha
		Tween(fill, 0.3, { Size = UDim2.fromScale(alpha, 1) })
		percentLabel.Text = string.format("%d%%", math.floor(alpha * 100))
	end

	element.Set = element.SetValue
	element:SetValue(config.Default or 0)

	table.insert(self.Elements, element)
	return element
end

--=============================================================================
-- SECTION 33 · CONFIG (SAVE / LOAD)
--=============================================================================

function Library:GetConfig()
	local data = {}
	for flag, value in pairs(Library.Flags) do
		if typeof(value) == "Color3" then
			data[flag] = { __type = "Color3", R = value.R, G = value.G, B = value.B }
		elseif typeof(value) == "EnumItem" then
			data[flag] = { __type = "EnumItem", Value = tostring(value) }
		elseif typeof(value) ~= "function" and typeof(value) ~= "Instance" then
			data[flag] = value
		end
	end
	return data
end

function Library:LoadConfig(data)
	for flag, value in pairs(data or {}) do
		local option = Library.Options[flag]
		if option and option.SetValue then
			if typeof(value) == "table" and value.__type == "Color3" then
				option:SetValue(Color3.new(value.R, value.G, value.B))
			elseif typeof(value) == "table" and value.__type == "EnumItem" then
				local keyName = string.match(value.Value, "Enum%.KeyCode%.(.+)")
				option:SetValue(keyName and Enum.KeyCode[keyName] or nil)
			else
				option:SetValue(value)
			end
		end
	end
end

function Library:SaveConfigFile(name)
	if not (Shim.writefile and Shim.isfolder) then
		return false, "Executor tidak mendukung filesystem"
	end
	ensureFolder(Library.WorkspaceFolder)
	ensureFolder(Library.ConfigFolder)

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(Library:GetConfig())
	end)
	if not ok then
		return false, encoded
	end

	local path = Library.ConfigFolder .. "/" .. (name or "default") .. ".json"
	local written = pcall(Shim.writefile, path, encoded)
	return written, path
end

function Library:LoadConfigFile(name)
	if not (Shim.readfile and Shim.isfile) then
		return false, "Executor tidak mendukung filesystem"
	end
	local path = Library.ConfigFolder .. "/" .. (name or "default") .. ".json"
	local exists = false
	pcall(function()
		exists = Shim.isfile(path)
	end)
	if not exists then
		return false, "Config tidak ditemukan"
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(Shim.readfile(path))
	end)
	if not ok then
		return false, decoded
	end

	Library:LoadConfig(decoded)
	return true, path
end

function Library:ListConfigs()
	local configs = {}
	if not Shim.listfiles then
		return configs
	end
	pcall(function()
		for _, file in ipairs(Shim.listfiles(Library.ConfigFolder)) do
			local name = string.match(file, "([^/\\]+)%.json$")
			if name then
				table.insert(configs, name)
			end
		end
	end)
	return configs
end

--=============================================================================
-- SECTION 34 · UNLOAD
--=============================================================================

function Library:Unload()
	Library.Unloaded = true

	for _, connection in ipairs(Library.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(Library.Connections)

	for _, window in ipairs(Library.Windows) do
		pcall(function()
			window:Destroy()
		end)
	end
	table.clear(Library.Windows)

	Library:SetBlur(false)

	task.delay(0.3, function()
		pcall(function()
			if Library.ScreenGui then
				Library.ScreenGui:Destroy()
			end
		end)
	end)

	if Library.OnUnload then
		pcall(Library.OnUnload)
	end
end

Library.Destroy = Library.Unload

--=============================================================================
-- SECTION 35 · RETURN
--=============================================================================


function Library:GetThemeList()
	local list = {}
	for name in pairs(Library.Themes) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

function Library:SetAccent(color)
	if typeof(color) ~= "Color3" then return end
	Library.Theme.Accent = color
	Library:SetTheme(Library.Theme, true)
end

return Library
