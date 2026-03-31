# EasyPrescience

EasyPrescience is a lightweight utility addon for Augmentation Evokers that lets you assign **Prescience**, **Blistering Scales**, **Rescue**, **Spatial Paradox**, and **Verdant Embrace** targets directly from the right-click unit context menu on party, raid, target, and nameplate frames, while automatically creating, reviewing, and repairing the related macros.

It is built for fast target setup with minimal friction and is especially useful in raid and group content where assignments need to be changed quickly.

Even though Prescience is Augmentation-specific, the addon still stays useful for **any Evoker spec** because the multi-spec utility spell macros can be configured and maintained from the same workflow.

## Features

- Right-click any supported player unit frame and assign it to:
  - **Set on Shift**
  - **Set on Alt**
  - **Set on Ctrl**
  - **Set Blistering Scales**
  - **Set Rescue**
  - **Set Spatial Paradox**
- **Set Verdant Embrace**
- No modifier casts **Prescience** normally
- Holding **Shift / Alt / Ctrl** casts **Prescience** on the player assigned to that modifier
- Each non-Prescience support spell uses its own configurable modifier key from the Blizzard Settings panel
- **Blistering Scales**, **Rescue**, **Spatial Paradox / Time Spiral**, and **Verdant Embrace** all cast normally by default and target the assigned player when their configured modifier is held
- Automatically creates macros if they do not already exist
- Automatically reviews and repairs missing, outdated, or manually modified macros
- Includes a full **Blizzard Settings -> AddOns** configuration panel for macro names and stored targets
- Works in **Raid / Party / Arena / Battlegrounds**
- Minimal setup, no extra UI windows, lightweight footprint

## Macro behavior

Prescience behavior:

- No modifier -> casts **Prescience** normally
- Shift -> casts on the player assigned to **Shift**
- Alt -> casts on the player assigned to **Alt**
- Ctrl -> casts on the player assigned to **Ctrl**

Blistering Scales behavior:

- No modifier -> casts **Blistering Scales** normally
- Configured modifier -> casts on the assigned player name

Rescue behavior:

- No modifier -> casts **Rescue** normally
- Configured modifier -> casts on the player assigned to **Rescue**

Spatial Paradox behavior:

- If **Spatial Paradox** is talented, the macro casts **Spatial Paradox**
- If **Time Spiral** is talented instead, the same macro casts **Time Spiral**
- Configured modifier -> targets the assigned player when the selected spell supports that behavior

Verdant Embrace behavior:

- No modifier -> casts **Verdant Embrace** normally
- Configured modifier -> casts on the player assigned to **Verdant Embrace**

## Commands

- `/ep` - show current settings
- `/ep macro <MacroName>` - set the Prescience macro name (default: `PrescienceName`)
- `/ep blisteringmacro <MacroName>` - set the Blistering Scales macro name (default: `BlisteringScales`)
- `/ep rescuemacro <MacroName>` - set the Rescue macro name (default: `RescueTarget`)
- `/ep spatialmacro <MacroName>` - set the Spatial Paradox macro name (default: `SpatialParadox`)
- `/ep verdantmacro <MacroName>` - set the Verdant Embrace macro name (default: `VerdantEmbrace`)
- `/ep set <shift|alt|ctrl> <player[-realm]>` - assign a Prescience target manually
- `/ep blistering <player[-realm]>` - assign the Blistering Scales target manually
- `/ep rescue <player[-realm]>` - assign the Rescue target manually
- `/ep spatial <player[-realm]>` - assign the Spatial Paradox target manually
- `/ep verdant <player[-realm]>` - assign the Verdant Embrace target manually
- `/ep clear <shift|alt|ctrl>` - clear one Prescience target
- `/ep clear blistering` - clear the Blistering Scales target
- `/ep clear rescue` - clear the Rescue target
- `/ep clear spatial` - clear the Spatial Paradox target
- `/ep clear verdant` - clear the Verdant Embrace target
- `/ep update` - force a macro refresh out of combat
- `/ep deletemacros` - delete every macro managed by EasyPrescience
- `/ep cleanuptargets` - normalize and refresh stored target values

## Settings UI

All configurable settings are available inside **Blizzard Settings -> AddOns -> EasyPrescience**.

From there you can:

- Rename every managed macro
- Choose the modifier key used by every non-Prescience support spell
- Edit stored player targets directly
- Pick targets from roster dropdowns when group members are available
- Run a full macro review to recreate or repair managed macros
- Clean up saved targets if you want to normalize or refresh stored values
- Delete all managed macros before removing the addon if you want a clean uninstall

## Notes

- Macro creation and editing are blocked in combat due to Blizzard restrictions
- Supports Blizzard unit menus and most common frames that use the modern Menu API
- Includes fixes for assignment update issues when switching groups, so retargeting remains reliable without needing macro rename workarounds

## Author

Dydko-Draenor

## Codebase / Support

This addon codebase is AI-generated and structured for fast maintenance, automated support, and rapid feature iteration.
