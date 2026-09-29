-- Server-only pet rolls. The client never chooses or reports a pet: it asks EggHatchingService to hatch,
-- and this module picks the pet with the server's own random generator.
local Modules = game:GetService("ReplicatedStorage").Modules
local EggConfig = require(Modules.EggConfig)
local HatchMath = require(Modules.HatchMath)

local PetRollService = {}

local rng = Random.new()

-- Returns the egg's pet entry and whether it came out Shiny.
function PetRollService.Roll(egg, luck)
	local pet = HatchMath.Pick(egg, HatchMath.GetChances(egg, luck), rng)
	local shiny = rng:NextNumber() < HatchMath.GetShinyChance(luck)
	return pet, shiny
end

-- A new inventory entry for a rolled pet.
function PetRollService.MakePet(uid, entry, shiny)
	return {
		Uid = uid,
		Name = entry.Name,
		Rarity = entry.Rarity,
		Multiplier = entry.Multiplier * (if shiny then EggConfig.Shiny.Multiplier else 1),
		Golden = false,
		Shiny = shiny,
		Level = 1,
		Locked = false,
	}
end

return PetRollService
