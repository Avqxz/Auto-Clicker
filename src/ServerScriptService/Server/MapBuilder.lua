-- Builds the world from the Blender art package (art/, see ASSETS.md): the imported World_Assembled
-- model (ServerStorage.ArtPack.World) holds the lobby, seven biome islands, bridges, gates and egg
-- stands in their designed positions. This script lines that model up with the coordinates below and
-- wires gameplay onto its named pieces:
--   Barrier_<Zone>  -> the Ascension gate into <Zone> (solid until unlocked, see Client/ZoneGates.lua)
--   EggBody_<Zone>  -> that zone's egg (EggBody_Lobby is the Starter Egg)
-- plus the lobby stations (Upgrades / Pet Index / Daily Rewards houses, fountain, trading plaza),
-- spawn, click orb and one boss per biome.
local CollectionService=game:GetService('CollectionService')
local Config=require(game.ReplicatedStorage.Modules.GameConfig)
local EggConfig=require(game.ReplicatedStorage.Modules.EggConfig)
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
-- Invisible walls behind each Ascension gate: taller than any jump, wider than the bridge.
local GATE_WALL={Width=26,Height=100,Thickness=2,Below=12} -- Below: studs under the bridge deck
local ZONE_COLORS={Lobby=C(92,233,236),Grasslands=C(120,220,90),Desert=C(255,190,80),Ice=C(120,200,255),
 Enchanted=C(200,120,255),Volcano=C(255,110,40),Candy=C(255,120,200),Celestial=C(255,225,120)}

local function part(parent,name,size,pos,color,material)
 local p=Instance.new('Part') p.Name=name p.Size=size p.Position=pos p.Color=color
 p.Material=material or Enum.Material.SmoothPlastic p.Anchored=true p.TopSurface=Enum.SurfaceType.Smooth p.Parent=parent return p
