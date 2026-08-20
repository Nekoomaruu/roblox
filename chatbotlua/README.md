# AI Chatbot Roblox — Obsidian UI

Script Roblox (Luau) untuk **Delta Executor** dkk, dengan UI [Obsidian](https://github.com/deividcomsono/Obsidian).
Chatbot AI multi-provider: **Google AI Studio, OpenRouter, Groq, NVIDIA NIM**.

---

## Cara Pakai

1. Buka Delta Executor, tempel loader di bawah, lalu Execute:

```lua
loadstring(game:HttpGet("https://RAW-URL-KAMU/AIChatbot.lua"))()
```

Atau salin isi `AIChatbot.lua` langsung ke editor executor.

2. **Login Window** muncul:
   - Pilih **Provider** (contoh: `Google AI Studio`)
   - Tempel **API Key**, contoh format: `AQ.*********************`
   - Klik **Test Koneksi** (opsional) lalu **Login / Connect**
3. Menu utama terbuka. Toggle menu dengan **RightShift**.

---

## Kategori / Tabs

| Tab | Isi |
|---|---|
| **Main** | Kolom chat, Select Model, slider panjang output (max tokens), temperature, tombol Kirim/Clear History, panel jawaban, copy jawaban, kirim jawaban ke chat game |
| **API** | Ganti provider, ganti/hapus API key, custom model, timeout, test API key, info hint key |
| **Prompt** | System prompt (kepribadian AI), preset (Asisten Game, Translator, Coder Lua, Roleplay NPC), ingat percakapan + jumlah pesan |
| **Settings** | Keybind menu, unload script |
| **UI Settings** | Tema Obsidian + save/load config (ThemeManager & SaveManager) |

> API key **tidak** ikut tersimpan di config (di-ignore) demi keamanan.

---

## Cara Dapat API Key

### 1. Google AI Studio (gratis, kuota harian)
1. Buka https://aistudio.google.com/apikey
2. Login akun Google
3. Klik **Create API key** → pilih/buat project
4. Copy key (format `AIzaSy...` atau `AQ.Ab8...`)
5. Model gratis: `gemini-2.0-flash`, `gemini-2.5-flash`

### 2. OpenRouter (banyak model gratis `:free`)
1. Buka https://openrouter.ai dan daftar/login
2. Masuk ke https://openrouter.ai/keys
3. Klik **Create Key**, beri nama, (limit opsional) → **Create**
4. Copy key `sk-or-v1-...` (hanya tampil sekali)
5. Daftar model gratis: https://openrouter.ai/models?max_price=0

### 3. Groq (super cepat, gratis)
1. Buka https://console.groq.com dan login (Google/GitHub)
2. Menu **API Keys** → https://console.groq.com/keys
3. **Create API Key** → beri nama → **Submit**
4. Copy key `gsk_...`
5. Model: `llama-3.3-70b-versatile`, `llama-3.1-8b-instant`

### 4. NVIDIA NIM (build.nvidia.com)
1. Buka https://build.nvidia.com dan login/daftar akun NVIDIA
2. Pilih salah satu model (contoh `meta/llama-3.3-70b-instruct`)
3. Klik **Get API Key** / **Build with this NIM** → **Generate Key**
4. Copy key `nvapi-...` (dapat kredit gratis)
5. Endpoint yang dipakai script: `https://integrate.api.nvidia.com/v1`

---

## Syarat Executor

- Mendukung `game:HttpGet` (untuk load Obsidian)
- Mendukung fungsi HTTP: `request` / `http_request` / `syn.request` (Delta ✔)
- Opsional: `setclipboard` untuk copy jawaban

---

## Troubleshooting

| Pesan | Penyebab / Solusi |
|---|---|
| `Executor tidak mendukung HTTP request` | Executor tanpa `request`. Pakai Delta/Wave/Swift versi terbaru |
| `API error: API key not valid` | Key salah/expired → buat baru di dashboard provider |
| `API error: model not found` | Nama model salah → isi **Custom model** di tab API |
| `429 / rate limit` | Kuota gratis habis, tunggu reset atau ganti provider |
| Balasan kosong | Naikkan slider panjang output di tab Main |

---

## Catatan

- Jangan share API key kamu ke siapa pun.
- Fitur "Kirim jawaban ke chat game" bisa memicu moderasi/kick — pakai dengan risiko sendiri.
- Contoh key di dokumentasi ini sudah expired dan hanya ilustrasi format.
- 
