# NekomaruUI

UI library buat script Roblox — dibuat untuk **Delta Executor**, jalan juga di
Solara / Wave / Xeno / Codex. Dark navy + accent cyan/pink, sidebar tab ber-icon,
minimize jadi icon bulat mengambang, dan support icon PNG lokal lewat
`getcustomasset`.

Konsepnya sama seperti Obsidian / Rayfield: **UI-nya di library, logic-nya di script kamu.**

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nekoomaruu/roblox/main/NekomaruUi/Library.lua", true))()

local Window = Library:CreateWindow({
    Title = "Nekomaru Hub",
    SubTitle = "Universal | v1.0.6",
    Icon = "icon",
    ToggleKeybind = Enum.KeyCode.RightShift,
})

local Tab = Window:AddTab("Player", "Home")
local Sec = Tab:AddSection("Utility Player")

Sec:AddToggle("Noclip", {
    Text = "Noclip",
    Desc = "Tembus tembok",
    Callback = function(v) print("noclip:", v) end,
})

Sec:AddSlider("WalkSpeed", { Text = "Walk Speed", Min = 16, Max = 200, Default = 16,
    Callback = function(v)
        local c = game.Players.LocalPlayer.Character
        if c and c:FindFirstChildOfClass("Humanoid") then c.Humanoid.WalkSpeed = v end
    end })

Library:Notify({ Title = "Nekomaru Hub", Content = "Loaded!", Type = "success" })
```

## Fitur

- Window draggable + topbar (judul, subtitle, minimize, close)
- **Minimize ke icon bulat** yang bisa di-drag, klik untuk buka lagi
- Sidebar tab ber-icon + indikator tab aktif
- Section/groupbox berbentuk kartu
- Element: Toggle, Button, Slider, Input, Dropdown (single & multi), Keybind,
  ColorPicker, Label, Paragraph, Divider
- Notifikasi (info / success / warning / error) + watermark draggable
- **Icon PNG lokal** via `getcustomasset`, auto-download kalau file belum ada,
  fallback `rbxassetid://` kalau executor tidak support
- `SaveManager` — simpan/load config JSON, autoload
- `ThemeManager` — 4 preset theme + custom accent
- Support mouse & touch (mobile-friendly)
- Smooth animation untuk window open/restore/minimize, tab, toggle, dropdown, dan interaksi
- `Library:Unload()` bersih: semua koneksi di-disconnect

## Struktur Repository

```text
NekomaruUI
├── Library.lua              # core library (satu file, tinggal loadstring)
├── Addons
│   ├── SaveManager.lua      # config save/load JSON
│   └── ThemeManager.lua     # preset theme
├── Assets/*.png             # icon (dipakai getcustomasset)
├── Examples
│   └── Universal.lua        # contoh integrasi ke universal script
├── Docs
│   ├── API.md               # referensi lengkap semua fungsi
│   ├── ICONS.md             # cara kerja getcustomasset per executor
│   ├── THEMING.md           # token warna & theme
│   └── MIGRATION_OBSIDIAN.md# panduan pindah dari Obsidian
├── CHANGELOG.md
└── LICENSE
```

## Instalasi

**Cara 1 — online (disarankan)**

```lua
local BASE = "https://raw.githubusercontent.com/Nekoomaruu/roblox/main/NekomaruUi/"
local Library      = loadstring(game:HttpGet(BASE .. "Library.lua", true))()
local SaveManager  = loadstring(game:HttpGet(BASE .. "Addons/SaveManager.lua", true))()
local ThemeManager = loadstring(game:HttpGet(BASE .. "Addons/ThemeManager.lua", true))()
```

Icon otomatis terdownload ke `NekomaruUI/Assets/` di workspace executor pada
pemakaian pertama.

> Path GitHub bersifat **case-sensitive**. Folder repo ini bernama persis
> `NekomaruUi`, bukan `NekomaruUI`. Parameter `true` memaksa bypass cache executor.

### Atur animasi

```lua
Library:SetAnimation({
    Enabled = true,
    Fast = 0.12,
    Normal = 0.20,
    Slow = 0.28,
})
```

**Cara 2 — offline**

Copy `Library.lua` + folder `Assets/` ke workspace executor, lalu:

```lua
local Library = loadstring(readfile("NekomaruUI/Library.lua"))()
```

## Dokumentasi

- [API lengkap](Docs/API.md)
- [Icon & getcustomasset](Docs/ICONS.md)
- [Theming](Docs/THEMING.md)
- [Migrasi dari Obsidian](Docs/MIGRATION_OBSIDIAN.md)
- [Contoh script](Examples/Universal.lua)

## Lisensi

MIT — bebas dipakai, kredit dihargai.
