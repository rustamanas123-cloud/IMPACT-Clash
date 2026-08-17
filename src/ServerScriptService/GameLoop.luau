local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GameState = require(ServerScriptService:WaitForChild("GameState"))

local INTERMISSION_DURATION = 8
local ROUND_DURATION = 120
local MIN_PLAYERS = 1

local function getSpawnPoints()
	local points = {}
	local folder = workspace:FindFirstChild("Spawns")
	if folder then
		for _, object in ipairs(folder:GetChildren()) do
			if object:IsA("BasePart") then
				table.insert(points, object)
			end
		end
	end
	return points
end

local function teleportPlayer(player: Player, index: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawns = getSpawnPoints()
	if #spawns > 0 then
		local spawnPart = spawns[((index - 1) % #spawns) + 1]
		root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
	else
		local angle = ((index - 1) / math.max(#Players:GetPlayers(), 1)) * math.pi * 2
		root.CFrame = CFrame.new(math.cos(angle) * 12, 4, math.sin(angle) * 12)
	end
end

local function clearRoundState()
	for player in pairs(GameState.Participants) do
		GameState.Participants[player] = nil
		GameState.Alive[player] = nil
		GameState.ChargeStarted[player] = nil
		GameState.StunnedUntil[player] = nil
		GameState.IsBlocking[player] = nil
		GameState.ComboCount[player] = nil
		GameState.LastAttackTime[player] = nil
		GameState.ComboExpiresAt[player] = nil
	end
end

local function startRound()
	clearRoundState()
	GameState.Current = GameState.States.ROUND

	local index = 0
	for _, player in ipairs(Players:GetPlayers()) do
		index += 1
		GameState.Participants[player] = true
		GameState.Alive[player] = true
		GameState.IsBlocking[player] = false
		GameState.ComboCount[player] = 0
		GameState.ComboExpiresAt[player] = 0
		player:LoadCharacter()
	end

	task.wait(0.75)
	index = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if GameState.Participants[player] then
			index += 1
			teleportPlayer(player, index)
		end
	end
end

local function countAlive()
	local count = 0
	for player in pairs(GameState.Alive) do
		if GameState.Participants[player] then
			count += 1
		end
	end
	return count
end

Players.PlayerRemoving:Connect(function(player)
	GameState.Participants[player] = nil
	GameState.Alive[player] = nil
	GameState.ChargeStarted[player] = nil
	GameState.StunnedUntil[player] = nil
	GameState.IsBlocking[player] = nil
	GameState.ComboCount[player] = nil
	GameState.LastAttackTime[player] = nil
	GameState.ComboExpiresAt[player] = nil
end)

task.spawn(function()
	while true do
		GameState.Current = GameState.States.LOBBY
		while #Players:GetPlayers() < MIN_PLAYERS do
			task.wait(1)
		end

		GameState.Current = GameState.States.INTERMISSION
		for _ = INTERMISSION_DURATION, 1, -1 do
			if #Players:GetPlayers() < MIN_PLAYERS then break end
			task.wait(1)
		end

		if #Players:GetPlayers() < MIN_PLAYERS then
			continue
		end

		startRound()
		local roundEndsAt = os.clock() + ROUND_DURATION

		while GameState.Current == GameState.States.ROUND and os.clock() < roundEndsAt do
			if countAlive() <= 1 then break end
			task.wait(0.25)
		end

		GameState.Current = GameState.States.ENDED
		for player in pairs(GameState.ChargeStarted) do
			GameState.ChargeStarted[player] = nil
			GameState.IsBlocking[player] = false
		end
		task.wait(5)
	end
end)

print(">>> IMPACT Clash GameLoop loaded <<<")
