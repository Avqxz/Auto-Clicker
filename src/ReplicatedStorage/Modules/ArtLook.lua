-- Gives an imported art-package model its Blender colors. Imports carry one palette-atlas texture on
-- every mesh; pieces that use a single material get that material's flat Color instead (Neon for the
-- glowing ones), and the few multi-material pieces keep the texture with a white Color so it isn't tinted.
local ArtMaterials = require(script.Parent.ArtMaterials)

local ArtLook = {}

-- modelName: the art file the model came from (e.g. "World_Assembled", "Pet_Ice_Penguin").
function ArtLook.Apply(model, modelName)
	local pieces = ArtMaterials.Models[modelName] or {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("MeshPart") then
			-- Duplicate names from a manual import come back as "Name.001"-style or with a numeric suffix.
			local material = pieces[part.Name] or pieces[(part.Name:gsub("%d+$", ""))]
			local swatch = material and ArtMaterials.Palette[material]
			if swatch then
				part.TextureID = ""
				part.Color = Color3.fromRGB(swatch[1], swatch[2], swatch[3])
				part.Material = if swatch[4] then Enum.Material.Neon else Enum.Material.SmoothPlastic
			else
				part.Color = Color3.new(1, 1, 1)
				part.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

return ArtLook
