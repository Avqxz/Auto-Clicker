# Clicking Simulator

A Roblox "clicking simulator" game: click a button to earn coins, buy upgrades
to increase your coins per click, buy auto-clickers for passive income, and
rebirth for a permanent multiplier once you've saved up enough. Progress is
saved per-player with `DataStoreService`.

## Features

- **Click to earn** — click the big button to earn coins based on your click power.
- **Upgrades** — spend coins to permanently increase coins earned per click.
- **Auto-clickers** — spend coins on passive generators that earn coins every second, even between clicks.
- **Rebirth** — reset your coins and upgrades in exchange for a permanent earnings multiplier, then start climbing again.
- **Leaderboard** — Coins and Rebirths show up in Roblox's built-in leaderboard (`leaderstats`).
- **Persistent saves** — data is loaded on join, saved every 60 seconds, and saved again on leave/server shutdown.
- **Server-authoritative** — all coin/currency changes happen on the server; the client only sends button-press intent, with a cooldown to prevent click-spam exploits.

## Project layout

This is a [Rojo](https://rojo.space/) project, the standard way to develop
Roblox games in a text editor / git repo and sync them into Roblox Studio.

```
default.project.json                                  # Rojo project definition
src/
  ReplicatedStorage/Modules/GameConfig.lua             # Shared config: upgrades, auto-clickers, rebirth math
  ServerScriptService/Server/init.server.lua           # Server bootstrap: remotes, click/purchase/rebirth handling, autosave
  ServerScriptService/Server/PlayerData.lua             # DataStore load/save/cache module
  StarterPlayer/StarterPlayerScripts/Client/init.client.lua  # Builds the HUD/shop UI and talks to the server
```

## Running it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (the CLI, plus the [Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004)).
2. From the project root, start the Rojo server:
   ```
   rojo serve
   ```
3. In Roblox Studio, open the Rojo plugin and click **Connect**.
4. Press Play to test. Click the button to earn coins, open the Shop to buy
   upgrades/auto-clickers, and Rebirth once you've saved enough.

You can also build a standalone place file without Studio open:

```
rojo build -o build/ClickingSimulator.rbxl
```

## Tuning the game

All balancing — upgrade costs, click power gains, auto-clicker rates, and
rebirth requirements/multipliers — lives in
`src/ReplicatedStorage/Modules/GameConfig.lua`, shared by both server and
client so the UI always reflects the same numbers the server enforces. Add
more upgrades/auto-clickers by appending entries to the `Upgrades` or
`AutoClickers` tables; the shop UI generates itself from that list.
