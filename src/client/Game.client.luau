--!strict
local Players = game:GetService("Players")
local HUDView = require(script.Parent:WaitForChild("HUDView"))
local HUD = require(script.Parent:WaitForChild("HUDController"))
local Prompts = require(script.Parent:WaitForChild("PromptController"))
local Nameplates = require(script.Parent:WaitForChild("NameplateController"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local view = HUDView.Create(playerGui)
Prompts.Start(view)
Nameplates.Start(view, Prompts.GetFocus)
HUD.Start(view)
