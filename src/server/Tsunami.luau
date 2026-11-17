--!strict
-- Warning/sweep/recession timeline and continuous wave exposure checks.
-- The wave removes carried cargo only; it never damages players or placed models.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local State = require(script.Parent.GameState)
local Carry = require(script.Parent.Carry)

local Tsunami = {}
local started = false
local wall: Model? = nil
local edge = Config.World.PlazaSize / 2 + Config.Tsunami.EdgeMargin

local function buildWall(): Model
	local world = State.World
	assert(world, "World is required for the wave")
	local model = Instance.new("Model")
	model.Name = "TsunamiWall"
	local water = Instance.new("Part")
	water.Name = "Water"
	water.Size = Vector3.new(edge * 2, Config.Tsunami.Height, Config.Tsunami.Depth)
	water.Color = Color3.fromRGB(29, 163, 255)
	water.Material = Enum.Material.Glass
	water.Transparency = 1
	water.Anchored = true
	water.CanCollide = false
	water.CanTouch = false
	water.CanQuery = false
	water.CastShadow = false
	water.Parent = model
	model.PrimaryPart = water
	for index = 1, 3 do
		local foam = Instance.new("Part")
		foam.Name = "Foam"
		foam.Size = Vector3.new(edge * 2, 0.6, 0.7)
		foam.CFrame = CFrame.new(0, Config.Tsunami.Height / 2 - index * 0.7, Config.Tsunami.Depth / 2 + 0.1)
		foam.Color = Color3.fromRGB(210, 255, 255)
		foam.Material = Enum.Material.Neon
		foam.Transparency = 1
		foam.Anchored = true
		foam.CanCollide = false
		foam.CanTouch = false
		foam.CanQuery = false
		foam.CastShadow = false
		foam.Parent = model
	end
	model.Parent = world.Root
	return model
end

local function render(z: number, centerY: number, visible: boolean)
	local model = wall
	assert(model, "Wave visuals must be built")
	model:PivotTo(CFrame.new(0, centerY, z))
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = if not visible then 1 elseif child.Name == "Water" then 0.32 else 0.12
		end
	end
end

function Tsunami.IsSheltered(position: Vector3): boolean
	local world = State.World
	assert(world, "World is required for shelter checks")
	for _, plot in world.Bases do
		local localPosition = plot.SafeZone.CFrame:PointToObjectSpace(position)
		-- Every plot footprint shelters, even a rival/unclaimed plot; jumping stays safe.
		if math.abs(localPosition.X) <= plot.SafeZone.Size.X / 2
			and math.abs(localPosition.Z) <= plot.SafeZone.Size.Z / 2 then
			return true
		end
	end
	return false
end

local function playerPosition(record: State.PlayerState): Vector3?
	local avatar = record.Player.Character
	local root = if avatar then avatar:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	-- A reset cannot make exposed cargo immune: use the carrier's last known position.
	return State.Tsunami.PlayerPositions[record.Player.UserId]
end

local function exposed(position: Vector3): boolean
	return math.abs(position.X) <= edge + 2 and position.Y >= -3
		and position.Y <= Config.Tsunami.Height + 3 and not Tsunami.IsSheltered(position)
end

local function sweep(previousZ: number, z: number)
	local halfDepth = Config.Tsunami.Depth / 2 + 2
	for userId, record in State.Players do
		local current = playerPosition(record)
		if not current or not record.CarriedCharacter then
			continue
		end
		local previous = State.Tsunami.PlayerPositions[userId] or current
		local a = previous.Z - previousZ
		local b = current.Z - z
		-- Test relative swept movement, rather than Touched or just a single frame slab.
		if math.min(a, b) <= halfDepth and math.max(a, b) >= -halfDepth then
			local alpha = if math.abs(a - b) > 0.00001 then math.clamp(a / (a - b), 0, 1) else 1
			local hitPosition = previous:Lerp(current, alpha)
			if exposed(hitPosition) or (math.abs(b) <= halfDepth and exposed(current)) then
				Carry.WashAway(record)
			end
		end
	end
end

