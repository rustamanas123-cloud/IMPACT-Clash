local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local AttackRemote = ReplicatedStorage:WaitForChild("AttackRemote")
local ToggleBlock = ReplicatedStorage:WaitForChild("ToggleBlock")
local HitFXRemote = ReplicatedStorage:WaitForChild("HitFX")

local charging = false
local blocking = false
local chargeStartedAt = 0
local chargeDuration = 1.02
local shakePower = 0
local shakeTime = 0
local shakeFrequency = 38
local baseFOV = 70

local function make(className: string, properties: {[string]: any}, parent: Instance): Instance
	local object = Instance.new(className)
	for property, value in pairs(properties) do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local gui = make("ScreenGui", {
	Name = "ImpactCombatUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
}, playerGui) :: ScreenGui

local vignette = make("Frame", {
	Name = "ImpactFlash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 45, 45),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, gui) :: Frame

local centerMessage = make("TextLabel", {
	Name = "CenterMessage",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.40),
	Size = UDim2.fromOffset(600, 100),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeColor3 = Color3.fromRGB(8, 8, 12),
	TextStrokeTransparency = 0.1,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextTransparency = 1,
}, gui) :: TextLabel

local comboLabel = make("TextLabel", {
	Name = "ComboLabel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -42, 0, 42),
	Size = UDim2.fromOffset(260, 62),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeColor3 = Color3.fromRGB(10, 10, 15),
	TextStrokeTransparency = 0,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextTransparency = 1,
}, gui) :: TextLabel

local chargeBack = make("Frame", {
	Name = "ChargeBar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -48),
	Size = UDim2.fromOffset(420, 18),
	BackgroundColor3 = Color3.fromRGB(20, 20, 28),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
}, gui) :: Frame

make("UICorner", {CornerRadius = UDim.new(1, 0)}, chargeBack)

local chargeFill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(90, 180, 255),
	BorderSizePixel = 0,
}, chargeBack) :: Frame
make("UICorner", {CornerRadius = UDim.new(1, 0)}, chargeFill)

local chargeText = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -7),
	Size = UDim2.fromOffset(420, 28),
	BackgroundTransparency = 1,
	Text = "HOLD  •  RELEASE",
	TextColor3 = Color3.fromRGB(205, 215, 230),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
}, chargeBack) :: TextLabel

local blockLabel = make("TextLabel", {
	Name = "BlockLabel",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 42, 1, -42),
	Size = UDim2.fromOffset(230, 42),
	BackgroundTransparency = 1,
	Text = "RMB  •  BLOCK",
	TextColor3 = Color3.fromRGB(170, 190, 215),
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
}, gui) :: TextLabel

local function shakeCamera(power: number, duration: number)
	shakePower = math.max(shakePower, power)
	shakeTime = math.max(shakeTime, duration)
end

local function punchFOV(amount: number, duration: number)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local target = baseFOV + amount
	TweenService:Create(camera, TweenInfo.new(duration * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = target}):Play()
	task.delay(duration * 0.35, function()
		if workspace.CurrentCamera == camera then
			TweenService:Create(camera, TweenInfo.new(duration * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FieldOfView = baseFOV}):Play()
		end
	end)
end

local function flash(color: Color3, transparency: number, duration: number)
	vignette.BackgroundColor3 = color
	vignette.BackgroundTransparency = transparency
	TweenService:Create(vignette, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
end

local function showMessage(text: string, color: Color3, duration: number)
	centerMessage.Text = text
	centerMessage.TextColor3 = color
	centerMessage.TextTransparency = 1
	centerMessage.Size = UDim2.fromOffset(560, 80)

	TweenService:Create(centerMessage, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		Size = UDim2.fromOffset(640, 100),
	}):Play()

	task.delay(duration, function()
		TweenService:Create(centerMessage, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
		}):Play()
	end)
end

local function updateCombo(combo: number)
	if combo <= 1 then
		comboLabel.TextTransparency = 1
		return
	end

	comboLabel.Text = "x" .. combo .. "  COMBO"
	comboLabel.TextTransparency = 0
	comboLabel.TextColor3 = combo >= 3 and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 205, 70)
	comboLabel.Size = UDim2.fromOffset(290, 70)
	TweenService:Create(comboLabel, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(260, 62),
	}):Play()

	task.delay(0.95, function()
		if comboLabel.Text == "x" .. combo .. "  COMBO" then
			TweenService:Create(comboLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		end
	end)
end

local function setChargeVisual(value: number, state: string)
	value = math.clamp(value, 0, 1)
	chargeFill.Size = UDim2.fromScale(value, 1)

	if state == "Perfect" then
		chargeFill.BackgroundColor3 = Color3.fromRGB(255, 190, 55)
		chargeText.Text = "PERFECT WINDOW"
		chargeText.TextColor3 = Color3.fromRGB(255, 205, 90)
	elseif state == "Overcharge" then
		chargeFill.BackgroundColor3 = Color3.fromRGB(255, 55, 65)
		chargeText.Text = "OVERCHARGE  •  RELEASE NOW"
		chargeText.TextColor3 = Color3.fromRGB(255, 100, 105)
	elseif state == "Weak" then
		chargeFill.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
		chargeText.Text = "WEAK"
		chargeText.TextColor3 = Color3.fromRGB(170, 205, 255)
	else
		chargeFill.BackgroundColor3 = Color3.fromRGB(90, 180, 255)
		chargeText.Text = "CHARGING"
		chargeText.TextColor3 = Color3.fromRGB(205, 215, 230)
	end
end

local function beginCharge()
	if charging or blocking then return end
	charging = true
	chargeStartedAt = os.clock()
	setChargeVisual(0, "Normal")
	AttackRemote:FireServer("Start")
end

local function releaseCharge()
	if not charging then return end
	charging = false
	local heldFor = os.clock() - chargeStartedAt
	chargeStartedAt = 0
	AttackRemote:FireServer("Release")
	shakeCamera(0.07, 0.05)
	chargeFill.Size = UDim2.fromScale(0, 1)
	chargeText.Text = "HOLD  •  RELEASE"
	chargeText.TextColor3 = Color3.fromRGB(205, 215, 230)

	if heldFor >= 0.85 and heldFor <= 0.98 then
		shakeCamera(0.10, 0.06)
		punchFOV(4, 0.14)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		beginCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if not blocking and not charging then
			blocking = true
			blockLabel.Text = "RMB  •  BLOCKING"
			blockLabel.TextColor3 = Color3.fromRGB(105, 200, 255)
			ToggleBlock:FireServer(true)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		releaseCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if blocking then
			blocking = false
			blockLabel.Text = "RMB  •  BLOCK"
			blockLabel.TextColor3 = Color3.fromRGB(170, 190, 215)
			ToggleBlock:FireServer(false)
		end
	end
end)

