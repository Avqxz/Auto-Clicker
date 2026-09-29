-- Builds the world from the Blender art package (art/, see ASSETS.md): the imported World_Assembled
-- model (ServerStorage.ArtPack.World) holds the lobby, seven biome islands, bridges, gates and egg
-- stands in their designed positions. This script lines that model up with the coordinates below and
-- wires gameplay onto its named pieces:
--   Barrier_<Zone>  -> the Ascension gate into <Zone> (solid until unlocked, see Client/ZoneGates.lua)
--   EggBody_<Zone>  -> that zone's egg (EggBody_Lobby is the Starter Egg)
-- plus the lobby stations (Upgrades / Pet Index / Daily Rewards houses, fountain, trading plaza),
-- spawn, click orb and one boss per biome.
local Config=require(game.ReplicatedStorage.Modules.GameConfig)
local PetModelFactory=require(game.ReplicatedStorage.Modules.PetModelFactory)
local ArtLook=require(game.ReplicatedStorage.Modules.ArtLook)
local MapBuilder={}
local V=Vector3.new local C=Color3.fromRGB

-- Island centers (walkable surface height) and radii, from the art's build script (Blender (x,y,z)
-- -> Roblox (x, z, -y)).
local ISLANDS={
 Lobby={center=V(0,0,0),radius=38},
 Grasslands={center=V(0,2,-95),radius=34},
 Desert={center=V(90,8,-155),radius=37},
 Ice={center=V(190,12,-120),radius=37},
 Enchanted={center=V(270,20,-205),radius=39},
 Volcano={center=V(215,24,-305),radius=39},
 Candy={center=V(105,34,-338),radius=37},
 Celestial={center=V(-10,48,-290),radius=40},
}
-- Where two pieces sit in the design; used to line the imported model up.
local ANCHOR_NAME,ANCHOR_POS='Barrier_Grasslands',V(0,5.3,-49.5)
local CHECK_NAME,CHECK_POS='EggBody_Celestial',V(-23,53.2,-285)
local ZONE_COLORS={Lobby=C(92,233,236),Grasslands=C(120,220,90),Desert=C(255,190,80),Ice=C(120,200,255),
 Enchanted=C(200,120,255),Volcano=C(255,110,40),Candy=C(255,120,200),Celestial=C(255,225,120)}

local function part(parent,name,size,pos,color,material)
 local p=Instance.new('Part') p.Name=name p.Size=size p.Position=pos p.Color=color
 p.Material=material or Enum.Material.SmoothPlastic p.Anchored=true p.TopSurface=Enum.SurfaceType.Smooth p.Parent=parent return p
end
local function label(p,text,maxDistance)
 local gui=Instance.new('BillboardGui') gui.Size=UDim2.fromOffset(210,56) gui.StudsOffset=V(0,5,0) gui.MaxDistance=maxDistance or 95 gui.Parent=p
 local t=Instance.new('TextLabel') t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.Text=text
 t.Font=Enum.Font.FredokaOne t.TextScaled=true t.TextColor3=C(255,255,255) t.TextStrokeColor3=C(25,44,62) t.TextStrokeTransparency=0 t.Parent=gui
 return gui
