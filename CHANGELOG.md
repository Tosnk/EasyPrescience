# Changelog

## 2.3.5

- Repackaged the 2.3.4 feature set under a fresh release tag so CurseForge receives the correct archive contents and changelog

## 2.3.4

- Prevented auto-assignment from overwriting manual assignments on routine group updates
- Limited automatic reassignment to cases where a tracked assigned player actually moved to a new unit slot or left the group
- Fixed settings dropdowns to refresh immediately after changing preferred healer selections and other auto-assignment-driven values
- Added `Evoker` addon menu categorization in the TOC metadata
- Added Chinese locale support and left only ruzzian unsupported

## 2.3.3

- Re-released to sync the manual CurseForge changelog with the latest published addon state

## 2.3.2

- Added locale-safe macro generation for supported WoW clients instead of relying on English spell names
- Added explicit locale support handling for all WoW locales except ruzzian
- Added Verdant Embrace auto-assignment in party and raid groups

## 2.3.1

- Updated the addon metadata for WoW 12.0.5 compatibility

## 2.3

- Added Source of Magic support with its own target, macro, menu entry, options, and auto-assignment
- Added Source of Magic healer preference selection for both party and raid auto-assignment
- Changed Spatial Paradox preferred healer class default to Any healer
- Hid self-only Verdant Embrace assignment from your own player and nameplate context menus for consistency

## 2.2.1

- Hid self-only utility assignment options from your own player and nameplate context menus for better consistency
- Improved CurseForge packaging configuration to use the manual changelog

## 2.2

- Added automatic assignment support for party and raid play, with separate toggles for supported spells
- Added a minimap button with tooltip help, Shift-Left Click settings access, and optional visibility control
- Added chat output for current assignments from the minimap button and optional auto-assignment summaries
- Improved reassignment behavior when tracked group members leave the party or raid
- Cleaned up the Blizzard Settings layout and wording
- Added a simplified circular addon icon better suited for minimap use
- Improved slash-command status output and settings access quality-of-life
- Fixed issues with the minimap settings opener and minimap icon rendering
