-- Session-locked UpdateAsync profiles. A failed load can never overwrite a save.
local DSS = game:GetService('DataStoreService')
local RunService = game:GetService('RunService')
local HttpService = game:GetService('HttpService')
local Config = require(game.ReplicatedStorage.Modules.GameConfig)
local PlayerData = {Cache={}, Sessions={}, Saving={}}
local Store = DSS:GetDataStore('ClickingSimulator_PlayerData_v1')
local OWNER = game.JobId ~= '' and game.JobId or HttpService:GenerateGUID(false)
local LEASE = 180
local DEFAULT = {Coins=0,ClickPower=Config.StartingClickPower,UpgradeLevels={},AutoClickerLevels={},RebirthCount=0,TotalCoinsEarned=0,Pets={},EquippedPetUids={},NextPetUid=1,RedeemedCodes={},EggsHatched=0,HasPickedStarterPet=false,Gems=0,Skills={},Gear={Items={},Equipped={},NextUid=1}}
local function copy(t)
 local out={} for k,v in pairs(t) do out[k]=type(v)=='table' and copy(v) or v end return out
end
local function defaults(data)
 for k,v in pairs(DEFAULT) do if data[k]==nil then data[k]=type(v)=='table' and copy(v) or v end end
 return data
end
function PlayerData.Load(player)
 -- Studio uses disposable data deliberately, protecting production profiles.
 if RunService:IsStudio() then
  PlayerData.Cache[player.UserId]=copy(DEFAULT)
  player:SetAttribute('SaveStatus','Studio preview — progress is not saved')
  return PlayerData.Cache[player.UserId]
 end
 local result
 for attempt=1,3 do
  local ok,value=pcall(function()
   return Store:UpdateAsync('Player_'..player.UserId,function(old)
    old=old or copy(DEFAULT)
    if old._Session and old._Session.Owner~=OWNER and old._Session.Expires>os.time() then return nil end
    old._Session={Owner=OWNER,Expires=os.time()+LEASE}
    return defaults(old)
   end)
  end)
  if ok and value then result=value break end
  task.wait(attempt)
 end
 if not result then player:Kick('Your save is unavailable or open in another server. Please rejoin shortly; your progress is safe.') return nil end
 result._Session=nil
 PlayerData.Cache[player.UserId]=result PlayerData.Sessions[player.UserId]=true
 player:SetAttribute('SaveStatus','Saved')
 return result
end
function PlayerData.Get(player) return PlayerData.Cache[player.UserId] end
function PlayerData.IsPersistent(player) return PlayerData.Sessions[player.UserId]==true end
function PlayerData.Save(player,release)
 local id=player.UserId
 if not PlayerData.Sessions[id] then return false end
 while PlayerData.Saving[id] do task.wait(0.1) end
 if not PlayerData.Cache[id] then return false end
 PlayerData.Saving[id]=true
 PlayerData.Cache[id].LastOnline=os.time() -- for the Offline Earnings skill
 local snapshot=copy(PlayerData.Cache[id]) local saved=false local lost=false
 for attempt=1,3 do
  local ok,value=pcall(function()
   return Store:UpdateAsync('Player_'..id,function(old)
    if not old or not old._Session or old._Session.Owner~=OWNER then lost=true return nil end
    local nextData=copy(snapshot)
    if not release then nextData._Session={Owner=OWNER,Expires=os.time()+LEASE} end
    return nextData
   end)
  end)
  if ok and value then saved=true break end
  if lost then break end
  task.wait(attempt)
 end
 PlayerData.Saving[id]=nil
 player:SetAttribute('SaveStatus',saved and 'Saved' or 'Save retry pending')
 if lost then PlayerData.Sessions[id]=nil player:Kick('Save session changed. Please rejoin to keep your progress safe.') end
 return saved
end
function PlayerData.Release(player)
 PlayerData.Save(player,true)
 PlayerData.Sessions[player.UserId]=nil PlayerData.Cache[player.UserId]=nil
end
return PlayerData
