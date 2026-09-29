-- Pet rarity tiers, shared by the server (rolls, announcements, auto-delete) and the client (colors,
-- reveal effects). Order matters: later tiers are rarer.
--
--   LuckPower      how strongly luck scales this tier's weight (weight * luck ^ LuckPower). 0 = never
--                  boosted; the chances are renormalized afterwards, so they stay positive and sum to 1.
--   AutoDeletable  players may choose to auto-delete this tier when it hatches.
--   Announce       a hatch is announced to the whole server.
--   Reveal         which hatch reveal plays: "Normal", "Rare", "Legendary" or "Secret".
--   Hidden         shown as a silhouette with "???" in egg previews until the player discovers it.
local PetConfig = {}

PetConfig.Rarities = {
	{ Id = "Common", Color = Color3.fromRGB(176, 190, 204), LuckPower = 0, AutoDeletable = true, Reveal = "Normal" },
	{ Id = "Unique", Color = Color3.fromRGB(96, 214, 140), LuckPower = 0.25, AutoDeletable = true, Reveal = "Normal" },
	{ Id = "Rare", Color = Color3.fromRGB(80, 170, 255), LuckPower = 0.5, AutoDeletable = true, Reveal = "Rare" },
	{ Id = "Epic", Color = Color3.fromRGB(180, 90, 255), LuckPower = 0.75, AutoDeletable = true, Reveal = "Rare" },
	{ Id = "Legendary", Color = Color3.fromRGB(255, 190, 40), LuckPower = 1, Announce = true, Reveal = "Legendary", Hidden = true },
	{ Id = "Mythic", Color = Color3.fromRGB(255, 80, 110), LuckPower = 1, Announce = true, Reveal = "Secret", Hidden = true },
	{ Id = "Secret", Color = Color3.fromRGB(40, 30, 60), LuckPower = 1.1, Announce = true, Reveal = "Secret", Hidden = true, Rainbow = true },
}

-- Allow auto-deleting Legendary and rarer tiers too (normally they are always kept).
PetConfig.AllowAutoDeleteRare = false

PetConfig.ById = {}
for rank, tier in ipairs(PetConfig.Rarities) do
	tier.Rank = rank
	PetConfig.ById[tier.Id] = tier
end

function PetConfig.Get(rarity)
	return PetConfig.ById[rarity] or PetConfig.Rarities[1]
end

function PetConfig.Rank(rarity)
	return PetConfig.Get(rarity).Rank
end

-- True if `rarity` is `atLeast` or rarer.
function PetConfig.AtLeast(rarity, atLeast)
	return PetConfig.Rank(rarity) >= PetConfig.Rank(atLeast)
end

function PetConfig.CanAutoDelete(rarity)
	local tier = PetConfig.ById[rarity]
	return tier ~= nil and (tier.AutoDeletable == true or PetConfig.AllowAutoDeleteRare)
end

return PetConfig
