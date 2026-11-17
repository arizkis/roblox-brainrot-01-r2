--!strict
-- The only mutable gameplay state home. Client attributes are output, never authority.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local WorldBuilder = require(script.Parent.WorldBuilder)

export type PlayerState = {
	Player: Player,
	BaseId: number?,
	Cash: number,
	Rebirths: number,
	RebirthCost: number,
	IncomeMultiplier: number,
	IncomePerSecond: number,
	PadAllowance: number,
	PadsUsed: number,
	Pads: {[number]: Model},
	CarriedCharacter: Model?,
	ActionMessage: string,
	ActionSequence: number,
	Revision: number,
	LockExpiresAt: number,
	LockReadyAt: number,
	SlowedHumanoid: Humanoid?,
	NormalWalkSpeed: number?,
}

export type CharacterState = {
	Model: Model,
	CharacterId: string,
	Mutation: string,
	Root: BasePart,
	Status: "Belt" | "Carried" | "Placed",
	BuyPrice: number,
	IntrinsicIncome: number,
	IncomePerSecond: number,
	BeltProgress: number,
	OwnerUserId: number?,
	CarrierUserId: number?,
	PadIndex: number?,
	Prompt: ProximityPrompt?,
	PromptConnection: RBXScriptConnection?,
	CarryWeld: WeldConstraint?,
	StolenFromUserId: number?,
}

local State = {
	World = nil :: WorldBuilder.World?,
	Signals = nil :: Folder?,
	Players = {} :: {[number]: PlayerState},
	Characters = {} :: {[Model]: CharacterState},
	BaseOwners = {} :: {[number]: number},
	WaitingForBase = {} :: {number},
	ConveyorElapsed = 0,
	IncomeElapsed = 0,
	CarryScanElapsed = 0,
	LockUpdateElapsed = 0,
	RebirthUpdateElapsed = 0,
	Tsunami = {
		Phase = "Calm", NextWaveAt = 0, LastWaveZ = 0,
		PlayerPositions = {} :: {[number]: Vector3},
	},
}

function State.Publish(record: PlayerState)
	local player = record.Player
	player:SetAttribute("Cash", record.Cash)
	player:SetAttribute("IncomePerSecond", record.IncomePerSecond)
	player:SetAttribute("Rebirths", record.Rebirths)
	player:SetAttribute("RebirthCost", record.RebirthCost)
	player:SetAttribute("CanRebirth", record.BaseId ~= nil and record.RebirthCost > 0 and record.Cash >= record.RebirthCost)
	player:SetAttribute("IncomeMultiplier", record.IncomeMultiplier)
	player:SetAttribute("PadAllowance", record.PadAllowance)
	player:SetAttribute("PadsUsed", record.PadsUsed)
	player:SetAttribute("BaseId", record.BaseId or 0)
	player:SetAttribute("Carrying", record.CarriedCharacter ~= nil)
	local carried = if record.CarriedCharacter then State.Characters[record.CarriedCharacter] else nil
	player:SetAttribute("CarryingCharacterId", if carried then carried.CharacterId else "")
	player:SetAttribute("CarryingStolen", carried ~= nil and carried.StolenFromUserId ~= nil)
	local now = workspace:GetServerTimeNow()
	local locked = math.max(0, math.ceil(record.LockExpiresAt - now))
	local readyIn = math.max(0, math.ceil(record.LockReadyAt - now))
	local lockState = if not record.BaseId then "NoBase" elseif locked > 0 then "Locked" elseif readyIn > 0 then "Cooldown" else "Ready"
	player:SetAttribute("LockState", lockState)
	player:SetAttribute("LockRemaining", locked)
	player:SetAttribute("LockCooldownRemaining", math.max(0, math.ceil(record.LockReadyAt - math.max(now, record.LockExpiresAt))))
	player:SetAttribute("LockReadyIn", readyIn)
	player:SetAttribute("LockExpiresAt", record.LockExpiresAt)
	player:SetAttribute("LockReadyAt", record.LockReadyAt)
	player:SetAttribute("ActionMessage", record.ActionMessage)
	player:SetAttribute("ActionSequence", record.ActionSequence)
	-- Written last: a HUD can use this change as a complete snapshot notification.
	record.Revision += 1
	player:SetAttribute("StateRevision", record.Revision)
end

function State.Notify(record: PlayerState, message: string)
	record.ActionMessage = message
	record.ActionSequence += 1
	State.Publish(record)
end

function State.AddPlayer(player: Player): PlayerState
	assert(not State.Players[player.UserId], "Player already has a session")
	local record: PlayerState = {
		Player = player, BaseId = nil,
		Cash = Config.Economy.StartingCash, Rebirths = Config.Economy.StartingRebirths,
		RebirthCost = 0, LockExpiresAt = 0, LockReadyAt = 0,
		IncomeMultiplier = Config.Economy.StartingMultiplier, IncomePerSecond = 0,
		PadAllowance = Config.World.StartingPads, PadsUsed = 0, Pads = {},
		CarriedCharacter = nil, ActionMessage = "", ActionSequence = 0, Revision = 0,
		SlowedHumanoid = nil, NormalWalkSpeed = nil,
	}
	State.Players[player.UserId] = record
	State.Publish(record)
	return record
end

function State.PublishCharacter(record: CharacterState)
	local model = record.Model
	model:SetAttribute("Status", record.Status)
	model:SetAttribute("OwnerUserId", record.OwnerUserId or 0)
	model:SetAttribute("CarrierUserId", record.CarrierUserId or 0)
	model:SetAttribute("PadIndex", record.PadIndex or 0)
	model:SetAttribute("Stolen", record.StolenFromUserId ~= nil)
end

function State.ClearPrompt(record: CharacterState)
	if record.PromptConnection then
		record.PromptConnection:Disconnect()
		record.PromptConnection = nil
	end
	if record.Prompt then
		local anchor = record.Prompt.Parent
		record.Prompt:Destroy()
		record.Prompt = nil
		if anchor and anchor:IsA("Attachment") then
			anchor:Destroy()
		end
	end
end

-- Callers remove owned pad references before destroying owned characters.
-- Conveyor expiry uses this directly only for unowned belt characters.
function State.DestroyCharacter(record: CharacterState)
	State.Characters[record.Model] = nil
	State.ClearPrompt(record)
	if record.CarryWeld then
		record.CarryWeld:Destroy()
		record.CarryWeld = nil
	end
	record.Model:Destroy()
end

return State
