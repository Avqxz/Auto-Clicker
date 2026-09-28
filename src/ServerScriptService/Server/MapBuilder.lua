-- Builds the world: biome zones in a line along -Z, linked by walkways, each walkway ending in a
-- rebirth gate. Forest/Ice/Lava come from JTea's free simulator pack; Candy/Space are free
-- Creator Store maps saved in ServerStorage.ZoneMaps (see ASSETS.md).
local Config=require(game.ReplicatedStorage.Modules.GameConfig)
local MapBuilder={}
local V=Vector3.new local C=Color3.fromRGB
local GAP=30 -- walkway length between one zone's outer edge and the next

-- Where each zone's map comes from, which part/model is its floor, and its egg/gate color.
local SOURCES={
 Forest={pack=true,floor='Texture Part',color=C(92,233,236)},
 Ice={pack=true,floor='Floor',color=C(120,200,255)},
 Lava={pack=true,floor='Lava Ground',color=C(255,120,40)},
 Candy={floor='Baseplate',color=C(255,120,200)},
 Space={floor='Basic Floor',color=C(150,110,255)},
}

local function part(parent,name,size,pos,color,material)
 local p=Instance.new('Part') p.Name=name p.Size=size p.Position=pos p.Color=color
 p.Material=material or Enum.Material.SmoothPlastic p.Anchored=true p.TopSurface=Enum.SurfaceType.Smooth p.Parent=parent return p
end
local function label(p,text,maxDistance)
 local gui=Instance.new('BillboardGui') gui.Size=UDim2.fromOffset(210,56) gui.StudsOffset=V(0,5,0) gui.MaxDistance=maxDistance or 95 gui.Parent=p
 local t=Instance.new('TextLabel') t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.Text=text
 t.Font=Enum.Font.FredokaOne t.TextScaled=true t.TextColor3=C(255,255,255) t.TextStrokeColor3=C(25,44,62) t.TextStrokeTransparency=0 t.Parent=gui
end
local function place(template,parent,name,pos,height)
 local m=template:Clone() m.Name=name m.Parent=parent
 if height then local _,size=m:GetBoundingBox() m:ScaleTo(m:GetScale()*height/size.Y) end
 local cf,size=m:GetBoundingBox()
 m:PivotTo(CFrame.new(pos+V(0,size.Y/2,0))*cf:Inverse()*m:GetPivot())
 for _,d in ipairs(m:GetDescendants()) do
  if d:IsA('BasePart') then d.Anchored=true
  elseif d:IsA('LuaSourceContainer') then d:Destroy() end
 end
 return m
end
local function bounds(x)
 if x:IsA('Model') then return x:GetBoundingBox() end
 return x.CFrame,x.Size
