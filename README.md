# EasyPrescience

EasyPrescience is a lightweight Evoker addon that assigns **Prescience**, **Blistering Scales**, **Rescue**, **Spatial Paradox / Time Spiral**, and **Verdant Embrace** from the right-click unit menu and keeps their macros updated automatically.

It is useful for **any Evoker spec**, not only Augmentation, because it also covers multi-spec utility spells.

## Features

- Assign targets from the Blizzard unit context menu
- Prescience supports **Shift**, **Alt**, and **Ctrl**, plus an optional **No Mod** assigned target
- Rescue, Spatial Paradox / Time Spiral, and Verdant Embrace use configurable modifier keys
- Blistering Scales uses its own dedicated assigned target
- Managed macros are created, repaired, and refreshed automatically
- Assignments are tracked by roster identity and remap automatically after party or raid swaps
- If an assigned player leaves the group, the addon clears that assignment and notifies you in chat
- Mouseover and normal default casting behavior are preserved
- Full configuration is available in **Blizzard Settings -> AddOns -> EasyPrescience**

## Commands

- `/ep` shows current status
- `/ep update` reviews and rebuilds all managed macros
- `/ep clear <nomod|shift|alt|ctrl|blistering|rescue|spatial|verdant>` clears one assignment
- `/ep macro <name>`
- `/ep blisteringmacro <name>`
- `/ep rescuemacro <name>`
- `/ep spatialmacro <name>`
- `/ep verdantmacro <name>`
- `/ep deletemacros` deletes all managed macros

## Notes

- Macro creation and editing are blocked in combat
- Spatial Paradox automatically swaps to Time Spiral when that talent is selected
- The addon tracks assigned players across party and raid slot changes automatically
