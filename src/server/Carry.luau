--!strict
-- Server prompt handling, avatar attachment and delivery detection.
-- Cash and pad occupancy are always changed through Economy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local State = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local Factory = require(script.Parent.CharacterFactory)

local Carry = {}
local started = false
local placedHandler: ((State.CharacterState) -> ())? = nil

function Carry.LivingRoot(player: Player): BasePart?
	local avatar = player.Character
	if not avatar then
		return nil
	end
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	local root = avatar:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Carry.RestoreSpeed(record: State.PlayerState)
	local humanoid = record.SlowedHumanoid
	if humanoid and humanoid.Parent and record.NormalWalkSpeed then
		humanoid.WalkSpeed = record.NormalWalkSpeed
	end
	record.SlowedHumanoid = nil
	record.NormalWalkSpeed = nil
end

local function updateSpeed(record: State.PlayerState, stolen: boolean)
	local avatar = record.Player.Character
	local humanoid = if avatar then avatar:FindFirstChildOfClass("Humanoid") else nil
	if not stolen or not humanoid or humanoid.Health <= 0 then
		Carry.RestoreSpeed(record)
		return
	end
	if record.SlowedHumanoid ~= humanoid then
		Carry.RestoreSpeed(record)
		record.SlowedHumanoid = humanoid
		record.NormalWalkSpeed = humanoid.WalkSpeed
	end
	local normalSpeed = record.NormalWalkSpeed
	assert(normalSpeed, "Missing original walk speed")
	humanoid.WalkSpeed = normalSpeed * Config.StealLock.StolenSpeedFactor
end

local function detach(character: State.CharacterState)
	if character.CarryWeld then
		character.CarryWeld:Destroy()
		character.CarryWeld = nil
	end
	character.Root.Anchored = true
end

local function attach(character: State.CharacterState, avatarRoot: BasePart)
	local existing = character.CarryWeld
	if existing and existing.Parent and existing.Part0 == avatarRoot then
		return
	end
	detach(character)
	character.Model:PivotTo(avatarRoot.CFrame * CFrame.new(Config.Carry.Offset))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	-- Unanchor before joining the avatar, so the avatar is never anchored by the prop.
	character.Root.Anchored = false
	weld.Part0 = avatarRoot
	weld.Part1 = character.Root
	weld.Parent = character.Root
	character.CarryWeld = weld
end

-- Callers finish authorization and any cash/pad transaction before this no-yield step.
function Carry.Begin(record: State.PlayerState, character: State.CharacterState, avatarRoot: BasePart, stolen: boolean)
	State.ClearPrompt(character)
	character.Status = "Carried"
	character.CarrierUserId = record.Player.UserId
	character.PadIndex = nil
	character.StolenFromUserId = if stolen then character.OwnerUserId else nil
	if not stolen then
		character.OwnerUserId = record.Player.UserId
	end
	record.CarriedCharacter = character.Model
	Factory.SetForSale(character.Model, false)
	character.IncomePerSecond = character.IntrinsicIncome * record.IncomeMultiplier
	Factory.SetIncome(character.Model, character.IncomePerSecond)
	State.PublishCharacter(character)
	attach(character, avatarRoot)
	updateSpeed(record, stolen)
end

function Carry.WashAway(record: State.PlayerState): boolean
	local model = record.CarriedCharacter
	local character = if model then State.Characters[model] else nil
	if not character or character.Status ~= "Carried" or character.CarrierUserId ~= record.Player.UserId then
		return false
	end
	detach(character)
	record.CarriedCharacter = nil
	Carry.RestoreSpeed(record)
	State.DestroyCharacter(character)
	State.Notify(record, "WASHED AWAY! Your carried character was lost. Shelter inside any base.")
	return true
end

