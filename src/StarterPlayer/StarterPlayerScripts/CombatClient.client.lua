local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local AttackRemote = ReplicatedStorage:WaitForChild("AttackRemote")
local ToggleBlock = ReplicatedStorage:WaitForChild("ToggleBlock")
local HitFXRemote = ReplicatedStorage:WaitForChild("HitFX")
local MatchRemote = ReplicatedStorage:WaitForChild("MatchRemote")

local PERFECT_MIN = 0.85
local PERFECT_MAX = 0.98
local OVERCHARGE = 1.02
local MAX_CHARGE = 1.02

local charging = false
local blocking = false
local chargeStartedAt = 0
local shakePower = 0
local shakeTime = 0
local baseFOV = 70

local oldGui = playerGui:FindFirstChild("IMPACTHUD")
if oldGui then oldGui:Destroy() end

local function make(className: string, properties: {[string]: any}, parent: Instance): Instance
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local gui = make("ScreenGui", {
	Name = "IMPACTHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 100,
}, playerGui) :: ScreenGui

local topBar = make("Frame", {
	Name = "TopBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.fromOffset(520, 76),
	BackgroundColor3 = Color3.fromRGB(9, 12, 20),
	BackgroundTransparency = 0.17,
	BorderSizePixel = 0,
}, gui) :: Frame
make("UICorner", {CornerRadius = UDim.new(0, 16)}, topBar)
make("UIStroke", {Thickness = 1.5, Transparency = 0.45, Color = Color3.fromRGB(75, 120, 255)}, topBar)

local stateText = make("TextLabel", {
	Name = "State",
	Position = UDim2.fromOffset(18, 8),
	Size = UDim2.fromOffset(300, 28),
	BackgroundTransparency = 1,
	Text = "IMPACT CLASH",
	Font = Enum.Font.GothamBlack,
	TextSize = 21,
	TextColor3 = Color3.fromRGB(235, 240, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local infoText = make("TextLabel", {
	Name = "Info",
	Position = UDim2.fromOffset(18, 38),
	Size = UDim2.fromOffset(340, 24),
	BackgroundTransparency = 1,
	Text = "WAITING FOR PLAYERS",
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(150, 165, 195),
	TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local timerText = make("TextLabel", {
	Name = "Timer",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.fromOffset(115, 58),
	BackgroundTransparency = 1,
	Text = "--:--",
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(90, 185, 255),
	TextXAlignment = Enum.TextXAlignment.Right,
}, topBar) :: TextLabel

local chargeBack = make("Frame", {
	Name = "ChargeBack",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -42),
	Size = UDim2.fromOffset(460, 24),
	BackgroundColor3 = Color3.fromRGB(12, 15, 24),
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, gui) :: Frame
make("UICorner", {CornerRadius = UDim.new(1, 0)}, chargeBack)
make("UIStroke", {Thickness = 1, Transparency = 0.55, Color = Color3.fromRGB(80, 110, 180)}, chargeBack)

local chargeFill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(75, 175, 255),
	BorderSizePixel = 0,
}, chargeBack) :: Frame
make("UICorner", {CornerRadius = UDim.new(1, 0)}, chargeFill)

local perfectMarker = make("Frame", {
	Name = "PerfectMarker",
	Position = UDim2.fromScale(PERFECT_MIN / MAX_CHARGE, 0),
	Size = UDim2.new((PERFECT_MAX - PERFECT_MIN) / MAX_CHARGE, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(255, 195, 55),
	BackgroundTransparency = 0.62,
	BorderSizePixel = 0,
}, chargeBack) :: Frame

local overMarker = make("Frame", {
	Name = "OverchargeMarker",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(4, 24),
	BackgroundColor3 = Color3.fromRGB(255, 50, 65),
	BorderSizePixel = 0,
}, chargeBack) :: Frame

local chargeLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -7),
	Size = UDim2.fromOffset(460, 24),
	BackgroundTransparency = 1,
	Text = "HOLD LMB  •  RELEASE",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(190, 205, 230),
}, chargeBack) :: TextLabel

local comboText = make("TextLabel", {
	Name = "Combo",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -34, 0, 116),
	Size = UDim2.fromOffset(320, 72),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 210, 70),
	TextStrokeTransparency = 0,
	TextStrokeColor3 = Color3.fromRGB(8, 10, 16),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextTransparency = 1,
}, gui) :: TextLabel

