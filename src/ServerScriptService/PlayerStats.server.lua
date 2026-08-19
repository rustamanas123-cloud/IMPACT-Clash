local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local STATS_STORE = DataStoreService:GetDataStore("IMPACT_CLASH_PLAYER_DATA_V1")
local AUTOSAVE_INTERVAL = 60

local loaded: {[Player]: boolean} = {}
local saving: {[Player]: boolean} = {}

local function setupLeaderstats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local defaults = {
		Wins = 0,
		KOs = 0,
		Coins = 0,
		Streak = 0,
	}

	for name, defaultValue in pairs(defaults) do
		local value = leaderstats:FindFirstChild(name)
		if not value then
			value = Instance.new("IntValue")
			value.Name = name
			value.Value = defaultValue
			value.Parent = leaderstats
		elseif not value:IsA("IntValue") then
			value:Destroy()
			local replacement = Instance.new("IntValue")
			replacement.Name = name
			replacement.Value = defaultValue
			replacement.Parent = leaderstats
		end
	end

	player:SetAttribute("StatsLoaded", false)
	player:SetAttribute("CanSaveStats", false)
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function loadData(player: Player)
	local leaderstats = player:WaitForChild("leaderstats")

	local success, data = pcall(function()
		return STATS_STORE:GetAsync(keyFor(player))
	end)

	if not success then
		warn("[PlayerStats] Load failed for " .. player.Name .. ": " .. tostring(data))
		return
	end

	if type(data) == "table" then
		for _, name in ipairs({"Wins", "KOs", "Coins", "Streak"}) do
			local value = leaderstats:FindFirstChild(name)
			if value and value:IsA("IntValue") then
				value.Value = math.max(0, math.floor(tonumber(data[name]) or 0))
			end
		end
	end

	loaded[player] = true
	player:SetAttribute("StatsLoaded", true)
	player:SetAttribute("CanSaveStats", true)
end

local function saveData(player: Player): boolean
	if not loaded[player] or saving[player] or player:GetAttribute("CanSaveStats") ~= true then
		return false
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end

	local payload = {}
	for _, name in ipairs({"Wins", "KOs", "Coins", "Streak"}) do
		local value = leaderstats:FindFirstChild(name)
		if value and value:IsA("IntValue") then
			payload[name] = value.Value
		end
	end

	saving[player] = true
	local success, err = pcall(function()
		STATS_STORE:UpdateAsync(keyFor(player), function()
			return payload
		end)
	end)
	saving[player] = nil

	if not success then
		warn("[PlayerStats] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end

	return true
end

local function onPlayerAdded(player: Player)
	if player:FindFirstChild("leaderstats") then return end
	setupLeaderstats(player)
	task.spawn(loadData, player)
end

local function onPlayerRemoving(player: Player)
	saveData(player)
	loaded[player] = nil
	saving[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in pairs(loaded) do
			task.spawn(saveData, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in pairs(loaded) do
		pending += 1
		task.spawn(function()
			saveData(player)
			pending -= 1
		end)
	end

	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

print(">>> IMPACT Clash PlayerStats // PERSISTENT LEADERBOARD READY <<<")
