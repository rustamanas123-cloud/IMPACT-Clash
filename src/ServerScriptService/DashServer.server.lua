local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GameState = require(ServerScriptService:WaitForChild("GameState"))
local DashRemote = ReplicatedStorage:WaitForChild("DashRemote")

local DASH_SPEED = 72
local DASH_DURATION = 0.16
local DASH_COOLDOWN = 1.15
local MAX_DASH_RATE = 5

local rateState = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	local state = rateState[player]
	if not state or now - state.window >= 1 then
		rateState[player] = {window = now, count = 1}
		return true
	end
	state.count += 1
	return state.count <= MAX_DASH_RATE
end

DashRemote.OnServerEvent:Connect(function(player)
	if not allowed(player) then return end
	if GameState.Current ~= GameState.States.ROUND then return end
	if not GameState.Participants[player] or not GameState.Alive[player] then return end

	local now = os.clock()
	if now < (GameState.DashReadyAt[player] or 0) then return end
	GameState.DashReadyAt[player] = now + DASH_COOLDOWN

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if direction.Magnitude < 0.1 then return end
	direction = direction.Unit

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local attachment = Instance.new("Attachment")
	attachment.Name = "ImpactDashAttachment"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "ImpactDash"
	velocity.MaxForce = 200000
	velocity.VectorVelocity = direction * DASH_SPEED + Vector3.new(0, 2, 0)
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Parent = root

	task.delay(DASH_DURATION, function()
		if velocity.Parent then velocity:Destroy() end
		if attachment.Parent then attachment:Destroy() end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	rateState[player] = nil
end)
