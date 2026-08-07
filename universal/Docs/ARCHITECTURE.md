# Architecture — Teleport Saver (Nekomaru Hub)

## Tujuan refactor
Script lama (`TeleportSaver_fixed.lua`, ~1900 baris) dipecah jadi module kecil.
**Perilaku, fitur, flow, dan UI library tidak diubah sama sekali.**

## Struktur

```text
Repository
├── Main.lua              entry point: load Obsidian, bikin Context, Init module
├── Modules
│   ├── Services.lua      semua game:GetService()
│   ├── Utils.lua         notify, safeCall/safeMethod, getRoot, isFriendly, newDraw
│   ├── UI.lua            Window + semua Tab
│   ├── DefaultCheckpoints.lua  26 checkpoint default
│   ├── Config.lua        save/load/delete config JSON (filesystem executor)
│   ├── Teleport.lua      checkpoint, play/pause/stop, loop, delay, config UI
│   ├── Player.lua        speed, jump, inf jump, noclip, misc, TP to player
│   ├── Visual.lua        no fog, fullbright, FPS boost
│   ├── ESP.lua           box/tracer/name/distance/health/chams
│   ├── Vehicle.lua       vehicle fly
│   ├── Server.lua        anti AFK, auto rejoin, server hop
│   ├── Aimbot.lua        aimlock + FOV circle
│   ├── Hitbox.lua        hitbox expander
│   ├── Alert.lua         self alert (player/admin) + bypass username
│   ├── Info.lua          player/server info + Join Discord
│   └── Settings.lua      watermark, KeyTab, ThemeManager, SaveManager
├── Build/bundle.py       gabung semua jadi 1 file untuk Delta
├── Docs
└── Assets/checkpoints
```

## Context (`ctx`)
Main.lua bikin satu table `ctx` dan mengirimnya ke `Module.Init(ctx)`:

| field | isi |
| --- | --- |
| `ctx.Library` / `ThemeManager` / `SaveManager` | hasil load Obsidian |
| `ctx.Services` | hasil `Services.Init()` |
| `ctx.Utils` | helper umum |
| `ctx.Window`, `ctx.Tabs` | UI dari `UI.Init` |
| `ctx.Config`, `ctx.DefaultCheckpoints` | data & filesystem |
| `ctx.<Module>` | return value tiap module fitur |

Module **tidak** boleh saling `require`; semua komunikasi lewat `ctx`.

## Urutan Init (WAJIB)
Urutan `Init` di Main.lua menentukan urutan groupbox di UI.
Contoh: `Aimbot` harus sebelum `Hitbox` supaya kolom kiri tab Auto Aim
tetap “Aimlock” lalu “Hitbox Expander”, sama seperti script lama.

## Bundling
Delta tidak punya `require` untuk file lokal, jadi `Build/bundle.py`
mendaftarkan setiap module ke `_NH_MODULES[name] = function() ... end`,
dan `Main.lua` memakai `nhRequire` yang membaca registry itu
(fallback: `readfile` dari folder repo di executor).

Hasil akhir: `dist/TeleportSaver.lua` — file inilah yang dieksekusi.
