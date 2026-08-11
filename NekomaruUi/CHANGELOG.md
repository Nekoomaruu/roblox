# Changelog

## [1.1.0] — 2026-08-11

### Fixed
- Semua raw URL sekarang menunjuk struktur repo yang benar:
  `Nekoomaruu/roblox/main/NekomaruUi/`.
- `AssetsBaseURL` tidak lagi menunjuk repository lama yang tidak ada.
- Example loader menampilkan file, URL, dan error yang jelas saat download gagal.
- Request example memakai bypass cache agar commit terbaru langsung terambil.

### Added
- Smooth open, minimize, restore, dan perpindahan tab.
- `Library:SetAnimation()` untuk mengatur atau mematikan animasi.

## [1.0.0] — 2026-08-10

Rilis pertama NekomaruUI.

### Added
- Core `Library.lua`: Window, Tab, Section, dan element
  Toggle, Button, Slider, Input, Dropdown (single/multi), Keybind,
  ColorPicker, Label, Paragraph, Divider.
- Minimize ke icon bulat mengambang (draggable, klik untuk restore).
- Sistem icon `getcustomasset` dengan auto-download + fallback `rbxassetid://`.
- Notifikasi 4 tipe (info/success/warning/error) dan watermark draggable.
- `Addons/SaveManager.lua` — config JSON: create, load, overwrite, delete,
  refresh, autoload.
- `Addons/ThemeManager.lua` — 4 preset theme + custom accent + default theme.
- Dokumentasi: `API.md`, `ICONS.md`, `THEMING.md`, `MIGRATION_OBSIDIAN.md`.
- Contoh integrasi `Examples/Universal.lua`.
