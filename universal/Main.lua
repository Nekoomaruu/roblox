--[[
    Main.lua — Teleport Saver by Nekomaru Hub
    Entry point. Tugasnya cuma: load Obsidian, bikin Context, lalu Init tiap module
    dengan URUTAN yang tidak boleh diubah (urutan = urutan groupbox di UI).

    Cara require module:
      - Kalau dibundle jadi 1 file (Build/bundle.lua -> dist/TeleportSaver.lua),
        module sudah terdaftar di _NH_MODULES.
      - Kalau dijalanin dari file terpisah, fallback ke readfile("Modules/<Name>.lua").
]]

local REPO_ROOT = "NekomaruHub/TeleportSaver/Repo"

local function nhRequire(name)
    local reg = rawget(_G, "_NH_MODULES")
    if reg and reg[name] then
        local m = reg[name]
        if type(m) == "function" then
            local res = m()
            reg[name] = res
            return res
        end
        return m
    end
    -- fallback: baca dari filesystem executor
    local path = REPO_ROOT .. "/Modules/" .. name .. ".lua"
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(path) then
        local chunk = loadstring(readfile(path), name)
        if chunk then return chunk() end
    end
    error("[Nekomaru Hub] Module tidak ditemukan: " .. tostring(name))
end

-- ============================================================
-- Load Obsidian (Library / ThemeManager / SaveManager)
-- ============================================================
local BASE = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local function loadRemote(url, label)
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if not ok or type(src) ~= "string" or #src < 100 then
        warn("[Nekomaru Hub] Gagal download " .. label)
        return nil
    end
    local chunk, err = loadstring(src, label)
    if not chunk then
        warn("[Nekomaru Hub] Syntax error " .. label .. ": " .. tostring(err))
        return nil
    end
    local ok2, res = pcall(chunk)
    if not ok2 then
        warn("[Nekomaru Hub] Runtime error " .. label .. ": " .. tostring(res))
        return nil
    end
    return res
end

local Library      = loadRemote(BASE .. "Library.lua", "Obsidian Library")
if not Library then
    error("[Nekomaru Hub] Obsidian Library gagal diload, cek koneksi / executor.")
end
local ThemeManager = loadRemote(BASE .. "addons/ThemeManager.lua", "ThemeManager")
local SaveManager  = loadRemote(BASE .. "addons/SaveManager.lua", "SaveManager")

-- ============================================================
-- Context
-- ============================================================
local ctx = {}
ctx.Library      = Library
ctx.ThemeManager = ThemeManager
ctx.SaveManager  = SaveManager

ctx.Services = nhRequire("Services").Init()
ctx.Utils    = nhRequire("Utils").Init(ctx)

local ui = nhRequire("UI").Init(ctx)
ctx.Window = ui.Window
ctx.Tabs   = ui.Tabs

ctx.DefaultCheckpoints = nhRequire("DefaultCheckpoints")
ctx.Config   = nhRequire("Config").Init(ctx)

-- URUTAN INIT — jangan diacak, ini yang menentukan posisi groupbox.
ctx.Teleport = nhRequire("Teleport").Init(ctx)
ctx.Player   = nhRequire("Player").Init(ctx)
ctx.Visual   = nhRequire("Visual").Init(ctx)
ctx.ESP      = nhRequire("ESP").Init(ctx)
ctx.Server   = nhRequire("Server").Init(ctx)
ctx.Aimbot   = nhRequire("Aimbot").Init(ctx)
ctx.Hitbox   = nhRequire("Hitbox").Init(ctx)
ctx.Alert    = nhRequire("Alert").Init(ctx)
ctx.Info      = nhRequire("Info").Init(ctx)
ctx.Changelog = nhRequire("Changelog").Init(ctx)
ctx.Settings = nhRequire("Settings").Init(ctx)

-- Bootstrap terakhir (config dropdown + default checkpoints + notify)
ctx.Teleport.Bootstrap()

return ctx