end
local function short(n)
 for _,u in ipairs({{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do if n>=u[1] then return (string.format('%.1f',n/u[1]):gsub('%.0$',''))..u[2] end end
 return tostring(n)
end
local function invisible(p) p.Transparency=1 p.CanCollide=false p.CanQuery=false return p end
local function prompt(parent,action,object,distance)
 local pr=Instance.new('ProximityPrompt') pr.ActionText=action pr.ObjectText=object or ''
 pr.HoldDuration=0 pr.MaxActivationDistance=distance or 14 pr.RequiresLineOfSight=false pr.Parent=parent
 return pr
end

-- Finds the imported world in ServerStorage.ArtPack (named World or World_Assembled, or its only model).
local function findWorldTemplate()
 local pack=game.ServerStorage:FindFirstChild('ArtPack')
 if not pack then return nil end
 local world=pack:FindFirstChild('World') or pack:FindFirstChild('World_Assembled')
 if not world then
  for _,c in ipairs(pack:GetChildren()) do if c:IsA('Model') then world=c break end end
 end
 return world
end

-- Turns and moves `model` so its pieces ANCHOR_NAME and CHECK_NAME sit at their design positions.
-- The yaw matters: Open Cloud imports come in turned 180 degrees from the 3D Importer's. Returns the
-- distance left between CHECK_NAME and CHECK_POS (large if the import was scaled), or nil if a piece is missing.
local function alignWorld(model)
 local anchor=model:FindFirstChild(ANCHOR_NAME,true)
 local check=model:FindFirstChild(CHECK_NAME,true)
 if not (anchor and anchor:IsA('BasePart') and check and check:IsA('BasePart')) then return nil end
 local function yawOf(v) return math.atan2(v.X,v.Z) end
 local turn=yawOf(CHECK_POS-ANCHOR_POS)-yawOf(check.Position-anchor.Position)
 local around=CFrame.new(anchor.Position)
 model:PivotTo(around*CFrame.Angles(0,turn,0)*around:Inverse()*model:GetPivot())
 model:PivotTo(model:GetPivot()+(ANCHOR_POS-anchor.Position))
 return (check.Position-CHECK_POS).Magnitude
end

-- A clear spot for a boss on an island: tries points around the center until a box above the ground
-- is free of scenery (ignoring flat pieces like the ground, paths and ponds).
local function findClearSpot(island,avoid,size)
 local params=OverlapParams.new() params.FilterType=Enum.RaycastFilterType.Include params.FilterDescendantsInstances=avoid
 for _,r in ipairs({14,18,22,10,26}) do
  for i=0,11 do
   local a=math.rad(i*30+15)
   local pos=island.center+V(math.cos(a)*r,0,math.sin(a)*r)
   local clear=true
   for _,p in ipairs(workspace:GetPartBoundsInBox(CFrame.new(pos+V(0,size.Y/2+1.5,0)),size,params)) do
    if p.Position.Y+p.Size.Y/2>island.center.Y+1.5 then clear=false break end
   end
   if clear then return pos end
  end
 end
 return island.center+V(0,0,island.radius*0.4)
end

function MapBuilder.Build()
 local template=findWorldTemplate()
 assert(template,'Import the art package world first: World_Assembled.fbx into ServerStorage.ArtPack (see ASSETS.md).')
 local old=workspace:FindFirstChild('Map') if old then old:Destroy() end
 local map=Instance.new('Folder') map.Name='Map' map.Parent=workspace
 local zones=Instance.new('Folder') zones.Name='Zones' zones.Parent=map
 local interactive=Instance.new('Folder') interactive.Name='Interactives' interactive.Parent=map
 local gatesFolder=Instance.new('Folder') gatesFolder.Name='Gates' gatesFolder.Parent=map

 -- The world: anchored, scripts stripped, small decorations non-colliding.
 local world=template:Clone()
 if not world:IsA('Model') then local w=Instance.new('Model') world.Parent=w world=w end
 world.Name='World'
 for _,d in ipairs(world:GetDescendants()) do
  if d:IsA('LuaSourceContainer') then d:Destroy()
  elseif d:IsA('BasePart') then
   d.Anchored=true
   local big=math.max(d.Size.X,d.Size.Y,d.Size.Z)
   if big<3 and not d.Name:find('^Barrier') and not d.Name:find('Plank') then d.CanCollide=false end
  end
 end
 world.Parent=zones
 ArtLook.Apply(world,'World_Assembled')
 local off=alignWorld(world)
 if not off then
  warn('[MapBuilder] '..ANCHOR_NAME..' or '..CHECK_NAME..' not found in the imported world; it is left where it was imported.')
 elseif off>3 then
  warn(('[MapBuilder] Imported world looks scaled: %s is %.0f studs from its design position. Re-import at scale 1.'):format(CHECK_NAME,off))
 end

 -- Gates: each Barrier_<Zone> becomes the Ascension gate into that zone.
 local gates={}
 for i=2,#Config.Zones do
  local zone=Config.Zones[i]
  local barrier=world:FindFirstChild('Barrier_'..zone.Id,true)
  if barrier and barrier:IsA('BasePart') then
   barrier.Name=zone.Id..'Gate' barrier.Parent=gatesFolder
   barrier.CanCollide=true barrier.Transparency=0.3
   barrier:SetAttribute('Zone',zone.Id) barrier:SetAttribute('ZoneName',zone.Name)
   barrier:SetAttribute('RequiredRebirths',zone.RequiredRebirths)
   local sign=invisible(part(gatesFolder,zone.Id..'GateSign',V(1,1,1),barrier.Position+V(0,barrier.Size.Y/2+5,0),ZONE_COLORS[zone.Id]))
   label(sign,string.upper(zone.Name)..'\n'..zone.RequiredRebirths..' Ascension'..(zone.RequiredRebirths==1 and '' or 's'),160)
   table.insert(gates,barrier)
  else
   warn('[MapBuilder] Missing Barrier_'..zone.Id..' in the imported world; that zone has no gate.')
  end
 end

 -- Spawn, click orb and Ascend altar (on the trading plaza).
 local templateSpawn=workspace:FindFirstChild('SpawnLocation') if templateSpawn then templateSpawn.Enabled=false end
 local baseplate=workspace:FindFirstChild('Baseplate') if baseplate and baseplate:IsA('BasePart') then baseplate:Destroy() end
 local spawn=Instance.new('SpawnLocation') spawn.Name='MainSpawn' spawn.Size=V(10,0.5,10)
 spawn.Position=V(0,1.1,19) spawn.Transparency=1 spawn.Anchored=true spawn.Neutral=true spawn.Duration=0 spawn.CanCollide=false spawn.Parent=map
 local orb=part(interactive,'ClickOrb',V(5,5,5),V(0,4.5,8),C(255,212,94),Enum.Material.Neon) orb.Shape=Enum.PartType.Ball
 label(orb,'CLICK TO EARN')
 local altar=part(interactive,'RebirthAltar',V(8,0.4,8),V(19,0.9,15),C(177,104,240),Enum.Material.Neon)
 label(altar,'ASCEND\nGems + permanent power')

 -- Lobby stations: prompts in front of the art's buildings open their panels (see init.server.lua).
 local stations={}
 for _,s in ipairs({
  {kind='Shop',pos=V(24,2.5,5),action='Upgrades'},
  {kind='Pets',pos=V(0,2.5,-20),action='Pet Index'},
  {kind='Daily',pos=V(-24,2.5,5),action='Daily Rewards'},
  {kind='TokenShop',pos=V(8,3,0),action='Boosts',sign='BOOSTS\nWishing fountain'},
 }) do
  local hit=invisible(part(interactive,s.kind..'Prompt',V(2,2,2),s.pos,C(255,255,255)))
  stations[s.kind]=prompt(hit,s.action)
  if s.sign then label(hit,s.sign,90).StudsOffset=V(0,6,0) end
 end

 -- Eggs: an invisible clickable box around each art egg, with a label and sparkles.
 local eggs={}
 for _,egg in ipairs(Config.Eggs) do
  local island=ISLANDS[egg.Zone]
  local body=world:FindFirstChild('EggBody_'..egg.Zone,true)
  local cf,size
  if body and body:IsA('BasePart') then cf,size=body.CFrame,body.Size
  elseif island then cf,size=CFrame.new(island.center+V(-13,5.2,5)),V(4.2,5,4.2)
  else warn('[MapBuilder] No island for egg '..egg.Id) end
  if cf then
   local p=invisible(part(interactive,egg.Id,size+V(1.5,1.5,1.5),cf.Position,ZONE_COLORS[egg.Zone] or C(255,255,255)))
   p:SetAttribute('Zone',egg.Zone)
   label(p,egg.Name..'\n'..short(egg.Cost)..' Coins'..(egg.RequiredRebirths>0 and ' • '..egg.RequiredRebirths..' Ascensions' or '')).StudsOffset=V(0,size.Y/2+3,0)
   local sparkle=Instance.new('ParticleEmitter') sparkle.Texture='rbxasset://textures/particles/sparkles_main.dds'
   sparkle.Color=ColorSequence.new(ZONE_COLORS[egg.Zone] or C(255,255,255)) sparkle.Size=NumberSequence.new(0.35,0)
   sparkle.Lifetime=NumberRange.new(0.6,1.2) sparkle.Rate=6 sparkle.Speed=NumberRange.new(0.5,1.5)
   sparkle.SpreadAngle=Vector2.new(180,180) sparkle.LightEmission=0.8 sparkle.Parent=p
   eggs[egg.Id]=p
  end
 end

 -- Bosses: a giant version of the biome's Legendary pet on a glowing ring, facing the island center.
 local bosses={}
 for _,boss in ipairs(Config.Bosses) do
  local island=ISLANDS[boss.Zone]
  if island then
   local pos=findClearSpot(island,{world},V(14,14,14))
   local ring=part(zones,boss.Id..'Arena',V(0.4,16,16),pos,ZONE_COLORS[boss.Zone],Enum.Material.Neon)
   ring.Shape=Enum.PartType.Cylinder ring.CFrame=CFrame.new(pos+V(0,0.2,0))*CFrame.Angles(0,0,math.pi/2)
   local m=PetModelFactory.Create({Name=boss.Model,Rarity=boss.Rarity},{WithEffects=false})
   m.Name=boss.Id
   local _,size=m:GetBoundingBox()
   m:ScaleTo(m:GetScale()*12/math.max(size.Y,0.1))
   local toCenter=V(island.center.X,pos.Y,island.center.Z)-pos
   local yaw=math.atan2(-toCenter.X,-toCenter.Z) -- pets face -Z; turn that toward the center
   m:PivotTo(CFrame.new(pos)*CFrame.Angles(0,yaw,0))
   local cf,newSize=m:GetBoundingBox()
   m:PivotTo(m:GetPivot()+V(0,pos.Y+0.4-(cf.Position.Y-newSize.Y/2),0))
   m.Parent=zones
   local body=m.PrimaryPart or m:FindFirstChildWhichIsA('BasePart',true)
   body.CanCollide=true
   label(body,boss.Name..'\n❤ '..short(boss.Health)..' HP',140).StudsOffset=V(0,newSize.Y/2+2,0)
   bosses[boss.Id]={Model=m,Prompt=prompt(body,'Fight',boss.Name,22),Position=pos}
  end
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

 -- Global leaderboards go on the art's two panels at the lobby's south edge (facing the spawn).
 local boardSpots={CFrame.new(-6,6,29.4),CFrame.new(6,6,29.4)}
 return {ClickOrb=orb,RebirthAltar=altar,EggParts=eggs,Gates=gates,Bosses=bosses,Stations=stations,BoardSpots=boardSpots}
end
return MapBuilder
