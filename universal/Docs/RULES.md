# Rules — kontributor & AI agent

1. **Jangan ubah perilaku.** Refactor = pindah kode, bukan ganti logika, default value, teks UI, atau urutan elemen.
2. **Satu module satu tanggung jawab.** Fitur baru → module baru di `Modules/`, jangan numpuk di module lain.
3. **Dilarang `game:GetService()` di luar `Modules/Services.lua`.** Ambil dari `ctx.Services`.
4. **Dilarang `require` antar module.** Semua dependency lewat `ctx`.
5. **Dilarang `goto` / `::label::`** — Luau tidak mendukung, `loadstring` akan gagal.
6. **Semua API executor opsional harus dicek**: `writefile`, `readfile`, `setclipboard`, `Drawing` — pakai `typeof(x) == "function"` atau helper di `Utils`.
7. **Panggilan Obsidian yang versinya bisa beda** dibungkus `Utils.safeMethod` / `pcall`.
8. **Urutan `Init` di `Main.lua` tidak boleh diacak** (menentukan layout UI).
9. **Key toggle/slider/dropdown tidak boleh diganti** — dipakai SaveManager untuk config user.
10. Setelah edit, selalu jalankan `python3 Build/bundle.py` dan validasi syntax `dist/TeleportSaver.lua` sebelum dipakai.
