--!strict
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local State = require(script:WaitForChild("GameState"))

State.World = WorldBuilder.Build(workspace)
print("BRAINROT BAZAAR foundation ready: six unclaimed bases and a static conveyor.")
