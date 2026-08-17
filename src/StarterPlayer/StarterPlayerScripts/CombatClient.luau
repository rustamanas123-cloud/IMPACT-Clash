local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local AttackRemote = ReplicatedStorage:WaitForChild("AttackRemote")
local ToggleBlock = ReplicatedStorage:WaitForChild("ToggleBlock")
local HitFXRemote = ReplicatedStorage:WaitForChild("HitFX")

local charging = false
local chargeStartedAt = 0
local cameraShake = 0
local cameraShakeDuration = 0
local cameraShakeFrequency = 35

local function shakeCamera(power: number, duration: number)
	cameraShake = math.max(cameraShake, power)
	cameraShakeDuration = math.max(cameraShakeDuration, duration)
end

local function playImpactSound(volume: number, playbackSpeed: number)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local sound = Instance.new("Sound")
	sound.Name = "PredictedImpact"
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.RollOffMaxDistance = 100
	sound.Parent = camera
	sound:Play()
	Debris:AddItem(sound, 2)
end

local function predictReleaseFX()
	shakeCamera(0.18, 0.10)
	playImpactSound(0.35, 0.82)
end

local function beginCharge()
	if charging then return end
	charging = true
	chargeStartedAt = os.clock()
	AttackRemote:FireServer("Start")
end

local function releaseCharge()
	if not charging then return end
	charging = false
	local heldFor = os.clock() - chargeStartedAt
	chargeStartedAt = 0

	predictReleaseFX()
	AttackRemote:FireServer("Release")

	if heldFor >= 0.85 and heldFor <= 0.98 then
		shakeCamera(0.10, 0.06)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		beginCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		ToggleBlock:FireServer(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		releaseCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		ToggleBlock:FireServer(false)
	end
end)

HitFXRemote.OnClientEvent:Connect(function(role, hitType)
	if role == "Attacker" then
		if hitType == "Finisher" then
			shakeCamera(0.32, 0.16)
			playImpactSound(0.65, 0.65)
		elseif hitType == "Perfect" then
			shakeCamera(0.24, 0.12)
			playImpactSound(0.55, 0.72)
		elseif hitType == "Blocked" then
			shakeCamera(0.10, 0.07)
			playImpactSound(0.42, 0.55)
		elseif hitType ~= "Miss" then
			shakeCamera(0.14, 0.08)
			playImpactSound(0.45, 0.78)
		end
	elseif role == "Victim" then
		if hitType == "Finisher" then
			shakeCamera(0.55, 0.24)
		elseif hitType == "Perfect" then
			shakeCamera(0.38, 0.18)
		elseif hitType == "Blocked" then
			shakeCamera(0.12, 0.08)
		else
			shakeCamera(0.25, 0.12)
		end
	end
end)

RunService:BindToRenderStep("IMPACTCameraShake", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	if cameraShakeDuration <= 0 or cameraShake <= 0 then
		cameraShake = 0
		cameraShakeDuration = 0
		return
	end

	cameraShakeDuration -= deltaTime
	local camera = workspace.CurrentCamera
	if not camera then return end

	local t = os.clock() * cameraShakeFrequency
	local fade = math.clamp(cameraShakeDuration / 0.24, 0, 1)
	local power = cameraShake * fade
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

player.CharacterRemoving:Connect(function()
	if charging then
		charging = false
		chargeStartedAt = 0
	end
end)

print(">>> IMPACT Clash CombatClient loaded <<<")
