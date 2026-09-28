-- JTea's free simulator pack supplies the lobby map and shops. Sky islands (reached with extra
-- jumps, Clicker Simulator style) are built from smooth cartoon primitives.
local Config=require(game.ReplicatedStorage.Modules.GameConfig)
local MapBuilder={}
local V=Vector3.new local C=Color3.fromRGB
local function part(parent,name,size,pos,color,material)
 local p=Instance.new('Part') p.Name=name p.Size=size p.Position=pos p.Color=color
 p.Material=material or Enum.Material.SmoothPlastic p.Anchored=true p.TopSurface=Enum.SurfaceType.Smooth p.Parent=parent return p
end
local function cyl(parent,name,diameter,height,pos,color,material,rotation)
 local p=part(parent,name,V(height,diameter,diameter),pos,color,material) p.Shape=Enum.PartType.Cylinder
 p.CFrame=CFrame.new(pos)*(rotation or CFrame.Angles(0,0,math.pi/2)) return p -- default: axis vertical
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
-- Island placement and palette; heights come from GameConfig.Islands[].RequiredJumps.
local THEMES={
 Ice={pos=V(-58,0,-55),top=C(225,245,255),rock=C(150,190,225),egg=C(255,216,99)},
 Lava={pos=V(58,0,-55),top=C(96,74,80),rock=C(62,46,54),egg=C(255,120,40)},
 Candy={pos=V(-30,0,-105),top=C(255,176,214),rock=C(206,124,192),egg=C(255,120,200)},
 Space={pos=V(30,0,-105),top=C(96,70,170),rock=C(55,40,105),egg=C(150,110,255)},
}
local function decorate(m,id,c)
 local function ring(i,n,r) local a=(i/n)*math.pi*2 return c+V(math.cos(a)*r,0,math.sin(a)*r),a end
 if id=='Ice' then
  for i=1,5 do local pos,a=ring(i,5,16) local h=6+i%3*2
   local p=part(m,'Crystal',V(2,h,2),pos,C(170,225,255),Enum.Material.Glass) p.Transparency=0.15
   p.CFrame=CFrame.new(pos+V(0,h/2-0.5,0))*CFrame.Angles(0.2,a,0.15)
  end
 elseif id=='Lava' then
  for i=1,3 do local pos=ring(i,3,14) cyl(m,'LavaPool',7,0.3,pos+V(0,0.15,0),C(255,110,30),Enum.Material.Neon) end
  for i=1,3 do local pos=ring(i+0.5,3,15) local d=4+i
   local r=part(m,'Boulder',V(d,d,d),pos+V(0,d/2-1,0),C(70,55,60)) r.Shape=Enum.PartType.Ball end
 elseif id=='Candy' then
  local heads={C(255,90,150),C(120,200,255),C(255,220,90),C(160,120,255)}
  for i=1,4 do local pos,a=ring(i,4,15)
   cyl(m,'LollipopStick',0.8,7,pos+V(0,3.5,0),C(255,255,255))
   cyl(m,'Lollipop',5,1,pos+V(0,8.5,0),heads[i],nil,CFrame.Angles(0,-a,0))
  end
  for i=1,3 do local pos=ring(i+0.5,3,11)
   local g=part(m,'Gumdrop',V(3,3,3),pos+V(0,1,0),heads[i+1]) g.Shape=Enum.PartType.Ball end
 elseif id=='Space' then
  for i=1,3 do local pos=ring(i,3,17) local d=3+i
   local planet=part(m,'Planet',V(d,d,d),pos+V(0,9+i*2,0),C(120+i*40,90,255-i*40),Enum.Material.Neon)
   planet.Shape=Enum.PartType.Ball planet.CanCollide=false
   cyl(m,'PlanetRing',d*1.8,0.2,planet.Position,C(230,220,255),nil,CFrame.Angles(0,0,math.pi/2)*CFrame.Angles(0.35,0,0)).CanCollide=false
  end
  for i=1,8 do local pos=ring(i,8,20)
   local star=part(m,'Star',V(0.8,0.8,0.8),pos+V(0,6+(i%4)*3,0),C(255,245,180),Enum.Material.Neon)
   star.Shape=Enum.PartType.Ball star.CanCollide=false
  end
 end
end
local function buildIsland(parent,island)
 local theme=THEMES[island.Id]
 local topY=1+Config.GetJumpReach(island.RequiredJumps)-3 -- a little under the max reach
 local c=V(theme.pos.X,topY,theme.pos.Z)
 local m=Instance.new('Model') m.Name=island.Id..'Island' m.Parent=parent
 cyl(m,'Top',44,4,c-V(0,2,0),theme.top)
 for i,d in ipairs({34,24,12}) do cyl(m,'Underside',d,3,c-V(0,4+(i-0.5)*3,0),theme.rock) end -- tiered floating-rock base
 decorate(m,island.Id,c)
 local sign=part(m,'Sign',V(1,1,1),c+V(0,12,0),C(255,255,255)) sign.Transparency=1 sign.CanCollide=false sign.CanQuery=false
 label(sign,string.upper(island.Name)..'\n'..island.RequiredJumps..' jumps',260)
 return c
