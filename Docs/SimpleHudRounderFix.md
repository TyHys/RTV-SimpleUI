# SimpleHUD Stamina/Fatigue Scale-Fix Plan

## Purpose

This plan defines how to fix the stamina/fatigue display instability in `SimpleHUD` where values near `1.0` can suddenly render as ~`100` due to mixed unit detection (`0..1` vs `0..100`). It is written so a developer can implement it from scratch without prior context.

## Problem Summary

Observed behavior in logs:

- `body(raw=1.0167 pct=1.0167 display=1 scale=percent_0_to_100)`
- `body(raw=1.0000 pct=100.0000 display=100 scale=normalized_0_to_1)`
- `body(raw=0.9833 pct=98.3333 display=98 scale=normalized_0_to_1)`

Current normalization in `SimpleHUD/SimpleHUD/HudOverlay.gd`:

- For most stats, values `<= 1.0001` are treated as normalized and multiplied by 100.
- Values `> 1.0001` are treated as percentages directly.

This causes a hard threshold flip at ~`1.0`, creating a large visual jump and making low stamina appear incorrect.

## Important Context (Game vs Mod)

From decompiled game scripts:

- Game stamina is fundamentally maintained in `0..100` (`Character.gd` clamp logic).
- Around zero, game logic can oscillate between tiny positive values and zero due to drain/regen branch transitions. This is expected from game logic and should not be "fixed" in SimpleHUD.

SimpleHUD responsibility:

- Render game values consistently and predictably.
- Avoid dynamic per-frame unit reinterpretation for stamina/fatigue.

## Goals

1. Remove scale-discontinuity for stamina/fatigue display.
2. Ensure no frame can reinterpret stamina/fatigue scale based on raw value threshold.
3. Keep compatibility with existing preset configs (radial/text/nohide variants).
4. Preserve debugging clarity in logs.
5. Avoid changing unrelated stat behavior unless explicitly required.

## Non-Goals

- Rewriting game stamina logic in decompiled game scripts.
- Broad redesign of all stat widgets.
- Changing existing workshop-facing visual style beyond fixing incorrect values.

## Implementation Strategy

### 1) Replace dynamic stamina/fatigue scale detection with deterministic policy

Current risk point: `HudOverlay._normalized_percent()` infers units from magnitude.

Plan:

- Introduce an explicit per-stat normalization policy in `HudOverlay.gd`.
- For `STAT_STAMINA` and `STAT_FATIGUE`, do **not** use `<= 1.0001` auto-detection.
- Use a deterministic conversion path:
  - Preferred: treat as percent domain (`0..100`) always.
  - Optional compatibility mode (if needed for historical forks): provide a config flag to force normalized (`0..1`) interpretation, but never auto-switch at runtime.

Recommended helper shape:

- `_stat_domain_mode(sid) -> String` returning one of:
  - `"percent_0_to_100"`
  - `"normalized_0_to_1"`
  - `"legacy_auto"` (discouraged; for temporary fallback only)

Apply to:

- `_normalized_percent()`
- `_log_stamina_trace()` scale labels (`scale=...`)

### 2) Add explicit config setting for stamina/fatigue domain (optional but recommended)

File candidates:

- `SimpleHUD/SimpleHUD/Config.gd` (primary config surface)

Add fields (example names):

- `stamina_domain_mode` default `"percent_0_to_100"`
- `fatigue_domain_mode` default `"percent_0_to_100"`

Requirements:

- Safe defaults preserve expected behavior for current game.
- If config is missing (older INI/preset), fallback to percent mode.

### 3) Stabilize display value generation and rounding

In widget update flow, ensure value formatting does not amplify noise:

- Keep percent clamped to `0..100`.
- Keep current integer display via `round()` unless design requests floor/ceil.
- Optional: for numeric widgets only, add tiny deadband near 0 (`abs(v) < epsilon => 0`) to avoid `1/0/1` flicker due to game oscillation.

Do **not** hide real data changes; deadband should be minimal and explicit.

### 4) Update diagnostics to reveal policy, not inferred guess

In `_log_stamina_trace()`:

