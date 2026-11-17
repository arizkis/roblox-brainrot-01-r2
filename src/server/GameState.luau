--!strict
-- The only mutable gameplay state home. Services will use these maps next turn.
local WorldBuilder = require(script.Parent.WorldBuilder)

export type PlayerState = {
	Player: Player,
	BaseId: number?,
	Cash: number,
	Rebirths: number,
}

export type CharacterState = {
	Model: Model,
	CharacterId: string,
	Mutation: string,
	OwnerUserId: number?,
	CarrierUserId: number?,
	PadIndex: number?,
}

local State = {
	World = nil :: WorldBuilder.World?,
	Players = {} :: {[number]: PlayerState},
	Characters = {} :: {[Model]: CharacterState},
	BaseOwners = {} :: {[number]: number},
}

return State
