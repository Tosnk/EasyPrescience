# EasyPrescience

EasyPrescience is a lightweight World of Warcraft addon that lets you **pick Prescience targets instantly** from the **right-click unit context menu** on player frames (party/raid/target/nameplates/etc.) and **automatically creates/updates your macro**.

## Features

- ✅ Right-click any player unit frame → set **Prescience Main** / **Prescience Alt**
- ✅ Works in **Raid / Party / Arena / Battlegrounds**
- ✅ Automatically **creates the macro** if it doesn't exist
- ✅ **Modifier remap**: ALT / CTRL / SHIFT
- ✅ Optional **invert** mode (modifier casts Main)
- ✅ No spec checks, no extra UI, minimal footprint

## How it works

EasyPrescience adds two entries to unit context menus for player units:

- **Set Prescience (Main)**
- **Set Prescience (Alt)**

When clicked, the addon stores the selected character names and updates your macro accordingly.

## Macro behavior

Default behavior:
- No modifier → casts **Main**
- Modifier (default **ALT**) → casts **Alt**

Optional invert mode:
- Modifier → casts **Main**
- No modifier → casts **Alt**

## Macro creation

By default, EasyPrescience creates/updates a macro named:

`PrescienceName`

If the macro does not exist, the addon will create it automatically (out of combat).

## Commands

Type `/ep` to print current settings.

- `/ep macro <MacroName>`  
  Set which macro to create/update (default: `PrescienceName`).

- `/ep mod <alt|ctrl|shift>`  
  Change which modifier triggers the alternate target.

- `/ep invert <on|off>`  
  If **on**, the modifier casts **Main** and default casts **Alt**.

- `/ep update`  
  Force a macro refresh (out of combat only).

## Notes / Limitations

- Blizzard blocks macro creation/editing in combat.
- Most unit frames are supported through the modern Menu API. Some heavily customized unit-frame addons may use custom context menus.

## Author

- **Dydko-Draenor**
- Discord: **Nkvri#2705**

## Codebase / Support

This addon codebase is **AI-generated and structured for automated support and iteration**.  
It is ready for rapid changes, feature extensions, and maintenance in an automated workflow.

## License

MIT License (see `LICENSE` file).
