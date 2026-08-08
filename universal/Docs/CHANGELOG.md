# Changelog

Semua perubahan penting dicatat di sini. Format: [Keep a Changelog](https://keepachangelog.com/),
versi mengikuti [Semantic Versioning](https://semver.org/).

> Sumber data yang sama juga ada di `Modules/Changelog.lua` supaya bisa dibaca
> langsung dari tab **Changelog** di dalam script. Kalau update salah satu,
> update dua-duanya.

## [3.3.0] - 2026-08-08
### Added
- Tab **Changelog** di dalam script: riwayat versi (Added / Changed / Removed / Fixed) bisa dibaca langsung di UI.
- `README.md` di root repository + `Docs/CHANGELOG.md`.
- Tombol **Copy Full Changelog** dan **Join Discord (copy link)** di tab Changelog.

## [3.2.0] - 2026-08-01
### Changed
- Refactor total: single-file dipecah jadi `Main.lua` + `Modules/*.lua` dengan Context bersama.
- Perilaku, fitur, dan UI library tidak diubah sama sekali.
### Added
- `Build/bundle.py` untuk generate `dist/TeleportSaver.lua` (single-file Delta).
- `Docs/ARCHITECTURE.md` dan `Docs/RULES.md`.

## [3.1.0] - 2026-07-28
### Added
- Tab **Auto Aim**: aimlock, smoothness, prediction, wall check, team check.
- FOV circle (POV lingkaran) dengan radius & warna custom.
- Hitbox expander: HRP, Head, Torso, Arms, Legs + size & transparency.
- Fullbright dan FPS Boost (low graphics).
- Anti-Fling, Anti-Void, Anti-Fall Damage, Reset Character/Camera.
### Changed
- Discord jadi satu tombol **Join Discord** yang auto copy link.
### Removed
- Leaderboard di tab Info.

## [3.0.0] - 2026-07-27
### Added
- Tab **Info**: player info, server info, community.
- `GuiService:SetGameplayPausedNotificationEnabled(false)` untuk matiin notif Gameplay Paused.
### Fixed
- Script gagal execute karena `goto` / `::continue::` (tidak didukung Luau).
- Pemanggilan API Obsidian yang salah (`CreateKeyTab`, `CreateGroupbox`).
- Nil-guard untuk executor tanpa `Drawing` API.

## [2.0.0] - 2026-07-26
### Added
- Config manager: create, load, delete, refresh config lewat filesystem executor.
- 26 default checkpoint (Nekomaru default).
- ESP, Movement (speed/jump), Vehicle Fly, Rejoin.

## [1.0.0] - 2026-07-25
### Added
- Save checkpoint tanpa batas, nama custom atau default `Cp 1`, `Cp 2`, ...
- Teleport manual, delete checkpoint.
- Play / Pause / Stop playback.
- Delay slider 0.5 - 3 detik dan toggle Loop.
- Self Alert (player biasa & admin) dengan method Kick atau Server Hop.
- UI Obsidian: tab Teleport, Self Alert, Settings.

