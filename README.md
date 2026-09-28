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
- **Combo & crits** — consecutive clicks inside the combo window build a combo (x1.25 at 25, x1.5 at 50, x2 at 100, **OVERDRIVE** x3 at 200, with a glowing screen edge and sparks); every click can crit. Results are computed on the server and shown as floating "+N ⚡" numbers beside the character. Holding the CLICK button auto-clicks at 5/sec.
- **Upgrades** — spend coins to increase coins per click, plus Critical Chance / Critical Damage / Combo Duration boosts; buy x1, x10 or MAX at a time.
- **Auto-clickers** — spend coins on passive generators that earn coins every second, even between clicks (also boosted by equipped pets).
- **Ascension** — reset coins, upgrades, auto-clickers and click power for a permanent power multiplier, an extra pet-equip slot, and **Gems** (more if you overshoot the requirement). Pets, Gems and skills are kept. Each Ascension also opens the next zone gate. The Ascend panel previews the Gems, the multiplier change and what unlocks. (Stored as `RebirthCount` in saves.)
- **Skill tree** — permanent nodes bought with Gems in three branches: Power (Click Mastery, Crit Mastery, Mega Crits, Combo Boost), Automation (Auto Power, Offline Earnings, Head Start) and Luck (Egg Luck, Pet Slots, Golden Touch). Later nodes need their branch's first node.
- **Bosses** — each zone has a boss at its far end (Mossback, Frost Golem, Magma King, Gummy Tyrant, Void Titan). A Fight prompt starts a personal 60-second fight: your clicks damage the boss (same power/combo/crit math) instead of earning coins. Wins pay coins, Gems and a guaranteed gear drop; short cooldowns after wins and losses.
- **Equipment** — Gloves / Aura / Core / Artifact slots (GEAR tab). Each boss drops one of four themed pieces, Common (Forest) up to Mythic (Space), adding click power, crit chance/damage or auto income; Ember Idol and Quantum Gloves add a burst (every 100th click x5 / x10). Up to 40 pieces in the bag; Discard needs a second tap.
- **Leaderboard** — Coins and Rebirths show up in Roblox's built-in leaderboard (`leaderstats`).
- **Persistent saves** — data is loaded on join, saved every 60 seconds, and saved again on leave/server shutdown.
- **Server-authoritative** — all coin/currency/pet changes happen on the server; the client only sends intent (click, hatch, equip, fuse), with a click-rate cooldown to prevent spam exploits.
- **Five linked biome zones** — Forest (spawn, clickable orb, Rebirth shrine, Basic Egg), Ice World, Lava World, Candy World and Space World, laid out in a line and connected by walkways. Each walkway ends in a gate that needs 1 / 2 / 3 / 5 rebirths; gates are opened per player on the client, so each player only passes the ones they've unlocked. Every zone has its own egg, which must be hatched in person. The map is flattened to a smooth cartoon SmoothPlastic look. Forest/Ice/Lava come from JTea's free simulator pack and Candy/Space from free Creator Store maps — see [ASSETS.md](ASSETS.md). The in-world orb/eggs/altar are also directly clickable via `ClickDetector`s wired to the same server logic as the HUD buttons.
- **3D pet models** — a simple procedural "critter" model (`PetModelFactory.lua`) represents every pet: it's used for the pets that visibly orbit your character when equipped (seen by every player, not just you), for the icons in the Pets inventory list, and for the spinning model in the hatch-reveal popup. Golden pets get a neon look and sparkle particles.

Not implemented (possible extensions): hand-authored mesh/asset pets (pets
are simple primitive-part builds), an Aura/dice gacha system, more than one
world, and gamepass monetization — the last would need real Roblox
MarketplaceService product IDs configured in Studio, which can't be set up
from code alone.

## Project layout

This is a [Rojo](https://rojo.space/) project, the standard way to develop
Roblox games in a text editor / git repo and sync them into Roblox Studio.

```
default.project.json                                  # Rojo project definition
src/
  ReplicatedStorage/Modules/GameConfig.lua             # Shared config: upgrades, auto-clickers, eggs/pets, rebirth math
  ReplicatedStorage/Modules/PetModelFactory.lua        # Builds the procedural pet "critter" model (server + client)
  ServerScriptService/Server/init.server.lua           # Server bootstrap: remotes, click/purchase/hatch/equip/fuse/rebirth handling, autosave
  ServerScriptService/Server/PlayerData.lua             # DataStore load/save/cache module
  ServerScriptService/Server/MapBuilder.lua             # Builds the five biome zones, walkways, rebirth gates, lighting and interactives
  ServerScriptService/Server/AssetScenery.lua           # Scatters optional prop assets (trees, rocks, bushes) along the zone edges
  ServerScriptService/Server/PetFollowers.lua           # Spawns/animates the equipped pets that orbit each player
  StarterPlayer/StarterPlayerScripts/Client/init.client.lua  # Builds the HUD/Shop/Eggs/Pets UI and talks to the server
  StarterPlayer/StarterPlayerScripts/Client/ZoneGates.lua    # Opens the zone gates the local player has unlocked
  StarterPlayer/StarterPlayerScripts/Client/ClickFeel.lua    # Floating click numbers, combo meter and OVERDRIVE effects
  StarterPlayer/StarterPlayerScripts/Client/AscensionUI.lua  # Ascend panel, Gem-bought skill tree panel and HUD gem counter
  StarterPlayer/StarterPlayerScripts/Client/BossUI.lua       # Boss fight HUD (HP bar, timer) and results
  StarterPlayer/StarterPlayerScripts/Client/GearUI.lua       # GEAR tab: equipped slots and gear bag
```

## Running it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (the CLI, plus the [Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004)).
2. From the project root, start the Rojo server:
   ```
   rojo serve
   ```
3. In Roblox Studio, open the Rojo plugin and click **Connect**. The first
   time, also import the map assets into ServerStorage (see [ASSETS.md](ASSETS.md)).
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
