--!strict
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local State = require(script:WaitForChild("GameState"))
local Sessions = require(script:WaitForChild("PlayerSessions"))
local Economy = require(script:WaitForChild("Economy"))
local Carry = require(script:WaitForChild("Carry"))
local Conveyor = require(script:WaitForChild("Conveyor"))

State.World = WorldBuilder.Build(workspace)
Sessions.Start()
Economy.Start()
Carry.Start()
Conveyor.Start(Carry.Bind)
print("BRAINROT BAZAAR core loop ready: buy, carry, place, earn.")
