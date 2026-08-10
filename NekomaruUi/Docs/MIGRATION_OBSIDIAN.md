# Migrasi dari Obsidian → NekomaruUI

API-nya sengaja dibikin mirip supaya script lama (`Modules/UI.lua`, `Teleport.lua`, dll)
cuma butuh sedikit perubahan.

## 1. Load library

```lua
-- Obsidian
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()

-- NekomaruUI
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nekoomaruu/NekomaruUI/main/Library.lua"))()
```

## 2. Window

```lua
-- Obsidian
Library:CreateWindow({ Title = "Teleport Saver", Footer = "By Nekomaru Hub",
    ToggleKeybind = Enum.KeyCode.RightShift, Center = true, AutoShow = true })

-- NekomaruUI
Library:CreateWindow({ Title = "Teleport Saver", SubTitle = "By Nekomaru Hub",
    Icon = "icon", ToggleKeybind = Enum.KeyCode.RightShift, AutoShow = true })
```

`Center` tidak perlu (window selalu di tengah kecuali `Position` diisi).
`Footer` tetap diterima sebagai alias `SubTitle`.

## 3. Tab & Groupbox

```lua
-- Obsidian
local Tab = Window:AddTab("Player", "user")
local Box = Tab:AddLeftGroupbox("Utility")

-- NekomaruUI (satu kolom, section berupa kartu)
local Tab = Window:AddTab("Player", "Home")   -- icon = nama file PNG di Assets
local Box = Tab:AddSection("Utility")         -- AddGroupbox juga bisa
```

> Icon Obsidian pakai nama Lucide (`"user"`, `"map-pin"`). Di NekomaruUI, icon
> merujuk file PNG di `Assets/`. Lihat [ICONS.md](ICONS.md) untuk daftar dan
> cara menambah icon.

## 4. Element

| Obsidian | NekomaruUI |
| --- | --- |
| `Box:AddToggle("Idx", { Text=, Default=, Callback= })` | sama (`Desc` opsional) |
| `Box:AddButton({ Text=, Func= })` | `AddButton({ Text=, Callback= })` (`Func` juga masih jalan) |
| `Box:AddSlider("Idx", { Text=, Default=, Min=, Max=, Rounding=, Callback= })` | sama |
| `Box:AddInput("Idx", { Text=, Default=, Placeholder=, Callback= })` | sama |
| `Box:AddDropdown("Idx", { Values=, Default=, Multi=, Callback= })` | sama (`Default` pakai value, bukan index) |
| `Box:AddLabel("text")` | sama |
| `Box:AddDivider()` | sama |
| `Toggle:AddKeyPicker(...)` | `Section:AddKeybind("Idx", { ... })` (element terpisah) |
| `Toggle:AddColorPicker(...)` | `Section:AddColorPicker("Idx", { ... })` |
| `Library.Toggles["Idx"].Value` | sama |
| `Library.Options["Idx"]:SetValue(v)` | sama |
| `Library:Notify("text", 3)` | sama |
| `Library:Unload()` | sama |

## 5. Dropdown refresh

```lua
-- Obsidian
Library.Options.ConfigList:SetValues(list)

-- NekomaruUI (sama)
Library.Options.ConfigList:SetValues(list)
```

## 6. SaveManager / ThemeManager

```lua
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("NekomaruHub/Universal")
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(Tabs.Settings)   -- Obsidian: BuildConfigSection(tab)
SaveManager:LoadAutoloadConfig()

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("NekomaruHub/Universal")
ThemeManager:BuildThemeSection(Tabs.Settings)   -- Obsidian: ApplyToTab(tab)
```

## 7. Yang belum ada (dan gantinya)

| Obsidian | Status di NekomaruUI |
| --- | --- |
| `AddLeftGroupbox` / `AddRightGroupbox` | satu kolom, pakai `AddSection` |
| `AddTabbox` | pakai tab terpisah |
| `KeyPicker` menempel di toggle | element `AddKeybind` sendiri |
| `Library:SetNotifySide` | notifikasi selalu di kanan bawah |