local function buy(player: Player, character: State.CharacterState)
	local record = State.Players[player.UserId]
	if not record then
		return
	end
	local avatarRoot = Carry.LivingRoot(player)
	if not avatarRoot then
		State.Notify(record, "Wait for your character to respawn.")
		return
	end
	if State.Characters[character.Model] ~= character or character.Status ~= "Belt" then
		State.Notify(record, "Someone already grabbed that character.")
		return
	end
	-- Triggered is still validated on the server; no client-supplied prices or targets.
	if (avatarRoot.Position - character.Root.Position).Magnitude > Config.Carry.PromptDistance + 2 then
		State.Notify(record, "Move closer to buy that character.")
		return
	end
	local purchased, reason = Economy.TryPurchase(record, character)
	if not purchased then
		State.Notify(record, reason)
		return
	end
	-- Nothing in this transaction yields, including the Economy call above.
	Carry.Begin(record, character, avatarRoot, false)
	State.Notify(record, "Bought " .. character.Model.Name .. "! Walk onto an empty pad in your base.")
end

function Carry.Bind(character: State.CharacterState)
	assert(character.Status == "Belt" and not character.Prompt, "Only bind a fresh belt character")
	local anchor = Instance.new("Attachment")
	anchor.Name = "PurchaseAnchor"
	anchor.Position = Vector3.new(0, 1.8, 0)
	anchor.Parent = character.Root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyCharacter"
	prompt.ObjectText = character.Model.Name
	prompt.ActionText = string.format("Buy $%d", character.BuyPrice)
	prompt.HoldDuration = Config.Carry.PromptHoldDuration
	prompt.MaxActivationDistance = Config.Carry.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = anchor
	character.Prompt = prompt
	character.PromptConnection = prompt.Triggered:Connect(function(player: Player)
		buy(player, character)
	end)
end

local function nearestEmptyPad(record: State.PlayerState, position: Vector3): number?
	local plot = Economy.GetPlot(record)
	if not plot then
		return nil
	end
	local nearest: number? = nil
	local bestDistance = math.huge
	for index = 1, math.min(record.PadAllowance, #plot.Pads) do
		if record.Pads[index] then
			continue
		end
		local pad = plot.Pads[index]
		local localPosition = pad.CFrame:PointToObjectSpace(position)
		if math.abs(localPosition.X) <= pad.Size.X / 2 + Config.Carry.PadEdgeTolerance
			and math.abs(localPosition.Z) <= pad.Size.Z / 2 + Config.Carry.PadEdgeTolerance
			and localPosition.Y >= -0.5 and localPosition.Y <= Config.Carry.PadVerticalReach then
			local distance = localPosition.X ^ 2 + localPosition.Z ^ 2
			if distance < bestDistance then
				bestDistance = distance
				nearest = index
			end
		end
	end
	return nearest
end

function Carry.Scan()
	for _, record in State.Players do
		local model = record.CarriedCharacter
		if not model then
			Carry.RestoreSpeed(record)
			continue
		end
		local character = State.Characters[model]
		if not character or character.Status ~= "Carried" or character.CarrierUserId ~= record.Player.UserId then
			record.CarriedCharacter = nil
			Carry.RestoreSpeed(record)
			State.Publish(record)
			continue
		end
		local avatarRoot = Carry.LivingRoot(record.Player)
		if not avatarRoot then
			-- Keep an undelivered purchase across resets; reattach after respawning.
			detach(character)
			Carry.RestoreSpeed(record)
			continue
		end
		attach(character, avatarRoot)
		updateSpeed(record, character.StolenFromUserId ~= nil)
		local index = nearestEmptyPad(record, avatarRoot.Position)
		local plot = Economy.GetPlot(record)
		if index and plot and Economy.TryPlace(record, character, index) then
			detach(character)
			-- Slot transforms are horizontal and sit exactly on the pad's top surface.
			model:PivotTo(plot.PadSlots[index].WorldCFrame)
			Carry.RestoreSpeed(record)
			if placedHandler then
				placedHandler(character)
			end
		end
	end
end

function Carry.Start(onPlaced: (State.CharacterState) -> ())
	assert(not started, "Carry already started")
	started = true
	placedHandler = onPlaced
	RunService.Heartbeat:Connect(function(dt: number)
		State.CarryScanElapsed += dt
		if State.CarryScanElapsed >= Config.Carry.PadScanInterval then
			State.CarryScanElapsed %= Config.Carry.PadScanInterval
			Carry.Scan()
		end
	end)
end

return Carry
