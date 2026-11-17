--!strict
-- Geometry and references only; gameplay modules drive the resulting controls/effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local WorldBuilder = {}
local v = Vector3.new
local rgb = Color3.fromRGB
local INK = rgb(34, 30, 65)
local WHITE = rgb(255, 255, 247)
local CYAN = rgb(36, 232, 246)
local PINK = rgb(255, 73, 155)
local GOLD = rgb(255, 215, 60)
local BASE_COLORS = {PINK, CYAN, rgb(143, 236, 57), rgb(255, 147, 54), rgb(169, 105, 255), GOLD}

export type BasePlot = {
	Id: number,
	Model: Model,
	Deck: BasePart,
	Color: Color3,
	PadFolder: Folder,
	Pads: {BasePart},
	PadSlots: {Attachment},
	SafeZone: BasePart,
	LockButton: BasePart,
	OwnerLabel: TextLabel,
	LockLabel: TextLabel,
	Shield: BasePart,
	RebirthButton: BasePart,
	LockPrompt: ProximityPrompt?,
	RebirthPrompt: ProximityPrompt?,
}

export type World = {
	Root: Model,
	Bases: {BasePlot},
	Belt: BasePart,
	BeltStart: Attachment,
	BeltEnd: Attachment,
	Spawn: SpawnLocation,
	Characters: Folder,
}

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function block(parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Parent = parent
	return part
end

local function decoration(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function label(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, maxSize: number): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.Position = position
	textLabel.Size = size
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Text = text
	textLabel.TextColor3 = WHITE
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextScaled = true
	textLabel.TextWrapped = false
	textLabel.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = maxSize
	constraint.Parent = textLabel
	return textLabel
end

local function sign(part: BasePart, title: string, subtitle: string, face: Enum.NormalId?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1000, 220)
	gui.LightInfluence = 0
	gui.Parent = part
	local titleLabel = label(gui, "Title", title, UDim2.fromScale(0.02, 0.04), UDim2.fromScale(0.96, 0.56), 86)
	label(gui, "Subtitle", subtitle, UDim2.fromScale(0.02, 0.63), UDim2.fromScale(0.96, 0.3), 45)
	return titleLabel
end

local function smallBillboard(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ButtonLabel"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(144, 40)
	gui.StudsOffsetWorldSpace = v(0, 1.5, 0)
	gui.MaxDistance = 65
	gui.LightInfluence = 0
	gui.Parent = part
	local textLabel = label(gui, "Title", text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 30)
	textLabel.BackgroundColor3 = color
	textLabel.BackgroundTransparency = 0.1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = textLabel
end

local function buildPlaza(root: Model)
	local plaza = group(root, "Plaza")
	local size = Config.World.PlazaSize
	block(plaza, "Floor", v(size, 2, size), CFrame.new(0, -1, 0), rgb(82, 213, 184))
	local center = block(plaza, "CenterDisc", v(0.08, 86, 86), CFrame.new(0, 0.04, 0)
		* CFrame.Angles(0, 0, math.rad(90)), rgb(135, 231, 218))
	center.Shape = Enum.PartType.Cylinder
	decoration(center)
	for _, side in {-1, 1} do
		block(plaza, "EdgeEastWest", v(2, 1.2, size), CFrame.new(side * (size / 2 - 1), 0, 0), GOLD)
		block(plaza, "EdgeNorthSouth", v(size, 1.2, 2), CFrame.new(0, 0, side * (size / 2 - 1)), GOLD)
	end
	-- A clear approach from the player spawn to the center.
	block(plaza, "EntryWalk", v(12, 0.08, 29), CFrame.new(0, 0.05, -26), rgb(255, 231, 157))
	for z = -38, -14, 4 do
		local stripe = block(plaza, "WalkStripe", v(10, 0.04, 0.45), CFrame.new(0, 0.11, z), WHITE)
		decoration(stripe)
	end
end

local function buildConveyor(root: Model): (BasePart, Attachment, Attachment)
	local conveyor = group(root, "Conveyor")
	local start = Config.World.ConveyorStart
	local finish = Config.World.ConveyorEnd
	local length = (finish - start).Magnitude
	local middle = (start + finish) / 2
	local frame = CFrame.lookAt(middle - v(0, 0.3, 0), finish - v(0, 0.3, 0))
	local width = Config.World.ConveyorWidth
	local belt = block(conveyor, "Belt", v(width, 0.6, length), frame, INK)
	-- These are floor-level character pivots, facing down the lane (local -Z).
	local beltStart = Instance.new("Attachment")
	beltStart.Name = "BeltStart"
	beltStart.CFrame = CFrame.new(0, 0.3, length / 2)
	beltStart.Parent = belt
	local beltEnd = Instance.new("Attachment")
	beltEnd.Name = "BeltEnd"
	beltEnd.CFrame = CFrame.new(0, 0.3, -length / 2)
	beltEnd.Parent = belt

	for _, side in {-1, 1} do
		block(conveyor, "SideRail", v(0.45, 0.8, length + 1), frame * CFrame.new(side * (width / 2 + 0.3), 0.2, 0), CYAN)
		local light = block(conveyor, "RailLight", v(0.12, 0.12, length), frame * CFrame.new(side * (width / 2 + 0.3), 0.67, 0), PINK, Enum.Material.Neon)
		decoration(light)
	end
	for z = -length / 2 + 5, length / 2 - 3, 7 do
		local seam = block(conveyor, "BeltSeam", v(width - 0.2, 0.025, 0.06), frame * CFrame.new(0, 0.3125, z), rgb(72, 66, 100))
		decoration(seam)
		for _, side in {-1, 1} do
			local arrow = block(conveyor, "DirectionChevron", v(0.18, 0.04, 1.8),
				frame * CFrame.new(side * 0.6, 0.34, z - 1.5) * CFrame.Angles(0, math.rad(side * 45), 0), GOLD)
			decoration(arrow)
		end
	end

	local arch = group(conveyor, "SpawnArch")
	local gate = frame * CFrame.new(0, 0, length / 2 + 2)
	for _, side in {-1, 1} do
		block(arch, "Column", v(1.4, 9.2, 1.4), gate * CFrame.new(side * 6.4, 4, 0), PINK)
		block(arch, "ColumnFoot", v(2.2, 0.5, 2.2), gate * CFrame.new(side * 6.4, -0.4, 0), GOLD)
		local strip = block(arch, "ArchLight", v(0.25, 7, 0.16), gate * CFrame.new(side * 6.4, 4, -0.8), CYAN, Enum.Material.Neon)
		decoration(strip)
	end
	local header = block(arch, "BazaarTitle", v(24, 4, 0.7), gate * CFrame.new(0, 9, 0), INK)
	sign(header, "BRAINROT BAZAAR", "COLLECT  •  CASH  •  CHAOS")
	sign(header, "BRAINROT BAZAAR", "FRESH NONSENSE ARRIVES HERE", Enum.NormalId.Back)
	local top = block(arch, "TitleCrown", v(25, 0.35, 1), gate * CFrame.new(0, 11.2, 0), GOLD)
	decoration(top)

	local endGate = frame * CFrame.new(0, 0, -length / 2 - 1.5)
	for _, side in {-1, 1} do
		block(conveyor, "ExitPost", v(0.7, 3.7, 0.7), endGate * CFrame.new(side * 5.5, 1.2, 0), rgb(162, 100, 255))
	end
	local exitSign = block(conveyor, "ExitSign", v(12, 1.4, 0.3), endGate * CFrame.new(0, 3.6, 0), INK)
	sign(exitSign, "LAST CHANCE", "BELT END", Enum.NormalId.Back)
	return belt, beltStart, beltEnd
end

function WorldBuilder.SetPadAllowance(plot: BasePlot, allowance: number)
	assert(allowance >= Config.World.StartingPads and allowance <= Config.World.MaxPads, "Invalid pad allowance")
	for index = #plot.Pads, allowance + 1, -1 do
		plot.Pads[index]:Destroy()
		plot.Pads[index] = nil
	end
	for index = 1, allowance do
		if plot.Pads[index] then
			continue
		end
		local pad = block(plot.PadFolder, string.format("Pad_%02d", index), v(3.5, 0.3, 3.5),
			plot.PadSlots[index].WorldCFrame * CFrame.new(0, -0.15, 0), plot.Color)
		pad:SetAttribute("PadIndex", index)
		pad:SetAttribute("BaseId", plot.Id)
		pad:SetAttribute("Occupied", false)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "PadNumber"
		gui.Face = Enum.NormalId.Top
		gui.CanvasSize = Vector2.new(200, 200)
		gui.LightInfluence = 0
		gui.Parent = pad
		label(gui, "Number", string.format("%02d", index), UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.8), 100)
		plot.Pads[index] = pad
	end
end

local function buildBase(root: Model, id: number): BasePlot
	local plot = group(root, string.format("Base_%02d", id))
	plot:SetAttribute("BaseId", id)
	plot:SetAttribute("OwnerUserId", 0)
	local color = BASE_COLORS[id]
	-- Endpoints sit halfway between adjacent plots, leaving the lane unobstructed.
	local angle = math.rad(15 + (id - 1) * 60)
	local location = v(math.cos(angle) * Config.World.BaseRadius, 0, math.sin(angle) * Config.World.BaseRadius)
	local frame = CFrame.lookAt(location, Vector3.zero)
	local deck = block(plot, "Deck", v(32, 0.8, 24), frame * CFrame.new(0, 0.4, 0), rgb(239, 237, 255))
	for _, side in {-1, 1} do
		block(plot, "SideTrim", v(0.35, 0.35, 24), frame * CFrame.new(side * 15.8, 0.95, 0), color)
	end
	block(plot, "Threshold", v(31, 0.08, 1), frame * CFrame.new(0, 0.85, -11), color)
	block(plot, "PadRowArea", v(27, 0.1, 5), frame * CFrame.new(0, 0.85, 3.5), rgb(61, 55, 94))
	block(plot, "ExpansionArea", v(19, 0.08, 4), frame * CFrame.new(0, 0.85, -2), rgb(218, 215, 239))

	local padFolder = Instance.new("Folder")
	padFolder.Name = "Pads"
	padFolder.Parent = plot
	local slots = {}
	for index = 1, Config.World.MaxPads do
		local position: Vector3
		if index <= Config.World.StartingPads then
			position = v((index - 3.5) * 4.2, 1.2, 3.5)
		else
			position = v((index - 8.5) * 4.2, 1.2, -2)
		end
		local slot = Instance.new("Attachment")
		slot.Name = string.format("PadSlot_%02d", index)
		slot.Position = position - v(0, 0.4, 0)
		slot:SetAttribute("PadIndex", index)
		slot.Parent = deck
		table.insert(slots, slot)
	end

	for _, side in {-1, 1} do
		block(plot, "SignPost", v(0.5, 6.8, 0.5), frame * CFrame.new(side * 11.5, 4.2, 10.6), color)
	end
	local board = block(plot, "OwnerSign", v(26, 3.5, 0.4), frame * CFrame.new(0, 6.8, 10.6), color)
	local ownerLabel = sign(board, string.format("BASE %02d • UNCLAIMED", id), "A HOME FOR YOUR BRAINROT")
	local lockBoard = block(plot, "LockStateSign", v(23, 1.6, 0.35), frame * CFrame.new(0, 9.5, 10.6), INK)
	local lockLabel = sign(lockBoard, "LOCK READY", "")
	local shield = block(plot, "PadShield", v(28, 8, 11), frame * CFrame.new(0, 5.2, 0.75), CYAN, Enum.Material.ForceField)
	shield.Transparency = 1
	decoration(shield)

	local pedestal = block(plot, "LockPedestal", v(2.6, 1.8, 2.6), frame * CFrame.new(12, 1.7, -7.5), INK)
	sign(pedestal, "BASE LOCK", "60s / 90s CD")
	local button = block(plot, "LockButton", v(2.2, 0.4, 2.2), frame * CFrame.new(12, 2.8, -7.5), rgb(126, 244, 79), Enum.Material.Neon)
	button:SetAttribute("BaseId", id)
	smallBillboard(button, "LOCK", INK)
	block(plot, "RebirthPedestal", v(2.6, 1.8, 2.6), frame * CFrame.new(-12, 1.7, -7.5), INK)
	local rebirthButton = block(plot, "RebirthButton", v(2.2, 0.4, 2.2), frame * CFrame.new(-12, 2.8, -7.5), GOLD, Enum.Material.Neon)
	rebirthButton:SetAttribute("BaseId", id)
	smallBillboard(rebirthButton, "REBIRTH", INK)
	local safeZone = block(plot, "SafeZone", v(32, 8, 24), frame * CFrame.new(0, 4.8, 0), color)
	safeZone.Transparency = 1
	decoration(safeZone)
	safeZone:SetAttribute("BaseId", id)
	local result: BasePlot = {
		Id = id, Model = plot, Deck = deck, Color = color, PadFolder = padFolder, Pads = {}, PadSlots = slots,
		SafeZone = safeZone, LockButton = button, OwnerLabel = ownerLabel,
		LockLabel = lockLabel, Shield = shield, RebirthButton = rebirthButton,
	}
	WorldBuilder.SetPadAllowance(result, Config.World.StartingPads)
	return result
end

local function buildDecor(root: Model)
	local decor = group(root, "Decor")
	-- Tall decorations stay at the rim; the field and base entrances stay open.
	for index = 1, 12 do
		local angle = math.rad(index * 30)
		local x = math.cos(angle) * 87
		local z = math.sin(angle) * 87
		local color = BASE_COLORS[(index - 1) % #BASE_COLORS + 1]
		block(decor, "CandyTreeTrunk", v(0.7, 3.3, 0.7), CFrame.new(x, 1.65, z), rgb(142, 85, 147))
		local crown = block(decor, "CandyTreeCrown", v(4, 4, 4), CFrame.new(x, 4.6, z) * CFrame.Angles(0, math.rad(30), math.rad(10)), color)
		decoration(crown)
		local small = block(decor, "CandyTreeFruit", v(1.3, 1.3, 1.3), CFrame.new(x + 1.6, 5.6, z - 0.8), GOLD)
		small.Shape = Enum.PartType.Ball
		decoration(small)
	end
	-- A compact, seven-color economy directory alongside the entry walk.
	local directoryFrame = CFrame.lookAt(v(16, 0, -34), v(0, 0, -34))
	local directory = block(decor, "TierDirectory", v(15, 9, 0.5), directoryFrame * CFrame.new(0, 5.2, 0), INK)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TierDirectory"
	gui.CanvasSize = Vector2.new(840, 600)
	gui.LightInfluence = 0
	gui.Parent = directory
	label(gui, "Title", "THE BAZAAR LADDER", UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.94, 0.12), 48)
	for index, tierName in Config.TierOrder do
		local tier = Config.Tiers[tierName]
		local row = label(gui, tierName, string.format("%s   $%d   /   $%d/s", tierName, tier.BuyPrice, tier.IncomePerSecond),
			UDim2.fromScale(0.04, 0.16 + (index - 1) * 0.112), UDim2.fromScale(0.92, 0.097), 34)
		row.BackgroundTransparency = 0
		row.BackgroundColor3 = tier.Color
	end
	for _, side in {-1, 1} do
		block(decor, "DirectoryPost", v(0.5, 1.1, 0.5), directoryFrame * CFrame.new(side * 6.5, 0.55, 0), GOLD)
	end
end

function WorldBuilder.Build(parent: Instance): World
	assert(not parent:FindFirstChild("BrainrotBazaar"), "BrainrotBazaar world already built")
	local root = group(parent, "BrainrotBazaar")
	local characters = Instance.new("Folder")
	characters.Name = "Characters"
	characters.Parent = root
	buildPlaza(root)
	local belt, beltStart, beltEnd = buildConveyor(root)
	local basesRoot = group(root, "Bases")
	local bases = {}
	for id = 1, Config.World.BaseCount do
		table.insert(bases, buildBase(basesRoot, id))
	end
	buildDecor(root)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BazaarSpawn"
	spawn.Size = v(8, 0.3, 8)
	spawn.CFrame = CFrame.lookAt(v(0, 0.25, -40), v(0, 0.25, 0))
	spawn.Color = GOLD
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = root
	local welcome = block(root, "WelcomeMat", v(12, 0.1, 3), CFrame.new(0, 0.1, -46), INK)
	sign(welcome, "WELCOME TO THE BAZAAR", "", Enum.NormalId.Top)
	return {Root = root, Bases = bases, Belt = belt, BeltStart = beltStart, BeltEnd = beltEnd, Spawn = spawn, Characters = characters}
end

return WorldBuilder
