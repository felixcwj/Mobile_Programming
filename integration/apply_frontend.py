#!/usr/bin/env python3
"""Apply the integration implementation to the pinned frontend submodule copy.

The upstream frontend belongs to another teammate. Do not push changes there.
This script changes only the checked-out local copy. Run after clone --recurse-submodules.
"""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
frontend = root / "frontend"
if not (frontend / "pubspec.yaml").exists():
    raise SystemExit("Missing frontend submodule. Run: git submodule update --init --recursive")
for src in (root / "integration" / "frontend_overlay").rglob("*.dart"):
    dest = frontend / src.relative_to(root / "integration" / "frontend_overlay")
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    print("overlay", dest.relative_to(frontend))

def replace(path, old, new):
    p = frontend / path
    content = p.read_text()
    if old not in content:
        raise SystemExit(f"Patch mismatch: {path}: {old[:80]!r}")
    p.write_text(content.replace(old, new))

replace("pubspec.yaml", "  firebase_auth: 5.7.0\n", "  firebase_auth: 5.7.0\n  http: ^1.5.0\n")
replace("lib/screens/signup_screen.dart",
        r"RegExp(r'^[a-zA-Z0-9]{4,20}$')",
        r"RegExp(r'^[a-zA-Z0-9_]{4,12}$')")
replace("lib/screens/signup_screen.dart",
        "hint: '영문 및 숫자 4~20자',",
        "hint: '영문·숫자·밑줄 4~12자',")
replace("lib/screens/signup_screen.dart",
        "'영문 및 숫자 4~20자로 입력해 주세요.'",
        "'영문·숫자·밑줄 4~12자로 입력해 주세요.'")
replace("lib/screens/profile/account_edit_screen.dart",
        "maxLength: widget.editPassword ? 128 : 30,",
        "maxLength: widget.editPassword ? 20 : 12,")
replace("lib/screens/profile/account_edit_screen.dart",
        "r'^[a-zA-Z0-9_]{4,30}$'",
        "r'^[a-zA-Z0-9_]{4,12}$'")
replace("lib/screens/profile/account_edit_screen.dart",
        "'영문, 숫자, 밑줄로 4~30자 입력해 주세요.'",
        "'영문, 숫자, 밑줄로 4~12자 입력해 주세요.'")
print("Frontend integration patch applied; run flutter pub get and flutter analyze.")

# HTTP is permitted on the Android emulator only in the debug flavor.
# Release builds retain the platform default (HTTPS required).
debug_manifest = frontend / "android/app/src/debug/AndroidManifest.xml"
debug_manifest.write_text("""<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <application android:usesCleartextTraffic="true" />
</manifest>
""")