local message = make("TextLabel", {
	Name = "Message",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.39),
	Size = UDim2.fromOffset(650, 105),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeTransparency = 0.12,
	TextStrokeColor3 = Color3.fromRGB(5, 7, 12),
	TextTransparency = 1,
}, gui) :: TextLabel

local flashFrame = make("Frame", {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 40, 60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, gui) :: Frame

local controls = make("TextLabel", {
	Name = "Controls",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 30, 1, -30),
	Size = UDim2.fromOffset(330, 55),
	BackgroundTransparency = 1,
	Text = "LMB  ATTACK     RMB  BLOCK     Q  DASH",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(155, 170, 195),
	TextXAlignment = Enum.TextXAlignment.Left,
}, gui) :: TextLabel

local function playSound(volume: number, speed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 2)
end

local function shake(power: number, duration: number)
	shakePower = math.max(shakePower, power)
	shakeTime = math.max(shakeTime, duration)
end

local function fovPunch(amount: number, duration: number)
	local camera = workspace.CurrentCamera
	if not camera then return end
	TweenService:Create(camera, TweenInfo.new(duration * 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseFOV + amount}):Play()
	task.delay(duration * 0.28, function()
		if workspace.CurrentCamera == camera then
			TweenService:Create(camera, TweenInfo.new(duration * 0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FieldOfView = baseFOV}):Play()
		end
	end)
end

local function flashScreen(color: Color3, transparency: number, duration: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = transparency
	TweenService:Create(flashFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
end

local function showMessage(text: string, color: Color3, duration: number)
	message.Text = text
	message.TextColor3 = color
	message.TextTransparency = 0
	message.Size = UDim2.fromOffset(560, 82)
	TweenService:Create(message, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(690, 112),
	}):Play()
	task.delay(duration, function()
		TweenService:Create(message, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
	end)
end

local function burstAtCharacter(color: Color3, scale: number, withRing: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Lifetime = NumberRange.new(0.18, 0.35)
	particles.Speed = NumberRange.new(18 * scale, 30 * scale)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Rate = 0
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-240, 240)
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.18 * scale), NumberSequenceKeypoint.new(0.5, 0.09 * scale), NumberSequenceKeypoint.new(1, 0)})
	particles.Parent = attachment
	particles:Emit(math.floor(18 + 24 * scale))

	if withRing then
		local ring = Instance.new("Part")
		ring.Name = "ImpactRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.18
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanTouch = false
		ring.Size = Vector3.new(2.5, 0.14, 2.5)
		ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0))
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(12 * scale, 0.05, 12 * scale),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.3)
	end

	Debris:AddItem(attachment, 1)
end

local function setChargeVisual(value: number, state: string)
	value = math.clamp(value, 0, 1)
	chargeFill.Size = UDim2.fromScale(value, 1)
	if state == "Perfect" then
		chargeFill.BackgroundColor3 = Color3.fromRGB(255, 195, 55)
		chargeLabel.Text = "PERFECT WINDOW  •  RELEASE"
		chargeLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	elseif state == "Overcharge" then
		chargeFill.BackgroundColor3 = Color3.fromRGB(255, 48, 62)
		chargeLabel.Text = "OVERCHARGE  •  TOO LATE"
		chargeLabel.TextColor3 = Color3.fromRGB(255, 95, 105)
	elseif state == "Weak" then
		chargeFill.BackgroundColor3 = Color3.fromRGB(72, 156, 240)
		chargeLabel.Text = "WEAK"
		chargeLabel.TextColor3 = Color3.fromRGB(160, 195, 245)
	else
		chargeFill.BackgroundColor3 = Color3.fromRGB(80, 175, 255)
		chargeLabel.Text = "CHARGING"
		chargeLabel.TextColor3 = Color3.fromRGB(195, 210, 235)
	end
