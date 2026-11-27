#!/usr/bin/env python3
"""Apply the tracked integration files to the local frontend submodule."""

from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
frontend = root / "frontend"
overlay = root / "integration" / "frontend_overlay"
pubspec = frontend / "pubspec.yaml"

if not pubspec.is_file():
    raise SystemExit("Missing frontend submodule. Run: git submodule update --init --recursive")


def add_after(content, anchor, addition):
    if addition in content:
        return content
    if content.count(anchor) != 1:
        raise SystemExit(f"Patch mismatch: pubspec.yaml: {anchor!r}")
    return content.replace(anchor, anchor + addition, 1)


original = pubspec.read_text(encoding="utf-8")
content = original
anchor = "  firebase_auth: 5.7.0\n"
for dependency in reversed((
    "  http: ^1.5.0\n",
    "  shared_preferences: ^2.5.3\n",
    "  flutter_localizations:\n    sdk: flutter\n",
    "  intl: any\n",
)):
    content = add_after(content, anchor, dependency)
content = add_after(content, "\nflutter:\n", "  generate: true\n")
if content != original:
    pubspec.write_text(content, encoding="utf-8", newline="\n")

for src in sorted(overlay.rglob("*")):
    if not src.is_file():
        continue
    dest = frontend / src.relative_to(overlay)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.is_file() or src.read_bytes() != dest.read_bytes():
        shutil.copyfile(src, dest)
        print("overlay", dest.relative_to(frontend))

print("Frontend overlay applied. Run flutter pub get and flutter gen-l10n in frontend.")