local function publish(now: number)
	local signals = State.Signals
	assert(signals, "Signals are required for the tsunami")
	local state = State.Tsunami
	local seconds = math.max(0, math.ceil(state.NextWaveAt - now))
	signals:SetAttribute("TsunamiPhase", state.Phase)
	signals:SetAttribute("SecondsToWave", seconds)
	signals:SetAttribute("NextWaveAt", state.NextWaveAt)
	signals:SetAttribute("WaveEndsAt", state.NextWaveAt + Config.Tsunami.SweepDuration)
	signals:SetAttribute("TsunamiWarning", state.Phase == "Warning")
	local banner = ""
	if state.Phase == "Warning" then
		banner = string.format("TSUNAMI IN %ds! SHELTER IN ANY BASE!", seconds)
	elseif state.Phase == "Sweeping" then
		banner = "TSUNAMI! CARRIED CHARACTERS ARE AT RISK!"
	elseif state.Phase == "Receding" then
		banner = "WATER RECEDING"
	end
	signals:SetAttribute("TsunamiBanner", banner)
end

function Tsunami.Advance(now: number)
	local state = State.Tsunami
	local settings = Config.Tsunami
	if state.Phase == "Calm" and now >= state.NextWaveAt - settings.WarningDuration then
		state.Phase = "Warning"
	end
	if state.Phase == "Warning" then
		local rise = math.clamp(1 - (state.NextWaveAt - now) / settings.WarningDuration, 0, 1)
		render(-edge, -settings.Height / 2 + rise * settings.Height, true)
		if now >= state.NextWaveAt then
			state.Phase = "Sweeping"
			state.LastWaveZ = -edge
		end
	end
	if state.Phase == "Sweeping" then
		local progress = math.clamp((now - state.NextWaveAt) / settings.SweepDuration, 0, 1)
		local z = -edge + edge * 2 * progress
		render(z, settings.Height / 2, true)
		sweep(state.LastWaveZ, z)
		state.LastWaveZ = z
		if progress >= 1 then
			state.Phase = "Receding"
		end
	end
	if state.Phase == "Receding" then
		local progress = math.clamp((now - state.NextWaveAt - settings.SweepDuration) / settings.RecedeDuration, 0, 1)
		render(edge, settings.Height / 2 - progress * settings.Height, true)
		if progress >= 1 then
			state.Phase = "Calm"
			-- Normal cadence is exactly 90s between sweep starts. After a huge server
			-- stall, guarantee a fresh warning rather than replaying overdue cycles.
			state.NextWaveAt = math.max(state.NextWaveAt + settings.CycleDuration, now + settings.WarningDuration + 1)
			render(-edge, -settings.Height, false)
		end
	end
	for userId, record in State.Players do
		local position = playerPosition(record)
		if position then
			state.PlayerPositions[userId] = position
		end
	end
	publish(now)
end

function Tsunami.ResetForTour(secondsToWave: number)
	assert(RunService:IsStudio(), "Tour clock controls are Studio-only")
	assert(secondsToWave >= 0 and secondsToWave <= Config.Tsunami.CycleDuration)
	State.Tsunami.Phase = "Calm"
	State.Tsunami.NextWaveAt = workspace:GetServerTimeNow() + secondsToWave
	State.Tsunami.LastWaveZ = -edge
	table.clear(State.Tsunami.PlayerPositions)
	render(-edge, -Config.Tsunami.Height, false)
	Tsunami.Advance(workspace:GetServerTimeNow())
end

function Tsunami.Start()
	assert(not started, "Tsunami already started")
	started = true
	wall = buildWall()
	local now = workspace:GetServerTimeNow()
	State.Tsunami.Phase = "Calm"
	State.Tsunami.NextWaveAt = now + Config.Tsunami.CycleDuration
	State.Tsunami.LastWaveZ = -edge
	render(-edge, -Config.Tsunami.Height, false)
	Tsunami.Advance(now)
	RunService.Heartbeat:Connect(function()
		Tsunami.Advance(workspace:GetServerTimeNow())
	end)
end

return Tsunami
