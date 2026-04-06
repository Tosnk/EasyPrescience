# EasyPrescience

EasyPrescience is a lightweight Evoker addon that lets you assign Prescience and utility targets from the Blizzard unit menu while keeping your macros updated automatically.

It is built for Augmentation convenience, but it also supports utility spells used by any Evoker spec.

## Features

- Assign Prescience, Blistering Scales, Rescue, Spatial Paradox / Time Spiral, and Verdant Embrace from the unit context menu
- Support Prescience targets for Shift, Alt, Ctrl, and an optional No Modifier target
- Configure modifier keys for Rescue, Spatial Paradox / Time Spiral, and Verdant Embrace
- Automatically create, repair, and update managed macros
- Auto-assign targets for party and raid play with separate toggles for each supported spell
- Reassign tracked targets when group members leave and notify you in chat
- Keep normal mouseover and default spell behavior intact
- Open settings from Blizzard Settings or the optional minimap button

## Auto-Assign Highlights

- In 5-player groups:
- Blistering Scales prefers the tank
- Rescue prefers the healer
- Prescience can target the other damage dealers

- In raids:
- Blistering Scales prefers the main tank, or the first tank if no main tank is set
- Spatial Paradox can prefer a selected healer class, with Priest favored by default

## Commands

- `/ep` shows the current addon status
- `/ep update` reviews and rebuilds all managed macros
- `/ep review` reviews and rebuilds all managed macros
- `/ep clear <nomod|shift|alt|ctrl|blistering|rescue|spatial|verdant>` clears one assignment
- `/ep autoassign on|off` enables or disables auto-assignment
- `/ep chatselections on|off` enables or disables chat output for auto-assigned targets
- `/ep macro <name>`
- `/ep blisteringmacro <name>`
- `/ep rescuemacro <name>`
- `/ep spatialmacro <name>`
- `/ep verdantmacro <name>`
- `/ep deletemacros` deletes all managed macros

## Notes

- Macro creation and editing are blocked in combat
- Spatial Paradox automatically switches to Time Spiral when that talent is selected
- The minimap button opens settings with Shift-Left Click
