--!strict
-- Reads server attributes; the only writes sent to the server are two ability requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presentation = require(Shared:WaitForChild("Presentation"))
local Config = require(Shared:WaitForChild("GameConfig"))
local HUDView = require(script.Parent.HUDView)
local C = Presentation.Colors
local HUD = {}

function HUD.Start(view: HUDView.View)
	local player = Players.LocalPlayer
	local signals = ReplicatedStorage:WaitForChild("GameSignals")
	local lockRequest = signals:WaitForChild("RequestLock") :: RemoteEvent
	local rebirthRequest = signals:WaitForChild("RequestRebirth") :: RemoteEvent
	local lockPending = false
	local rebirthPending = false
	local canLock = false
	local canRebirth = false
	local noticeVersion = 0
	local noticeTween: Tween? = nil
	local splashDismissed = false

	local function number(name: string, fallback: number): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else fallback
	end

	local function dismissSplash()
		if splashDismissed then
			return
		end
		splashDismissed = true
		local tween = TweenService:Create(view.Splash, TweenInfo.new(0.6), {GroupTransparency = 1})
		tween:Play()
		tween.Completed:Once(function()
			view.Splash.Visible = false
		end)
	end
	task.delay(4, dismissSplash)
	ProximityPromptService.PromptShown:Once(dismissSplash)

	local function showNotice()
		local message = player:GetAttribute("ActionMessage")
		if typeof(message) ~= "string" or message == "" then
			return
		end
		noticeVersion += 1
		local version = noticeVersion
		if noticeTween then
			noticeTween:Cancel()
		end
		view.NoticeText.Text = message
		view.Notice.GroupTransparency = 0
		view.Notice.Visible = true
		task.delay(4.5, function()
			if version ~= noticeVersion then
				return
			end
			noticeTween = TweenService:Create(view.Notice, TweenInfo.new(0.35), {GroupTransparency = 1})
			noticeTween:Play()
			noticeTween.Completed:Once(function()
				if version == noticeVersion then
					view.Notice.Visible = false
				end
			end)
		end)
	end

	local function buttonState(button: TextButton, enabled: boolean, color: Color3)
		button.Active = enabled
		button.Selectable = enabled
		button.BackgroundColor3 = if enabled then color else C.Disabled
		local outline = button:FindFirstChild("Outline") :: UIStroke
		outline.Color = if enabled then color else C.Ink
	end

	local function update()
		local cash = number("Cash", 0)
		local income = number("IncomePerSecond", 0)
		local baseId = number("BaseId", 0)
		local allowance = number("PadAllowance", 6)
		local cost = number("RebirthCost", 0)
		view.Cash.Text = if player:GetAttribute("Cash") == nil then "$…" else Presentation.Money(cash, true)
		view.Income.Text = Presentation.Money(income, true) .. "/s"
		view.RebirthStat.Text = tostring(number("Rebirths", 0)) .. "  •  " .. Presentation.Multiplier(number("IncomeMultiplier", 1))
		view.Pads.Text = string.format("%d / %d", number("PadsUsed", 0), allowance)
		view.PadTitle.Text = if baseId > 0 then string.format("BASE %02d • PADS", baseId) else "WAITING • PADS"

		local now = workspace:GetServerTimeNow()
		local lockState = player:GetAttribute("LockState")
		canLock = baseId > 0 and lockState == "Ready" and not lockPending
		if lockPending then
			view.LockTitle.Text = "LOCKING…"
			view.LockDetail.Text = "Protecting your placed characters"
		elseif baseId == 0 then
			view.LockTitle.Text = "LOCK • NO BASE"
			view.LockDetail.Text = "Waiting for a free plot"
		elseif lockState == "Locked" then
			view.LockTitle.Text = string.format("LOCKED • %ds", math.max(0, math.ceil(number("LockExpiresAt", now) - now)))
			view.LockDetail.Text = "Shield up • stealing blocked"
		elseif lockState == "Cooldown" then
			view.LockTitle.Text = string.format("COOLDOWN • %ds", math.max(0, math.ceil(number("LockReadyAt", now) - now)))
			view.LockDetail.Text = "Shield down • protect your stock"
		else
			view.LockTitle.Text = "LOCK • READY"
			view.LockDetail.Text = "60s shield • then 90s cooldown"
		end
		buttonState(view.LockButton, canLock, C.Lime)

		canRebirth = player:GetAttribute("CanRebirth") == true and baseId > 0 and cost > 0 and cash >= cost and not rebirthPending
		if rebirthPending then
			view.RebirthTitle.Text = "REBIRTHING…"
			view.RebirthDetail.Text = "Keeping every placed character"
		elseif baseId == 0 then
			view.RebirthTitle.Text = "REBIRTH • NO BASE"
			view.RebirthDetail.Text = "Waiting for a free plot"
		elseif cost <= 0 then
			view.RebirthTitle.Text = "REBIRTH • NEED INCOME"
			view.RebirthDetail.Text = "Place a character on a pad to begin earning"
		else
			view.RebirthTitle.Text = "REBIRTH • " .. Presentation.Money(cost, true)
			if cash < cost then
				view.RebirthDetail.Text = "Need " .. Presentation.Money(cost - cash, true) .. " more • characters stay"
			else
				view.RebirthDetail.Text = if allowance < Config.World.MaxPads
					then "x1.5 income • +1 pad • keep characters"
					else "x1.5 income • 10 pads max • keep characters"
			end
		end
		buttonState(view.RebirthButton, canRebirth, C.Pink)

		local phase = signals:GetAttribute("TsunamiPhase")
		view.Banner.Visible = phase == "Warning" or phase == "Sweeping"
		if phase == "Warning" then
			local deadline = signals:GetAttribute("NextWaveAt")
			local seconds = if typeof(deadline) == "number" then math.max(0, math.ceil(deadline - now)) else 0
			view.BannerTitle.Text = string.format("TSUNAMI IN %ds • GET TO A BASE!", seconds)
			view.BannerHint.Text = "Any base is safe. Carried characters can wash away."
			view.Banner.BackgroundColor3 = C.Danger
		elseif phase == "Sweeping" then
			view.BannerTitle.Text = "TSUNAMI! SHELTER IN ANY BASE!"
			view.BannerHint.Text = "Protect your carried character. Placed characters are safe."
			view.Banner.BackgroundColor3 = Color3.fromRGB(27, 109, 191)
		end

		local carrying = player:GetAttribute("Carrying") == true
		view.CarryHint.Visible = carrying
		if carrying then
			local id = player:GetAttribute("CarryingCharacterId")
			local definition = if typeof(id) == "string" then Config.Characters[id] else nil
			local name = if definition then definition.Name else "character"
			local stolen = player:GetAttribute("CarryingStolen") == true
			view.CarryHint.Text = string.format("%s → BASE %02d • %s", name, baseId, if stolen then "STOLEN • 25% SLOWER" else "walk onto an empty pad")
			view.CarryHint.TextColor3 = if stolen then C.Gold else C.White
		end
	end

	view.LockButton.Activated:Connect(function()
		if not canLock then
			return
		end
		lockPending = true
		dismissSplash()
		update()
		lockRequest:FireServer()
		task.delay(1.5, function()
			lockPending = false
			update()
		end)
	end)
	view.RebirthButton.Activated:Connect(function()
		if not canRebirth then
			return
		end
		rebirthPending = true
		dismissSplash()
		update()
		rebirthRequest:FireServer()
		task.delay(1.5, function()
			rebirthPending = false
			update()
		end)
	end)
	player.AttributeChanged:Connect(function(name: string)
		if name == "ActionSequence" then
			lockPending = false
			rebirthPending = false
			showNotice()
		end
		update()
	end)
	signals.AttributeChanged:Connect(update)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed %= 0.1
			update()
		end
	end)
	update()
	showNotice()
end

return HUD
