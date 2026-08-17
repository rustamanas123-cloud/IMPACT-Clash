local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GameState = require(ServerScriptService:WaitForChild("GameState"))

local INTERMISSION_DURATION = 8
local ROUND_DURATION = 120
local MIN_PLAYERS = 1
local POST_ROUND_DELAY = 5

local function clearPlayerState(player)
	GameState.Participants[player] = nil
	GameState.Alive[player] = nil
	GameState.ChargeStarted[player] = nil
	GameState.StunnedUntil[player] = nil
	GameState.IsBlocking[player] = nil
	GameState.ComboCount[player] = nil
	GameState.LastAttackTime[player] = nil
	GameState.ComboExpiresAt[player] = nil
end

local function clearRoundState()
	local list = {}
	for player in pairs(GameState.Participants) do table.insert(list, player) end
	for _, player in ipairs(list) do clearPlayerState(player) end
end

local function spawnPoints()
	local result = {}
	local folder = workspace:FindFirstChild("Spawns")
	if folder then
		for _, object in ipairs(folder:GetChildren()) do
			if object:IsA("BasePart") then table.insert(result, object) end
		end
	end
	return result
end

local function teleportPlayer(player, index, total)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local points = spawnPoints()
	if #points > 0 then
		root.CFrame = points[((index - 1) % #points) + 1].CFrame + Vector3.new(0, 3, 0)
	else
		local angle = ((index - 1) / math.max(total, 1)) * math.pi * 2
		root.CFrame = CFrame.new(math.cos(angle) * 12, 4, math.sin(angle) * 12)
	end
end

local function hookDeath(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	humanoid.Died:Connect(function()
		if GameState.Participants[player] then
			GameState.Alive[player] = nil
			GameState.IsBlocking[player] = false
			GameState.ChargeStarted[player] = nil
		end
	end)
end

local function countAlive()
	local count = 0
	for player in pairs(GameState.Alive) do
		if GameState.Participants[player] then count += 1 end
	end
	return count
end

local function startRound()
	clearRoundState()
	GameState.Current = GameState.States.ROUND
	local players = Players:GetPlayers()
	for _, player in ipairs(players) do
		GameState.Participants[player] = true
		GameState.Alive[player] = true
		GameState.IsBlocking[player] = false
		GameState.ComboCount[player] = 0
		GameState.ComboExpiresAt[player] = 0
		GameState.LastAttackTime[player] = 0
		player:LoadCharacter()
	end

	task.wait(0.75)
	local active = Players:GetPlayers()
	for index, player in ipairs(active) do
		if GameState.Participants[player] then teleportPlayer(player, index, #active) end
		if player.Character then hookDeath(player, player.Character) end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		if GameState.Current == GameState.States.ROUND and GameState.Participants[player] then
			hookDeath(player, character)
		end
	end)
end)

Players.PlayerRemoving:Connect(clearPlayerState)

task.spawn(function()
	while true do
		GameState.Current = GameState.States.LOBBY
		while #Players:GetPlayers() < MIN_PLAYERS do task.wait(1) end

		GameState.Current = GameState.States.INTERMISSION
		for _ = INTERMISSION_DURATION, 1, -1 do
			if #Players:GetPlayers() < MIN_PLAYERS then break end
			task.wait(1)
		end
		if #Players:GetPlayers() < MIN_PLAYERS then continue end

		startRound()
		local endTime = os.clock() + ROUND_DURATION
		while GameState.Current == GameState.States.ROUND and os.clock() < endTime do
			if countAlive() <= 1 then break end
			task.wait(0.15)
		end

		GameState.Current = GameState.States.ENDED
		for player in pairs(GameState.Participants) do
			GameState.ChargeStarted[player] = nil
			GameState.IsBlocking[player] = false
		end
		task.wait(POST_ROUND_DELAY)
	end
end)

print(">>> IMPACT Clash GameLoop // ROUND SYSTEM READY <<<")
