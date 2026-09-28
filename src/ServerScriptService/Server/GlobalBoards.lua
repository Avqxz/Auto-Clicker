local DSS=game:GetService('DataStoreService')
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Config=require(game.ReplicatedStorage.Modules.GameConfig)
local Boards={}
local stores={DSS:GetOrderedDataStore('Clicker_Rebirths_v1'),DSS:GetOrderedDataStore('Clicker_LifetimeCoinsLog_v1')}
local names={}
local function format(n)
 if n>=1e12 then return string.format('%.2e',n) end
 for _,unit in ipairs({{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do if n>=unit[1] then return string.format('%.1f%s',n/unit[1],unit[2]) end end
 return tostring(math.floor(n))
end
function Boards.Start(PlayerData)
 local folder=Instance.new('Folder') folder.Name='GlobalLeaderboards' folder.Parent=workspace.Map
 local rows={}
 for index,title in ipairs({'GLOBAL ASCENSIONS','GLOBAL LIFETIME COINS'}) do
  local board=Instance.new('Part') board.Name=title board.Size=Vector3.new(27,19,1)
  board.Position=Vector3.new(index==1 and -32 or 32,12,76) board.Anchored=true
  board.Material=Enum.Material.Slate board.Color=Color3.fromRGB(25,39,59) board.Parent=folder
  local gui=Instance.new('SurfaceGui') gui.Face=Enum.NormalId.Front gui.CanvasSize=Vector2.new(700,500) gui.Parent=board
  local header=Instance.new('TextLabel') header.Size=UDim2.new(1,0,0,70) header.BackgroundColor3=Color3.fromRGB(0,179,219)
  header.Text=title header.TextSize=35 header.Font=Enum.Font.FredokaOne header.TextColor3=Color3.new(1,1,1) header.Parent=gui
  rows[index]={}
  for rank=1,8 do
   local row=Instance.new('TextLabel') row.Size=UDim2.new(1,-24,0,45) row.Position=UDim2.fromOffset(12,65+rank*44)
   row.BackgroundTransparency=1 row.Font=Enum.Font.GothamMedium row.TextSize=24 row.TextXAlignment=Enum.TextXAlignment.Left
   row.TextColor3=rank<=3 and Color3.fromRGB(255,219,128) or Color3.fromRGB(225,244,255)
   row.Text=rank..'.  Loading…' row.Parent=gui rows[index][rank]=row
  end
  local status=Instance.new('TextLabel') status.Name='Status' status.Size=UDim2.new(1,0,0,30) status.Position=UDim2.new(0,0,1,-32)
  status.BackgroundTransparency=1 status.TextColor3=Color3.fromRGB(150,203,218) status.TextSize=18 status.Font=Enum.Font.Gotham status.Parent=gui
  rows[index].Status=status
 end
 task.spawn(function()
  while folder.Parent do
   for _,player in ipairs(Players:GetPlayers()) do
    local d=PlayerData.Get(player)
    if d and PlayerData.IsPersistent(player) then
     for index,value in ipairs({d.RebirthCount, math.floor(math.log10(1+d.TotalCoinsEarned)*1e6)}) do
      pcall(function() stores[index]:UpdateAsync(tostring(player.UserId),function(old) return math.max(old or 0,value) end) end)
     end
    end
   end
   for index,store in ipairs(stores) do
    local ok,page=false,nil
    if not RunService:IsStudio() then ok,page=pcall(function() return store:GetSortedAsync(false,8):GetCurrentPage() end) end
    rows[index].Status.Text=ok and 'All servers • refreshes every 2 minutes' or 'Global ranking unavailable • no sample scores'
    for rank=1,8 do
     local entry=ok and page[rank]
     if entry then
      if not names[entry.key] then
       local found,name=pcall(Players.GetNameFromUserIdAsync,Players,tonumber(entry.key))
       names[entry.key]=found and name or ('Player '..entry.key)
      end
      local value=index==1 and entry.value or (10^(entry.value/1e6)-1)
      rows[index][rank].Text=rank..'.  '..names[entry.key]..'  —  '..format(value)
     else rows[index][rank].Text=rank..'.  —' end
    end
   end
   task.wait(Config.LeaderboardRefreshSeconds)
  end
 end)
end
return Boards
