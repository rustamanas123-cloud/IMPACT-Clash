local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameState = require(ServerScriptService:WaitForChild("GameState"))
local ArenaController = require(ServerScriptService:WaitForChild("ArenaController"))
local MatchRemote = ReplicatedStorage:WaitForChild("MatchRemote")

local INTERMISSION_DURATION = 8
local ROUND_DURATION = 75
local POST_ROUND_DELAY = 6
local NORMAL_MIN_PLAYERS = 2
local SHRINK_STEPS = {
	{at = 15, radius = 36},
	{at = 30, radius = 28},
	{at = 45, radius = 20},
	{at = 60, radius = 12},
}

local MIN_PLAYERS = RunService:IsStudio() and 1 or NORMAL_MIN_PLAYERS
local SOLO_TEST = RunService:IsStudio()

local function fireState(state: string, remaining: number, alive: number, total: number)
	MatchRemote:FireAllClients("State", state, math.max(0, math.ceil(remaining)), alive, total, GameState.RoundNumber)
end

local function clearPlayerState(player: Player)
	GameState.Participants[player] = nil
	GameState.Alive[player] = nil
	GameState.ChargeStarted[player] = nil
	GameState.StunnedUntil[player] = nil
	GameState.IsBlocking[player] = nil
	GameState.ComboCount[player] = nil
	GameState.LastAttackTime[player] = nil
	GameState.ComboExpiresAt[player] = nil
	GameState.DashReadyAt[player] = nil
end

local function clearRoundState()
	local list = {}
	for player in pairs(GameState.Participants) do table.insert(list, player) end
	for _, player in ipairs(list) do clearPlayerState(player) end
end

local function countAlive(): number
	local count = 0
	for player in pairs(GameState.Alive) do
		if GameState.Participants[player] then count += 1 end
	end
	return count
end

local function eliminate(player: Player, reason: string)
	if not GameState.Participants[player] or not GameState.Alive[player] then return end
	GameState.Alive[player] = nil
	GameState.IsBlocking[player] = false
	GameState.ChargeStarted[player] = nil
	GameState.StunnedUntil[player] = nil
	MatchRemote:FireAllClients("Eliminated", player.UserId, player.DisplayName, reason)

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then humanoid.Health = 0 end
end

