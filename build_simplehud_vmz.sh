#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT/mod"
OUT_FILE="$OUT_DIR/SimpleHUD.vmz"

mkdir -p "$OUT_DIR"

if [ ! -d "$ROOT/SimpleHUD" ] || [ ! -f "$ROOT/mod.txt" ] || [ ! -f "$ROOT/SimpleHUD.default.ini" ]; then
	echo "SimpleHUD bundle incomplete in $ROOT (need mod.txt, SimpleHUD.default.ini, SimpleHUD/)" >&2
	exit 1
fi

if command -v zip >/dev/null 2>&1; then
	(
		cd "$ROOT"
		rm -f "$OUT_FILE"
		items=(mod.txt SimpleHUD.default.ini SimpleHUD)
		if [ -d "$ROOT/Docs" ]; then items+=(Docs); fi
		zip -r -q "$OUT_FILE" "${items[@]}"
	)
else
	ROOT="$ROOT" OUT_FILE="$OUT_FILE" python3 - <<'PY'
import pathlib
import os
import zipfile

root = pathlib.Path(os.environ["ROOT"])
out = pathlib.Path(os.environ["OUT_FILE"])
out.parent.mkdir(parents=True, exist_ok=True)

entries = [
	pathlib.Path("mod.txt"),
	pathlib.Path("SimpleHUD.default.ini"),
	pathlib.Path("SimpleHUD"),
	pathlib.Path("Docs"),
]

with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as zf:
	for rel in entries:
		if rel.name == "Docs" and not (root / rel).exists():
			continue
		path = root / rel
		if path.is_file():
			zf.write(path, rel.as_posix())
		else:
			for child in path.rglob("*"):
				if child.is_file():
					zf.write(child, child.relative_to(root).as_posix())
PY
fi

echo "Built: $OUT_FILE"