end
function MapBuilder.Build()
 local pack=game.ServerStorage:FindFirstChild('JTeaSimulatorPack')
 assert(pack,'Import the free JTea pack 7151365600 into ServerStorage as JTeaSimulatorPack (see ASSETS.md).')
 local library=pack:GetChildren()[1]:GetChildren()[1]
 local old=workspace:FindFirstChild('Map') if old then old:Destroy() end
 local preview=workspace:FindFirstChild('JTeaPreview') if preview then preview:Destroy() end
 local map=Instance.new('Folder') map.Name='Map' map.Parent=workspace
 local zones=Instance.new('Folder') zones.Name='Zones' zones.Parent=map
 local interactive=Instance.new('Folder') interactive.Name='Interactives' interactive.Parent=map
 local function biome(name,z,floorName)
  local m=library[name].Map:GetChildren()[1]:Clone() m.Name=name m.Parent=zones
  local floor=m:FindFirstChild(floorName)
  assert(floor,'Pack floor missing for '..name)
  local offset=V(-floor.Position.X,1-(floor.Position.Y+floor.Size.Y/2),z-floor.Position.Z)
  m:PivotTo(m:GetPivot()+offset)
  for _,d in ipairs(m:GetDescendants()) do
   if d:IsA('BasePart') then d.Anchored=true end
  end
  return m
 end
 biome('Forest',0,'Texture Part')
 -- Clear terrain left by older builds (Terrain is always textured), then lay smooth cartoon ground:
 -- a flat slab just under floor height plus rounded domes along both sides to close in each zone.
 for _,zone in ipairs({{z=0,ground=C(112,214,92),hill=C(86,190,78)}}) do
  workspace.Terrain:FillBlock(CFrame.new(0,-8,zone.z),V(280,24,280),Enum.Material.Air)
  part(zones,'Ground',V(258,4,258),V(0,-1.5,zone.z),zone.ground)
  for _,side in ipairs({-1,1}) do for i=1,5 do
   local hill=part(zones,'Hill',V(30,30,30),V(side*122,-8,zone.z-95+i*36),zone.hill) hill.Shape=Enum.PartType.Ball
  end end
 end
 require(script.Parent.AssetScenery).Build(map)
 -- Cartoon pass: flat SmoothPlastic with slightly punchier colors on everything but glowing/glass effects.
 for _,d in ipairs(map:GetDescendants()) do
  if d:IsA('BasePart') and d.Material~=Enum.Material.Neon and d.Material~=Enum.Material.Glass and d.Material~=Enum.Material.ForceField then
   d.Material=Enum.Material.SmoothPlastic d.Reflectance=0
   local h,s,v=d.Color:ToHSV()
   if s>0.08 then d.Color=Color3.fromHSV(h,math.min(1,s*1.25),math.min(1,v*1.08)) end
  end
 end
 local templateSpawn=workspace:FindFirstChild('SpawnLocation') if templateSpawn then templateSpawn.Enabled=false end
 local spawn=Instance.new('SpawnLocation') spawn.Name='MainSpawn' spawn.Size=V(10,0.5,10)
 spawn.Position=V(0,1.3,40) spawn.Transparency=1 spawn.Anchored=true spawn.Neutral=true spawn.Duration=0 spawn.Parent=map
 local function pad(name,pos,color)
  local p=part(interactive,name,V(10,0.6,10),pos,color,Enum.Material.Neon) return p
 end
 pad('SpawnRing',V(0,1.2,40),C(68,219,238))
 local orb=part(interactive,'ClickOrb',V(5,5,5),V(0,5,10),C(255,212,94),Enum.Material.Neon) orb.Shape=Enum.PartType.Ball
 label(orb,'CLICK TO EARN')
 local altar=pad('RebirthAltar',V(49,1.5,0),C(177,104,240)) label(altar,'REBIRTH\nPermanent power')
 place(library.Forest['Extra Portal']:GetChildren()[1],zones,'RebirthShrine',V(49,1,0),18)
 local islandCenters={}
 for _,island in ipairs(Config.Islands) do islandCenters[island.Id]=buildIsland(zones,island) end
 local iceShop=library:FindFirstChild('Ice') and library.Ice:FindFirstChild('Shop')
 if iceShop and islandCenters.Ice then place(iceShop:GetChildren()[1],zones,'IceShop',islandCenters.Ice+V(0,0,-12),12) end
 local eggs={}
 for _,egg in ipairs(Config.Eggs) do
  local p
  if egg.Zone=='Lobby' then
   local pos=V(-42,1,-3)
   place(library.Forest.Shop:GetChildren()[1],zones,egg.Id..'Shop',pos,16)
   p=part(interactive,egg.Id,V(4.5,6,4.5),pos+V(0,4.5,5),C(92,233,236),Enum.Material.Neon)
  else
   local c=assert(islandCenters[egg.Zone],'No island for egg zone '..egg.Zone)
   cyl(interactive,egg.Id..'Pedestal',8,1.5,c+V(0,0.75,0),C(245,245,255))
   p=part(interactive,egg.Id,V(4.5,6,4.5),c+V(0,4.5,0),THEMES[egg.Zone].egg,Enum.Material.Neon)
  end
  p.Shape=Enum.PartType.Ball p:SetAttribute('Zone',egg.Zone)
  label(p,egg.Name..'\n'..egg.Cost..' coins'..(egg.RequiredRebirths>0 and ' • '..egg.RequiredRebirths..' rebirths' or ''))
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
 return {ClickOrb=orb,RebirthAltar=altar,EggParts=eggs}
end
return MapBuilder
