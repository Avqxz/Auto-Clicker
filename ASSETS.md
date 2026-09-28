# Map assets

The map is built from free Creator Store assets that live in the place file,
not in this repo (Rojo doesn't sync ServerStorage). Import them once in Studio
before pressing Play. Delete any scripts that come inside imported models;
the map code also strips scripts from every clone.

## Required: `ServerStorage/JTeaSimulatorPack`

Insert JTea's free simulator pack (asset **7151365600**) from the Toolbox and
move it into ServerStorage, renamed `JTeaSimulatorPack`. `MapBuilder.lua`
errors on startup without it. It uses these parts of the pack:

- `Forest` / `Ice` / `Lava` → `Map`: the Forest, Ice World and Lava World zones
- `Forest` / `Ice` / `Lava` → `Shop`: one glass egg capsule per egg (Candy and Space use the Forest capsule)
- `Forest` → `Extra Portal`: the Rebirth shrine

## Required: `ServerStorage/ZoneMaps`

Two free Creator Store maps, cleaned up (scripts, sounds, spawn points and
leftover buttons removed) and saved in the place:

| Child   | Source                                             | Floor used          |
|---------|----------------------------------------------------|---------------------|
| `Candy` | "Candy simulator MAP (Fixed)" (**4511240477**), only the meadow section between its Lvl20 and Lvl40 walls | `Baseplate` |
| `Space` | "Button SImulator Space map" (**5109843560**)     | `Basic Floor` model |

Zones are laid out in a line along -Z, linked by walkways that end in a
rebirth gate. `MapBuilder` clears any scenery standing in a walkway or on an
egg spot at build time, so the maps don't need hand-editing.

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
clears Terrain under the Forest, places the five zones with walkways and gates, flattens every map part to SmoothPlastic for
a cartoon look (Neon/Glass/ForceField kept), and sets Lighting. Put hand-placed extras
outside `Map`, or they'll be wiped.