- Replace current inferred `scale=normalized_0_to_1|percent_0_to_100` from raw magnitude.
- Log configured/selected domain mode for each stat.
- Include both raw and normalized values so developers can validate transformation.

Example target log shape:

- `body(raw=0.9833 pct=0.9833 display=1 domain=percent_0_to_100 ...)`

or (if normalized mode chosen):

- `body(raw=0.9833 pct=98.3333 display=98 domain=normalized_0_to_1 ...)`

### 5) Preserve backward compatibility carefully

If there is concern some environments truly provide `0..1` stamina:

- Implement a temporary migration guard:
  - Config default percent.
  - One-time startup warning when raw values repeatedly stay in `0..1` for long periods while configured percent, suggesting user override.
- Do not auto-flip per-frame.

This keeps behavior deterministic while still helping diagnose edge deployments.

## File-Level Change Plan

### `SimpleHUD/SimpleHUD/HudOverlay.gd`

- Refactor `_normalized_percent()` to route through explicit stat-domain policy.
- Add helper(s) for per-stat domain lookup.
- Update `_log_stamina_trace()` to print deterministic domain mode.
- Keep all existing clamp guarantees.

### `SimpleHUD/SimpleHUD/Config.gd` (if config-based mode is implemented)

- Add domain fields and getters.
- Ensure defaults are set and loaded safely.
- Ensure no preset breaks when fields are absent.

### Optional preset/config docs

- If user-facing tuning is exposed, add brief note to docs/presets describing available domain modes and recommended default.

## Test Plan

Run tests in this order:

1. **Baseline smoke**
   - Start game with SimpleHUD enabled.
   - Verify no runtime errors and HUD binds correctly.

2. **Stamina drain to zero while sprinting**
   - Hold sprint continuously through depletion.
   - Expected: display should not jump from ~`1` to ~`100` around threshold.
   - Expected: value may oscillate near zero due to game logic, but within same domain scale.

3. **Fatigue (arm stamina) depletion**
   - Trigger weapon posture/aim conditions to drain fatigue.
   - Verify same no-jump behavior.

4. **Recovery path**
   - Stop sprinting/arm-drain triggers.
   - Verify smooth increase from low values with no domain flips.

5. **Preset matrix**
   - Validate at least:
     - `RadialColor`
     - `RadialPlain`
     - `TextNumericColor`
     - `TextNumericPlain`
     - one `NoHide` variant
   - Ensure all show consistent stamina/fatigue scaling.

6. **Log verification**
   - Confirm trace logs show fixed deterministic domain labels.
   - Confirm no alternating `scale=` modes based solely on crossing `1.0`.

## Acceptance Criteria

- No stamina/fatigue display jump from low numbers to near-100 at the `1.0` boundary.
- Scale mode for stamina/fatigue is deterministic across frames.
- HUD remains stable across radial and numeric presets.
- No regressions for non-stamina stats.
- Logging clearly explains conversion policy.

## Risks and Mitigations

- **Risk:** Some users may actually run a build where stamina is truly normalized (`0..1`).
  - **Mitigation:** optional config override for domain mode, deterministic per session.

- **Risk:** Existing logs/scripts might expect old `scale=` semantics.
  - **Mitigation:** document new `domain=` terminology and keep a short migration note.

- **Risk:** Touching shared normalization affects other stats.
  - **Mitigation:** scope changes explicitly to stamina/fatigue policy; add quick sanity checks for all stat IDs.

## Suggested Implementation Sequence (Practical)

1. Add domain helpers and refactor normalization in `HudOverlay.gd`.
2. Update stamina trace logging to use deterministic domain.
3. Add config fields/getters (if included).
4. Run manual in-game verification + log checks.
5. Validate preset matrix.
6. Document user-facing note (only if exposing config).

## Notes for a New Developer

- The bug is not "rounding math gone bad"; it is primarily **unit reinterpretation at runtime**.
- The game already clamps stamina/fatigue to `0..100`; SimpleHUD should trust a stable domain unless explicitly configured otherwise.
- If you see oscillation near zero after this fix, that is expected from game logic branch behavior and should be visually modest once scale is consistent.

