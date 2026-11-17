--!strict
local Players = game:GetService("Players")
local HUDView = require(script.Parent:WaitForChild("HUDView"))
local HUD = require(script.Parent:WaitForChild("HUDController"))
local Prompts = require(script.Parent:WaitForChild("PromptController"))
local Nameplates = require(script.Parent:WaitForChild("NameplateController"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local view = HUDView.Create(playerGui)
if game:GetService("RunService"):IsStudio() then
	local CaptureView = require(script.Parent:WaitForChild("CaptureViewController"))
	CaptureView.Start(view)
end
Prompts.Start(view)
Nameplates.Start(view, Prompts.GetFocus)
HUD.Start(view)
