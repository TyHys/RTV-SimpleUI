#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT/mod"
# Each preset is a small class extending SimpleHUDConfigCore.gd; the build copies it onto staged SimpleHUD/Config.gd (stable load path).
PRESETS_DIR="$ROOT/presets"

mkdir -p "$OUT_DIR"

if [ ! -d "$ROOT/SimpleHUD" ] || [ ! -f "$ROOT/mod.txt" ] || [ ! -f "$ROOT/SimpleHUD.default.ini" ] || [ ! -d "$PRESETS_DIR" ]; then
	echo "SimpleHUD bundle incomplete in $ROOT (need mod.txt, SimpleHUD.default.ini, SimpleHUD/, presets/)" >&2
	exit 1
fi

## Copy each preset Config into SimpleHUD/preset_configs/ so the runtime main-menu preset dropdown can load them (same sources as presets/<Name>/Config.gd).
mkdir -p "$ROOT/SimpleHUD/preset_configs"
for preset_dir in "$PRESETS_DIR"/*/ ; do
	[[ -d "$preset_dir" ]] || continue
	name=$(basename "$preset_dir")
	if [[ -f "${preset_dir}Config.gd" ]]; then
		cp "${preset_dir}Config.gd" "$ROOT/SimpleHUD/preset_configs/${name}.gd"
	fi
done

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
		print(f"Skip preset '{preset_name}': missing presets/{preset_dir.name}/Config.gd")
		continue

	out_file = out_dir / f"SimpleUI-{preset_name}.vmz"
	if out_file.exists():
		out_file.unlink()

	with tempfile.TemporaryDirectory(prefix="simplehud-build-") as tmp:
		stage = pathlib.Path(tmp)
		shutil.copy2(root / "mod.txt", stage / "mod.txt")
		shutil.copy2(root / "SimpleHUD.default.ini", stage / "SimpleHUD.default.ini")
		# Runtime package only — preset sources stay under ROOT/presets (not zipped).
		shutil.copytree(root / "SimpleHUD", stage / "SimpleHUD")

		# Replace repo Config.gd (entrypoint) with this preset; implementation stays in SimpleHUDConfigCore.gd.
		shutil.copy2(preset_config, stage / "SimpleHUD" / "Config.gd")

		with zipfile.ZipFile(out_file, "w", compression=zipfile.ZIP_DEFLATED) as zf:
			for rel in [
				pathlib.Path("mod.txt"),
				pathlib.Path("SimpleHUD.default.ini"),
				pathlib.Path("SimpleHUD"),
			]:
				path = stage / rel
				if path.is_file():
					zf.write(path, rel.as_posix())
				else:
					for child in path.rglob("*"):
						if child.is_file():
							zf.write(child, child.relative_to(stage).as_posix())

	print(f"Built: {out_file}")
	built_any = True

if not built_any:
	raise SystemExit("No presets were built. Check presets/*/Config.gd")
PY

echo "Done building preset VMZ files in $OUT_DIR"
