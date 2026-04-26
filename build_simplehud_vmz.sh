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

if [ ! -f "$ROOT/mod_mcm.txt" ]; then
	echo "Missing mod_mcm.txt for MCM build (expected at $ROOT/mod_mcm.txt)" >&2
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

out_dir.mkdir(parents=True, exist_ok=True)

if not default_config.is_file():
    raise SystemExit(f"Default preset config missing: {default_config}")


def stage_common(stage: pathlib.Path) -> None:
    """Copy files common to both builds (SimpleHUD tree + default.ini + baked Config.gd)."""
    shutil.copy2(root / "SimpleHUD.default.ini", stage / "SimpleHUD.default.ini")
    shutil.copytree(root / "SimpleHUD", stage / "SimpleHUD")
    shutil.copy2(default_config, stage / "SimpleHUD" / "Config.gd")


def write_vmz(stage: pathlib.Path, out_file: pathlib.Path) -> None:
    """Zip staged mod.txt + SimpleHUD.default.ini + SimpleHUD tree into a VMZ."""
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


# --- Standard build (SimpleUI.vmz) ---
# Uses mod.txt; MCM/ directory excluded (no MCM dependency).
out_std = out_dir / "SimpleUI.vmz"
if out_std.exists():
    out_std.unlink()

with tempfile.TemporaryDirectory(prefix="simplehud-build-std-") as tmp:
    stage = pathlib.Path(tmp)
    stage_common(stage)
    shutil.copy2(root / "mod.txt", stage / "mod.txt")
    mcm_dir = stage / "SimpleHUD" / "MCM"
    if mcm_dir.exists():
        shutil.rmtree(mcm_dir)
    write_vmz(stage, out_std)

print(f"Built: {out_std}")


# --- MCM build (SimpleUI-MCM.vmz) ---
# Uses mod_mcm.txt (renamed to mod.txt inside archive); includes SimpleHUD/MCM/ autoload.
# Requires Mod Configuration Menu (modworkshop.net/mod/53713) to be installed alongside this mod.
out_mcm = out_dir / "SimpleUI-MCM.vmz"
if out_mcm.exists():
    out_mcm.unlink()

with tempfile.TemporaryDirectory(prefix="simplehud-build-mcm-") as tmp:
    stage = pathlib.Path(tmp)
    stage_common(stage)
    shutil.copy2(root / "mod_mcm.txt", stage / "mod.txt")
    write_vmz(stage, out_mcm)

print(f"Built: {out_mcm}")
PY

echo "Done: $OUT_DIR/SimpleUI.vmz + $OUT_DIR/SimpleUI-MCM.vmz (default preset: ${DEFAULT_PRESET})"
