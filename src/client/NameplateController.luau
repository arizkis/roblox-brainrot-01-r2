--!strict
-- Keep billboard text at a legible screen size, then cull overlapping callouts.
-- Labels are either shown at full size or hidden; they never shrink into tiny text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local HUDView = require(script.Parent.HUDView)
local Nameplates = {}

type Rect = {X: number, Y: number, Width: number, Height: number}
type Candidate = {Gui: BillboardGui, Rect: Rect, Score: number, Pinned: boolean}

local function overlaps(a: Rect, b: Rect): boolean
	return a.X < b.X + b.Width and a.X + a.Width > b.X
		and a.Y < b.Y + b.Height and a.Y + a.Height > b.Y
end

function Nameplates.Start(view: HUDView.View, getFocus: () -> Model?)
	local tracked: {[BillboardGui]: boolean} = {}
	local player = Players.LocalPlayer
	local function watch(instance: Instance)
		if instance:IsA("BillboardGui") and (instance.Name == "Nameplate" or instance.Name == "ButtonLabel") then
			tracked[instance] = true
		end
	end
	workspace.DescendantAdded:Connect(watch)
	workspace.DescendantRemoving:Connect(function(instance: Instance)
		if instance:IsA("BillboardGui") then
			tracked[instance] = nil
		end
	end)
	for _, instance in workspace:GetDescendants() do
		watch(instance)
	end
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed %= 0.1
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		-- Width is the screenshot target; labels do not need a full-height canvas.
		-- Keep the font size after a downscale to 768px, including wide viewports.
		local scale = math.max(0.75, view.Host.AbsoluteSize.X / Presentation.Width)
		local focus = getFocus()
		local candidates: {Candidate} = {}
		for gui in tracked do
			local panel = gui:FindFirstChild("Panel")
			local designWidth = gui:GetAttribute("DesignWidth")
			local designHeight = gui:GetAttribute("DesignHeight")
			if not panel or not panel:IsA("Frame") or typeof(designWidth) ~= "number" or typeof(designHeight) ~= "number" then
				continue
			end
			local scaler = panel:FindFirstChild("ReadabilityScale") :: UIScale?
			if not scaler then
				scaler = Instance.new("UIScale")
				scaler.Name = "ReadabilityScale"
				scaler.Parent = panel
			end
			scaler.Scale = scale
			gui.Size = UDim2.fromOffset(designWidth * scale, designHeight * scale)
			local adorn = gui.Adornee or gui.Parent
			local position: Vector3? = nil
			if adorn and adorn:IsA("Attachment") then
				position = adorn.WorldPosition
			elseif adorn and adorn:IsA("BasePart") then
				position = adorn.Position
			end
			gui.Enabled = false
			if not position then
				continue
			end
			local point, onScreen = camera:WorldToViewportPoint(position + gui.StudsOffsetWorldSpace)
			local distance = (camera.CFrame.Position - position).Magnitude
			if not onScreen or point.Z <= 0 or distance > gui.MaxDistance then
				continue
			end
			local model = gui:FindFirstAncestorOfClass("Model")
			local pinned = gui.Name == "Nameplate" and model ~= nil
				and (model == focus or model:GetAttribute("CarrierUserId") == player.UserId)
			local width = designWidth * scale
			local height = designHeight * scale
			local rect: Rect = {X = point.X - width / 2 - 4, Y = point.Y - height / 2 - 4, Width = width + 8, Height = height + 8}
			local priority = if pinned then 0 elseif gui.Name == "ButtonLabel" and distance < 18 then 1 else 2
			table.insert(candidates, {Gui = gui, Rect = rect, Score = priority * 10000 + distance, Pinned = pinned})
		end
		table.sort(candidates, function(a: Candidate, b: Candidate)
			return a.Score < b.Score
		end)
		local occupied: {Rect} = {}
		for _, object in {view.Stats, view.Banner, view.Notice, view.Splash, view.PromptCard, view.LockButton, view.RebirthButton} do
			if object.Visible then
				table.insert(occupied, {X = object.AbsolutePosition.X, Y = object.AbsolutePosition.Y, Width = object.AbsoluteSize.X, Height = object.AbsoluteSize.Y})
			end
		end
		local shown = 0
		for _, candidate in candidates do
			local blocked = false
			for _, rect in occupied do
				if overlaps(candidate.Rect, rect) then
					blocked = true
					break
				end
			end
			if candidate.Pinned or (not blocked and shown < 4) then
				candidate.Gui.Enabled = true
				table.insert(occupied, candidate.Rect)
				shown += 1
			end
		end
	end)
end

return Nameplates
