# EasyPrescience

EasyPrescience is a lightweight utility addon for Augmentation Evokers that lets you assign **Prescience**, **Blistering Scales**, **Rescue**, and **Spatial Paradox** targets directly from the right-click unit context menu on party, raid, target, and nameplate frames, while automatically creating and updating the related macros.

It is built for fast target setup with minimal friction and is especially useful in raid and group content where assignments need to be changed quickly.

## Features

- Right-click any supported player unit frame and assign it to:
  - **Set on Shift**
  - **Set on Alt**
  - **Set on Ctrl**
  - **Set Blistering Scales**
  - **Set Rescue**
  - **Set Spatial Paradox**
- No modifier casts **Prescience**, **Rescue**, and **Spatial Paradox** normally
- Holding **Shift / Alt / Ctrl** casts **Prescience** on the player assigned to that modifier
- Holding **Alt** casts **Rescue** on the assigned player
- Holding **Alt** casts **Spatial Paradox** on the assigned player
- **Blistering Scales** uses its own dedicated target and macro with no modifier support
- Automatically creates macros if they do not already exist
- Automatically updates macros when assignments change
- Works in **Raid / Party / Arena / Battlegrounds**
- Minimal setup, no extra UI windows, lightweight footprint

## Macro behavior

Prescience behavior:

- No modifier -> casts **Prescience** normally
- Shift -> casts on the player assigned to **Shift**
- Alt -> casts on the player assigned to **Alt**
- Ctrl -> casts on the player assigned to **Ctrl**

Blistering Scales behavior:

- Casts **Blistering Scales** on the assigned player name
- Uses no modifier support

Rescue behavior:

- No modifier -> casts **Rescue** normally
- Alt -> casts on the player assigned to **Rescue**

Spatial Paradox behavior:

- No modifier -> casts **Spatial Paradox** normally
- Alt -> casts on the player assigned to **Spatial Paradox**

## Commands

- `/ep` - show current settings
- `/ep macro <MacroName>` - set the Prescience macro name (default: `PrescienceName`)
- `/ep blisteringmacro <MacroName>` - set the Blistering Scales macro name (default: `BlisteringScales`)
- `/ep rescuemacro <MacroName>` - set the Rescue macro name (default: `RescueTarget`)
- `/ep spatialmacro <MacroName>` - set the Spatial Paradox macro name (default: `SpatialParadox`)
- `/ep set <shift|alt|ctrl> <player[-realm]>` - assign a Prescience target manually
- `/ep blistering <player[-realm]>` - assign the Blistering Scales target manually
- `/ep rescue <player[-realm]>` - assign the Rescue Alt target manually
- `/ep spatial <player[-realm]>` - assign the Spatial Paradox Alt target manually
- `/ep clear <shift|alt|ctrl>` - clear one Prescience target
- `/ep clear blistering` - clear the Blistering Scales target
- `/ep clear rescue` - clear the Rescue Alt target
- `/ep clear spatial` - clear the Spatial Paradox Alt target
- `/ep update` - force a macro refresh out of combat

## Notes

- Macro creation and editing are blocked in combat due to Blizzard restrictions
- Supports Blizzard unit menus and most common frames that use the modern Menu API
- Includes fixes for assignment update issues when switching groups, so retargeting remains reliable without needing macro rename workarounds

## Author

Dydko-Draenor

## Codebase / Support

This addon codebase is AI-generated and structured for fast maintenance, automated support, and rapid feature iteration.
