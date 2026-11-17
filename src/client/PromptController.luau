--!strict
-- Presentation/input adapter for Roblox prompts; Triggered still reaches the server.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local HUDView = require(script.Parent.HUDView)
local PromptController = {}
local focused: ProximityPrompt? = nil

function PromptController.GetFocus(): Model?
	return if focused then focused:FindFirstAncestorOfClass("Model") else nil
end

function PromptController.Start(view: HUDView.View)
	local player = Players.LocalPlayer
	local watched: {[ProximityPrompt]: {RBXScriptConnection}} = {}
	local inputType = Enum.ProximityPromptInputType.Keyboard
	local holdStarted: number? = nil
	local pointerPrompt: ProximityPrompt? = nil
	local pointerInput: InputObject? = nil
	ProximityPromptService.MaxPromptsVisible = 1

	local function releasePointer()
		local prompt = pointerPrompt
		pointerPrompt = nil
		pointerInput = nil
		if prompt and prompt.Parent then
			prompt:InputHoldEnd()
		end
	end

	local function allowed(prompt: ProximityPrompt): boolean
		if prompt:GetAttribute("Available") ~= true then
			return false
		end
		local kind = prompt:GetAttribute("Kind")
		local carrying = player:GetAttribute("Carrying") == true
		local baseId = player:GetAttribute("BaseId")
		if kind == "Buy" then
			return not carrying
		elseif kind == "Steal" then
			return not carrying and prompt:GetAttribute("OwnerUserId") ~= player.UserId
				and typeof(baseId) == "number" and baseId > 0
		elseif kind == "Lock" or kind == "Rebirth" then
			return typeof(baseId) == "number" and baseId > 0 and prompt:GetAttribute("BaseId") == baseId
		end
		return false
	end

	local function render()
		local prompt = focused
		if not prompt or not prompt.Parent or not prompt.Enabled or not allowed(prompt) then
			focused = nil
			holdStarted = nil
			view.PromptCard.Visible = false
			view.PromptProgress.Size = UDim2.fromScale(0, 1)
			return
		end
		view.PromptCard.Visible = true
		view.PromptObject.Text = prompt.ObjectText
		view.PromptAction.Text = prompt.ActionText
		local key: string
		if inputType == Enum.ProximityPromptInputType.Touch then
			key = "HOLD"
		elseif inputType == Enum.ProximityPromptInputType.Gamepad then
			key = prompt.GamepadKeyCode.Name:gsub("Button", "")
		else
			key = prompt.KeyboardKeyCode.Name
		end
		view.PromptKey.Text = key
		local instruction = if inputType == Enum.ProximityPromptInputType.Touch then "Hold the button"
			elseif prompt.HoldDuration > 0 then "Hold " .. key else "Press " .. key
		local kind = prompt:GetAttribute("Kind")
		local cash = player:GetAttribute("Cash")
		local price = prompt:GetAttribute("Price")
		local used = player:GetAttribute("PadsUsed")
		local allowance = player:GetAttribute("PadAllowance")
		if (kind == "Buy" or kind == "Steal") and typeof(used) == "number" and typeof(allowance) == "number" and used >= allowance then
			view.PromptHint.Text = "Base full • no empty pads"
		elseif kind == "Buy" and typeof(cash) == "number" and typeof(price) == "number" and cash < price then
			view.PromptHint.Text = "Need " .. Presentation.Money(price - cash) .. " more"
		elseif kind == "Steal" then
			view.PromptHint.Text = instruction .. " • carry home at 75% walk speed"
		elseif kind == "Rebirth" then
			view.PromptHint.Text = instruction .. " • x1.5 income • keep your characters"
		elseif kind == "Lock" then
			view.PromptHint.Text = instruction .. " • 90s cooldown after the shield"
		else
			view.PromptHint.Text = instruction .. " • deliver to an empty pad at your base"
		end
	end

	local function apply(prompt: ProximityPrompt)
		local enabled = allowed(prompt)
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
		if focused == prompt then
			render()
		end
	end

	local function watch(instance: Instance)
		if not instance:IsA("ProximityPrompt") or watched[instance] then
			return
		end
		local prompt = instance
		local connections = {}
		watched[prompt] = connections
		for _, name in {"Available", "Kind", "OwnerUserId", "BaseId"} do
			table.insert(connections, prompt:GetAttributeChangedSignal(name):Connect(function()
				apply(prompt)
			end))
		end
		table.insert(connections, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			apply(prompt)
		end))
		for _, property in {"ObjectText", "ActionText"} do
			table.insert(connections, prompt:GetPropertyChangedSignal(property):Connect(function()
				if focused == prompt then
					render()
				end
			end))
		end
		apply(prompt)
	end

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, kind: Enum.ProximityPromptInputType)
		if not watched[prompt] or not allowed(prompt) then
			return
		end
		releasePointer()
		focused = prompt
		inputType = kind
		holdStarted = nil
		render()
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if focused == prompt then
			releasePointer()
			focused = nil
			render()
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		if focused == prompt then
			holdStarted = os.clock()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		if focused == prompt then
			holdStarted = nil
			view.PromptProgress.Size = UDim2.fromScale(0, 1)
		end
	end)
	view.PromptButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local prompt = focused
		if prompt and prompt.Enabled then
			pointerPrompt = prompt
			pointerInput = input
			prompt:InputHoldBegin()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == pointerInput or (pointerInput and input.UserInputType == Enum.UserInputType.MouseButton1) then
			releasePointer()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(releasePointer)
	RunService.RenderStepped:Connect(function()
		local prompt = focused
		if prompt and holdStarted and prompt.HoldDuration > 0 then
			view.PromptProgress.Size = UDim2.fromScale(math.clamp((os.clock() - holdStarted) / prompt.HoldDuration, 0, 1), 1)
		end
	end)
	workspace.DescendantAdded:Connect(watch)
	workspace.DescendantRemoving:Connect(function(instance: Instance)
		if instance:IsA("ProximityPrompt") and watched[instance] then
			for _, connection in watched[instance] do
				connection:Disconnect()
			end
			watched[instance] = nil
			if focused == instance then
				releasePointer()
				focused = nil
				render()
			end
		end
	end)
	player.AttributeChanged:Connect(function()
		for prompt in watched do
			apply(prompt)
		end
	end)
	for _, instance in workspace:GetDescendants() do
		watch(instance)
	end
end

return PromptController
