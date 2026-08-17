local Players = game:GetService("Players")

local function setup(player: Player)
	if player:FindFirstChild("leaderstats") then return end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = leaderstats

	local kos = Instance.new("IntValue")
	kos.Name = "KOs"
	kos.Value = 0
	kos.Parent = leaderstats
end

Players.PlayerAdded:Connect(setup)
for _, player in ipairs(Players:GetPlayers()) do
	setup(player)
end
