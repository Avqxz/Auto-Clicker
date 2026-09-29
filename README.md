# Clicking Simulator

A Roblox pet-collection clicking simulator, in the style of games like
*Rebirth Champions Ultimate*: click to earn Power, hatch eggs for
pets that multiply your earnings, fuse duplicate pets into stronger Golden
versions, buy upgrades and auto-clickers, and rebirth for a permanent
multiplier plus more pet-equip slots. Progress is saved per-player with
`DataStoreService`.

## Features

- **Five currencies** — ⚡ **Power** (from clicking and auto-clickers; buys upgrades, needed to Ascend), 💰 **Coins** (from bosses, quests, daily rewards and **selling Power** with the SELL button; buys eggs), 💎 **Gems** (Ascension, bosses, quests; buys skills), 🎫 **Tokens** (quests, day-7 streak; buys 15-minute 2x Power / 2x Luck boosts in the Token Shop) and ✨ **Essence** (bosses, salvaging gear; upgrades gear to +5). Saves from before the split are converted once on join: old Coins become Power.
- **Click to earn** — click anywhere (or the CLICK button) to earn Power based on your total click power.
- **Pets & eggs** — walk up to an egg pedestal (eggs float and turn above their stands) and an egg panel opens: the egg, its price, the pets it can hatch with their odds (after your luck), and **Hatch 1 [E] / Hatch 3 [R] / Auto [T]**; touch screens get bigger buttons instead of key hints. Hatches are decided on the server, then play a reveal: the egg flies to the center, shakes, cracks in a flash and the pet pops out, with light rays for Rare+, and a colored flash, camera shake and fanfare for Mythic/Secret (click/tap/Space speeds it up). Seven rarity tiers (Common, Unique, Rare, Epic, Legendary, Mythic, Secret); Legendary+ pets stay "???" silhouettes in the odds until you hatch one. A 1-in-250 **Shiny** roll (x1.5 power) on every hatch. **Luck** from the Egg Luck skill, pet abilities, the Lucky pass, 2x Luck boosts and a server event multiplier scales rarer tiers more (`luck ^ power` per tier, renormalized). **Auto Hatch** (free from 1 Ascension, or a pass) keeps hatching until you turn it off, walk away, run out of Coins or fill your inventory. **Auto Delete** settings for Common–Epic (Shiny and newly discovered pets are always kept). Legendary+ and Shiny hatches are announced to the server. Equip pets to multiply your click power and passive income.
- **Pet fusion** — collect 5 duplicates of the same (non-Golden) pet and fuse them into a Golden version worth 2x the multiplier.
- **Pet abilities** — every Epic, Legendary and Mythic pet (★ in the egg list) has an ability while equipped: bursts (e.g. Ancient Dragon's *Overcharge*: every 30 clicks, next click x10), random procs (Volcano Titan: 3% chance of x20), *Void Surge* (5% chance to fill the combo to OVERDRIVE), or passives (crit, auto income, egg luck, combo window/bonus, +Coins). Golden pets get 1.5x the passive part. Abilities stack with each other and with gear.
- **Combo & crits** — consecutive clicks inside the combo window build a combo (x1.25 at 25, x1.5 at 50, x2 at 100, **OVERDRIVE** x3 at 200, with a glowing screen edge and sparks); every click can crit. Results are computed on the server and shown as floating "+N ⚡" numbers beside the character. Holding the CLICK button auto-clicks at 5/sec.
- **Upgrades** — spend Power to increase Power per click, plus Critical Chance / Critical Damage / Combo Duration boosts; buy x1, x10 or MAX at a time.
- **Auto-clickers** — spend Power on passive generators that earn Power every second, even between clicks (also boosted by equipped pets).
- **Ascension** — reset Power, Coins, upgrades, auto-clickers and click power for a permanent power multiplier, an extra pet-equip slot, and **Gems** (more if you overshoot the requirement). Pets, gear, skills, Gems, Tokens and Essence are kept. Each Ascension also opens the next zone gate. The Ascend panel previews the Gems, the multiplier change and what unlocks. (Stored as `RebirthCount` in saves.)
- **Skill tree** — permanent nodes bought with Gems in three branches: Power (Click Mastery, Crit Mastery, Mega Crits, Combo Boost), Automation (Auto Power, Offline Earnings, Head Start) and Luck (Egg Luck, Pet Slots, Golden Touch). Later nodes need their branch's first node.
- **Bosses** — each biome island has a boss, a giant version of its Legendary pet (Stag King, Great Sphinx, Aurora Owl, Crystal Deer, Phoenix Lord, Cake Dragon, Celestial Dragon). A Fight prompt starts a personal 60-second fight: your clicks damage the boss (same power/combo/crit math) instead of earning coins. Wins pay coins, Gems and a guaranteed gear drop; short cooldowns after wins and losses.
- **Equipment** — Gloves / Aura / Core / Artifact slots (GEAR tab). Each boss drops one of four themed pieces, Common (Grasslands) up to Mythic (Celestial), adding click power, crit chance/damage or auto income; Ember Idol and Quantum Gloves add a burst (every 100th click x5 / x10). Up to 40 pieces in the bag; Discard needs a second tap.
- **Daily rewards** — a 7-day login streak (Gems and Coins; 40 Gems + 10 Tokens on day 7); missing a day restarts it. The calendar opens by itself when a reward is ready.
- **Quests** — 3 daily and 3 weekly quests (clicks, hatches, bosses, combos, Ascensions, upgrades, Legendary hatches) paying Gems; the same set for everyone each UTC day/week. QUESTS/DAILY buttons show a red dot when something can be claimed.
- **Offline earnings** — auto-clickers keep earning 5% of their rate while you're away (8h max, more with the Offline Earnings skill), shown in a Welcome Back panel.
- **UI polish** — clean mobile style (thin soft outlines, subtle gradients), the world blurs behind open menus, panels pop in, Power/Coins/Gems counters roll to new values, buttons light up on hover and dim on press, and Legendary/Mythic moments shake the camera (all motion respects the FX LOW toggle).
- **Background music** — joyful, calm tracks from Roblox's licensed APM library (Feeling Glad, A Welcome Smile, Ukelele Maiden, Feels Easy, On the Go) in a shuffled, cross-faded loop; the round 🎵 button mutes it (separate from the SOUND effects toggle). Tracks and volume are in `GameConfig.Music`.
- **Leaderboard** — Power and Ascensions show up in Roblox's built-in leaderboard (`leaderstats`).
- **Persistent saves** — data is loaded on join, saved every 60 seconds, and saved again on leave/server shutdown.
- **Server-authoritative** — all coin/currency/pet changes happen on the server; the client only sends intent (click, hatch, equip, fuse), with a click-rate cooldown to prevent spam exploits.
- **Lobby + seven biome islands** — the Blender art package's world (see [ASSETS.md](ASSETS.md)): a lobby (spawn, click orb, Ascend altar on the trading plaza, Upgrades / Pet Index / Daily Rewards buildings, Boosts fountain, leaderboards, Starter Egg) and Grasslands, Desert, Ice Peaks, Enchanted Forest, Volcano, Candy Land and Celestial Heaven, joined by bridges. Each bridge's gate needs 1 / 2 / 3 / 4 / 5 / 6 / 8 Ascensions and is opened per player on the client. Every island has its own egg (hatched in person) and a boss. The in-world orb/eggs/altar are also clickable via `ClickDetector`s wired to the same server logic as the HUD buttons.
- **Pets** — 49 pets from the art package, seven per biome (Common, Rare, Epic, Legendary, Secret/Mythic), plus older pets kept for existing saves. Imported pet models (`ReplicatedStorage.ArtPets`) and their rendered icons are used where present; otherwise `PetModelFactory.lua` builds a cartoon cube pet in the biome's colors. Legendary/Mythic accents glow, Mythic and Golden pets sparkle, Golden pets turn gold.

- **Store (gamepasses & developer products)** — Auto Click (AUTO toggle), Triple Hatch (Hatch 3), Auto Hatch, +3 Pet Equip, Lucky (x1.5 egg luck), Fast Hatch (half cooldown) and VIP (+10% Power and Coins, [VIP] chat tag, +5 Gems per daily reward, sparkle aura); plus 2x Power / 2x Luck (15 min), Instant Boss Retry and a 25-Token pack. All convenience; nothing is required to progress. **IDs start at 0 (hidden from players)** — see "Setting up monetization" below.

Not implemented (possible extensions): the art package's pet variants
(Rainbow, Shiny, Void, Crystal), an Aura/dice gacha system, trading (the
lobby's trading plaza hosts the Ascend altar for now), a battle pass,
limited-time events and an hourly global boss.

## Setting up monetization

1. In the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open this experience →
   **Monetization → Passes** and create one pass per entry in `GameConfig.GamePasses`
   (Auto Click, Triple Hatch, +3 Pet Equip, Lucky, Fast Hatch, VIP). Give each a price and put it
   **On Sale**. Ready-made 512×512 icons are in `assets/gamepass-icons/` (`AutoClick.png`,
   `TripleHatch.png`, `PetSlots.png`, `Lucky.png`, `FastHatch.png`, `VIP.png`); their SVG sources and
   generator (`make_icons.py`, rendered with headless Chrome) are alongside.
2. Under **Monetization → Developer Products**, create one product per entry in
   `GameConfig.DevProducts` (2x Power, 2x Luck, Instant Boss Retry, Token Pack) with a price.
3. Copy each numeric ID into the matching `Id = 0` in
   `src/ReplicatedStorage/Modules/GameConfig.lua` and publish. Items with an ID show in the STORE
   with their Robux price; items left at 0 stay hidden (Studio shows them as "ID not set").

Developer product purchases are recorded per player (`Receipts` in the save) and saved before
Roblox is told they were granted, so a retry never grants twice.

## Project layout

This is a [Rojo](https://rojo.space/) project, the standard way to develop
Roblox games in a text editor / git repo and sync them into Roblox Studio.

```
default.project.json                                  # Rojo project definition
src/
  ReplicatedStorage/Modules/GameConfig.lua             # Shared config: upgrades, auto-clickers, pets, rebirth math
  ReplicatedStorage/Modules/EggConfig.lua              # Eggs, pet odds, hatch options, keys, luck, Shiny and hatch sounds
  ReplicatedStorage/Modules/PetConfig.lua              # Rarity tiers (colors, luck scaling, announcements, auto-delete)
  ReplicatedStorage/Modules/HatchMath.lua              # Shared odds math: normalizing, luck, rolls, chance labels
  ReplicatedStorage/Modules/PetModelFactory.lua        # Builds pet models: imported art pets, or cartoon cube pets (server + client)
  ReplicatedStorage/Modules/ArtLook.lua                # Colors imported art models from ArtMaterials.lua (generated)
  ServerScriptService/Server/init.server.lua           # Server bootstrap: remotes, click/purchase/hatch/equip/fuse/rebirth handling, autosave
  ServerScriptService/Server/PlayerData.lua             # DataStore load/save/cache module
  ServerScriptService/Server/MapBuilder.lua             # Places the imported art world and wires gates, eggs, stations, bosses and lighting
  ServerScriptService/Server/PetFollowers.lua           # Spawns/animates the equipped pets that orbit each player
  ServerScriptService/Server/EggHatchingService.lua     # RequestHatch: validation, anti-spam, payment, inventory, auto-delete, announcements
  ServerScriptService/Server/PetRollService.lua         # Server-only pet and Shiny rolls
  ServerScriptService/Server/Quests.lua                 # Daily/weekly quest progress and the daily login reward
  ServerScriptService/Server/Monetization.lua           # Gamepass ownership, VIP aura, developer product receipts
  StarterPlayer/StarterPlayerScripts/Client/init.client.lua  # Builds the HUD/Shop/Eggs/Pets UI and talks to the server
  StarterPlayer/StarterPlayerScripts/Client/ZoneGates.lua    # Opens the zone gates the local player has unlocked
  StarterPlayer/StarterPlayerScripts/Client/EggInteractionController.lua  # Egg panel (proximity), hatch buttons/keys, Auto Hatch, Auto Delete
  StarterPlayer/StarterPlayerScripts/Client/HatchAnimationController.lua  # Hatch reveal animation (1 or 3 eggs)
  StarterPlayer/StarterPlayerScripts/Client/EggPedestals.lua # Floating, turning pedestal eggs
  StarterPlayer/StarterPlayerScripts/Client/ClickFeel.lua    # Floating click numbers, combo meter and OVERDRIVE effects
  StarterPlayer/StarterPlayerScripts/Client/AscensionUI.lua  # Ascend panel, Gem-bought skill tree panel and HUD gem counter
  StarterPlayer/StarterPlayerScripts/Client/BossUI.lua       # Boss fight HUD (HP bar, timer) and results
  StarterPlayer/StarterPlayerScripts/Client/GearUI.lua       # GEAR tab: equipped slots and gear bag
  StarterPlayer/StarterPlayerScripts/Client/RetentionUI.lua  # Quests, Daily rewards and Welcome Back panels
  StarterPlayer/StarterPlayerScripts/Client/EconomyUI.lua    # Coins counter, SELL button, boost timers and Token Shop
  StarterPlayer/StarterPlayerScripts/Client/UIPolish.lua     # Menu blur, panel pop-in and camera shake
  StarterPlayer/StarterPlayerScripts/Client/Counter.lua      # Animated number labels
  StarterPlayer/StarterPlayerScripts/Client/MusicPlayer.lua  # Background music playlist and 🎵 mute button
  StarterPlayer/StarterPlayerScripts/Client/StoreUI.lua      # Shopping-cart STORE button + panel, AUTO click toggle, [VIP] chat tag
tools/art/                                            # Art-package import: FBX reader/fixer, Open Cloud uploader, material generator (see ASSETS.md)
```

## Running it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (the CLI, plus the [Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004)).
2. From the project root, start the Rojo server:
   ```
   rojo serve
   ```
3. In Roblox Studio, open the Rojo plugin and click **Connect**. The first
   time, also import the map assets into ServerStorage (see [ASSETS.md](ASSETS.md)).
4. Press Play to test. Click to earn Power, SELL it for Coins, open **Eggs** to hatch
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
- Add eggs in `EggConfig.lua` (each pet needs `Name`, `Rarity`, `Multiplier`, and a `Weight` or percentage `Chance`; they're normalized), then give a pedestal the egg's id: MapBuilder does this for the art package's egg stands, or tag any part `EggPedestal` with an `EggId` attribute. The egg panel, Eggs menu and odds build themselves. Rarity tiers (colors, luck scaling, announcements, auto-delete) are in `PetConfig.lua`; hatch options, keys, luck, Shiny odds and sounds in `EggConfig.lua`.
- Testing in Studio: set a JSON string attribute `StudioTestData` on ServerStorage (e.g. `{"Coins":1000000,"RebirthCount":3}`) and it's merged into the throwaway Studio save.
- Tune `BaseMaxEquippedPets` and `FusionRequirement` to change how many pets a player can equip at once and how many duplicates are needed to fuse a Golden pet.

## Credits

- World, eggs and pets: the Clicking Simulator Blender art package in `art/` (git-ignored; see ASSETS.md).
- Music: Roblox's licensed APM music library.
