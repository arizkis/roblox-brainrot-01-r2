--!strict
-- Spawns, rolls and moves unclaimed characters. Carry binds the purchase prompts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local State = require(script.Parent.GameState)
local Factory = require(script.Parent.CharacterFactory)

local Conveyor = {}
local random = Random.new()
local started = false
local castByTier: {[string]: {string}} = {}
for _, tierName in Config.TierOrder do
	castByTier[tierName] = {}
end
for _, id in Config.CharacterOrder do
	table.insert(castByTier[Config.Characters[id].Tier], id)
end

local function highestRebirth(): number
	local highest = 0
	for _, record in State.Players do
		highest = math.max(highest, record.Rebirths)
	end
	return math.max(0, math.floor(highest))
end

local function rollTier(bandIndex: number): string
	local weights = Config.Conveyor.TierOddsBands[bandIndex]
	local roll = random:NextNumber(0, 100)
	local cumulative = 0
	for index, weight in weights do
		cumulative += weight
		if roll < cumulative then
			return Config.TierOrder[index]
		end
	end
	return Config.TierOrder[#Config.TierOrder]
end

local function rollMutation(tierName: string): string
	local odds = Config.Tiers[tierName].MutationOdds
	local roll = random:NextNumber()
	local cumulative = 0
	for _, name in Config.MutationOrder do
		cumulative += odds[name]
		if roll < cumulative then
			return name
		end
	end
	return "Normal"
end

function Conveyor.Spawn(onSpawn: (State.CharacterState) -> ())
	local world = State.World
	assert(world, "Build the world before spawning characters")
	local highest = highestRebirth()
	local band = math.min(highest + 1, #Config.Conveyor.TierOddsBands)
	local tierName = rollTier(band)
	local cast = castByTier[tierName]
	local id = cast[random:NextInteger(1, #cast)]
	local mutation = rollMutation(tierName)
	local tier = Config.Tiers[tierName]
	local multiplier = if mutation == "Normal" then 1 else Config.Mutations[mutation].Multiplier
	local intrinsicIncome = tier.IncomePerSecond * multiplier
	local model = Factory.Create(id, mutation, world.BeltStart.WorldCFrame)
	local root = model.PrimaryPart
	assert(root, "Factory model needs its root")
	local character: State.CharacterState = {
		Model = model, CharacterId = id, Mutation = mutation, Root = root,
		Status = "Belt", BuyPrice = tier.BuyPrice,
		IntrinsicIncome = intrinsicIncome, IncomePerSecond = intrinsicIncome, BeltProgress = 0,
		OwnerUserId = nil, CarrierUserId = nil, PadIndex = nil,
		Prompt = nil, PromptConnection = nil, CarryWeld = nil,
	}
	State.Characters[model] = character
	State.PublishCharacter(character)
	Factory.SetForSale(model, true)
	model.Parent = world.Characters
	world.Root:SetAttribute("HighestRebirth", highest)
	world.Root:SetAttribute("ConveyorOddsBand", band)
	onSpawn(character)
end

function Conveyor.Advance(dt: number)
	local world = State.World
	assert(world, "Build the world before moving the conveyor")
	local start = world.BeltStart.WorldCFrame
	local finish = world.BeltEnd.WorldCFrame
	local length = (finish.Position - start.Position).Magnitude
	for _, character in State.Characters do
		if character.Status ~= "Belt" then
			continue
		end
		character.BeltProgress += dt * Config.Conveyor.Speed / length
		if character.BeltProgress >= 1 then
			State.DestroyCharacter(character)
		else
			character.Model:PivotTo(start:Lerp(finish, character.BeltProgress))
		end
	end
end

function Conveyor.Start(onSpawn: (State.CharacterState) -> ())
	assert(not started, "Conveyor already started")
	started = true
	Conveyor.Spawn(onSpawn)
	RunService.Heartbeat:Connect(function(dt: number)
		Conveyor.Advance(dt)
		State.ConveyorElapsed += dt
		if State.ConveyorElapsed >= Config.Conveyor.SpawnInterval then
			State.ConveyorElapsed %= Config.Conveyor.SpawnInterval
			Conveyor.Spawn(onSpawn)
		end
	end)
end

return Conveyor
