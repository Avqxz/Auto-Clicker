# Clicking Simulator

A Roblox pet-collection clicking simulator, in the style of games like
*Rebirth Champions Ultimate*: click a button to earn coins, hatch eggs for
pets that multiply your earnings, fuse duplicate pets into stronger Golden
versions, buy upgrades and auto-clickers, and rebirth for a permanent
multiplier plus more pet-equip slots. Progress is saved per-player with
`DataStoreService`.

## Features

- **Click to earn** — click the big button to earn coins based on your total click power.
- **Pets & eggs** — spend coins to hatch eggs; each egg has a weighted pool of pets with different rarities (Common → Mythic) and multipliers. Equip pets to multiply your click power and passive income.
- **Pet fusion** — collect 5 duplicates of the same (non-Golden) pet and fuse them into a Golden version worth 2x the multiplier.
- **Upgrades** — spend coins to permanently increase base coins earned per click.
- **Auto-clickers** — spend coins on passive generators that earn coins every second, even between clicks (also boosted by equipped pets).
- **Rebirth** — reset your coins, upgrades, and base click power in exchange for a permanent earnings multiplier and an extra pet-equip slot. Pets are a permanent collection and carry over through rebirth.
- **Leaderboard** — Coins and Rebirths show up in Roblox's built-in leaderboard (`leaderstats`).
- **Persistent saves** — data is loaded on join, saved every 60 seconds, and saved again on leave/server shutdown.
- **Server-authoritative** — all coin/currency/pet changes happen on the server; the client only sends intent (click, hatch, equip, fuse), with a click-rate cooldown to prevent spam exploits.

Not implemented (possible extensions): Aura/dice gacha system, multiple
zones/worlds, gamepass monetization — these would need real Roblox
MarketplaceService product IDs configured in Studio, which can't be set up
from code alone.

## Project layout

This is a [Rojo](https://rojo.space/) project, the standard way to develop
Roblox games in a text editor / git repo and sync them into Roblox Studio.

```
default.project.json                                  # Rojo project definition
src/
  ReplicatedStorage/Modules/GameConfig.lua             # Shared config: upgrades, auto-clickers, eggs/pets, rebirth math
  ServerScriptService/Server/init.server.lua           # Server bootstrap: remotes, click/purchase/hatch/equip/fuse/rebirth handling, autosave
  ServerScriptService/Server/PlayerData.lua             # DataStore load/save/cache module
  StarterPlayer/StarterPlayerScripts/Client/init.client.lua  # Builds the HUD/Shop/Eggs/Pets UI and talks to the server
```

## Running it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (the CLI, plus the [Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004)).
2. From the project root, start the Rojo server:
   ```
   rojo serve
   ```
3. In Roblox Studio, open the Rojo plugin and click **Connect**.
4. Press Play to test. Click the button to earn coins, open **Eggs** to hatch
   pets, **Pets** to equip/fuse them, **Shop** to buy upgrades/auto-clickers,
   and Rebirth once you've saved enough.

You can also build a standalone place file without Studio open:

```
rojo build -o build/ClickingSimulator.rbxl
```

## Tuning the game

All balancing — upgrade costs, click power gains, auto-clicker rates, egg
costs/pet pools/rarities/multipliers, fusion requirements, and rebirth
requirements/multipliers — lives in
`src/ReplicatedStorage/Modules/GameConfig.lua`, shared by both server and
client so the UI always reflects the same numbers the server enforces.

- Add more upgrades/auto-clickers by appending entries to the `Upgrades` or `AutoClickers` tables; the Shop UI generates itself from that list.
- Add more eggs/pets by appending to the `Eggs` table (each pet needs `Name`, `Rarity`, `Weight`, `Multiplier`); the Eggs and Pets UIs generate themselves from that list.
- Tune `BaseMaxEquippedPets` and `FusionRequirement` to change how many pets a player can equip at once and how many duplicates are needed to fuse a Golden pet.
