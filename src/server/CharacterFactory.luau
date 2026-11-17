--!strict
-- Builds one unparented, welded model. No spawn rolls, timers, purchases or ownership here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Presentation = require(ReplicatedStorage.Shared:WaitForChild("Presentation"))

local Factory = {}
local v = Vector3.new
local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local INK = rgb(16, 18, 36)

local function addPart(
	model: Model, root: BasePart, name: string, shape: string, size: Vector3,
	transform: CFrame, color: Color3, material: Enum.Material
): BasePart
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local primitive = Instance.new("Part")
		if shape == "Ball" then
			primitive.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			primitive.Shape = Enum.PartType.Cylinder
		else
			assert(shape == "Block", "Unknown recipe shape: " .. shape)
		end
		part = primitive
	end
	part.Name = name
	part.Size = size
	part.CFrame = transform
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = "RootWeld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function outline(model: Model, color: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Name = "MutationOutline"
	highlight.Adornee = model
	highlight.FillTransparency = 1
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

local function applyMutation(model: Model, root: BasePart, mutation: string, height: number, bounds: Vector3): number
	local width = bounds.X
	local depth = bounds.Z
	local body = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			table.insert(body, child)
		end
	end
	local function detail(name: string, shape: string, size: Vector3, position: Vector3, color: Color3, rotation: Vector3?): BasePart
		local angles = rotation or v(0, 0, 0)
		return addPart(model, root, name, shape, size,
			CFrame.new(position) * CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z)),
			color, Enum.Material.Neon)
	end

	if mutation == "Golden" then
		local gold = Config.Mutations.Golden.Color
		for _, part in body do
			part.Color = part.Color:Lerp(gold, 0.22)
			part.Reflectance = 0.15
		end
		for _, side in {-1, 1} do
			detail("GoldTrimFrontBack", "Block", v(width + 0.15, 0.16, 0.12), v(0, 0.3, side * depth / 2), gold)
			detail("GoldTrimSide", "Block", v(0.12, 0.16, depth), v(side * width / 2, 0.3, 0), gold)
			detail("GoldCrownStud", "Block", v(0.24, 0.5, 0.24), v(side * 0.5, height + 0.1, 0), gold)
		end
		outline(model, gold)
		return height + 0.35
	elseif mutation == "Diamond" then
		local cyan = Config.Mutations.Diamond.Color
		for _, part in body do
			part.Color = part.Color:Lerp(cyan, 0.15)
			part.Reflectance = 0.2
		end
		for index, side in {-1, 1} do
			local center = v(side * (width / 2 + 0.2), height * (0.55 + index * 0.1), 0)
			detail("GlintVertical", "Block", v(0.12, 1.1, 0.12), center, WHITE)
			detail("GlintHorizontal", "Block", v(0.75, 0.12, 0.12), center, cyan)
		end
		detail("DiamondCrest", "Block", v(0.5, 0.5, 0.25), v(0, height + 0.2, 0), cyan, v(0, 0, 45))
		outline(model, cyan)
		return height + 0.6
	elseif mutation == "Glitch" then
		local channels = {rgb(255, 45, 97), rgb(58, 255, 141), rgb(53, 157, 255)}
		for index, part in body do
			local color = channels[(index - 1) % 3 + 1]
			part.Color = part.Color:Lerp(color, 0.4)
			if index % 3 == 0 then
				local ghost = addPart(model, root, "RGBEcho", "Block", part.Size,
					part.CFrame + v(0.16, 0.04, -0.12), color, Enum.Material.Neon)
				ghost.Transparency = 0.72
				ghost.CastShadow = false
			end
		end
		for index, color in channels do
			detail("GlitchPixel", "Block", v(0.5, 0.18, 0.3), v(width / 2 + 0.25, height * index / 4, -0.3), color)
		end
		outline(model, channels[1])
	elseif mutation == "Void" then
		local violet = rgb(174, 70, 255)
		for _, part in body do
			-- Keep faces visible even on an almost-black mutation.
			local face = string.find(part.Name, "Eye") or string.find(part.Name, "Pupil")
			part.Color = if face then violet else part.Color:Lerp(Config.Mutations.Void.Color, 0.78)
		end
		local aura = detail("VoidAura", "Ball", v(width + 0.6, height * 0.95, depth + 0.6), v(0, height / 2, 0), rgb(24, 5, 42))
		aura.Transparency = 0.88
		aura.CastShadow = false
		for _, side in {-1, 1} do
			detail("VoidShard", "Wedge", v(0.28, 0.8, 0.28), v(side * (width / 2 + 0.35), height * 0.7, 0), violet, v(0, 0, side * 25))
		end
		outline(model, violet)
	end
	return height
end

local money = Presentation.Number

local function incomeText(income: number, mutation: string, multiplier: number): string
	local text = "$" .. money(income, true) .. "/s"
	if mutation ~= "Normal" then
		text ..= "  •  " .. mutation .. " x" .. tostring(multiplier)
	end
	return text
end

