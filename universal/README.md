# Teleport Saver — by Nekomaru Hub

Universal Roblox script (Obsidian UI) buat save & replay checkpoint, plus fitur universal lain.
Dibuat & ditest untuk **Delta Executor**.

## Cara Pakai

1. Ambil file `dist/TeleportSaver.lua` (build single-file).
2. Paste / execute di Delta Executor.
3. Buka / tutup UI pakai **Right Shift**.

## Struktur Repository

```text
TeleportSaver
├── Main.lua                 # entry point: load Obsidian, bikin Context, Init module
├── Modules
│   ├── Services.lua         # pusat game:GetService()
│   ├── Utils.lua            # notify, safeCall, getRoot, isFriendly, Drawing guard
│   ├── UI.lua               # Window + semua Tab
│   ├── DefaultCheckpoints.lua
│   ├── Config.lua           # save/load config (filesystem executor)
│   ├── Teleport.lua         # checkpoint + playback
│   ├── Player.lua           # speed, jump, inf jump, noclip, misc
│   ├── Visual.lua           # fullbright, fog, fps boost
│   ├── ESP.lua
│   ├── Vehicle.lua
│   ├── Server.lua           # anti-afk, rejoin, server hop
│   ├── Aimbot.lua           # aimlock + FOV circle
│   ├── Hitbox.lua
│   ├── Alert.lua            # self alert (player / admin)
│   ├── Info.lua
│   ├── Changelog.lua        # riwayat versi (juga tampil di UI)
│   └── Settings.lua
├── Build/bundle.py          # gabungin semua module -> dist/TeleportSaver.lua
├── Docs (ARCHITECTURE.md, RULES.md, CHANGELOG.md)
├── Assets
└── dist/TeleportSaver.lua
```

## Fitur

### Teleport
- Save posisi tanpa batas, nama custom atau default `Cp 1`, `Cp 2`, ...
- Teleport manual ke checkpoint, rename, delete, clear all
- **Play** dari checkpoint pertama sampai terakhir
- **Pause** (lanjut dari checkpoint terakhir, bukan reset) & **Stop**
- Delay antar checkpoint 0.5 – 3 detik
- **Loop** playback
- Config: create / load / delete / refresh, tersimpan di filesystem executor
- 26 default checkpoint bawaan (Nekomaru default)

### Player
Walk speed, jump power, infinite jump, noclip, reset character & camera,
anti-fling, anti-void, anti-fall damage.

### Visuals
Player ESP (box/name/distance), fullbright, fog control, FPS boost (low graphics).

### Vehicle
Vehicle fly + kontrol kecepatan.

### Server
Anti-AFK, rejoin, server hop.

### Auto Aim
Aimlock (smoothness, prediction, wall check, team check), FOV circle dengan
radius & warna custom, hitbox expander (HRP, Head, Torso, Arms, Legs) dengan
size & transparency.

### Self Alert
Auto **Kick** atau **Server Hop** kalau ada player lain masuk, dan/atau kalau
terdeteksi admin di server. Dua toggle terpisah + pilihan method.

### Info
Player info (name, userid, account age, team, health, position, ping, FPS),
server info (placeid, jobid, player count, uptime, region), tombol
**Join Discord** (auto copy `https://posronda.my.id/discord`).

### Changelog
Riwayat versi langsung di dalam UI: apa yang **Added / Changed / Removed / Fixed**,
plus tombol copy changelog.

### Settings
Menu default Obsidian: keybind UI, theme manager, save manager, unload.

## Build

```sh
python3 Build/bundle.py
```

Output: `dist/TeleportSaver.lua`.

## Docs

- `Docs/ARCHITECTURE.md` — alur Context & urutan Init module
- `Docs/RULES.md` — aturan kontribusi biar behaviour ga berubah
- `Docs/CHANGELOG.md` — riwayat versi

## Community

Discord: https://posronda.my.id/discord
