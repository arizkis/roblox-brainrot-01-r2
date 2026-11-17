--!strict
-- Owns all cash changes, pad occupancy and placed income. No carrying physics here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local State = require(script.Parent.GameState)
local Factory = require(script.Parent.CharacterFactory)

local Economy = {}
local started = false

function Economy.GetPlot(record: State.PlayerState)
	local world = State.World
	local baseId = record.BaseId
	if not world or not baseId or State.BaseOwners[baseId] ~= record.Player.UserId then
		return nil
	end
	return world.Bases[baseId]
end

function Economy.FreePad(record: State.PlayerState): number?
	local plot = Economy.GetPlot(record)
	if plot then
		for index = 1, math.min(record.PadAllowance, #plot.Pads) do
			if not record.Pads[index] then
				return index
			end
		end
	end
	return nil
end

function Economy.Refresh(record: State.PlayerState)
	local total = 0
	local used = 0
	for _, model in record.Pads do
		local character = State.Characters[model]
		if character and character.Status == "Placed" and character.OwnerUserId == record.Player.UserId then
			local income = character.IntrinsicIncome * record.IncomeMultiplier
			if character.IncomePerSecond ~= income then
				character.IncomePerSecond = income
				Factory.SetIncome(model, income)
			end
			total += income
			used += 1
		end
	end
	record.IncomePerSecond = total
	record.PadsUsed = used
end

-- This is a synchronous transaction: validate everything before charging anything.
function Economy.TryPurchase(record: State.PlayerState, character: State.CharacterState): (boolean, string)
	if State.Characters[character.Model] ~= character or character.Status ~= "Belt" then
		return false, "That character has already left the belt."
	end
	if not Economy.GetPlot(record) then
		return false, "Waiting for a free base."
	end
	if record.CarriedCharacter then
		return false, "Already carrying! Place your character on a pad first."
	end
	if not Economy.FreePad(record) then
		return false, "Base full! You need an empty pad."
	end
	if record.Cash < character.BuyPrice then
		return false, string.format("Not enough cash! You need $%d.", character.BuyPrice)
	end
	record.Cash -= character.BuyPrice
	return true, ""
end

function Economy.TryPlace(record: State.PlayerState, character: State.CharacterState, index: number): boolean
	local plot = Economy.GetPlot(record)
	if State.Characters[character.Model] ~= character
		or not plot or not plot.Pads[index] or index < 1 or index > record.PadAllowance
		or record.Pads[index] or record.CarriedCharacter ~= character.Model
		or character.Status ~= "Carried" or character.OwnerUserId ~= record.Player.UserId
		or character.CarrierUserId ~= record.Player.UserId then
		return false
	end
	record.Pads[index] = character.Model
	record.CarriedCharacter = nil
	character.Status = "Placed"
	character.PadIndex = index
	character.CarrierUserId = nil
	character.IncomePerSecond = character.IntrinsicIncome * record.IncomeMultiplier
	Factory.SetIncome(character.Model, character.IncomePerSecond)
	plot.Pads[index]:SetAttribute("Occupied", true)
	plot.Pads[index]:SetAttribute("CharacterId", character.CharacterId)
	State.PublishCharacter(character)
	Economy.Refresh(record)
	State.Notify(record, string.format("Placed %s on pad %02d!", character.Model.Name, index))
	return true
end

function Economy.RemovePlayer(record: State.PlayerState)
	local plot = Economy.GetPlot(record)
	if plot then
		for _, pad in plot.Pads do
			pad:SetAttribute("Occupied", false)
			pad:SetAttribute("CharacterId", nil)
		end
	end
	table.clear(record.Pads)
	record.CarriedCharacter = nil
	for _, character in State.Characters do
		if character.OwnerUserId == record.Player.UserId then
			State.DestroyCharacter(character)
		end
	end
	record.IncomePerSecond = 0
	record.PadsUsed = 0
end

function Economy.Pay(ticks: number)
	for _, record in State.Players do
		Economy.Refresh(record)
		record.Cash += record.IncomePerSecond * ticks
		State.Publish(record)
	end
end

function Economy.Start()
	assert(not started, "Economy already started")
	started = true
	RunService.Heartbeat:Connect(function(dt: number)
		State.IncomeElapsed += dt
		local ticks = math.floor(State.IncomeElapsed / Config.Economy.TickInterval)
		if ticks > 0 then
			State.IncomeElapsed -= ticks * Config.Economy.TickInterval
			Economy.Pay(ticks)
		end
	end)
end

return Economy
