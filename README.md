# Top Me Off

An auto-restocking add-on for [Turtle WoW](https://turtle-wow.org/) (1.12 vanilla client). Automatically purchases reagents from vendors and moves consumables from your bank to your bags, so you never show up to raid empty-handed.

## Features

### Vendor Auto-Buy (Reagents)

When you open a merchant window, Top Me Off automatically purchases any reagents you're missing up to your configured target amounts:

- Rune of Portals
- Rune of Teleportation
- Arcane Powder

Reports total gold spent and warns if you can't afford something.

### Bank Auto-Restock (Consumables)

When you open your bank, the addon:

1. **Prints a color-coded summary** of every tracked consumable showing bag count, target, and bank reserves
   - Green: bags at or above target
   - Yellow: bags below target, bank has stock
   - Red: bags below target, bank is empty
2. **Automatically moves items** from bank to bags to reach target amounts
3. **Reports shortages** for anything the bank is low on or out of

Tracked consumable categories:

| Category | Items |
|---|---|
| Healing/Mana | Major Healing Potion, Major Mana Potion, Danonzo's Tel'Abim Delight, Nordanaar Herbal Tea |
| Elixirs | Greater Arcane Elixir, Dreamshard Elixir, Elixir of Greater Arcane Power, Cerebral Cortex Compound, Dreamtonic, Spirit of Zanza, Elixir of Fortitude, Mageblood Potion, Elixir of Poison Resistance |
| Potions | Magic Resistance Potion, Limited Invulnerability Potion, Potion of Quickness, Juju Flurry |
| Protection Potions | Greater Arcane/Nature/Fire/Shadow/Frost Protection Potions |
| Other | Heavy Runecloth Bandage, Light Feather, Savory Deviate Delight |
| Wizard Oils | Blessed Wizard Oil, Brilliant Wizard Oil |

### Chat Output

All messages are color-coded and printed to the default chat frame. Enable verbose mode to see individual item movements.

## Commands

| Command | Description |
|---|---|
| `/topmeoff` or `/tmo` | Show available commands |
| `/topmeoff status` | Print current bag and bank counts for all reagents and consumables |
| `/topmeoff verbose` | Toggle verbose mode (shows per-item purchase/move messages) |

## Installation

1. Download or clone this repository
2. Copy the `TopMeOff` folder to your WoW `Interface/AddOns` directory
3. Restart WoW or type `/reload` if already logged in

## Configuration

Item lists and target amounts are defined at the top of `TopMeOff.lua`. Edit the `REAGENTS` and `CONSUMABLES` tables to customize which items are tracked and how many you want to carry.

```lua
local CONSUMABLES = {
    [13446] = { name = "Major Healing Potion", target = 10 },
    -- ...
}
```