local function hookDeath(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	humanoid.Died:Connect(function()
		if GameState.Participants[player] then
			GameState.Alive[player] = nil
			GameState.IsBlocking[player] = false
			GameState.ChargeStarted[player] = nil
			MatchRemote:FireAllClients("Eliminated", player.UserId, player.DisplayName, "KO")
		end
	end)
end

local function teleportToSpawn(player: Player, index: number, total: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local points = ArenaController.GetSpawnPoints()
	if #points > 0 then
		local point = points[((index - 1) % #points) + 1]
		root.CFrame = point.CFrame + Vector3.new(0, 3, 0)
	else
		local angle = ((index - 1) / math.max(total, 1)) * math.pi * 2
		root.CFrame = CFrame.new(math.cos(angle) * 12, 5, math.sin(angle) * 12)
	end
	root.AssemblyLinearVelocity = Vector3.zero
end

local function startRound()
	clearRoundState()
	ArenaController.ResetRadius()
	GameState.RoundNumber += 1
	GameState.Winner = nil
	GameState.Current = GameState.States.ROUND

	local participants = Players:GetPlayers()
	for _, player in ipairs(participants) do
		GameState.Participants[player] = true
		GameState.Alive[player] = true
		GameState.IsBlocking[player] = false
		GameState.ComboCount[player] = 0
		GameState.ComboExpiresAt[player] = 0
		GameState.LastAttackTime[player] = 0
		GameState.DashReadyAt[player] = 0
		player:LoadCharacter()
	end

	task.wait(0.85)

	local active = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if GameState.Participants[player] and player.Character then
			table.insert(active, player)
			hookDeath(player, player.Character)
		end
	end

	for index, player in ipairs(active) do teleportToSpawn(player, index, #active) end
	MatchRemote:FireAllClients("RoundStart", GameState.RoundNumber, #active)
end

local function findWinner(): Player?
	local winner: Player? = nil
	for player in pairs(GameState.Alive) do
		if GameState.Participants[player] then
			if winner then return nil end
			winner = player
		end
	end
	return winner
end

local function waitForStats(player: Player)
	local deadline = os.clock() + 5
	while player.Parent and player:GetAttribute("StatsLoaded") ~= true and os.clock() < deadline do
		task.wait(0.1)
	end
	return player.Parent ~= nil
end

local function adjustIntStat(player: Player, statName: string, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(statName)
	if value and value:IsA("IntValue") then
		value.Value = math.max(0, value.Value + amount)
	end
end

local function sendWinner(winner: Player?)
	GameState.Winner = winner

	for player in pairs(GameState.Participants) do
		if player.Parent then waitForStats(player) end
	end

	if winner then
		adjustIntStat(winner, "Wins", 1)
		adjustIntStat(winner, "Coins", 50)
		adjustIntStat(winner, "Streak", 1)

		for player in pairs(GameState.Participants) do
			if player ~= winner and player.Parent then
				adjustIntStat(player, "Coins", 10)
				adjustIntStat(player, "Streak", -1000000)
			end
		end

		MatchRemote:FireAllClients("Winner", winner.UserId, winner.DisplayName)
	else
		for player in pairs(GameState.Participants) do
			if player.Parent then
				adjustIntStat(player, "Coins", 10)
				adjustIntStat(player, "Streak", -1000000)
			end
		end
		MatchRemote:FireAllClients("Winner", 0, "NO WINNER")
	end
end

ArenaController.Build()

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		if GameState.Current == GameState.States.ROUND and GameState.Participants[player] then hookDeath(player, character) end
	end)
end)

Players.PlayerRemoving:Connect(clearPlayerState)

task.spawn(function()
	while true do
		GameState.Current = GameState.States.LOBBY
		GameState.Winner = nil
		ArenaController.ResetRadius()

		while #Players:GetPlayers() < MIN_PLAYERS do
			fireState(GameState.States.LOBBY, 0, countAlive(), 0)
			task.wait(1)
		end

		GameState.Current = GameState.States.INTERMISSION
		local intermissionEnds = os.clock() + INTERMISSION_DURATION
		while os.clock() < intermissionEnds do
			if #Players:GetPlayers() < MIN_PLAYERS then break end
			fireState(GameState.States.INTERMISSION, intermissionEnds - os.clock(), 0, #Players:GetPlayers())
			task.wait(0.25)
		end
		if #Players:GetPlayers() < MIN_PLAYERS then continue end

		startRound()
		local roundStart = os.clock()
		GameState.RoundEndsAt = roundStart + ROUND_DURATION
		local nextShrink = 1

		while GameState.Current == GameState.States.ROUND and os.clock() < GameState.RoundEndsAt do
			local elapsed = os.clock() - roundStart
			local alive = countAlive()
			fireState(GameState.States.ROUND, GameState.RoundEndsAt - os.clock(), alive, #Players:GetPlayers())

			local shrinkStep = SHRINK_STEPS[nextShrink]
			if shrinkStep and elapsed >= shrinkStep.at then
				ArenaController.SetRadius(shrinkStep.radius)
				MatchRemote:FireAllClients("Shrink", shrinkStep.radius, shrinkStep.at)
				nextShrink += 1
			end

			local center = ArenaController.GetCenter()
			local radius = ArenaController.GetRadius()
			for player in pairs(GameState.Alive) do
				if GameState.Participants[player] then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root then
						local flatOffset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
						if flatOffset.Magnitude > radius + 0.5 or root.Position.Y < -7 then eliminate(player, "FALL") end
					end
				end
			end

			if (not SOLO_TEST and alive <= 1) or (SOLO_TEST and alive <= 0) then break end
			task.wait(0.12)
		end

		GameState.Current = GameState.States.ENDED
		for player in pairs(GameState.Participants) do
			GameState.ChargeStarted[player] = nil
			GameState.IsBlocking[player] = false
		end

		local winner = findWinner()
		sendWinner(winner)
		fireState(GameState.States.ENDED, POST_ROUND_DELAY, countAlive(), #Players:GetPlayers())
		task.wait(POST_ROUND_DELAY)
	end
end)

print(">>> IMPACT Clash GameLoop // PERSISTENT REWARDS + CYBER ARENA ONLINE <<<")
