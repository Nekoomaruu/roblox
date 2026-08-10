# Theming — NekomaruUI

## Token warna

Semua warna ada di `Library.Theme`:

| Token | Default | Dipakai untuk |
| --- | --- | --- |
| `Background` | `11,16,28` | body window |
| `Sidebar` | `14,21,36` | sidebar tab + background section |
| `Topbar` | `16,24,40` | title bar |
| `Card` | `19,28,46` | kartu element |
| `CardHover` | `25,36,58` | hover kartu |
| `Stroke` | `34,48,74` | garis border |
| `Text` | `238,244,255` | teks utama |
| `SubText` | `139,156,182` | deskripsi |
| `Accent` | `34,184,255` | cyan — toggle aktif, tab aktif |
| `Accent2` | `255,45,120` | pink — aksen sekunder |
| `Success` / `Warning` / `Danger` | — | notifikasi & tombol |
| `Off` | `46,60,86` | track toggle/slider mati |

## Ganti warna

```lua
Library:SetTheme({
    Accent = Color3.fromRGB(255, 45, 120),
    Background = Color3.fromRGB(8, 10, 18),
})
```

Panggil **sebelum** `CreateWindow` supaya semua element ikut warnanya.

## ThemeManager

```lua
local ThemeManager = loadstring(game:HttpGet(BASE .. "Addons/ThemeManager.lua"))()
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("NekomaruHub/Universal")
ThemeManager:LoadDefault()                    -- pakai theme tersimpan
ThemeManager:BuildThemeSection(Tabs.Settings) -- UI pilih theme
```

Preset: `Nekomaru (Default)`, `Sakura`, `Midnight`, `Emerald`.

Tambah preset sendiri:

```lua
ThemeManager.Themes["Ocean"] = {
    Background = Color3.fromRGB(6, 18, 30),
    Sidebar    = Color3.fromRGB(9, 24, 40),
    Topbar     = Color3.fromRGB(10, 28, 46),
    Card       = Color3.fromRGB(14, 36, 58),
    CardHover  = Color3.fromRGB(20, 46, 72),
    Stroke     = Color3.fromRGB(28, 62, 94),
    Accent     = Color3.fromRGB(0, 200, 255),
    Accent2    = Color3.fromRGB(120, 255, 220),
}
```
