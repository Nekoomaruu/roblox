# Icons — `getcustomasset` (Delta & executor lain)

## Kenapa `getcustomasset`?

Roblox tidak bisa memuat file gambar dari disk lewat property `Image`.
Executor menyediakan fungsi non-standar:

```lua
getcustomasset("NekomaruUI/Assets/icon.png")
--> "rbxasset://<hash>" atau "rbxtemp://..." (content URL)
```

Fungsi ini membaca file **di dalam folder workspace executor**, meng-upload-nya ke
content provider lokal, lalu mengembalikan URL yang valid untuk
`ImageLabel.Image`, `ImageButton.Image`, `Decal.Texture`, dst.

Nama fungsi per executor:

| Executor | Fungsi | Folder workspace |
| --- | --- | --- |
| **Delta** (utama) | `getcustomasset(path)` | `/Delta/Workspace/` (Android) |
| Solara / Xeno | `getcustomasset(path)` | `Workspace/` |
| Wave / Codex | `getcustomasset(path)` | `workspace/` |
| Synapse X (lama) | `getsynasset(path)` | `workspace/` |

NekomaruUI otomatis mencari ketiganya:

```lua
local getcustomasset_f = getcustomasset or getsynasset or Getcustomasset
```

> Path selalu **relatif terhadap folder workspace executor**, bukan path absolut.
> Jangan tulis `/storage/emulated/0/Delta/Workspace/...`, cukup `NekomaruUI/Assets/icon.png`.

## Cara NekomaruUI resolve icon

`Library:GetIcon(name)` jalan berurutan:

1. Kalau `name` sudah `rbxassetid://`, `rbxthumb`, atau `http` → dipakai apa adanya.
2. Cek cache.
3. Cek file `NekomaruUI/Assets/<name>.png` → `getcustomasset`.
4. Kalau file belum ada → download dari `Library.AssetsBaseURL .. name .. ".png"`,
   `writefile` ke Assets, lalu `getcustomasset`.
5. Kalau semua gagal → fallback `rbxassetid://` dari `Library.FallbackIcons`.

Jadi user **tidak perlu manual copy icon**; cukup jalankan script, icon
terdownload sekali lalu dipakai offline seterusnya.

## Setup manual (opsional / offline)

Copy folder `Assets/` repo ini ke workspace executor:

```
Delta/Workspace/NekomaruUI/Assets/
├── icon.png
├── Settings.png
├── Home.png
...
```

## Ganti folder

```lua
Library.Folder        = "NekomaruHub"
Library.AssetsFolder  = "NekomaruHub/Assets"
Library.AssetsBaseURL = "https://raw.githubusercontent.com/Nekoomaruu/roblox/main/NekomaruUi/Assets/"
```

## Daftar icon bawaan

`Arrow`, `Clear`, `Clipboard`, `Close`, `Discord`, `Error`, `File`, `Home`,
`Info`, `LocalFile`, `Minimize`, `Open`, `Play`, `Settings`, `Timer`,
`Warning`, `WarningRed`, `Website`, `icon`, `teleport`.

Pemakaian:

```lua
Window:AddTab("Settings", "Settings")
Library:Notify({ Title = "Info", Content = "halo", Icon = "Info" })
```

## Tambah icon sendiri

1. Taruh `fish.png` di folder `Assets/` repo (dan/atau workspace executor).
2. Pakai `Window:AddTab("Fishing", "fish")`.
3. Opsional fallback online: `Library:SetIcon("fish", "rbxassetid://123456")`.

Sumber icon PNG gratis: [Lucide](https://lucide.dev), [Feather](https://feathericons.com),
[Material Symbols](https://fonts.google.com/icons). Ekspor PNG 64×64 atau 128×128,
background transparan, warna putih (UI mewarnai icon otomatis lewat `ImageColor3`).

## Troubleshooting

| Masalah | Sebab | Solusi |
| --- | --- | --- |
| Icon kosong/putih | file tidak ada & tidak ada internet | copy manual ke `Assets/` |
| `attempt to call a nil value (getcustomasset)` | executor tidak support | otomatis fallback `rbxassetid` |
| Icon lama nyangkut | cache executor | hapus file di `Assets/`, jalankan ulang |
| Icon gepeng | PNG tidak kotak | pakai gambar rasio 1:1 |
| `HTTP 404` | URL masih menunjuk repo lama atau kapitalisasi folder salah | gunakan path `Nekoomaruu/roblox/main/NekomaruUi/` persis |
