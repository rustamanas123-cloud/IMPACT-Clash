local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ImpactCombatUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local AttackRemote = ReplicatedStorage:WaitForChild("AttackRemote")
local ToggleBlock = ReplicatedStorage:WaitForChild("ToggleBlock")
local HitFXRemote = ReplicatedStorage:WaitForChild("HitFX")

local charging = false
local blocking = false
local chargeStart = 0
local shakePower = 0
local shakeTime = 0
local baseFOV = 70
local PERFECT_MIN = 0.85
local PERFECT_MAX = 0.98
local OVERCHARGE = 1.02

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -48)
bar.Size = UDim2.fromOffset(420, 18)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
bar.BorderSizePixel = 0
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(90, 180, 255)
fill.BorderSizePixel = 0
fill.Parent = bar
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

local barText = Instance.new("TextLabel")
barText.Size = UDim2.fromOffset(420, 24)
barText.Position = UDim2.new(0.5, -210, 0, -25)
barText.BackgroundTransparency = 1
barText.Text = "HOLD • RELEASE"
barText.TextColor3 = Color3.fromRGB(205, 215, 230)
barText.Font = Enum.Font.GothamBold
barText.TextSize = 13
barText.Parent = bar

local comboText = Instance.new("TextLabel")
comboText.AnchorPoint = Vector2.new(1, 0)
comboText.Position = UDim2.new(1, -38, 0, 38)
comboText.Size = UDim2.fromOffset(280, 58)
comboText.BackgroundTransparency = 1
comboText.TextTransparency = 1
comboText.TextColor3 = Color3.fromRGB(255, 205, 70)
comboText.TextStrokeTransparency = 0
comboText.Font = Enum.Font.FredokaOne
comboText.TextScaled = true
comboText.Parent = gui

local centerText = Instance.new("TextLabel")
centerText.AnchorPoint = Vector2.new(0.5, 0.5)
centerText.Position = UDim2.fromScale(0.5, 0.40)
centerText.Size = UDim2.fromOffset(650, 100)
centerText.BackgroundTransparency = 1
centerText.TextTransparency = 1
centerText.TextStrokeTransparency = 0.15
centerText.Font = Enum.Font.FredokaOne
centerText.TextScaled = true
centerText.Parent = gui

local flashFrame = Instance.new("Frame")
flashFrame.Size = UDim2.fromScale(1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.Parent = gui

local function shake(power, duration)
	shakePower = math.max(shakePower, power)
	shakeTime = math.max(shakeTime, duration)
end

local function fovPunch(amount, duration)
	local camera = workspace.CurrentCamera
	if not camera then return end
	TweenService:Create(camera, TweenInfo.new(duration * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseFOV + amount}):Play()
	task.delay(duration * 0.3, function()
		if workspace.CurrentCamera == camera then
			TweenService:Create(camera, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FieldOfView = baseFOV}):Play()
		end
	end)
end

local function flash(color, transparency, duration)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = transparency
	TweenService:Create(flashFrame, TweenInfo.new(duration), {BackgroundTransparency = 1}):Play()
end

local function message(text, color)
	centerText.Text = text
	centerText.TextColor3 = color
	centerText.TextTransparency = 0
	TweenService:Create(centerText, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(680, 105)}):Play()
	task.delay(0.45, function()
		TweenService:Create(centerText, TweenInfo.new(0.22), {TextTransparency = 1}):Play()
	end)
end

local function comboFeedback(combo)
	if combo <= 1 then comboText.TextTransparency = 1 return end
	comboText.Text = "x" .. combo .. " COMBO"
	comboText.TextColor3 = combo >= 3 and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 205, 70)
	comboText.TextTransparency = 0
	task.delay(0.9, function()
		if comboText.Text == "x" .. combo .. " COMBO" then
			TweenService:Create(comboText, TweenInfo.new(0.18), {TextTransparency = 1}):Play()
		end
	end)
end

