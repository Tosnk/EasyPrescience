# EasyPrescience

EasyPrescience is a lightweight World of Warcraft addon that lets you assign **Prescience** and **Blistering Scales** targets directly from the **right-click unit context menu** and automatically creates or updates the related macros.

## What changed

This version uses a cleaner and more reliable workflow:

- No modifier -> **casts Prescience normally**
- **Shift** -> casts on the player stored for Shift
- **Alt** -> casts on the player stored for Alt
- **Ctrl** -> casts on the player stored for Ctrl
- **Blistering Scales** gets its own dedicated target and macro with no modifier support

It also includes a menu update pass so target reassignments keep working more consistently after roster or group changes.

## Features

- Right-click any supported player frame and assign a target to:
  - **Set on Shift**
  - **Set on Alt**
  - **Set on Ctrl**
  - **Set Blistering Scales**
- No modifier still behaves like a normal **Prescience** cast
- **Blistering Scales** uses a separate single-target macro
- Works in **Raid / Party / Arena / Battlegrounds**
- Automatically **creates macros** if they don't exist
- Automatically **updates macros** when targets change
- Minimal setup, no extra UI

## How it works

EasyPrescience adds four entries to supported unit context menus for player units:

- **Set on Shift**
- **Set on Alt**
- **Set on Ctrl**
- **Set Blistering Scales**

When clicked, the addon stores that player's name for the selected option and refreshes the relevant macro.

## Macro behavior

Prescience macro behavior:

- No modifier -> normal **Prescience** cast
- **Shift** held -> cast on stored **Shift** target
- **Alt** held -> cast on stored **Alt** target
- **Ctrl** held -> cast on stored **Ctrl** target
- If a modifier target is not configured, the macro falls back to the normal cast

Blistering Scales macro behavior:

- Casts **Blistering Scales** on the stored player name
- Uses no modifier support

## Macro creation

By default, EasyPrescience creates or updates these macros:

- `PrescienceName`
- `BlisteringScales`

If a macro does not exist, the addon will create it automatically when allowed by the game client.

## Commands

Type `/ep` to print current settings.

- `/ep macro <MacroName>`
  Set which Prescience macro to create or update.

- `/ep blisteringmacro <MacroName>`
  Set which Blistering Scales macro to create or update.

- `/ep set <shift|alt|ctrl> <player[-realm]>`
  Assign a player to a Prescience modifier slot manually.

- `/ep blistering <player[-realm]>`
  Assign the Blistering Scales target manually.

- `/ep clear <shift|alt|ctrl>`
  Clear one Prescience modifier slot.

- `/ep clear blistering`
  Clear the Blistering Scales target.

- `/ep update`
  Force all configured macros to refresh.

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
