# Map assets

The map is built from free Creator Store assets that live in the place file,
not in this repo (Rojo doesn't sync ServerStorage). Import them once in Studio
before pressing Play. Delete any scripts that come inside imported models;
the map code also strips scripts from every clone.

## Required: `ServerStorage/JTeaSimulatorPack`

Insert JTea's free simulator pack (asset **7151365600**) from the Toolbox and
move it into ServerStorage, renamed `JTeaSimulatorPack`. `MapBuilder.lua`
errors on startup without it. It uses these parts of the pack:

- `Forest` → `Map` (lobby floor and layout), `Shop` (Basic Egg shop), `Extra Portal` (Rebirth shrine)
- `Ice` → `Shop` (decoration on Ice Island; skipped if missing)

## Optional: `ServerStorage/EnvironmentAssets`

A folder of props that `AssetScenery.lua` scatters along the zone edges. It
warns and skips everything if the folder is missing, and skips any single
name that isn't there. Any free models work; names must match exactly:

| Name        | Used for                                        |
|-------------|-------------------------------------------------|
| `Tree`      | Leafy trees (Forest only)                       |
| `Pine`      | Pine trees (both zones)                         |
| `Rock`      | Rocks (recolored to slate purple)               |
| `Bush`      | Bushes                                          |
| `Cottage`   | One house near spawn                            |
| `Mushrooms` | Small cluster near spawn                        |

Models are rescaled to a target height when they're placed, so their
original size doesn't matter.

## What the code owns

`MapBuilder.lua` destroys and rebuilds `Workspace.Map` on every server start,
clears Terrain under the lobby, builds the sky islands from smooth parts, flattens every map part to SmoothPlastic for
a cartoon look (Neon/Glass/ForceField kept), and sets Lighting. Put hand-placed extras
outside `Map`, or they'll be wiped.
