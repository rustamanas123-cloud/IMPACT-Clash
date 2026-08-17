local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local DashRemote = ReplicatedStorage:WaitForChild("DashRemote")

local COOLDOWN = 1.15
local localReadyAt = 0

local function playDashFX()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, 0.8, 1.1)
	attachment0.Parent = root

	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, 0.8, -1.1)
	attachment1.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = 0.16
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(80, 190, 255), Color3.fromRGB(255, 70, 140))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = root

	local ring = Instance.new("Part")
	ring.Name = "DashRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(90, 190, 255)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(2.5, 0.08, 2.5)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(9, 0.03, 9),
		Transparency = 1,
	}):Play()

	Debris:AddItem(trail, 0.22)
	Debris:AddItem(attachment0, 0.25)
	Debris:AddItem(attachment1, 0.25)
	Debris:AddItem(ring, 0.3)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode ~= Enum.KeyCode.Q then return end

	local now = os.clock()
	if now < localReadyAt then return end
	localReadyAt = now + COOLDOWN

	playDashFX()
	DashRemote:FireServer()
end)

print(">>> IMPACT Clash Dash // ONLINE <<<")
