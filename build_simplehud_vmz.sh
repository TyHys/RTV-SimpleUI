#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT/mod"
# Ship one VMZ with this preset baked in as SimpleHUD/Config.gd (stable load path). Runtime menu presets load from preset_configs/.
PRESETS_DIR="$ROOT/presets"
DEFAULT_PRESET="RadialPlainNoHide"

mkdir -p "$OUT_DIR"

if [ ! -d "$ROOT/SimpleHUD" ] || [ ! -f "$ROOT/mod.txt" ] || [ ! -f "$ROOT/SimpleHUD.default.ini" ] || [ ! -d "$PRESETS_DIR" ]; then
	echo "SimpleHUD bundle incomplete in $ROOT (need mod.txt, SimpleHUD.default.ini, SimpleHUD/, presets/)" >&2
	exit 1
fi

DEFAULT_CONFIG="${PRESETS_DIR}/${DEFAULT_PRESET}/Config.gd"
if [ ! -f "$DEFAULT_CONFIG" ]; then
	echo "Missing default preset config: $DEFAULT_CONFIG" >&2
	exit 1
fi

## Copy each preset Config into SimpleHUD/preset_configs/ so the main-menu preset dropdown can load them (same sources as presets/<Name>/Config.gd).
mkdir -p "$ROOT/SimpleHUD/preset_configs"
for preset_dir in "$PRESETS_DIR"/*/ ; do
	[[ -d "$preset_dir" ]] || continue
	name=$(basename "$preset_dir")
	if [[ -f "${preset_dir}Config.gd" ]]; then
		cp "${preset_dir}Config.gd" "$ROOT/SimpleHUD/preset_configs/${name}.gd"
	fi
done

ROOT="$ROOT" OUT_DIR="$OUT_DIR" DEFAULT_CONFIG="$DEFAULT_CONFIG" python3 - <<'PY'
import pathlib
import os
import zipfile
import shutil
import tempfile

root = pathlib.Path(os.environ["ROOT"])
out_dir = pathlib.Path(os.environ["OUT_DIR"])
default_config = pathlib.Path(os.environ["DEFAULT_CONFIG"])
out_file = out_dir / "SimpleUI.vmz"

out_dir.mkdir(parents=True, exist_ok=True)
if out_file.exists():
	out_file.unlink()

if not default_config.is_file():
	raise SystemExit(f"Default preset config missing: {default_config}")

with tempfile.TemporaryDirectory(prefix="simplehud-build-") as tmp:
	stage = pathlib.Path(tmp)
	shutil.copy2(root / "mod.txt", stage / "mod.txt")
	shutil.copy2(root / "SimpleHUD.default.ini", stage / "SimpleHUD.default.ini")
	shutil.copytree(root / "SimpleHUD", stage / "SimpleHUD")

	# Default appearance when the mod loads (player can switch preset in menu).
	shutil.copy2(default_config, stage / "SimpleHUD" / "Config.gd")

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
PY

echo "Done: $OUT_DIR/SimpleUI.vmz (default preset: ${DEFAULT_PRESET})"