local function updateCharge()
	if not charging then return end
	local held = os.clock() - chargeStart
	fill.Size = UDim2.fromScale(math.clamp(held / OVERCHARGE, 0, 1), 1)
	if held >= PERFECT_MIN and held <= PERFECT_MAX then
		fill.BackgroundColor3 = Color3.fromRGB(255, 190, 55)
		barText.Text = "PERFECT WINDOW"
	elseif held >= OVERCHARGE then
		fill.BackgroundColor3 = Color3.fromRGB(255, 55, 65)
		barText.Text = "OVERCHARGE"
	elseif held < 0.40 then
		fill.BackgroundColor3 = Color3.fromRGB(90, 180, 255)
		barText.Text = "WEAK"
	else
		fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
		barText.Text = "CHARGING"
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not charging and not blocking then
		charging = true
		chargeStart = os.clock()
		AttackRemote:FireServer("Start")
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not charging then
		blocking = true
		ToggleBlock:FireServer(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and charging then
		charging = false
		local held = os.clock() - chargeStart
		chargeStart = 0
		AttackRemote:FireServer("Release")
		shake(0.05, 0.05)
		if held >= PERFECT_MIN and held <= PERFECT_MAX then
			shake(0.10, 0.07)
			fovPunch(4, 0.15)
		end
		fill.Size = UDim2.fromScale(0, 1)
		barText.Text = "HOLD • RELEASE"
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and blocking then
		blocking = false
		ToggleBlock:FireServer(false)
	end
end)

HitFXRemote.OnClientEvent:Connect(function(role, hitType, combo)
	combo = combo or 0
	if role == "Attacker" then
		if hitType == "Finisher" then shake(0.38, 0.18) fovPunch(8, 0.20) flash(Color3.fromRGB(255,45,45), 0.88, 0.14) message("FINISHER", Color3.fromRGB(255,65,65)) comboFeedback(3)
		elseif hitType == "Perfect" then shake(0.24, 0.12) fovPunch(5, 0.16) flash(Color3.fromRGB(255,195,55), 0.92, 0.10) message("PERFECT", Color3.fromRGB(255,205,70)) comboFeedback(combo)
		elseif hitType == "Blocked" then shake(0.12, 0.08) message("BLOCKED", Color3.fromRGB(120,200,255))
		elseif hitType == "Overcharge" then shake(0.22, 0.20) flash(Color3.fromRGB(255,45,55), 0.86, 0.18) message("OVERCHARGE", Color3.fromRGB(255,70,70))
		elseif hitType ~= "Miss" then shake(0.14, 0.08) comboFeedback(combo) end
	elseif role == "Victim" then
		if hitType == "Finisher" then shake(0.65, 0.26) fovPunch(-8, 0.25) flash(Color3.fromRGB(255,25,35), 0.76, 0.20)
		elseif hitType == "Perfect" then shake(0.42, 0.18) fovPunch(-5, 0.18) flash(Color3.fromRGB(255,170,45), 0.84, 0.14)
		elseif hitType == "KO" then shake(0.85, 0.35) fovPunch(-10, 0.30) flash(Color3.fromRGB(255,20,30), 0.65, 0.28)
		else shake(0.28, 0.13) end
	end
end)

RunService:BindToRenderStep("IMPACTCameraFX", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	updateCharge()
	if shakeTime <= 0 or shakePower <= 0 then shakePower = 0 shakeTime = 0 return end
	shakeTime -= deltaTime
	local camera = workspace.CurrentCamera
	if not camera then return end
	local t = os.clock() * 38
	local fade = math.clamp(shakeTime / 0.28, 0, 1)
	local power = shakePower * fade
	local offset = Vector3.new(math.noise(t,0,0)*power, math.noise(0,t,0)*power, 0)
	local rotation = CFrame.Angles(math.rad(math.noise(t,1,0)*power*1.5), math.rad(math.noise(1,t,0)*power*1.5), math.rad(math.noise(t,t,1)*power*2))
	camera.CFrame = camera.CFrame * CFrame.new(offset) * rotation
end)

print(">>> IMPACT Clash CombatClient // LOCAL FX READY <<<")