end
-- World signs: a tagged anchor that every client turns into floating 3D cartoon lettering
-- (Client/FloatingLabels.lua), hidden behind buildings like any other object. Lines split on "\n":
-- the first is big in `Color`, the second smaller in `SubColor`, any others small and pale.
--   opts: Offset (studs above p), Color, SubColor, Size (first-line letter height, studs), MaxDistance
local function label(p,text,opts)
 opts=opts or {}
 local a=Instance.new('Attachment') a.Name='FloatingLabel' a.Parent=p
 a.WorldPosition=p.Position+(opts.Offset or V(0,5,0))
 a:SetAttribute('Text',text)
 a:SetAttribute('Color',opts.Color or C(255,255,255))
 a:SetAttribute('SubColor',opts.SubColor or C(235,242,255))
 a:SetAttribute('Size',opts.Size or 2)
 a:SetAttribute('MaxDistance',opts.MaxDistance or 120)
 CollectionService:AddTag(a,'FloatingLabel')
 return a
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

 -- The art's flat sign boards become floating lettering too. Egg boards go (each egg has its own
 -- label with its price) and so does TRADING (the plaza is the Ascend altar, labelled ASCEND).
 local SIGN_COLORS={['DAILY REWARDS']=C(255,190,70),['PET INDEX']=C(255,130,200),['UPGRADES']=C(110,230,140)}
 for _,d in ipairs(world:GetChildren()) do
  local text=d.Name:match('^SignPanel_(.+)$')
  if text then
   if SIGN_COLORS[text] then
    local spot=invisible(part(interactive,'Sign_'..text,V(1,1,1),d.Position,C(255,255,255)))
    label(spot,text,{Offset=V(0,2.2,0),Color=SIGN_COLORS[text],Size=2.4})
   end
   d:Destroy()
  elseif d.Name:match('^SignText_') then
   d:Destroy()
  end
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
   label(sign,string.upper(zone.Name)..'\n'..zone.RequiredRebirths..' ASCENSION'..(zone.RequiredRebirths==1 and '' or 'S'),
    {Offset=V(0,0,0),Color=ZONE_COLORS[zone.Id],SubColor=C(255,214,90),Size=3.2,MaxDistance=220})
   table.insert(gates,barrier)
   -- The art barrier is a thin 8-stud panel you can jump over or slip past at the bridge edges, so
   -- each gate also gets a tall invisible wall across the bridge (perpendicular to the line between
   -- the two islands). It opens and closes with the gate on each client (Client/ZoneGates.lua).
   local from,to=ISLANDS[Config.Zones[i-1].Id],ISLANDS[zone.Id]
   if from and to then
    local across=V(to.center.X-from.center.X,0,to.center.Z-from.center.Z)
    local wall=part(gatesFolder,zone.Id..'GateWall',V(GATE_WALL.Width,GATE_WALL.Height,GATE_WALL.Thickness),barrier.Position,C(255,255,255))
    wall.CFrame=CFrame.lookAt(barrier.Position,barrier.Position+across)+V(0,GATE_WALL.Height/2-barrier.Size.Y/2-GATE_WALL.Below,0)
    wall.Transparency=1 wall.CanQuery=false wall.CastShadow=false
    wall:SetAttribute('Zone',zone.Id) wall:SetAttribute('ZoneName',zone.Name)
    wall:SetAttribute('RequiredRebirths',zone.RequiredRebirths) wall:SetAttribute('Invisible',true)
    table.insert(gates,wall)
   end
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
 label(orb,'CLICK TO EARN',{Offset=V(0,4,0),Color=C(255,212,94),Size=1.5})
 local altar=part(interactive,'RebirthAltar',V(8,0.4,8),V(19,0.9,15),C(177,104,240),Enum.Material.Neon)
 label(altar,'ASCEND\nGEMS + PERMANENT POWER',{Color=C(190,120,255),SubColor=C(255,214,90),Size=2})

 -- Lobby stations: prompts in front of the art's buildings open their panels (see init.server.lua).
 local stations={}
 for _,s in ipairs({
  {kind='Shop',pos=V(24,2.5,5),action='Upgrades'},
  {kind='Pets',pos=V(0,2.5,-20),action='Pet Index'},
  {kind='Daily',pos=V(-24,2.5,5),action='Daily Rewards'},
  {kind='TokenShop',pos=V(8,3,0),action='Boosts',sign='BOOSTS\nWISHING FOUNTAIN'},
 }) do
  local hit=invisible(part(interactive,s.kind..'Prompt',V(2,2,2),s.pos,C(255,255,255)))
  stations[s.kind]=prompt(hit,s.action)
  if s.sign then label(hit,s.sign,{Offset=V(0,8.5,0),Color=C(110,215,255),Size=1.9}) end
 end

 -- Egg pedestals: an invisible box around each egg, tagged EggPedestal with its EggId, carrying the
 -- price billboard and aura. The egg itself floats, bobs and turns on the clients
 -- (Client/EggPedestals.lua, which animates parts with a FloatingEgg attribute).
 local eggs={}
 for _,egg in ipairs(Config.Eggs) do
  local island=ISLANDS[egg.Zone]
  local body=world:FindFirstChild(egg.Model or ('EggBody_'..egg.Zone),true)
  local cf,size
  if body and body:IsA('BasePart') then cf,size=body.CFrame,body.Size
  elseif island then cf,size=CFrame.new(island.center+V(-13,5.2,5)),V(4.2,5,4.2)
  else warn('[MapBuilder] No island for egg '..egg.Id) end
  if cf then
   local color=ZONE_COLORS[egg.Zone] or C(255,255,255)
   local p=invisible(part(interactive,egg.Id,size+V(1.5,2.5,1.5),cf.Position+V(0,0.6,0),color))
   p.CanQuery=true -- clickable
   p:SetAttribute('EggId',egg.Id) p:SetAttribute('Zone',egg.Zone)
   CollectionService:AddTag(p,'EggPedestal')
   if body and body:IsA('BasePart') then
    body.CanCollide=false body:SetAttribute('FloatingEgg',egg.Id)
   end
   local currency=EggConfig.Currencies[egg.Currency] or EggConfig.Currencies.Coins
   label(p,string.upper(egg.Name)..'\n'..short(egg.Cost)..' '..string.upper(currency.Name)
    ..(egg.RequiredRebirths>0 and '\nNEEDS '..egg.RequiredRebirths..' ASCENSION'..(egg.RequiredRebirths==1 and '' or 'S') or ''),
    {Offset=V(0,size.Y/2+2.8,0),Color=color,SubColor=C(255,214,90),Size=1.6})
   local sparkle=Instance.new('ParticleEmitter') sparkle.Texture='rbxasset://textures/particles/sparkles_main.dds'
   sparkle.Color=ColorSequence.new(color) sparkle.Size=NumberSequence.new(0.35,0)
   sparkle.Lifetime=NumberRange.new(0.6,1.2) sparkle.Rate=6 sparkle.Speed=NumberRange.new(0.5,1.5)
   sparkle.SpreadAngle=Vector2.new(180,180) sparkle.LightEmission=0.8 sparkle.Parent=p
   if egg.Aura then
    local light=Instance.new('PointLight') light.Color=color light.Range=12 light.Brightness=1.4 light.Parent=p
    local aura=Instance.new('ParticleEmitter') aura.Name='Aura' aura.Texture='rbxasset://textures/particles/sparkles_main.dds'
    aura.Color=ColorSequence.new(color,C(255,255,255)) aura.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.3,0.6),NumberSequenceKeypoint.new(1,0)})
    aura.Transparency=NumberSequence.new(0.3,1) aura.Lifetime=NumberRange.new(1.2,2) aura.Rate=10
    aura.Speed=NumberRange.new(0.6,1.2) aura.SpreadAngle=Vector2.new(20,20) aura.EmissionDirection=Enum.NormalId.Top
    aura.Shape=Enum.ParticleEmitterShape.Cylinder aura.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
    aura.LightEmission=1 aura.Parent=p
   end
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
   label(body,boss.Name..'\n'..short(boss.Health)..' HP',{Offset=V(0,newSize.Y/2+2.5,0),Color=ZONE_COLORS[boss.Zone],
    SubColor=C(255,110,120),Size=2.4,MaxDistance=170})
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
 return {ClickOrb=orb,RebirthAltar=altar,EggParts=eggs,Gates=gates,Bosses=bosses,Stations=stations,BoardSpots=boardSpots,
  Islands=ISLANDS}
end
return MapBuilder
