--!strict
-- Rebirth validation and permanent progression; Economy owns the cash debit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local State = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local Carry = require(script.Parent.Carry)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Rebirth = {}
local started = false

function Rebirth.TryRebirth(player: Player): boolean
	local record = State.Players[player.UserId]
	if not record then
		return false
	end
	local plot = Economy.GetPlot(record)
	if not plot then
		State.Notify(record, "You need your own base to rebirth.")
		return false
	end
	Economy.Refresh(record)
	local cost = record.RebirthCost
	if cost <= 0 then
		State.Notify(record, "Rebirth unavailable: place a character to earn income first.")
		return false
	end
	if not Economy.Spend(record, cost) then
		State.Notify(record, string.format("Rebirth needs $%.2f (15 times your current income).", cost))
		return false
	end
	-- Placed characters and their pad positions are retained. This operation never yields.
	record.Rebirths += 1
	record.IncomeMultiplier *= Config.Rebirth.IncomeFactor
	record.PadAllowance = math.min(Config.World.MaxPads, record.PadAllowance + Config.Rebirth.PadIncrement)
	WorldBuilder.SetPadAllowance(plot, record.PadAllowance)
	Economy.Refresh(record)
	State.Notify(record, string.format("REBIRTH %d! Income x%.3g • %d pads. Characters kept!", record.Rebirths, record.IncomeMultiplier, record.PadAllowance))
	return true
end

function Rebirth.Refresh()
	local world = State.World
	assert(world, "World is required for rebirths")
	for id, plot in world.Bases do
		local ownerId = State.BaseOwners[id]
		local owner = if ownerId then State.Players[ownerId] else nil
		if plot.RebirthPrompt then
			plot.RebirthPrompt.Enabled = owner ~= nil and owner.RebirthCost > 0
			plot.RebirthPrompt.ActionText = if owner then string.format("Rebirth $%.2f", owner.RebirthCost) else "Rebirth"
		end
	end
end

function Rebirth.Start()
	assert(not started, "Rebirth already started")
	started = true
	local world = State.World
	local signals = State.Signals
	assert(world and signals, "World and signals must exist first")
	for _, plot in world.Bases do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Rebirth"
		prompt.ObjectText = "Keep characters • x1.5 income • +1 pad"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = plot.RebirthButton
		plot.RebirthPrompt = prompt
		prompt.Triggered:Connect(function(player: Player)
			local record = State.Players[player.UserId]
			local root = Carry.LivingRoot(player)
			if record and State.BaseOwners[plot.Id] ~= player.UserId then
				State.Notify(record, "Use the rebirth pedestal at your own base.")
			elseif record and root and (root.Position - plot.RebirthButton.Position).Magnitude <= 12 then
				Rebirth.TryRebirth(player)
			end
		end)
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "RequestRebirth"
	request.Parent = signals
	request.OnServerEvent:Connect(function(player: Player)
		Rebirth.TryRebirth(player)
	end)
	Rebirth.Refresh()
	RunService.Heartbeat:Connect(function(dt: number)
		State.RebirthUpdateElapsed += dt
		if State.RebirthUpdateElapsed >= 1 then
			State.RebirthUpdateElapsed %= 1
			Rebirth.Refresh()
		end
	end)
end

return Rebirth
