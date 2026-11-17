--!strict
-- Optional Studio review camera. Never starts in a published server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HUDView = require(script.Parent.HUDView)
local CaptureView = {}

function CaptureView.Start(view: HUDView.View)
	if not RunService:IsStudio() then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("GameSignals"):WaitForChild("TourView") :: RemoteEvent
	local generation = 0
	local savedFov: number? = nil
	local function release()
		generation += 1
		local camera = workspace.CurrentCamera
		if savedFov and camera then
			camera.FieldOfView = savedFov
			camera.CameraType = Enum.CameraType.Custom
			local avatar = Players.LocalPlayer.Character
			if avatar then
				camera.CameraSubject = avatar:FindFirstChildOfClass("Humanoid")
			end
		end
		savedFov = nil
	end
	remote.OnClientEvent:Connect(function(frame: CFrame, target: Vector3)
		local camera = workspace.CurrentCamera
		if not camera or typeof(frame) ~= "CFrame" or typeof(target) ~= "Vector3" then
			return
		end
		generation += 1
		local version = generation
		savedFov = savedFov or camera.FieldOfView
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 65
		camera.CFrame = frame
		camera.Focus = CFrame.new(target)
		view.Splash.Visible = false
		view.Notice.Visible = false
		task.delay(15, function()
			if generation == version then
				release()
			end
		end)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.V and savedFov then
			release()
		end
	end)
end

return CaptureView
