-- Short simulator-style numbers used everywhere: 999, 1.13K, 161.5M, 241.65Qn, 3Dc.
-- Up to two decimals, trailing zeros dropped; past the last suffix, scientific (1.2e66).
local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc",
	"Ud", "Dd", "Td", "Qdd", "Qnd", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

local function trim(text)
	return (text:gsub("%.?0+$", ""))
end

function NumberFormat.Short(n)
	n = tonumber(n) or 0
	if n ~= n then return "0" end -- NaN
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier >= #SUFFIXES then
		local exponent = math.floor(math.log10(n))
		return sign .. trim(string.format("%.2f", n / 10 ^ exponent)) .. "e" .. exponent
	end
	local scaled = n / 1000 ^ tier
	-- Round down (so 999.999K isn't "1000K"); the tiny tolerance keeps 1.13 from flooring to 1.12.
	local text = trim(string.format("%.2f", math.floor(scaled * 100 + 1e-6) / 100))
	return sign .. text .. SUFFIXES[tier + 1]
end

return NumberFormat
