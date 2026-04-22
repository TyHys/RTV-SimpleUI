#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT/mod"
PRESETS_DIR="$ROOT/SimpleHUD/widgets/ConfigPresets"

mkdir -p "$OUT_DIR"

if [ ! -d "$ROOT/SimpleHUD" ] || [ ! -f "$ROOT/mod.txt" ] || [ ! -f "$ROOT/SimpleHUD.default.ini" ] || [ ! -d "$PRESETS_DIR" ]; then
	echo "SimpleHUD bundle incomplete in $ROOT (need mod.txt, SimpleHUD.default.ini, SimpleHUD/)" >&2
	exit 1
fi

ROOT="$ROOT" OUT_DIR="$OUT_DIR" PRESETS_DIR="$PRESETS_DIR" python3 - <<'PY'
import pathlib
import os
import zipfile
import shutil
import tempfile

root = pathlib.Path(os.environ["ROOT"])
out_dir = pathlib.Path(os.environ["OUT_DIR"])
presets_dir = pathlib.Path(os.environ["PRESETS_DIR"])
out_dir.mkdir(parents=True, exist_ok=True)

preset_paths = sorted([p for p in presets_dir.iterdir() if p.is_dir()])
built_any = False

for preset_dir in preset_paths:
	preset_name = preset_dir.name
	preset_config = preset_dir / "Config.gd"
	if not preset_config.is_file():
		print(f"Skip preset '{preset_name}': missing Config.gd")
		continue

	out_file = out_dir / f"SimpleUI-{preset_name}.vmz"
	if out_file.exists():
		out_file.unlink()

	with tempfile.TemporaryDirectory(prefix="simplehud-build-") as tmp:
		stage = pathlib.Path(tmp)
		shutil.copy2(root / "mod.txt", stage / "mod.txt")
		shutil.copy2(root / "SimpleHUD.default.ini", stage / "SimpleHUD.default.ini")
		shutil.copytree(root / "SimpleHUD", stage / "SimpleHUD")
		if (root / "Docs").exists():
			shutil.copytree(root / "Docs", stage / "Docs")

		# Inject preset config as active runtime config for this bundle.
		shutil.copy2(preset_config, stage / "SimpleHUD" / "Config.gd")

		with zipfile.ZipFile(out_file, "w", compression=zipfile.ZIP_DEFLATED) as zf:
			for rel in [
				pathlib.Path("mod.txt"),
				pathlib.Path("SimpleHUD.default.ini"),
				pathlib.Path("SimpleHUD"),
				pathlib.Path("Docs"),
			]:
				path = stage / rel
				if rel.name == "Docs" and not path.exists():
					continue
				if path.is_file():
					zf.write(path, rel.as_posix())
				else:
					for child in path.rglob("*"):
						if child.is_file():
							zf.write(child, child.relative_to(stage).as_posix())

	print(f"Built: {out_file}")
	built_any = True

if not built_any:
	raise SystemExit("No presets were built. Check ConfigPresets/*/Config.gd")
PY

echo "Done building preset VMZ files in $OUT_DIR"
