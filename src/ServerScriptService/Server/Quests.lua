-- Daily/weekly quest progress and the daily login reward, stored in the player's save:
--   data.Quests = { Day, Daily = { {Id, Progress, Claimed} }, Week, Weekly = { ... } }
--   data.Daily  = { LastClaimDay, Streak }
-- Quests roll over whenever the UTC day/week changes (checked on every update).

local Config = require(game.ReplicatedStorage.Modules.GameConfig)

local Quests = {}

local function newSet(group, periodIndex)
	local set = {}
	for _, id in ipairs(Config.PickQuests(group, periodIndex)) do
		table.insert(set, { Id = id, Progress = 0, Claimed = false })
	end
	return set
end

-- Rolls the daily/weekly sets over if the period changed. Returns true if anything changed.
function Quests.Refresh(data)
	local q = data.Quests
	local day, week = Config.GetDayIndex(), Config.GetWeekIndex()
	local changed = false
	if q.Day ~= day then
		q.Day, q.Daily, changed = day, newSet("Daily", day), true
	end
	if q.Week ~= week then
		q.Week, q.Weekly, changed = week, newSet("Weekly", week), true
	end
	return changed
end

-- Adds progress to every unclaimed quest of this kind ("Combo" keeps the highest value instead).
function Quests.Track(data, kind, amount)
	Quests.Refresh(data)
	for _, group in ipairs({ "Daily", "Weekly" }) do
		for _, entry in ipairs(data.Quests[group]) do
			local def = Config.GetQuestDef(group, entry.Id)
			if def and def.Kind == kind and not entry.Claimed and entry.Progress < def.Target then
				local progress = if kind == "Combo" then math.max(entry.Progress, amount) else entry.Progress + amount
				entry.Progress = math.min(progress, def.Target)
			end
		end
	end
end

-- Pays a finished quest's Gems and Tokens. Returns the quest definition, or nil if it can't be claimed.
function Quests.Claim(data, group, index)
	Quests.Refresh(data)
	local entry = data.Quests[group] and data.Quests[group][index]
	local def = entry and Config.GetQuestDef(group, entry.Id)
	if not def or entry.Claimed or entry.Progress < def.Target then
		return nil
	end
	entry.Claimed = true
	data.Gems = (data.Gems or 0) + def.Gems
	data.Tokens = (data.Tokens or 0) + (def.Tokens or 0)
	return def
end

-- Claims today's login reward. Returns { Day, Gems, Tokens, Coins } (Coins still to be paid by the caller)
-- or nil if already claimed today.
function Quests.ClaimDaily(data)
	local day, claimable = Config.GetDailyRewardState(data.Daily)
	if not claimable then
		return nil
	end
	data.Daily.LastClaimDay = Config.GetDayIndex()
	data.Daily.Streak = day
	local reward = Config.DailyRewards[day]
	local gems, tokens = reward.Gems or 0, reward.Tokens or 0
	data.Gems = (data.Gems or 0) + gems
	data.Tokens = (data.Tokens or 0) + tokens
	local coins = if reward.CoinsPct then math.floor(Config.GetRebirthRequirement(data.RebirthCount) * reward.CoinsPct) else 0
	return { Day = day, Gems = gems, Tokens = tokens, Coins = coins }
end

return Quests
