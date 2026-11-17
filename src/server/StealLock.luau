--!strict
-- Rival theft authorization and the owner's timed base protection.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local State = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local Carry = require(script.Parent.Carry)

local StealLock = {}
local started = false

function StealLock.IsLocked(ownerUserId: number?): boolean
	local owner = if ownerUserId then State.Players[ownerUserId] else nil
	return owner ~= nil and owner.LockExpiresAt > workspace:GetServerTimeNow()
end

function StealLock.TrySteal(player: Player, character: State.CharacterState): boolean
	local thief = State.Players[player.UserId]
	if not thief then
		return false
	end
	local function refuse(message: string): boolean
		State.Notify(thief, message)
		return false
	end
	if State.Characters[character.Model] ~= character or character.Status ~= "Placed" then
		return refuse("That character is no longer on a pad.")
	end
	if character.OwnerUserId == player.UserId then
		return refuse("That is your own character!")
	end
	local victim = if character.OwnerUserId then State.Players[character.OwnerUserId] else nil
	if not victim or not Economy.GetPlot(victim) then
		return refuse("That base is no longer occupied.")
	end
	if StealLock.IsLocked(character.OwnerUserId) then
		return refuse("BASE LOCKED! Wait for the shield to drop.")
	end
	if not Economy.GetPlot(thief) then
		return refuse("You need your own base before stealing.")
	end
	if thief.CarriedCharacter then
		return refuse("Already carrying! Deliver your character first.")
	end
	if not Economy.FreePad(thief) then
		return refuse("Base full! You need an empty pad to steal.")
	end
	local root = Carry.LivingRoot(player)
	if not root or (root.Position - character.Root.Position).Magnitude > Config.Carry.PromptDistance + 2 then
		return refuse("Move closer to steal that character.")
	end
	-- Validation, unplacing and attachment run without yielding or accepting client state.
	if not Economy.Unplace(character) then
		return refuse("That character has already been moved.")
	end
	Carry.Begin(thief, character, root, true)
	State.Notify(victim, player.DisplayName .. " stole " .. character.Model.Name .. " from a pad!")
	State.Notify(thief, "STOLEN! Deliver to your base. Walk speed is reduced by 25%.")
	return true
end

function StealLock.Bind(character: State.CharacterState)
	assert(character.Status == "Placed", "Only placed characters can be stolen")
	State.ClearPrompt(character)
	local anchor = Instance.new("Attachment")
	anchor.Name = "StealAnchor"
	anchor.Position = Vector3.new(0, 1.8, 0)
	anchor.Parent = character.Root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealCharacter"
	prompt.ActionText = "Steal • carry to your base"
	prompt.ObjectText = character.Model.Name .. " • " .. Config.Characters[character.CharacterId].Tier
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	prompt:SetAttribute("Kind", "Steal")
	prompt:SetAttribute("OwnerUserId", character.OwnerUserId)
	prompt:SetAttribute("Available", not StealLock.IsLocked(character.OwnerUserId))
	prompt.MaxActivationDistance = Config.Carry.PromptDistance
	prompt.HoldDuration = Config.StealLock.StealHoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not StealLock.IsLocked(character.OwnerUserId)
	prompt.Parent = anchor
	character.Prompt = prompt
	character.PromptConnection = prompt.Triggered:Connect(function(player: Player)
		StealLock.TrySteal(player, character)
	end)
end

function StealLock.Refresh()
	local world = State.World
	assert(world, "World is required for locks")
	local now = workspace:GetServerTimeNow()
	for id, plot in world.Bases do
		local ownerId = State.BaseOwners[id]
		local owner = if ownerId then State.Players[ownerId] else nil
		local locked = owner ~= nil and now < owner.LockExpiresAt
		local cooldown = owner ~= nil and now < owner.LockReadyAt and not locked
		local text = "UNCLAIMED"
		if owner then
			if locked then
				text = string.format("LOCKED • %ds", math.ceil(owner.LockExpiresAt - now))
			elseif cooldown then
				text = string.format("LOCK COOLDOWN • %ds", math.ceil(owner.LockReadyAt - now))
			else
				text = "LOCK READY • 60s SHIELD"
			end
			State.Publish(owner)
		end
		plot.LockLabel.Text = text
		plot.Shield.Transparency = if locked then 0.78 else 1
		plot.LockButton.Color = if locked then Color3.fromRGB(255, 80, 110)
			elseif cooldown then Color3.fromRGB(255, 174, 54) else Color3.fromRGB(126, 244, 79)
		plot.Model:SetAttribute("Locked", locked)
		if plot.LockPrompt then
			local available = owner ~= nil and not locked and not cooldown
			plot.LockPrompt:SetAttribute("Available", available)
			plot.LockPrompt.Enabled = available
		end
	end
	for _, character in State.Characters do
		if character.Status == "Placed" and character.Prompt then
			local available = not StealLock.IsLocked(character.OwnerUserId)
			character.Prompt:SetAttribute("Available", available)
			character.Prompt.Enabled = available
		end
	end
end

function StealLock.TryLock(player: Player): boolean
	local record = State.Players[player.UserId]
	if not record then
		return false
	end
	if not Economy.GetPlot(record) then
		State.Notify(record, "You need a base to lock.")
		return false
	end
	local now = workspace:GetServerTimeNow()
	if now < record.LockReadyAt then
		State.Notify(record, string.format("Lock ready in %ds.", math.ceil(record.LockReadyAt - now)))
		return false
	end
	record.LockExpiresAt = now + Config.StealLock.LockDuration
	-- Cooldown begins AFTER protection expires: 60 locked + 90 cooling down.
	record.LockReadyAt = record.LockExpiresAt + Config.StealLock.CooldownDuration
	StealLock.Refresh()
	State.Notify(record, "BASE LOCKED for 60 seconds! Then a 90-second cooldown.")
	return true
end

function StealLock.Start()
	assert(not started, "StealLock already started")
	started = true
	local world = State.World
	local signals = State.Signals
	assert(world and signals, "World and signals must exist first")
	for _, plot in world.Bases do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LockBase"
		prompt.ActionText = "Lock base • 60s shield"
		prompt.ObjectText = string.format("Base %02d lock pedestal", plot.Id)
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
		prompt:SetAttribute("Kind", "Lock")
		prompt:SetAttribute("BaseId", plot.Id)
		prompt:SetAttribute("Available", false)
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = plot.LockButton
		plot.LockPrompt = prompt
		prompt.Triggered:Connect(function(player: Player)
			local record = State.Players[player.UserId]
			local root = Carry.LivingRoot(player)
			if record and State.BaseOwners[plot.Id] ~= player.UserId then
				State.Notify(record, "Only this base's owner can press its lock.")
			elseif record and root and (root.Position - plot.LockButton.Position).Magnitude <= 12 then
				StealLock.TryLock(player)
			end
		end)
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "RequestLock"
	request.Parent = signals
	-- HUD ability: always targets the sender's own base; no client-supplied plot id.
	request.OnServerEvent:Connect(function(player: Player)
		StealLock.TryLock(player)
	end)
	StealLock.Refresh()
	RunService.Heartbeat:Connect(function(dt: number)
		State.LockUpdateElapsed += dt
		if State.LockUpdateElapsed >= Config.StealLock.UpdateInterval then
			State.LockUpdateElapsed %= Config.StealLock.UpdateInterval
			StealLock.Refresh()
		end
	end)
end

return StealLock
