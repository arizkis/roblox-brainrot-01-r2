--!strict
-- Reproducible LIVE Studio scenes for TOUR.json, never invoked by normal play.
-- Fixtures use the game's own factory, transactions, carry, pads, locks and rebirths.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local State = require(script.Parent.GameState)
local Factory = require(script.Parent.CharacterFactory)
local Economy = require(script.Parent.Economy)
local Carry = require(script.Parent.Carry)
local StealLock = require(script.Parent.StealLock)
local Rebirth = require(script.Parent.Rebirth)
local Tsunami = require(script.Parent.Tsunami)
local Tour = {}

local function pose(record: State.PlayerState, position: Vector3, facing: Vector3): BasePart
	local root = Carry.LivingRoot(record.Player)
	assert(root, "Wait for the Studio avatar to spawn")
	local avatar = record.Player.Character
	assert(avatar)
	avatar:PivotTo(CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return root
end

local function stock(id: string, mutation: string, progress: number): State.CharacterState
	local world = State.World
	assert(world)
	local definition = Config.Characters[id]
	local tier = Config.Tiers[definition.Tier]
	local factor = if mutation == "Normal" then 1 else Config.Mutations[mutation].Multiplier
	local frame = world.BeltStart.WorldCFrame:Lerp(world.BeltEnd.WorldCFrame, progress)
	local model = Factory.Create(id, mutation, frame)
	local root = model.PrimaryPart
	assert(root)
	local record: State.CharacterState = {
		Model = model, CharacterId = id, Mutation = mutation, Root = root, Status = "Belt",
		BuyPrice = tier.BuyPrice, IntrinsicIncome = tier.IncomePerSecond * factor,
		IncomePerSecond = tier.IncomePerSecond * factor, BeltProgress = progress,
		OwnerUserId = nil, CarrierUserId = nil, PadIndex = nil,
		Prompt = nil, PromptConnection = nil, CarryWeld = nil, StolenFromUserId = nil,
	}
	State.Characters[model] = record
	State.PublishCharacter(record)
	Factory.SetForSale(model, true)
	model.Parent = world.Characters
	Carry.Bind(record)
	return record
end

local function buy(record: State.PlayerState, character: State.CharacterState)
	local root = Carry.LivingRoot(record.Player)
	assert(root)
	local ok, reason = Economy.TryPurchase(record, character)
	assert(ok, reason)
	Carry.Begin(record, character, root, false)
	State.Publish(record)
end

local function placed(record: State.PlayerState, id: string, mutation: string, index: number): State.CharacterState
	local plot = Economy.GetPlot(record)
	assert(plot)
	local character = stock(id, mutation, 0.45)
	buy(record, character)
	pose(record, plot.PadSlots[index].WorldPosition + Vector3.new(0, 3, 0), plot.Deck.Position)
	Carry.Scan()
	assert(character.Status == "Placed" and character.PadIndex == index, "Tour delivery failed")
	return character
end

local function camera(record: State.PlayerState, position: Vector3, target: Vector3)
	local signals = State.Signals
	assert(signals)
	local remote = signals:FindFirstChild("TourView")
	assert(remote and remote:IsA("RemoteEvent"), "Studio-only TourView must be ready")
	remote:FireClient(record.Player, CFrame.lookAt(position, target), target)
end

function Tour.Stage(shot: string): string
	assert(RunService:IsStudio() and RunService:IsRunning(), "CaptureTour is only available during Studio Play")
	assert(shot == "cover" or shot == "conveyor" or shot == "steal-lock" or shot == "base-rebirth", "Unknown tour shot")
	local records: {State.PlayerState} = {}
	for _, player in Players:GetPlayers() do
		local record = State.Players[player.UserId]
		if record and record.BaseId and Carry.LivingRoot(player) then
			table.insert(records, record)
		end
	end
	table.sort(records, function(a: State.PlayerState, b: State.PlayerState)
		return (a.BaseId or 0) < (b.BaseId or 0)
	end)
	assert(#records > 0, "Start Studio Play and wait for a claimed base")
	assert(shot ~= "steal-lock" or #records >= 2, "Use Studio Start Server with TWO clients for the rival-base shot")
	local hero = records[1]
	-- Each shot starts fresh, and the ordinary server systems keep running afterward.
	for _, record in State.Players do
		Carry.RestoreSpeed(record)
		Economy.RemovePlayer(record)
		record.Cash = 500000
		record.Rebirths = 0
		record.IncomeMultiplier = 1
		record.PadAllowance = Config.World.StartingPads
		record.LockExpiresAt = 0
		record.LockReadyAt = 0
		State.Publish(record)
	end
	for _, character in State.Characters do
		State.DestroyCharacter(character)
	end
	State.ConveyorElapsed = 0
	Tsunami.ResetForTour(90)
	local plot = Economy.GetPlot(hero)
	assert(plot)
	local home = plot.Deck.CFrame

	if shot == "conveyor" then
		for index, item in {
			{"wet_floor_sign", "Golden"}, {"rusty_clippy", "Diamond"},
			{"grandma_turbo", "Glitch"}, {"buff_goldfish", "Golden"},
			{"the_blue_screen", "Void"},
		} do
			stock(item[1], item[2], 0.25 + (index - 1) * 0.125)
		end
		pose(hero, Vector3.new(0, 4, -10), Vector3.zero)
		camera(hero, Vector3.new(0, 50, 44), Vector3.new(0, 3, 0))
	elseif shot == "steal-lock" then
		local rival = records[2]
		local rivalPlot = Economy.GetPlot(rival)
		assert(rivalPlot)
		local target = placed(rival, "solar_samurai_squirrel", "Golden", 1)
		placed(rival, "temporal_tuba", "Diamond", 3)
		placed(rival, "velvet_void_vortex", "Glitch", 6)
		pose(hero, target.Root.Position + Vector3.new(0, 3, -4), target.Root.Position)
		assert(StealLock.TrySteal(hero.Player, target), "Tour theft failed")
		assert(StealLock.TryLock(rival.Player), "Tour rival lock failed")
		local frame = rivalPlot.Deck.CFrame
		local position = (frame * CFrame.new(0, 3.5, -10)).Position
		pose(hero, position, plot.Deck.Position)
		camera(hero, (frame * CFrame.new(12, 17, -30)).Position, (frame * CFrame.new(0, 4, 2)).Position)
	else
		placed(hero, "disco_potato", "Golden", 1)
		placed(hero, "buff_goldfish", "Normal", 3)
		placed(hero, "grandma_turbo", "Diamond", 4)
		placed(hero, "celestial_sushi_roll", "Glitch", 6)
		assert(Rebirth.TryRebirth(hero.Player), "First tour rebirth failed")
		assert(Rebirth.TryRebirth(hero.Player), "Second tour rebirth failed")
		if shot == "cover" then
			local position = (home * CFrame.new(0, 3, -20)).Position
			pose(hero, position, plot.Deck.Position)
			buy(hero, stock("solar_samurai_squirrel", "Glitch", 0.55))
			Tsunami.ResetForTour(3)
			camera(hero, position + Vector3.new(18, 16, 35), position + Vector3.new(8, 5, -18))
		else
			pose(hero, (home * CFrame.new(-7, 3, -8)).Position, plot.Deck.Position)
			camera(hero, (home * CFrame.new(18, 23, -30)).Position, (home * CFrame.new(0, 3, 1)).Position)
		end
	end
	StealLock.Refresh()
	Rebirth.Refresh()
	return "Live Studio scene ready: " .. shot .. ". Capture the client owning the lowest-numbered base; V releases the camera."
end

return Tour