local function nameplate(model: Model, root: BasePart, height: number, name: string, tier: string, mutation: string, income: number, multiplier: number)
	local anchor = Instance.new("Attachment")
	anchor.Name = "NameplateAnchor"
	anchor.Position = v(0, height, 0)
	anchor.Parent = root

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(Presentation.NameplateWidth, Presentation.NameplateHeight)
	gui:SetAttribute("DesignWidth", Presentation.NameplateWidth)
	gui:SetAttribute("DesignHeight", Presentation.NameplateHeight)
	gui.StudsOffsetWorldSpace = v(0, 1.8, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = model

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(Presentation.NameplateWidth, Presentation.NameplateHeight)
	panel.BackgroundColor3 = INK
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = panel

	local function line(labelName: string, text: string, y: number, h: number, size: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = labelName
		label.Position = UDim2.fromOffset(6, y)
		label.Size = UDim2.new(1, -12, 0, h)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.TextColor3 = WHITE
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.TextWrapped = false
		label.Parent = panel
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = 24
		constraint.MaxTextSize = size
		constraint.Parent = label
		return label
	end

	line("CharacterName", name, 3, 38, 30)
	local rarity = line("Rarity", string.upper(tier), 42, 29, 24)
	rarity.BackgroundColor3 = Config.Tiers[tier].Color
	rarity.BackgroundTransparency = 0
	local rarityCorner = Instance.new("UICorner")
	rarityCorner.CornerRadius = UDim.new(0, 5)
	rarityCorner.Parent = rarity
	line("Income", incomeText(income, mutation, multiplier), 74, 39, 28)
	local price = line("Price", "", 115, 31, 25)
	price.Visible = false
end

function Factory.SetIncome(model: Model, income: number)
	model:SetAttribute("IncomePerSecond", income)
	local gui = model:FindFirstChild("Nameplate") :: BillboardGui
	local panel = gui:FindFirstChild("Panel") :: Frame
	local label = panel:FindFirstChild("Income") :: TextLabel
	label.Text = incomeText(income, model:GetAttribute("Mutation") :: string, model:GetAttribute("MutationMultiplier") :: number)
end

function Factory.SetForSale(model: Model, forSale: boolean)
	local gui = model:FindFirstChild("Nameplate") :: BillboardGui
	local panel = gui:FindFirstChild("Panel") :: Frame
	local price = panel:FindFirstChild("Price") :: TextLabel
	price.Text = "$" .. money(model:GetAttribute("BuyPrice") :: number) .. "  •  BUY"
	price.Visible = forSale
	local height = if forSale then Presentation.SaleNameplateHeight else Presentation.NameplateHeight
	gui:SetAttribute("DesignHeight", height)
	gui.Size = UDim2.fromOffset(Presentation.NameplateWidth, height)
	panel.Size = UDim2.fromOffset(Presentation.NameplateWidth, height)
end

function Factory.Create(characterId: string, mutationName: string?, origin: CFrame?): Model
	local definition = Config.Characters[characterId]
	assert(definition, "Unknown character id: " .. characterId)
	local tier = Config.Tiers[definition.Tier]
	local mutation = mutationName or "Normal"
	local mutationDefinition = Config.Mutations[mutation]
	assert(mutation == "Normal" or mutationDefinition, "Unknown mutation: " .. mutation)
	local multiplier = if mutationDefinition then mutationDefinition.Multiplier else 1
	assert(multiplier <= Config.MaxMutationMultiplier, "Mutation multiplier exceeds x15")
	local income = tier.IncomePerSecond * multiplier

	local model = Instance.new("Model")
	model.Name = definition.Name
	model:SetAttribute("CharacterId", characterId)
	model:SetAttribute("Tier", definition.Tier)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("MutationMultiplier", multiplier)
	model:SetAttribute("BaseIncomePerSecond", tier.IncomePerSecond)
	model:SetAttribute("IncomePerSecond", income)
	model:SetAttribute("BuyPrice", tier.BuyPrice)

	-- Only the root is anchored. Releasing it later makes a single welded assembly.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = v(0.2, 0.2, 0.2)
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.Anchored = true
	root.Massless = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	local height = 0
	for _, recipe in definition.Parts do
		local rotation = recipe.Rotation
		local transform = CFrame.new(recipe.Position)
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		local part = addPart(model, root, recipe.Name, recipe.Shape, recipe.Size, transform, recipe.Color, recipe.Material)
		local halfY = (math.abs(transform.RightVector.Y) * part.Size.X
			+ math.abs(transform.UpVector.Y) * part.Size.Y
			+ math.abs(transform.LookVector.Y) * part.Size.Z) / 2
		height = math.max(height, recipe.Position.Y + halfY)
	end
	local _, bounds = model:GetBoundingBox()
	if mutation ~= "Normal" then
		height = applyMutation(model, root, mutation, height, bounds)
	end
	nameplate(model, root, height, definition.Name, definition.Tier, mutation, income, multiplier)
	model:PivotTo(origin or CFrame.identity)
	return model
end

return Factory
