--!strict
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local State = require(script:WaitForChild("GameState"))
local Sessions = require(script:WaitForChild("PlayerSessions"))
local Economy = require(script:WaitForChild("Economy"))
local Carry = require(script:WaitForChild("Carry"))
local Conveyor = require(script:WaitForChild("Conveyor"))
local StealLock = require(script:WaitForChild("StealLock"))
local Rebirth = require(script:WaitForChild("Rebirth"))
local Tsunami = require(script:WaitForChild("Tsunami"))

State.World = WorldBuilder.Build(workspace)
local signals = Instance.new("Folder")
signals.Name = "GameSignals"
signals.Parent = game:GetService("ReplicatedStorage")
State.Signals = signals
Sessions.Start()
Economy.Start()
StealLock.Start()
Rebirth.Start()
Carry.Start(StealLock.Bind)
Conveyor.Start(Carry.Bind)
Tsunami.Start()
print("BRAINROT BAZAAR ready: collect, steal, shelter, lock and rebirth.")
