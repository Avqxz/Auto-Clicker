# Map & pet assets (art package)

The world and pets come from the Blender art package in `art/` (`art/README.md` describes it; `art/` is
git-ignored, the `.blend` and zip are ~75 MB). The meshes are uploaded to Roblox and live in the place:

| In the place | What | Used by |
|---|---|---|
| `ServerStorage.ArtPack.World` | `World_Assembled.fbx`: lobby, 7 biome islands, bridges, gates, egg stands | `MapBuilder.lua` |
| `ReplicatedStorage.ArtPets.Pet_<Biome>_<Name>` | the 49 pets | `PetModelFactory.lua` (followers, bosses, hatch reveal) |
| `ServerStorage.ArtPack.Props`, `.Variants` | the 8 prop sets and the 6 Puppy color variants | nothing yet (a library for building) |

Pet icons are uploaded images; their ids are in `GameConfig.PetArt` (`Icon`) and shown on pet cards.
Asset ids for everything are recorded in `tools/art/uploaded.json`, and each imported model carries an
`AssetId` attribute.

## How the place was imported

Studio's 3D Importer works too, but the package was imported by script:

1. `python3 tools/art/upload.py` uploads the world, pets, props, variants and icons with Open Cloud (needs an
   API key with Assets read+write, from the account that owns the place, in `~/.roblox/opencloud_key`).
   Before uploading, `fbxfix.py` rewrites each FBX to 1 unit = 1 stud: Blender stores root objects with
   scale 100 and centimeter offsets, which Open Cloud would otherwise import 100x too big.
2. The models were inserted in Studio (`InsertService:LoadAsset(id)`) into the folders above, named as in the
   table (the world as `World`).

To re-import one file after editing the art: re-export it, run `upload.py <name>` after deleting its entry from
`uploaded.json`, and replace the model in the place.

## What the code does with them

`MapBuilder.lua` clones the world into `Workspace.Map` on every server start and lines it up by
`Barrier_Grasslands` and `EggBody_Celestial` (so its position and turn in ServerStorage don't matter; Open Cloud
imports come in turned 180 degrees). It hooks gameplay onto named pieces:

| Piece in the import | Becomes |
|---|---|
| `Barrier_<Zone>` (7) | the Ascension gate into that zone |
| `EggBody_<Zone>` (8; `EggBody_Lobby` = Starter) | that zone's egg (clickable, labelled) |
| Lobby Upgrades / Pet Index / Daily Rewards houses, fountain | prompts that open Upgrades, Pets, Daily Rewards, Boosts |
| Lobby trading plaza | the Ascend altar |
| Lobby leaderboard panels | the two global leaderboards |

Imports carry the package's palette-atlas texture. `ArtLook.lua` swaps it for each piece's flat Blender color
(Neon for glowing materials) from `ArtMaterials.lua`, which `python3 tools/art/gen_materials.py` generates from
the FBX files; regenerate it if the art changes. Pieces with several materials keep the texture.

Bosses are giant versions of each biome's Legendary pet. Pets that aren't in `ArtPets` fall back to cube pets
in their biome's colors. If the output warns that `EggBody_Celestial` is far from its design position, the
world was imported at the wrong scale.

## Previous map

The JTea pack, `ZoneMaps`, `EnvironmentAssets`, `NaturePack`, `Cottage` and the MonzterDev pack were moved to
`ServerStorage.BeforeArtPackage`; delete that folder once you no longer need them.
