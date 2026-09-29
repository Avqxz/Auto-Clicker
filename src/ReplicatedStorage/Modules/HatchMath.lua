-- Hatch odds, shared by the server (which rolls) and the client (which shows the same chances).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggConfig = require(script.Parent.EggConfig)
local PetConfig = require(script.Parent.PetConfig)

local HatchMath = {}

-- A pet entry's raw weight: Weight (relative) or Chance (percent) - both are just proportions.
local function rawWeight(pet)
	return math.max(0, pet.Weight or pet.Chance or 0)
end

-- Chances (summing to 1) for each of egg.Pets, in order, with `luck` applied:
--   p_i = w_i * luck^k_i / sum_j(w_j * luck^k_j)   where k is the pet's rarity LuckPower.
-- luck >= 1 only ever moves probability from lower-k tiers to higher-k ones, every chance stays
-- positive, and luck = 1 gives the designer's plain normalized odds.
function HatchMath.GetChances(egg, luck)
	luck = math.max(1, luck or 1)
	local weights, total = {}, 0
	for i, pet in ipairs(egg.Pets) do
		local w = rawWeight(pet) * luck ^ PetConfig.Get(pet.Rarity).LuckPower
		weights[i] = w
		total += w
	end
	for i = 1, #weights do
		weights[i] = if total > 0 then weights[i] / total else 1 / #weights
	end
	return weights
end

-- Weighted pick: walks the cumulative chances with one uniform draw from `rng` (a Random).
function HatchMath.Pick(egg, chances, rng)
	local roll = rng:NextNumber()
	local cumulative = 0
	for i, chance in ipairs(chances) do
		cumulative += chance
		if roll < cumulative then
			return egg.Pets[i]
		end
	end
	return egg.Pets[#egg.Pets] -- floating-point leftovers
end

function HatchMath.GetShinyChance(luck)
	local shiny = EggConfig.Shiny
	return math.min(shiny.MaxChance, shiny.BaseChance * math.max(1, luck or 1) ^ shiny.LuckPower)
end

-- Total luck for a player's save (see EggConfig.Luck), plus a breakdown for the UI.
-- skillLevel: Egg Luck skill level. abilityLuck: summed EggLuck of equipped pet abilities.
function HatchMath.GetLuck(data, skillLevel, abilityLuck)
	local cfg = EggConfig.Luck
	local base = 1 + cfg.SkillPerLevel * (skillLevel or 0) + (abilityLuck or 0)
	local pass = if data.Passes and data.Passes[cfg.Pass] then cfg.PassMultiplier else 1
	local boostEnds = data.Boosts and data.Boosts[cfg.BoostKey]
	local boost = if boostEnds and boostEnds > os.time() then cfg.BoostMultiplier else 1
	local server = ReplicatedStorage:GetAttribute(cfg.ServerAttribute)
	server = if type(server) == "number" and server >= 1 then server else 1
	local total = math.clamp(base * pass * boost * server, 1, cfg.MaxLuck)
	return total, { Base = base, Pass = pass, Boost = boost, Server = server }
end

-- "35%", "2.5%", "0.4%", or "1 in 2,500" for tiny chances.
function HatchMath.FormatChance(chance)
	if chance >= 0.1 then
		return string.format("%d%%", math.floor(chance * 100 + 0.5))
	elseif chance >= 0.01 then
		return (string.format("%.1f", chance * 100):gsub("%.0$", "")) .. "%"
	elseif chance >= 0.002 then
		return (string.format("%.2f", chance * 100):gsub("0$", "")) .. "%"
	end
	local oneIn = math.floor(1 / math.max(chance, 1e-9) + 0.5)
	local text = tostring(oneIn):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "1 in " .. text
end

return HatchMath
