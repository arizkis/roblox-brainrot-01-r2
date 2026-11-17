--!strict
-- Constructs the UI on a 768x480 design canvas. Controllers supply all live text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local C = Presentation.Colors
local HUDView = {}

export type View = {
	Gui: ScreenGui, Host: Frame, Canvas: Frame, Scale: UIScale,
	Stats: Frame, Cash: TextLabel, Income: TextLabel, RebirthStat: TextLabel,
	Pads: TextLabel, PadTitle: TextLabel,
	Banner: Frame, BannerTitle: TextLabel, BannerHint: TextLabel,
	LockButton: TextButton, LockTitle: TextLabel, LockDetail: TextLabel,
	RebirthButton: TextButton, RebirthTitle: TextLabel, RebirthDetail: TextLabel,
	CarryHint: TextLabel, Notice: CanvasGroup, NoticeText: TextLabel, Splash: CanvasGroup,
	PromptCard: Frame, PromptObject: TextLabel, PromptAction: TextLabel,
	PromptHint: TextLabel, PromptButton: TextButton, PromptKey: TextLabel, PromptProgress: Frame,
}

local function style(object: GuiObject, color: Color3, radius: number)
	object.BackgroundColor3 = color
	object.BackgroundTransparency = 0.04
	object.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = C.Ink
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object
end

local function frame(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: Color3): Frame
	local object = Instance.new("Frame")
	object.Name = name
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
	style(object, color, 12)
	object.Parent = parent
	return object
end

local function text(parent: Instance, name: string, value: string, x: number, y: number, w: number, h: number, size: number): TextLabel
	local object = Instance.new("TextLabel")
	object.Name = name
	object.Text = value
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
	object.BackgroundTransparency = 1
	object.Font = Enum.Font.GothamBold
	object.TextColor3 = C.White
	object.TextStrokeColor3 = Color3.new(0, 0, 0)
	object.TextStrokeTransparency = 0
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextScaled = true
	object.TextWrapped = false
	object.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = math.min(18, size)
	limit.MaxTextSize = size
	limit.Parent = object
	return object
end

