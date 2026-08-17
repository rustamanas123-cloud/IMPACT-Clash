local Lighting = game:GetService("Lighting")

local ArenaController = {}

local MODEL_NAME = "IMPACT_ARENA"
local START_RADIUS = 46
local CENTER = Vector3.new(0, 0, 0)
local EDGE_SEGMENTS = 48

local currentRadius = START_RADIUS
local edgeParts = {}
local spawnPoints = {}
local arenaModel: Model? = nil

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3, transparency: number?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.Material = material
	part.Color = color
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addLight(parent: Instance, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = parent
end

local function updateEdge(radius: number)
	currentRadius = radius
	for index, edge in ipairs(edgeParts) do
		local angle = ((index - 1) / EDGE_SEGMENTS) * math.pi * 2
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local position = CENTER + Vector3.new(math.cos(angle) * radius, 0.9, math.sin(angle) * radius)
		edge.CFrame = CFrame.lookAt(position, position + tangent)
	end

	if arenaModel then
		local platform = arenaModel:FindFirstChild("Platform")
		if platform and platform:IsA("BasePart") then
			platform.Size = Vector3.new(radius * 2, 2.2, radius * 2)
		end
	end
end

local function configureLighting()
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 18.3
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.9

	local atmosphere = Lighting:FindFirstChild("ImpactAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "ImpactAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(150, 170, 205)
	atmosphere.Decay = Color3.fromRGB(55, 45, 80)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.1

	local bloom = Lighting:FindFirstChild("ImpactBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "ImpactBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 1.0
	bloom.Size = 28
	bloom.Threshold = 0.85

	local color = Lighting:FindFirstChild("ImpactColor")
	if not color then
		color = Instance.new("ColorCorrectionEffect")
		color.Name = "ImpactColor"
		color.Parent = Lighting
	end
	color.Contrast = 0.18
	color.Saturation = 0.12
	color.TintColor = Color3.fromRGB(215, 225, 255)
end

function ArenaController.Build()
	local old = workspace:FindFirstChild(MODEL_NAME)
	if old then old:Destroy() end

	arenaModel = Instance.new("Model")
	arenaModel.Name = MODEL_NAME
	arenaModel.Parent = workspace
	edgeParts = {}
	spawnPoints = {}

	configureLighting()

	local platform = makePart(arenaModel, "Platform", Vector3.new(START_RADIUS * 2, 2.2, START_RADIUS * 2), CFrame.new(CENTER), Enum.Material.Metal, Color3.fromRGB(24, 28, 40))
	platform.Shape = Enum.PartType.Cylinder
	platform.CanCollide = true
	platform.CanTouch = true

	local top = makePart(arenaModel, "CombatDeck", Vector3.new(START_RADIUS * 2 - 1.2, 0.35, START_RADIUS * 2 - 1.2), CFrame.new(CENTER + Vector3.new(0, 1.15, 0)), Enum.Material.SmoothPlastic, Color3.fromRGB(16, 20, 30))
	top.Shape = Enum.PartType.Cylinder

	local centerDisc = makePart(arenaModel, "CenterDisc", Vector3.new(12, 0.35, 12), CFrame.new(0, 1.37, 0), Enum.Material.Neon, Color3.fromRGB(40, 80, 150), 0.22)
	centerDisc.Shape = Enum.PartType.Cylinder
	addLight(centerDisc, Color3.fromRGB(60, 150, 255), 2.5, 18)

	local centerRing = makePart(arenaModel, "CenterRing", Vector3.new(14, 0.22, 14), CFrame.new(0, 1.58, 0), Enum.Material.Neon, Color3.fromRGB(255, 70, 110), 0.48)
	centerRing.Shape = Enum.PartType.Cylinder

	for i = 1, 12 do
		local angle = ((i - 1) / 12) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 18, 1.65, math.sin(angle) * 18)
		local pillar = makePart(arenaModel, "Pillar_" .. i, Vector3.new(1.4, 6, 1.4), CFrame.new(pos), Enum.Material.Metal, Color3.fromRGB(35, 40, 55))
		addLight(pillar, Color3.fromRGB(120, 60, 255), 1.4, 12)
		local glow = Instance.new("Beam")
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 2.3, 0)
		a0.Parent = pillar
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -2.3, 0)
		a1.Parent = pillar
		glow.Attachment0 = a0
		glow.Attachment1 = a1
		glow.Width0 = 0.25
		glow.Width1 = 0.25
		glow.LightEmission = 1
		glow.Color = ColorSequence.new(Color3.fromRGB(90, 150, 255), Color3.fromRGB(255, 70, 140))
		glow.Parent = pillar
	end

	for i = 1, EDGE_SEGMENTS do
		local angle = ((i - 1) / EDGE_SEGMENTS) * math.pi * 2
		local position = CENTER + Vector3.new(math.cos(angle) * START_RADIUS, 1.15, math.sin(angle) * START_RADIUS)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local edge = makePart(arenaModel, "EdgeGlow_" .. i, Vector3.new(0.8, 0.55, 2.9), CFrame.lookAt(position, position + tangent), Enum.Material.Neon, Color3.fromRGB(255, 70, 115), 0.12)
		edge.CanCollide = false
		edgeParts[i] = edge
	end

	local killPlane = makePart(arenaModel, "KillPlane", Vector3.new(220, 1, 220), CFrame.new(0, -12, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(12, 10, 20), 0.2)
	killPlane.CanCollide = false

	for i = 1, 12 do
		local angle = ((i - 1) / 12) * math.pi * 2 + math.rad(15)
		local position = Vector3.new(math.cos(angle) * 30, 4, math.sin(angle) * 30)
		local spawn = makePart(arenaModel, "Spawn_" .. i, Vector3.new(2, 0.5, 2), CFrame.new(position), Enum.Material.Neon, Color3.fromRGB(255, 255, 255), 1)
		spawn.CanCollide = false
		spawn.CanTouch = false
		table.insert(spawnPoints, spawn)
	end

	local lobby = makePart(arenaModel, "LobbySpawn", Vector3.new(8, 1, 8), CFrame.new(0, 8, 70), Enum.Material.Neon, Color3.fromRGB(70, 120, 255), 0.6)
	lobby.CanCollide = false
	addLight(lobby, Color3.fromRGB(70, 140, 255), 2, 18)

	updateEdge(START_RADIUS)
end

function ArenaController.SetRadius(radius: number)
	updateEdge(math.clamp(radius, 8, START_RADIUS))
end

function ArenaController.GetRadius(): number
	return currentRadius
end

function ArenaController.GetCenter(): Vector3
	return CENTER
end

function ArenaController.GetSpawnPoints(): {BasePart}
	return spawnPoints
end

function ArenaController.GetLobbySpawn(): BasePart?
	if not arenaModel then return nil end
	local lobby = arenaModel:FindFirstChild("LobbySpawn")
	return lobby and lobby:IsA("BasePart") and lobby or nil
end

function ArenaController.ResetRadius()
	updateEdge(START_RADIUS)
end

return ArenaController