end

local function beginCharge()
	if charging or blocking then return end
	charging = true
	chargeStartedAt = os.clock()
	AttackRemote:FireServer("Start")
end

local function releaseCharge()
	if not charging then return end
	charging = false
	local held = os.clock() - chargeStartedAt
	chargeStartedAt = 0
	AttackRemote:FireServer("Release")
	shake(0.05, 0.04)
	playSound(0.18, 0.95)
	if held >= PERFECT_MIN and held <= PERFECT_MAX then
		shake(0.11, 0.06)
		fovPunch(4, 0.14)
	end
	chargeFill.Size = UDim2.fromScale(0, 1)
	chargeLabel.Text = "HOLD LMB  •  RELEASE"
	chargeLabel.TextColor3 = Color3.fromRGB(190, 205, 230)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		beginCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if not blocking and not charging then
			blocking = true
			ToggleBlock:FireServer(true)
			controls.Text = "LMB  ATTACK     RMB  BLOCKING     Q  DASH"
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		releaseCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if blocking then
			blocking = false
			ToggleBlock:FireServer(false)
			controls.Text = "LMB  ATTACK     RMB  BLOCK     Q  DASH"
		end
	end
end)

MatchRemote.OnClientEvent:Connect(function(eventName, a, b, c, d, e)
	if eventName == "State" then
		local state = a
		local remaining = tonumber(b) or 0
		local alive = tonumber(c) or 0
		local total = tonumber(d) or 0
		local roundNumber = tonumber(e) or 0

		if state == "LOBBY" then
			stateText.Text = "IMPACT CLASH"
			infoText.Text = "WAITING FOR PLAYERS"
			timerText.Text = "--:--"
		elseif state == "INTERMISSION" then
			stateText.Text = "NEXT MATCH"
			infoText.Text = total .. " PLAYER" .. (total == 1 and "" or "S") .. " READY"
			timerText.Text = string.format("%02d", remaining)
		elseif state == "ROUND" then
			stateText.Text = string.format("ROUND %02d", roundNumber)
			infoText.Text = string.format("%d ALIVE  •  %d IN MATCH", alive, total)
			timerText.Text = string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
		else
			stateText.Text = "MATCH OVER"
			infoText.Text = "RESULTS"
			timerText.Text = string.format("%02d", remaining)
		end
	elseif eventName == "RoundStart" then
		showMessage("FIGHT", Color3.fromRGB(120, 200, 255), 0.6)
		playSound(0.32, 0.75)
	elseif eventName == "Shrink" then
		showMessage("ARENA SHRINKING", Color3.fromRGB(255, 90, 135), 0.62)
		shake(0.12, 0.14)
		playSound(0.28, 0.68)
	elseif eventName == "Winner" then
		local userId = tonumber(a) or 0
		local winnerName = tostring(b or "NO WINNER")
		if userId == player.UserId then
			showMessage("YOU WIN", Color3.fromRGB(255, 210, 70), 1.2)
			shake(0.45, 0.35)
			fovPunch(8, 0.28)
			flashScreen(Color3.fromRGB(255, 205, 70), 0.86, 0.25)
		else
			showMessage(winnerName .. " WINS", Color3.fromRGB(220, 225, 240), 0.9)
		end
	elseif eventName == "Eliminated" then
		local userId = tonumber(a) or 0
		if userId == player.UserId then
			showMessage("ELIMINATED", Color3.fromRGB(255, 75, 80), 0.7)
			flashScreen(Color3.fromRGB(255, 40, 60), 0.70, 0.22)
			shake(0.60, 0.30)
		end
	end
end)