HitFXRemote.OnClientEvent:Connect(function(role, hitType, combo, damage)
	combo = combo or 0
	damage = damage or 0

	if role == "Attacker" then
		if hitType == "Finisher" then
			shakeCamera(0.38, 0.18)
			punchFOV(8, 0.20)
			flash(Color3.fromRGB(255, 45, 45), 0.88, 0.14)
			showMessage("FINISHER", Color3.fromRGB(255, 65, 65), 0.55)
			updateCombo(3)
		elseif hitType == "Perfect" then
			shakeCamera(0.25, 0.12)
			punchFOV(5, 0.16)
			flash(Color3.fromRGB(255, 195, 55), 0.92, 0.10)
			showMessage("PERFECT", Color3.fromRGB(255, 205, 70), 0.42)
			updateCombo(combo)
		elseif hitType == "Blocked" then
			shakeCamera(0.12, 0.08)
			flash(Color3.fromRGB(90, 170, 255), 0.94, 0.08)
			showMessage("BLOCKED", Color3.fromRGB(120, 200, 255), 0.35)
		elseif hitType == "Overcharge" then
			shakeCamera(0.22, 0.20)
			flash(Color3.fromRGB(255, 45, 55), 0.86, 0.18)
			showMessage("OVERCHARGE", Color3.fromRGB(255, 70, 70), 0.55)
		elseif hitType == "Miss" then
			shakeCamera(0.03, 0.04)
		else
			shakeCamera(0.14, 0.08)
			updateCombo(combo)
		end
	elseif role == "Victim" then
		if hitType == "Finisher" then
			shakeCamera(0.65, 0.26)
			punchFOV(-8, 0.25)
			flash(Color3.fromRGB(255, 25, 35), 0.76, 0.20)
		elseif hitType == "Perfect" then
			shakeCamera(0.42, 0.18)
			punchFOV(-5, 0.18)
			flash(Color3.fromRGB(255, 170, 45), 0.84, 0.14)
		elseif hitType == "Blocked" then
			shakeCamera(0.10, 0.08)
			flash(Color3.fromRGB(70, 170, 255), 0.90, 0.08)
		elseif hitType == "KO" then
			shakeCamera(0.85, 0.35)
			punchFOV(-10, 0.30)
			flash(Color3.fromRGB(255, 20, 30), 0.65, 0.28)
		else
			shakeCamera(0.28, 0.13)
		end
	end
end)

RunService:BindToRenderStep("IMPACTCameraFX", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	if charging then
		local held = os.clock() - chargeStartedAt
		local progress = held / chargeDuration
		local state = "Normal"
		if held >= PERFECT_WINDOW_MIN and held <= PERFECT_WINDOW_MAX then
			state = "Perfect"
		elseif held >= OVERCHARGE_LIMIT then
			state = "Overcharge"
		elseif held < WEAK_MAX then
			state = "Weak"
		end
		setChargeVisual(progress, state)
	end

	if shakeTime <= 0 or shakePower <= 0 then
		shakePower = 0
		shakeTime = 0
		return
	end

	shakeTime -= deltaTime
	local camera = workspace.CurrentCamera
	if not camera then return end

	local t = os.clock() * shakeFrequency
	local fade = math.clamp(shakeTime / 0.28, 0, 1)
	local power = shakePower * fade
	local offset = Vector3.new(
		math.noise(t, 0, 0) * power,
		math.noise(0, t, 0) * power,
		0
	)
	local rotation = CFrame.Angles(
		math.rad(math.noise(t, 1, 0) * power * 1.5),
		math.rad(math.noise(1, t, 0) * power * 1.5),
		math.rad(math.noise(t, t, 1) * power * 2)
	)
	camera.CFrame = camera.CFrame * CFrame.new(offset) * rotation
end)

player.CharacterAdded:Connect(function()
	charging = false
	blocking = false
	chargeStartedAt = 0
	chargeFill.Size = UDim2.fromScale(0, 1)
	chargeText.Text = "HOLD  •  RELEASE"
	blockLabel.Text = "RMB  •  BLOCK"
end)

print(">>> IMPACT Clash CombatClient // HUD + IMPACT FX READY <<<")