local function action(parent: Instance, name: string, x: number, y: number, width: number): (TextButton, TextLabel, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(x, y)
	button.Size = UDim2.fromOffset(width, 60)
	button.Text = ""
	button.AutoButtonColor = false
	button.Selectable = true
	style(button, C.Disabled, 12)
	button.Parent = parent
	local title = text(button, "Title", "CONNECTING…", 12, 4, width - 24, 30, 26)
	local detail = text(button, "Detail", "Waiting for your base", 12, 35, width - 24, 21, 17)
	return button, title, detail
end

function HUDView.Create(playerGui: PlayerGui): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "BazaarHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	local host = Instance.new("Frame")
	host.Name = "SafeViewport"
	host.Size = UDim2.fromScale(1, 1)
	host.BackgroundTransparency = 1
	host.Parent = gui
	local canvas = Instance.new("Frame")
	canvas.Name = "DesignCanvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(Presentation.Width, Presentation.Height)
	canvas.BackgroundTransparency = 1
	canvas.Parent = host
	local scale = Instance.new("UIScale")
	scale.Name = "ViewportScale"
	scale.Parent = canvas
	local function resize()
		scale.Scale = math.max(0.1, math.min(host.AbsoluteSize.X / Presentation.Width, host.AbsoluteSize.Y / Presentation.Height))
	end
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	local stats = frame(canvas, "Stats", 16, 10, 736, 74, C.Ink)
	local function stat(name: string, title: string, x: number, width: number, size: number, color: Color3): (TextLabel, TextLabel)
		local strip = frame(stats, name .. "Accent", x + 10, 8, 4, 56, color)
		strip.BackgroundTransparency = 0
		local caption = text(stats, name .. "Caption", title, x + 23, 5, width - 31, 19, 14)
		caption.TextColor3 = C.Muted
		local value = text(stats, name, "—", x + 23, 25, width - 31, 43, size)
		return value, caption
	end
	local cash = stat("Cash", "CASH", 0, 208, 38, C.Lime)
	local income = stat("Income", "INCOME / SEC", 208, 192, 31, C.Cyan)
	local rebirthStat = stat("Rebirths", "REBIRTHS / BOOST", 400, 180, 25, C.Pink)
	local pads, padTitle = stat("Pads", "PADS", 580, 156, 29, C.Gold)

	local banner = frame(canvas, "TsunamiBanner", 16, 92, 736, 64, C.Danger)
	banner.ZIndex = 5
	banner.Visible = false
	local bannerTitle = text(banner, "Title", "TSUNAMI IN 10s", 12, 3, 712, 34, 32)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Center
	local bannerHint = text(banner, "Hint", "Get inside any base. Placed characters are safe.", 12, 37, 712, 23, 20)
	bannerHint.TextXAlignment = Enum.TextXAlignment.Center

	local notice = Instance.new("CanvasGroup")
	notice.Name = "ActionNotice"
	notice.Position = UDim2.fromOffset(32, 163)
	notice.Size = UDim2.fromOffset(704, 44)
	style(notice, C.Panel, 10)
	notice.Visible = false
	notice.ZIndex = 6
	notice.Parent = canvas
	local noticeText = text(notice, "Message", "", 12, 3, 680, 38, 22)
	noticeText.TextXAlignment = Enum.TextXAlignment.Center
	noticeText.TextWrapped = true

	local splash = Instance.new("CanvasGroup")
	splash.Name = "JoinSplash"
	splash.Position = UDim2.fromOffset(16, 214)
	splash.Size = UDim2.fromOffset(736, 112)
	style(splash, C.Ink, 16)
	splash.ZIndex = 8
	splash.Parent = canvas
	local splashTitle = text(splash, "Title", "BRAINROT BAZAAR", 16, 9, 704, 57, 48)
	splashTitle.Font = Enum.Font.GothamBlack
	splashTitle.TextColor3 = C.Gold
	splashTitle.TextXAlignment = Enum.TextXAlignment.Center
	local howTo = text(splash, "HowTo", "Grab a character • carry it home • earn cash • rebirth", 16, 73, 704, 27, 21)
	howTo.TextXAlignment = Enum.TextXAlignment.Center

	local touchLayout = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local actionsY = if touchLayout then 336 else 410
	local promptY = if touchLayout then 208 else 280
	local carryY = if touchLayout then 306 else 382
	local lockButton, lockTitle, lockDetail = action(canvas, "Lock", 16, actionsY, 252)
	local rebirthButton, rebirthTitle, rebirthDetail = action(canvas, "Rebirth", 280, actionsY, 472)
	lockButton.NextSelectionRight = rebirthButton
	rebirthButton.NextSelectionLeft = lockButton
	local carryHint = text(canvas, "CarryHint", "", 16, carryY, 736, 26, 21)
	carryHint.TextXAlignment = Enum.TextXAlignment.Center
	carryHint.Visible = false

	local promptCard = frame(canvas, "Interaction", 94, promptY, 580, 96, C.Ink)
	promptCard.Visible = false
	promptCard.ZIndex = 4
	local promptButton = Instance.new("TextButton")
	promptButton.Name = "HoldButton"
	promptButton.Text = ""
	promptButton.Position = UDim2.fromOffset(12, 16)
	promptButton.Size = UDim2.fromOffset(64, 60)
	promptButton.AutoButtonColor = false
	promptButton.Selectable = false
	style(promptButton, C.Cyan, 10)
	promptButton.Parent = promptCard
	local promptKey = text(promptButton, "Key", "E", 4, 3, 56, 52, 34)
	promptKey.TextXAlignment = Enum.TextXAlignment.Center
	local promptObject = text(promptCard, "Object", "", 90, 6, 476, 28, 23)
	promptObject.TextColor3 = C.Muted
	local promptAction = text(promptCard, "Action", "", 90, 33, 476, 32, 29)
	local promptHint = text(promptCard, "Hint", "", 90, 66, 476, 21, 18)
	local track = frame(promptCard, "HoldTrack", 12, 88, 556, 4, C.Disabled)
	local progress = Instance.new("Frame")
	progress.Name = "Progress"
	progress.Size = UDim2.fromScale(0, 1)
	progress.BackgroundColor3 = C.Lime
	progress.BorderSizePixel = 0
	progress.Parent = track

	return {
		Gui = gui, Host = host, Canvas = canvas, Scale = scale, Stats = stats,
		Cash = cash, Income = income, RebirthStat = rebirthStat, Pads = pads, PadTitle = padTitle,
		Banner = banner, BannerTitle = bannerTitle, BannerHint = bannerHint,
		LockButton = lockButton, LockTitle = lockTitle, LockDetail = lockDetail,
		RebirthButton = rebirthButton, RebirthTitle = rebirthTitle, RebirthDetail = rebirthDetail,
		CarryHint = carryHint, Notice = notice, NoticeText = noticeText, Splash = splash,
		PromptCard = promptCard, PromptObject = promptObject, PromptAction = promptAction,
		PromptHint = promptHint, PromptButton = promptButton, PromptKey = promptKey, PromptProgress = progress,
	}
end

return HUDView