HitFXRemote.OnClientEvent:Connect(function(role, hitType, combo)
	combo = tonumber(combo) or 0

	if role == "Attacker" then
		if hitType == "Finisher" then
			shake(0.42, 0.20)
			fovPunch(9, 0.22)
			flashScreen(Color3.fromRGB(255, 45, 70), 0.87, 0.15)
			showMessage("FINISHER", Color3.fromRGB(255, 70, 75), 0.55)
			playSound(0.48, 0.62)
			burstAtCharacter(Color3.fromRGB(255, 55, 80), 1.5, true)
			comboText.Text = "x3  COMBO"
			comboText.TextTransparency = 0
		elseif hitType == "Perfect" then
			shake(0.26, 0.13)
			fovPunch(5, 0.16)
			flashScreen(Color3.fromRGB(255, 195, 55), 0.91, 0.10)
			showMessage("PERFECT", Color3.fromRGB(255, 210, 85), 0.42)
			playSound(0.38, 0.72)
			burstAtCharacter(Color3.fromRGB(255, 205, 80), 1.0, true)
		elseif hitType == "Blocked" then
			shake(0.14, 0.09)
			showMessage("BLOCKED", Color3.fromRGB(115, 200, 255), 0.32)
		elseif hitType == "Overcharge" then
			shake(0.24, 0.22)
			flashScreen(Color3.fromRGB(255, 45, 55), 0.83, 0.18)
			showMessage("OVERCHARGE", Color3.fromRGB(255, 70, 70), 0.58)
		else
			shake(0.15, 0.08)
			if combo > 1 then
				comboText.Text = "x" .. combo .. "  COMBO"
				comboText.TextColor3 = combo == 2 and Color3.fromRGB(255, 210, 75) or Color3.fromRGB(255, 75, 75)
				comboText.TextTransparency = 0
				task.delay(0.9, function()
					if comboText.Text == "x" .. combo .. "  COMBO" then
						TweenService:Create(comboText, TweenInfo.new(0.18), {TextTransparency = 1}):Play()
					end
				end)
			end
		end
	else
		if hitType == "Finisher" then
			shake(0.70, 0.28)
			fovPunch(-9, 0.25)
			flashScreen(Color3.fromRGB(255, 25, 40), 0.72, 0.22)
			playSound(0.5, 0.6)
		elseif hitType == "Perfect" then
			shake(0.45, 0.18)
			fovPunch(-5, 0.19)
			flashScreen(Color3.fromRGB(255, 170, 45), 0.82, 0.14)
		else
			shake(0.30, 0.13)
		end
	end
end)

RunService:BindToRenderStep("IMPACTHUD", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	if charging then
		local held = os.clock() - chargeStartedAt
		local progress = held / MAX_CHARGE
		if held >= PERFECT_MIN and held <= PERFECT_MAX then
			setChargeVisual(progress, "Perfect")
		elseif held >= OVERCHARGE then
			setChargeVisual(progress, "Overcharge")
		elseif held < 0.4 then
			setChargeVisual(progress, "Weak")
		else
			setChargeVisual(progress, "Normal")
		end
	end

	if shakeTime <= 0 or shakePower <= 0 then
		shakePower = 0
		shakeTime = 0
		return
	end

	shakeTime -= deltaTime
	local camera = workspace.CurrentCamera
	if not camera then return end
	local t = os.clock() * 38
	local fade = math.clamp(shakeTime / 0.28, 0, 1)
	local power = shakePower * fade
	local offset = Vector3.new(math.noise(t, 0, 0) * power, math.noise(0, t, 0) * power, 0)
	local rotation = CFrame.Angles(
		math.rad(math.noise(t, 1, 0) * power * 1.6),
		math.rad(math.noise(1, t, 0) * power * 1.6),
		math.rad(math.noise(t, t, 1) * power * 2.2)
	)
	camera.CFrame = camera.CFrame * CFrame.new(offset) * rotation
end)

player.CharacterRemoving:Connect(function()
	charging = false
	blocking = false
	chargeStartedAt = 0
	chargeFill.Size = UDim2.fromScale(0, 1)
end)

print(">>> IMPACT Clash HUD // JUICE ONLINE <<<")
