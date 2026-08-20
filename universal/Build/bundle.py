#!/usr/bin/env python3
"""
Build/bundle.py — gabungin Main.lua + Modules/*.lua jadi satu file
dist/TeleportSaver.lua yang bisa langsung di-execute di Delta Executor.

Setiap module dibungkus jadi function di table _NH_MODULES, lalu Main.lua
ditempel di bawahnya. Tidak ada perubahan kode module sama sekali.
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ORDER = [
    "Services", "Utils", "UI", "DefaultCheckpoints", "Config",
    "Teleport", "Player", "Visual", "ESP", "Server",
    "Aimbot", "Hitbox", "Alert", "Info", "Changelog", "Settings",
]

out = ["-- Teleport Saver by Nekomaru Hub — bundled build (jangan edit manual)",
       "-- Sumber asli: Main.lua + Modules/*.lua",
       "local _NH_MODULES = {}",
       "_G._NH_MODULES = _NH_MODULES", ""]

for name in ORDER:
    src = (ROOT / "Modules" / f"{name}.lua").read_text(encoding="utf-8")
    out.append(f"_NH_MODULES[{name!r}] = function()")
    out.append(src)
    out.append("end")
    out.append("")

out.append((ROOT / "Main.lua").read_text(encoding="utf-8"))

dist = ROOT / "dist" / "TeleportSaver.lua"
dist.parent.mkdir(parents=True, exist_ok=True)
dist.write_text("\n".join(out), encoding="utf-8")
print("built:", dist, dist.stat().st_size, "bytes")
