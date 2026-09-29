-- Floating cartoon lettering for world signs. MapBuilder places tagged FloatingLabel attachments (Text,
-- Color, SubColor, Size, MaxDistance); this builds each one on this client as chunky letters: every
-- character its own label with a thick outline, a light-to-color gradient and a drop shadow, drawn on
-- an invisible part (a SurfaceGui), so buildings hide it like any other object instead of it floating
-- over everything. Signs bob gently and turn to face the camera; the letters wave one after another.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local FloatingLabels = {}

local FONT = Enum.Font.FredokaOne
local PIXELS_PER_STUD = 48
local SUB_SCALE = 0.55 -- second and later lines, relative to the first
local LINE_GAP = 0.12 -- studs between lines, per stud of letter height
local WHITE = Color3.new(1, 1, 1)

local function letterWidth(char, px)
	if char == " " then
		return px * 0.32
	end
	return TextService:GetTextSize(char, px, FONT, Vector2.new(4000, 4000)).X
end

-- One sign: returns { Part, Gui, Anchor, Letters = { { Label, Shadow, X, Y, Index } }, Phase }.
local function build(anchor, folder)
	local text = anchor:GetAttribute("Text") or ""
	local mainColor = anchor:GetAttribute("Color") or WHITE
	local subColor = anchor:GetAttribute("SubColor") or WHITE
	local height = anchor:GetAttribute("Size") or 2
	local maxDistance = anchor:GetAttribute("MaxDistance") or 120

	-- Lay out every line in pixels first.
	local lines = string.split(text, "\n")
	local layout, width, y = {}, 0, 0
	for i, line in ipairs(lines) do
		local px = math.floor(height * PIXELS_PER_STUD * (if i == 1 then 1 else SUB_SCALE))
		local chars, lineWidth = {}, 0
		for _, code in utf8.codes(line) do
			local char = utf8.char(code)
			local w = letterWidth(char, px)
			table.insert(chars, { Char = char, X = lineWidth, W = w })
			lineWidth += w
		end
		table.insert(layout, { Chars = chars, Width = lineWidth, Px = px, Y = y,
			Color = if i == 1 then mainColor elseif i == 2 then subColor else Color3.fromRGB(235, 242, 255) })
		width = math.max(width, lineWidth)
		y += px + height * LINE_GAP * PIXELS_PER_STUD
	end
	local pad = height * 0.35 * PIXELS_PER_STUD -- room for outlines and the wave
	local canvas = Vector2.new(width + pad * 2, y + pad * 2)

	local part = Instance.new("Part")
	part.Name = "Label"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(canvas.X / PIXELS_PER_STUD, canvas.Y / PIXELS_PER_STUD, 0.05)
	part.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false -- behind walls like the rest of the world
	gui.MaxDistance = maxDistance
	gui.Adornee = part
	gui.Parent = part

	local letters = {}
	local index = 0
	for _, line in ipairs(layout) do
		local left = pad + (width - line.Width) / 2
		local light = line.Color:Lerp(WHITE, 0.55)
		local dark = line.Color:Lerp(Color3.new(0, 0, 0), 0.62)
		for _, c in ipairs(line.Chars) do
			if c.Char ~= " " then
				index += 1
				local function make(color, zIndex)
					local l = Instance.new("TextLabel")
					l.BackgroundTransparency = 1
					l.Font = FONT
					l.TextSize = line.Px
					l.Text = c.Char
					l.TextColor3 = color
					l.AnchorPoint = Vector2.new(0.5, 0.5)
					l.Size = UDim2.fromOffset(c.W + line.Px * 0.2, line.Px * 1.2)
					l.ZIndex = zIndex
					l.Parent = gui
					local stroke = Instance.new("UIStroke")
					stroke.Color = dark
					stroke.Thickness = math.max(2, line.Px * 0.09)
					stroke.LineJoinMode = Enum.LineJoinMode.Round
					stroke.Parent = l
					return l
				end
				-- Drop shadow: the same letter in the outline color, nudged down.
				local shadow = make(dark, 1)
				local label = make(WHITE, 2)
				local gradient = Instance.new("UIGradient")
				gradient.Rotation = 90
				gradient.Color = ColorSequence.new(light, line.Color)
				gradient.Parent = label
				table.insert(letters, {
					Label = label, Shadow = shadow, Index = index,
					X = left + c.X + c.W / 2, Y = pad + line.Y + line.Px / 2, Px = line.Px,
				})
			end
		end
	end

	return { Part = part, Gui = gui, Anchor = anchor, Letters = letters, Phase = math.random() * math.pi * 2,
		MaxDistance = maxDistance, Height = height }
end

function FloatingLabels.Start()
	local folder = Instance.new("Folder")
	folder.Name = "FloatingLabels"
	folder.Parent = workspace

	local signs = {} -- [anchor] = sign

	local function add(anchor)
		if signs[anchor] or not anchor:IsA("Attachment") then return end
		signs[anchor] = build(anchor, folder)
	end
	local function remove(anchor)
		local sign = signs[anchor]
		if sign then
			sign.Part:Destroy()
			signs[anchor] = nil
		end
	end
	for _, anchor in ipairs(CollectionService:GetTagged("FloatingLabel")) do add(anchor) end
	CollectionService:GetInstanceAddedSignal("FloatingLabel"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("FloatingLabel"):Connect(remove)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local eye = camera.CFrame.Position
		local now = os.clock()
		for anchor, sign in pairs(signs) do
			if not anchor.Parent then
				remove(anchor)
				continue
			end
			local base = anchor.WorldPosition
			local distance = (base - eye).Magnitude
			local visible = distance <= sign.MaxDistance
			sign.Gui.Enabled = visible
			if visible then
				-- Bob and turn to face the camera (upright: only around the vertical axis).
				local t = now + sign.Phase
				local position = base + Vector3.new(0, math.sin(t * 1.4) * sign.Height * 0.12, 0)
				local toward = Vector3.new(eye.X, position.Y, eye.Z)
				if (toward - position).Magnitude > 0.01 then
					sign.Part.CFrame = CFrame.lookAt(position, toward)
				end
				-- Letter wave, skipped when far away where it wouldn't show.
				if distance < sign.MaxDistance * 0.6 then
					for _, letter in ipairs(sign.Letters) do
						local wave = math.sin(t * 3 - letter.Index * 0.55)
						local lift = wave * letter.Px * 0.08
						local tilt = math.sin(t * 2.2 - letter.Index * 0.8) * 5
						letter.Label.Position = UDim2.fromOffset(letter.X, letter.Y + lift)
						letter.Label.Rotation = tilt
						letter.Shadow.Position = UDim2.fromOffset(letter.X, letter.Y + lift + letter.Px * 0.07)
						letter.Shadow.Rotation = tilt
					end
				elseif not sign.Settled then
					for _, letter in ipairs(sign.Letters) do
						letter.Label.Position = UDim2.fromOffset(letter.X, letter.Y)
						letter.Label.Rotation = 0
						letter.Shadow.Position = UDim2.fromOffset(letter.X, letter.Y + letter.Px * 0.07)
						letter.Shadow.Rotation = 0
					end
				end
				sign.Settled = distance >= sign.MaxDistance * 0.6
			end
		end
	end)
end

return FloatingLabels
