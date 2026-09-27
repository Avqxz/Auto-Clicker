-- Curated free Creator Store assets, imported at edit time (never execute Toolbox scripts).
local Assets={}
function Assets.Build(map)
 local source=game.ServerStorage:FindFirstChild('EnvironmentAssets')
 if not source then warn('EnvironmentAssets missing: import the free packs listed in ASSETS.md') return end
 local folder=Instance.new('Folder') folder.Name='ImportedEnvironment' folder.Parent=map
 local function place(name,pos,height,rotation)
  local template=source:FindFirstChild(name) if not template then return end
  local model=template:Clone() model.Parent=folder
  if not model:IsA('Model') then local wrapper=Instance.new('Model') wrapper.Name=name wrapper.Parent=folder model.Parent=wrapper model=wrapper end
  local _,size=model:GetBoundingBox()
  model:ScaleTo(model:GetScale()*height/math.max(size.Y,0.1))
  local originalCenter=model:GetBoundingBox()
  model:PivotTo(CFrame.new(pos)*CFrame.Angles(0,math.rad(rotation or 0),0)*originalCenter:Inverse()*model:GetPivot())
  local cf,newSize=model:GetBoundingBox()
  model:PivotTo(model:GetPivot()+Vector3.new(0,pos.Y-(cf.Position.Y-newSize.Y/2),0))
  for _,p in ipairs(model:GetDescendants()) do
   if p:IsA('BasePart') then
    p.Anchored=true
    if name=='Rock' then p.Material=Enum.Material.Slate p.Color=Color3.fromRGB(127,115,166)
    elseif name=='Cottage' and p.Material==Enum.Material.SmoothPlastic then p.Material=Enum.Material.Wood
    elseif name=='Tree' or name=='Pine' then
     p.Material=p.Color.G>p.Color.R and Enum.Material.LeafyGrass or Enum.Material.Wood
    end
   end
  end
  return model
 end
 local rng=Random.new(915)
 for _,center in ipairs({0,-310}) do
  local frost=center~=0
  for _,side in ipairs({-1,1}) do
   for i=1,7 do
    local x=side*rng:NextNumber(88,112) local z=center-118+i*30
    place((i%2==0 and not frost) and 'Tree' or 'Pine',Vector3.new(x,0.6,z),rng:NextNumber(22,34),rng:NextNumber(0,360))
    place('Rock',Vector3.new(x-side*12,0.7,z+8),rng:NextNumber(4,7),i*37)
    place('Bush',Vector3.new(x-side*17,0.6,z-6),rng:NextNumber(3,5),i*12)
   end
  end
 end
 place('Cottage',Vector3.new(-67,0.6,45),30,180)
 place('Mushrooms',Vector3.new(-48,0.6,31),3,20)
 -- Terrain and lighting are owned by MapBuilder; this module only places props.
end
return Assets
