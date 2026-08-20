--[[
    Modules/Changelog.lua
    Tab Changelog: nampilin riwayat versi script (Added / Changed / Removed / Fixed)
    langsung di dalam UI, biar user ga perlu buka file Docs/CHANGELOG.md.

    Cara nambah entri: tambahin table baru di PALING ATAS list VERSIONS.
    Tipe yang didukung: "Added", "Changed", "Removed", "Fixed".
]]

local Changelog = {}

Changelog.Version = "3.5.0"

Changelog.VERSIONS = {
    {
        Version = "3.5.0",
        Date = "2026-08-19",
        Changes = {
            { "Added", "Fly di tab Player dengan 3 method: CFrame Fly, Velocity Fly, Align Fly (+ speed, vertical, keybind F, tombol up/down mobile)" },
            { "Added", "Groupbox Universal / Tools di tab Player: Freeze, Spin, Click Teleport, Sit/Stand, Copy Position" },
            { "Added", "Button Checkpoint Finder (execute script NekoCpFinder_v2 langsung dari executor)" },
            { "Added", "Server: Hop random, Auto Server Hop timer, Auto hop kalau server hampir full, Copy JobId/PlaceId/Join Script, Join by JobId, Leave Game" },
            { "Added", "Visuals: Disable Post FX, No Shadows, Camera FOV, Time of Day, Max Zoom, Clear Sky, X-Ray, Remove Textures" },
            { "Changed", "Tab Teleport diganti nama jadi Main" },
            { "Removed", "Watermark part \"Nekomaru Hub | Teleport Saver\"" },
            { "Removed", "Tab Vehicle + fitur Vehicle Fly" },
        },
    },
    {
        Version = "3.3.0",
        Date = "2026-08-08",
        Changes = {
            { "Added", "Tab Changelog di dalam script (riwayat versi bisa dibaca langsung di UI)" },
            { "Added", "README.md + Docs/CHANGELOG.md di repository" },
            { "Added", "Tombol Copy Changelog & Copy Discord di tab Changelog" },
        },
    },
    {
        Version = "3.2.0",
        Date = "2026-08-01",
        Changes = {
            { "Changed", "Refactor total: single-file dipecah jadi Main.lua + Modules/*.lua" },
            { "Added", "Build/bundle.py buat generate dist/TeleportSaver.lua (single-file Delta)" },
            { "Added", "Docs/ARCHITECTURE.md dan Docs/RULES.md" },
            { "Changed", "Perilaku, fitur, dan UI tidak diubah sama sekali" },
        },
    },
    {
        Version = "3.1.0",
        Date = "2026-07-28",
        Changes = {
            { "Added", "Tab Auto Aim: Aimlock, smoothness, prediction, wall check, team check" },
            { "Added", "FOV circle (POV lingkaran) dengan radius & warna custom" },
            { "Added", "Hitbox Expander: HRP, Head, Torso, Arms, Legs + size & transparency" },
            { "Added", "Fullbright, FPS Boost (low graphics)" },
            { "Added", "Anti-Fling, Anti-Void, Anti-Fall Damage, Reset Character/Camera" },
            { "Removed", "Leaderboard di tab Info" },
            { "Changed", "Discord jadi satu tombol Join Discord (auto copy link)" },
        },
    },
    {
        Version = "3.0.0",
        Date = "2026-07-27",
        Changes = {
            { "Added", "Tab Info: player info, server info, community" },
            { "Added", "GuiService:SetGameplayPausedNotificationEnabled(false)" },
            { "Fixed", "Script gagal execute: goto/::continue:: dihapus (ga didukung Luau)" },
            { "Fixed", "Pemanggilan API Obsidian yang salah (CreateKeyTab / CreateGroupbox)" },
            { "Fixed", "Nil-guard buat executor tanpa Drawing API" },
        },
    },
    {
        Version = "2.0.0",
        Date = "2026-07-26",
        Changes = {
            { "Added", "Config manager: create, load, delete, refresh config lewat filesystem Delta" },
            { "Added", "26 default checkpoint (Nekomaru default)" },
            { "Added", "ESP, Movement (speed/jump), Vehicle Fly, Rejoin" },
        },
    },
    {
        Version = "1.0.0",
        Date = "2026-07-25",
        Changes = {
            { "Added", "Save checkpoint (auto nama Cp 1, Cp 2, ...) + teleport manual" },
            { "Added", "Play / Pause / Stop playback checkpoint" },
            { "Added", "Delay slider 0.5 - 3 detik dan toggle Loop" },
            { "Added", "Self Alert: deteksi player biasa & admin, method Kick atau Server Hop" },
            { "Added", "UI Obsidian dengan tab Teleport, Self Alert, Settings" },
        },
    },
}

function Changelog.ToText()
    local lines = { "Teleport Saver by Nekomaru Hub - Changelog" }
    for _, v in ipairs(Changelog.VERSIONS) do
        table.insert(lines, "")
        table.insert(lines, "v" .. v.Version .. " (" .. v.Date .. ")")
        for _, c in ipairs(v.Changes) do
            table.insert(lines, "  [" .. c[1] .. "] " .. c[2])
        end
    end
    return table.concat(lines, "\n")
end

function Changelog.Init(ctx)
    local Tabs = ctx.Tabs
    local notify = ctx.Utils.notify

    local COMMUNITY_URL = "https://posronda.my.id/discord"

    local LatestBox = Tabs.Changelog:AddLeftGroupbox("Latest", "sparkles")
    local HistoryBox = Tabs.Changelog:AddRightGroupbox("History", "history")

    local latest = Changelog.VERSIONS[1]
    if latest then
        LatestBox:AddLabel("Version: v" .. latest.Version, true)
        LatestBox:AddLabel("Date: " .. latest.Date, true)
        LatestBox:AddDivider()
        for _, c in ipairs(latest.Changes) do
            LatestBox:AddLabel("[" .. c[1] .. "] " .. c[2], true)
        end
    end

    LatestBox:AddDivider()
    LatestBox:AddButton({
        Text = "Copy Full Changelog",
        Func = function()
            local text = Changelog.ToText()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, text)
                notify("Changelog disalin ke clipboard", 3)
            else
                notify("Executor tidak support setclipboard", 3)
            end
        end,
    })
    LatestBox:AddButton({
        Text = "Join Discord (copy link)",
        Func = function()
            if typeof(setclipboard) == "function" then
                pcall(setclipboard, COMMUNITY_URL)
                notify("Link discord disalin: " .. COMMUNITY_URL, 3)
            else
                notify(COMMUNITY_URL, 5)
            end
        end,
    })

    for i, v in ipairs(Changelog.VERSIONS) do
        if i > 1 then
            HistoryBox:AddLabel("v" .. v.Version .. "  (" .. v.Date .. ")", true)
            for _, c in ipairs(v.Changes) do
                HistoryBox:AddLabel("  [" .. c[1] .. "] " .. c[2], true)
            end
            HistoryBox:AddDivider()
        end
    end

    return Changelog
end

return Changelog
