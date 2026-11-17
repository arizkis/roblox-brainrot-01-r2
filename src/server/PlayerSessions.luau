--!strict
-- Player lifecycle and base claims. Economy removes owned assets on departure.
local Players = game:GetService("Players")
local State = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local Carry = require(script.Parent.Carry)

local Sessions = {}
local started = false

local function assignWaitingPlayers()
	local world = State.World
	assert(world, "Build the world before assigning bases")
	for id, plot in world.Bases do
		if State.BaseOwners[id] then
			continue
		end
		while #State.WaitingForBase > 0 do
			local userId = table.remove(State.WaitingForBase, 1)
			local record = State.Players[userId]
			if record and record.Player.Parent == Players and not record.BaseId then
				State.BaseOwners[id] = userId
				record.BaseId = id
				plot.Model:SetAttribute("OwnerUserId", userId)
				plot.OwnerLabel.Text = string.format("BASE %02d • %s", id, record.Player.DisplayName)
				State.Notify(record, string.format("Base %02d is yours! Buy a character and walk onto an empty pad.", id))
				break
			end
		end
	end
end

local function joined(player: Player)
	if State.Players[player.UserId] then
		return
	end
	local record = State.AddPlayer(player)
	table.insert(State.WaitingForBase, player.UserId)
	assignWaitingPlayers()
	if not record.BaseId then
		State.Notify(record, "All six bases are occupied. Waiting for a free base.")
	end
end

local function left(player: Player)
	local record = State.Players[player.UserId]
	if not record then
		return
	end
	Carry.RestoreSpeed(record)
	Economy.RemovePlayer(record)
	local baseId = record.BaseId
	local world = State.World
	if baseId and world and State.BaseOwners[baseId] == player.UserId then
		State.BaseOwners[baseId] = nil
		local plot = world.Bases[baseId]
		plot.Model:SetAttribute("OwnerUserId", 0)
		plot.OwnerLabel.Text = string.format("BASE %02d • UNCLAIMED", baseId)
	end
	State.Players[player.UserId] = nil
	State.Tsunami.PlayerPositions[player.UserId] = nil
	for index = #State.WaitingForBase, 1, -1 do
		if State.WaitingForBase[index] == player.UserId then
			table.remove(State.WaitingForBase, index)
		end
	end
	assignWaitingPlayers()
end

function Sessions.Start()
	assert(not started, "Player sessions already started")
	started = true
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(left)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return Sessions
