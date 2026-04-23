extends RefCounted

## Built-in appearance presets (parallel to `presets/<Id>/` in the repo; scripts live under `preset_configs/` in the shipped mod).
## Labels are ordered alphabetically for the menu dropdown.
const PRESETS: Array = [
	{"id": "RadialColor", "label": "Radial, Color", "script": "res://SimpleHUD/preset_configs/RadialColor.gd"},
	{"id": "RadialColorNoHide", "label": "Radial, Color, No Hide", "script": "res://SimpleHUD/preset_configs/RadialColorNoHide.gd"},
	{"id": "RadialPlain", "label": "Radial, Plain", "script": "res://SimpleHUD/preset_configs/RadialPlain.gd"},
	{"id": "RadialPlainNoHide", "label": "Radial, Plain, No Hide", "script": "res://SimpleHUD/preset_configs/RadialPlainNoHide.gd"},
	{"id": "TextNumericColor", "label": "Text Numeric, Color", "script": "res://SimpleHUD/preset_configs/TextNumericColor.gd"},
	{"id": "TextNumericColorNoHide", "label": "Text Numeric, Color, No Hide", "script": "res://SimpleHUD/preset_configs/TextNumericColorNoHide.gd"},
	{"id": "TextNumericPlain", "label": "Text Numeric, Plain", "script": "res://SimpleHUD/preset_configs/TextNumericPlain.gd"},
	{"id": "TextNumericPlainNoHide", "label": "Text Numeric, Plain, No Hide", "script": "res://SimpleHUD/preset_configs/TextNumericPlainNoHide.gd"},
]
