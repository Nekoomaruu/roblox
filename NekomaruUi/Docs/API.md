# API Reference — NekomaruUI

Semua fungsi di bawah bisa dipakai langsung setelah `Library` diload.

```lua
local Library = loadstring(game:HttpGet(BASE .. "Library.lua"))()
```

---

## Library

| Fungsi | Keterangan |
| --- | --- |
| `Library:CreateWindow(opt)` | Bikin window utama, return `Window` |
| `Library:Notify(text, duration)` | Notifikasi cepat |
| `Library:Notify(opt)` | Notifikasi lengkap (lihat di bawah) |
| `Library:SetWatermark(text)` | Watermark kiri atas (draggable) |
| `Library:SetWatermarkVisibility(bool)` | Show/hide watermark |
| `Library:GetIcon(name)` | Nama icon -> content URL (getcustomasset) |
| `Library:SetIcon(name, rbxassetid)` | Override / tambah fallback icon |
| `Library:PreloadIcons({ "Home", "Info" })` | Download icon lebih awal |
| `Library:SetTheme({ Accent = Color3... })` | Ganti warna runtime |
| `Library:Toggle(state)` | Show/hide semua window |
| `Library:Unload()` | Hancurkan UI + disconnect semua event |

Properti penting:

| Properti | Isi |
| --- | --- |
| `Library.Theme` | Tabel warna (lihat `THEMING.md`) |
| `Library.Options[idx]` | Semua element yang punya index (dipakai SaveManager) |
| `Library.Toggles[idx]` | Khusus toggle |
| `Library.AssetsFolder` | Default `NekomaruUI/Assets` |
| `Library.AssetsBaseURL` | URL raw buat auto-download icon |

### Notify options

```lua
Library:Notify({
    Title = "Nekomaru Hub",
    Content = "Script berhasil diload",
    Duration = 4,
    Icon = "Info",              -- nama file di Assets
    Type = "success",           -- info | success | warning | error
})
```

---

## Window

```lua
local Window = Library:CreateWindow({
    Title         = "Nekomaru Hub",
    SubTitle      = "Universal | v1.0.6",   -- teks kecil di samping judul
    Icon          = "icon",                 -- icon di topbar
    MinimizeIcon  = "icon",                 -- icon waktu minimize (default = Icon)
    Size          = UDim2.new(0, 620, 0, 420),
    Position      = UDim2.new(0.5, 0, 0.5, 0),
    IconPosition  = UDim2.new(0, 20, 0, 90),
    ToggleKeybind = Enum.KeyCode.RightShift,
    AutoShow      = true,
})
```

| Method | Keterangan |
| --- | --- |
| `Window:AddTab(name, icon)` | Tambah tab, return `Tab` |
| `Window:SelectTab(name)` | Pindah tab |
| `Window:Minimize()` | Kecilkan jadi icon bulat mengambang |
| `Window:Maximize()` | Buka lagi dari icon |
| `Window:Toggle(state?)` | Show/hide |
| `Window:Notify(...)` | Sama dengan `Library:Notify` |
| `Window:Destroy()` | Hapus window |

Window bisa di-drag lewat topbar. Icon minimize juga bisa di-drag; klik (tanpa drag) untuk buka lagi.

---

## Tab

| Method | Keterangan |
| --- | --- |
| `Tab:AddSection(name, opt?)` | Bikin kartu section, return `Section` |
| `Tab:AddGroupbox(name)` | Alias `AddSection` (gaya Obsidian) |
| `Tab:Select()` | Aktifkan tab ini |

`opt.Transparent = true` bikin section tanpa background.

---

## Section — Element

Semua element yang punya `idx` (string index) otomatis terdaftar di
`Library.Options[idx]` sehingga bisa disimpan SaveManager.

### Toggle
```lua
local t = Section:AddToggle("Noclip", {
    Text = "Noclip",
    Desc = "Tembus tembok",     -- opsional
    Default = false,
    Callback = function(value) end,
})
t:SetValue(true)      -- ubah + jalankan callback
t:SetValue(true, true)-- ubah tanpa callback
print(t.Value)
t:OnChanged(function(v) end)
```

### Button
```lua
Section:AddButton({
    Text = "Rejoin Server",
    Variant = "accent",   -- nil | "accent" | "danger"
    Callback = function() end,
})
```

### Slider
```lua
Section:AddSlider("WalkSpeed", {
    Text = "Walk Speed",
    Min = 16, Max = 200, Default = 16,
    Rounding = 0,       -- jumlah desimal
    Suffix = " studs",  -- opsional
    Callback = function(v) end,
})
```

### Input
```lua
Section:AddInput("Username", {
    Text = "Username",
    Placeholder = "ketik nama...",
    Default = "",
    Numeric = false,   -- true = hanya angka
    OnEnter = false,   -- true = callback hanya saat tekan Enter
    Callback = function(text) end,
})
```

### Dropdown
```lua
local dd = Section:AddDropdown("Checkpoint", {
    Text = "Checkpoint",
    Values = { "Cp 1", "Cp 2" },
    Default = "Cp 1",
    Multi = false,        -- true = multi-select (Value jadi tabel {["Cp 1"]=true})
    Placeholder = "None",
    Callback = function(v) end,
})
dd:SetValues({ "Cp 1", "Cp 2", "Cp 3" })  -- refresh isi
dd:SetValue("Cp 3")
```

### Keybind
```lua
local kb = Section:AddKeybind("AimlockKey", {
    Text = "Aimlock Key",
    Default = Enum.KeyCode.E,
    Callback = function(key) end,   -- saat keybind diganti
})
kb:OnClick(function() print("tombol ditekan") end)
```

### ColorPicker
```lua
Section:AddColorPicker("EspColor", {
    Text = "ESP Color",
    Default = Color3.fromRGB(0, 255, 140),
    Callback = function(c) end,
})
```

### Label / Paragraph / Divider
```lua
Section:AddLabel("Teks kecil abu-abu")
Section:AddParagraph({ Title = "Info", Content = "Penjelasan panjang..." })
Section:AddDivider()
```

---

## Method umum tiap element

| Method | Keterangan |
| --- | --- |
| `el:SetValue(v, silent?)` | Ubah value (`silent = true` -> tanpa callback) |
| `el:GetValue()` | Ambil value |
| `el:OnChanged(fn)` | Ganti callback |
| `el.Value` | Value sekarang |
| `el.Instance` | Frame Roblox-nya |