end
local function short(n)
 for _,u in ipairs({{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do if n>=u[1] then return (string.format('%.1f',n/u[1]):gsub('%.0$',''))..u[2] end end
 return tostring(n)
end

-- Removes zone scenery that rises above the floor inside `size` around `cf` (walkway corridors,
-- egg spots). Whole small models (a tree, a rock) go at once; big ones only lose the parts in the way.
local function clearBox(zoneModels,cf,size)
 local params=OverlapParams.new() params.FilterType=Enum.RaycastFilterType.Include params.FilterDescendantsInstances=zoneModels
 for _,p in ipairs(workspace:GetPartBoundsInBox(cf,size,params)) do
  if p.Parent and p.Position.Y+p.Size.Y/2>2 and not p:GetAttribute('ZoneFloor') then
   local zone,target=nil,p
   for _,z in ipairs(zoneModels) do if p:IsDescendantOf(z) then zone=z end end
   local a=p.Parent
   while zone and a and a~=zone do
    if a:IsA('Model') then local _,s=a:GetBoundingBox() if math.max(s.X,s.Z)<60 then target=a end end
    a=a.Parent
   end
   target:Destroy()
  end
 end
end

-- Clones a zone map, sets its floor top to y=1 centered on x=0, and returns it with its floor bounds.
local function loadZone(library,zoneMaps,zone,parent)
 local src=SOURCES[zone.Id]
 local template
 if src.pack then template=library[zone.Id].Map:GetChildren()[1]
 else template=assert(zoneMaps and zoneMaps:FindFirstChild(zone.Id),'Missing ServerStorage.ZoneMaps.'..zone.Id..' (see ASSETS.md)') end
 local m=template:Clone() m.Name=zone.Id m.Parent=parent
 for _,d in ipairs(m:GetDescendants()) do
  if d:IsA('LuaSourceContainer') or d:IsA('SpawnLocation') then d:Destroy()
  elseif d:IsA('BasePart') then d.Anchored=true end
 end
 local floor
 for _,d in ipairs(m:GetDescendants()) do
  if d.Name==src.floor and (d:IsA('BasePart') or d:IsA('Model')) then
   local cf,s=bounds(d) if not floor or cf.Position.Y<floor.cf.Position.Y then floor={inst=d,cf=cf,size=s} end
  end
 end
 assert(floor,'No floor "'..src.floor..'" in zone '..zone.Id)
 if floor.inst:IsA('BasePart') then floor.inst:SetAttribute('ZoneFloor',true) end
 for _,d in ipairs(floor.inst:GetDescendants()) do if d:IsA('BasePart') then d:SetAttribute('ZoneFloor',true) end end
 local top=floor.cf.Position.Y+floor.size.Y/2
 m:PivotTo(m:GetPivot()+V(-floor.cf.Position.X,1-top,-floor.cf.Position.Z))
 return m,floor.size
end

function MapBuilder.Build()
 local pack=game.ServerStorage:FindFirstChild('JTeaSimulatorPack')
 assert(pack,'Import the free JTea pack 7151365600 into ServerStorage as JTeaSimulatorPack (see ASSETS.md).')
 local library=pack:GetChildren()[1]:GetChildren()[1]
 local zoneMaps=game.ServerStorage:FindFirstChild('ZoneMaps')
 local old=workspace:FindFirstChild('Map') if old then old:Destroy() end
 local map=Instance.new('Folder') map.Name='Map' map.Parent=workspace
 local zones=Instance.new('Folder') zones.Name='Zones' zones.Parent=map
 local interactive=Instance.new('Folder') interactive.Name='Interactives' interactive.Parent=map
 local gatesFolder=Instance.new('Folder') gatesFolder.Name='Gates' gatesFolder.Parent=map

 -- Lay the zones out in a line: each zone's outer edge sits GAP studs past the previous one's.
 local placed={} -- {zone, model, floorSize, center}
 local prevMinZ
 for i,zone in ipairs(Config.Zones) do
  local m,floorSize=loadZone(library,zoneMaps,zone,zones)
  local cf,size=m:GetBoundingBox()
  local shift=0
  if prevMinZ then shift=(prevMinZ-GAP)-(cf.Position.Z+size.Z/2) end
  m:PivotTo(m:GetPivot()+V(0,0,shift))
  prevMinZ=cf.Position.Z+shift-size.Z/2
  placed[i]={zone=zone,model=m,floorSize=floorSize,center=V(0,1,shift)}
 end

 -- Walkways between consecutive floors, with the scenery in their way cleared.
 local walkways={}
 for i=2,#placed do
  local a,b=placed[i-1],placed[i]
  local fromZ=a.center.Z-a.floorSize.Z/2 local toZ=b.center.Z+b.floorSize.Z/2
  local midZ=(fromZ+toZ)/2 local length=fromZ-toZ
  clearBox({a.model,b.model},CFrame.new(0,40,midZ),V(30,78,length+6))
  walkways[i]={midZ=midZ,length=length,entranceZ=toZ}
 end

 -- Forest (starting zone) extras: smooth ground under and around it, side hills, and props.
 workspace.Terrain:FillBlock(CFrame.new(0,-8,0),V(280,24,280),Enum.Material.Air) -- clear terrain from older builds
 part(zones,'Ground',V(258,4,258),V(0,-1.5,0),C(112,214,92))
 for _,side in ipairs({-1,1}) do for i=1,5 do
  local hill=part(zones,'Hill',V(30,30,30),V(side*122,-8,-95+i*36),C(86,190,78)) hill.Shape=Enum.PartType.Ball
 end end
 require(script.Parent.AssetScenery).Build(map)

 -- Cartoon pass: flat SmoothPlastic with slightly punchier colors on everything but glowing/glass effects.
 for _,d in ipairs(map:GetDescendants()) do
  if d:IsA('BasePart') and d.Material~=Enum.Material.Neon and d.Material~=Enum.Material.Glass and d.Material~=Enum.Material.ForceField then
   d.Material=Enum.Material.SmoothPlastic d.Reflectance=0
   local h,s,v=d.Color:ToHSV()
   if s>0.08 then d.Color=Color3.fromHSV(h,math.min(1,s*1.25),math.min(1,v*1.08)) end
  end
 end

 -- Walkway decks and Ascension gates. Gates are solid on the server; each client makes the gates it
 -- has unlocked non-solid for its own character (see Client/ZoneGates.lua).
 local gates={}
 for i=2,#placed do
  local zone=placed[i].zone local w=walkways[i] local color=SOURCES[zone.Id].color
  part(zones,'Walkway',V(24,2,w.length+4),V(0,0,w.midZ),C(240,226,204))
  for _,side in ipairs({-1,1}) do part(zones,'WalkwayRail',V(1,2,w.length+4),V(side*12.5,2,w.midZ),C(255,255,255)) end
  local gateZ=w.entranceZ+1.5
  for _,side in ipairs({-1,1}) do part(gatesFolder,'GatePillar',V(4,22,4),V(side*14,12,gateZ),C(255,255,255)) end
  part(gatesFolder,'GateTop',V(32,4,4),V(0,24,gateZ),color)
  local gate=part(gatesFolder,zone.Id..'Gate',V(24,20,1.5),V(0,11,gateZ),color,Enum.Material.ForceField)
  gate.Transparency=0.3 gate:SetAttribute('Zone',zone.Id) gate:SetAttribute('ZoneName',zone.Name)
  gate:SetAttribute('RequiredRebirths',zone.RequiredRebirths)
  local sign=part(gatesFolder,zone.Id..'GateSign',V(1,1,1),V(0,26,gateZ),color) sign.Transparency=1 sign.CanCollide=false sign.CanQuery=false
  label(sign,string.upper(zone.Name)..'\n'..zone.RequiredRebirths..' Ascension'..(zone.RequiredRebirths==1 and '' or 's'),160)
  table.insert(gates,gate)
 end

 local templateSpawn=workspace:FindFirstChild('SpawnLocation') if templateSpawn then templateSpawn.Enabled=false end
 local spawn=Instance.new('SpawnLocation') spawn.Name='MainSpawn' spawn.Size=V(10,0.5,10)
 spawn.Position=V(0,1.3,40) spawn.Transparency=1 spawn.Anchored=true spawn.Neutral=true spawn.Duration=0 spawn.Parent=map
 local function pad(name,pos,color)
  return part(interactive,name,V(10,0.6,10),pos,color,Enum.Material.Neon)
 end
 pad('SpawnRing',V(0,1.2,40),C(68,219,238))
 local orb=part(interactive,'ClickOrb',V(5,5,5),V(0,5,10),C(255,212,94),Enum.Material.Neon) orb.Shape=Enum.PartType.Ball
 label(orb,'CLICK TO EARN')
 local altar=pad('RebirthAltar',V(49,1.5,0),C(177,104,240)) label(altar,'ASCEND\nGems + permanent power')
 place(library.Forest['Extra Portal']:GetChildren()[1],zones,'RebirthShrine',V(49,1,0),18)

 -- Egg stands: one glass capsule from the pack per egg (Candy/Space reuse the Forest capsule),
 -- its egg recolored per zone, with an invisible clickable hitbox around it. The starting egg keeps
 -- its lobby spot; the others stand just inside their zone's entrance.
 local function capsule(zoneId)
  local zone=library:FindFirstChild(zoneId) or library.Forest
  local best,bestSize
  for _,m in ipairs(zone.Shop:GetChildren()[1]:GetChildren()) do
   if m:IsA('Model') and m:FindFirstChild('Egg',true) then -- capsules hold an Egg part; the flat pads don't
    local _,sz=m:GetBoundingBox() if not bestSize or sz.Magnitude>bestSize then best,bestSize=m,sz.Magnitude end
   end
  end
  return best
 end
 local byZone={} for _,p in ipairs(placed) do byZone[p.zone.Id]=p end
 local eggs={}
 for _,egg in ipairs(Config.Eggs) do
  local z=assert(byZone[egg.Zone],'No zone for egg '..egg.Id)
  local pos=z==placed[1] and V(-42,1,-3) or V(-30,1,z.center.Z+z.floorSize.Z/2-45)
  if z~=placed[1] then clearBox({z.model},CFrame.new(pos+V(0,20,0)),V(16,38,16)) end
  local m=place(capsule(egg.Zone),zones,egg.Id..'Stand',pos,11)
  for _,d in ipairs(m:GetDescendants()) do if d:IsA('BasePart') and d.Name=='Egg' then d.Color=SOURCES[egg.Zone].color end end
  local cf,size=m:GetBoundingBox()
  local p=part(interactive,egg.Id,size+V(1,1,1),cf.Position,SOURCES[egg.Zone].color) p.CFrame=cf
  p.Transparency=1 p.CanCollide=false p:SetAttribute('Zone',egg.Zone)
  label(p,egg.Name..'\n'..short(egg.Cost)..' coins'..(egg.RequiredRebirths>0 and ' • '..egg.RequiredRebirths..' Ascensions' or ''))
  eggs[egg.Id]=p
 end

 -- Bright, soft, non-reflective lighting for a cartoon look.
 local lighting=game:GetService('Lighting') lighting.ClockTime=14 lighting.Brightness=3
 lighting.Ambient=C(150,150,172) lighting.OutdoorAmbient=C(190,190,205) lighting.ShadowSoftness=0.6
 lighting.EnvironmentSpecularScale=0 lighting.EnvironmentDiffuseScale=0.6
 local atmosphere=lighting:FindFirstChildOfClass('Atmosphere')
 if atmosphere then atmosphere.Haze=0 atmosphere.Glare=0 atmosphere.Density=math.min(atmosphere.Density,0.25) end
 local grade=lighting:FindFirstChild('SimulatorGrade') or Instance.new('ColorCorrectionEffect')
 grade.Name='SimulatorGrade' grade.Saturation=0.2 grade.Contrast=0.08 grade.Brightness=0.02 grade.Parent=lighting
 local bloom=lighting:FindFirstChild('SimulatorBloom') or Instance.new('BloomEffect')
 bloom.Name='SimulatorBloom' bloom.Intensity=0.3 bloom.Size=20 bloom.Threshold=1.4 bloom.Parent=lighting
 return {ClickOrb=orb,RebirthAltar=altar,EggParts=eggs,Gates=gates}
end
return MapBuilder
