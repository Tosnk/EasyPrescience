# EasyPrescience

EasyPrescience is a lightweight World of Warcraft addon that lets you **store Prescience targets directly on SHIFT / ALT / CTRL** from the **right-click unit context menu** and **automatically creates or updates your macro**.

## What changed

This version switches the addon to a cleaner and more reliable workflow:

- No modifier → **casts Prescience normally**
- **Shift** → casts on the player stored for Shift
- **Alt** → casts on the player stored for Alt
- **Ctrl** → casts on the player stored for Ctrl

It also includes a menu/update reliability pass so target reassignments keep working more consistently after roster or group changes.

## Features

- ✅ Right-click any supported player frame and assign a target to:
  - **Set on Shift**
  - **Set on Alt**
  - **Set on Ctrl**
- ✅ No modifier still behaves like a normal **Prescience** cast
- ✅ Works in **Raid / Party / Arena / Battlegrounds**
- ✅ Automatically **creates the macro** if it doesn't exist
- ✅ Automatically **updates the macro** when targets change
- ✅ Minimal setup, no extra UI

## How it works

EasyPrescience adds three entries to supported unit context menus for player units:

- **Set on Shift**
- **Set on Alt**
- **Set on Ctrl**

When clicked, the addon stores that player's name for the selected modifier and refreshes the macro.

## Macro behavior

Macro behavior is now:

- No modifier → normal **Prescience** cast
- **Shift** held → cast on stored **Shift** target
- **Alt** held → cast on stored **Alt** target
- **Ctrl** held → cast on stored **Ctrl** target
- If a modifier target is not configured, the macro falls back to the normal cast

## Macro creation

By default, EasyPrescience creates or updates a macro named:

`PrescienceName`

If the macro does not exist, the addon will create it automatically when allowed by the game client.

## Commands

Type `/ep` to print current settings.

- `/ep macro <MacroName>`  
  Set which macro to create or update.

- `/ep set <shift|alt|ctrl> <player[-realm]>`  
  Assign a player to a modifier slot manually.

- `/ep clear <shift|alt|ctrl>`  
  Clear one modifier slot.

- `/ep update`  
  Force a macro refresh.

## Notes / Limitations

- Blizzard blocks macro creation and editing in combat.
- Most default unit-frame context menus are supported through the modern Menu API.
- Some heavily customized unit-frame addons may use custom menus and may not expose these entries.

## Author

- **Dydko-Draenor**
- Discord: **Nkvri#2705**

## Codebase / Support

This addon codebase is **AI-generated and structured for automated support and iteration**.  
It is ready for rapid changes, feature extensions, and maintenance in an automated workflow.

## License

MIT License (see `LICENSE.txt`).
