local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local GameState = require(ServerScriptService:WaitForChild("GameState"))

local AttackRemote = ReplicatedStorage:WaitForChild("AttackRemote")
local ToggleBlock = ReplicatedStorage:WaitForChild("ToggleBlock")
local HitFXRemote = ReplicatedStorage:FindFirstChild("HitFX")

if not HitFXRemote then
	HitFXRemote = Instance.new("RemoteEvent")
	HitFXRemote.Name = "HitFX"
	HitFXRemote.Parent = ReplicatedStorage
end

local WEAK_MAX = 0.4
local PERFECT_WINDOW_MIN = 0.85
local PERFECT_WINDOW_MAX = 0.98
local OVERCHARGE_LIMIT = 1.02
local ATTACK_RANGE = 15
local MIN_DOT = 0.3
local STUN_DURATION = 0.45
local ATTACK_COOLDOWN = 0.6
local COMBO_WINDOW_DURATION = 0.73

local function isStunned(player: Player): boolean
	local untilTime = GameState.StunnedUntil[player]
	if not untilTime then return false end
	if os.clock() >= untilTime then
		GameState.StunnedUntil[player] = nil
		return false
	end
	return true
end

local function resetCombo(player: Player)
	GameState.ComboCount[player] = 0
	GameState.ComboExpiresAt[player] = 0
end

local function applyKnockback(attackerRoot: BasePart, victimRoot: BasePart, horizontalSpeed: number, upwardSpeed: number)
	local direction = attackerRoot.CFrame.LookVector
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.001 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	-- Смягчённая компенсация массы: тяжёлый аватар не становится неуязвимым,
	-- а лёгкий не улетает с чрезмерным ускорением. sqrt даёт мягкую кривую.
	local attackerMass = math.max(attackerRoot.AssemblyMass, 1)
	local victimMass = math.max(victimRoot.AssemblyMass, 1)
	local massRatio = math.sqrt(attackerMass / victimMass)
	local massFactor = math.clamp(massRatio, 0.78, 1.22)

	local velocityVector = direction * (horizontalSpeed * massFactor) + Vector3.new(0, upwardSpeed * massFactor, 0)
	local attachment = Instance.new("Attachment")
	attachment.Name = "CombatKnockbackAttachment"
	attachment.Parent = victimRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "CombatKnockback"
	linearVelocity.MaxForce = 200000
	linearVelocity.VectorVelocity = velocityVector
	linearVelocity.Attachment0 = attachment
	linearVelocity.Parent = victimRoot

	task.delay(0.12, function()
		if linearVelocity.Parent then linearVelocity:Destroy() end
		if attachment.Parent then attachment:Destroy() end
	end)
end

local function showDamageIndicator(part: BasePart, damage: number, isPerfect: boolean, comboStep: number, isFinisher: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageIndicator"
	billboard.Size = UDim2.new(0, 140, 0, 70)
	billboard.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2, math.random(-15, 15) / 10)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = isFinisher and (tostring(damage) .. " [FINISHER!]") or (comboStep > 1 and (tostring(damage) .. " (" .. comboStep .. " COMBO)") or tostring(damage))
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = isFinisher and Color3.fromRGB(255, 30, 30) or (isPerfect and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(255, 255, 255))
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = billboard

	local tweenPos = TweenService:Create(billboard, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, 4, 0)
	})
	local tweenText = TweenService:Create(textLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	tweenPos:Play()
	tweenText:Play()

	task.delay(1, function()
		if billboard.Parent then billboard:Destroy() end
	end)
end

local function getHitTarget(attacker: Player): Model?
	local attackerChar = attacker.Character
	local attackerRoot = attackerChar and attackerChar.PrimaryPart
	if not attackerRoot then return nil end

	local attackerPos = attackerRoot.Position
	local attackerLook = attackerRoot.CFrame.LookVector
	local bestTarget: Model? = nil
	local closestDist = ATTACK_RANGE

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= attacker and GameState.Participants[player] and GameState.Alive[player] then
			local victimChar = player.Character
			local victimRoot = victimChar and victimChar.PrimaryPart
			local humanoid = victimChar and victimChar:FindFirstChildOfClass("Humanoid")
			if victimRoot and humanoid and humanoid.Health > 0 then
				local offset = victimRoot.Position - attackerPos
				local distance = offset.Magnitude
				if distance <= closestDist and distance > 0.001 and attackerLook:Dot(offset.Unit) >= MIN_DOT then
					bestTarget = victimChar
					closestDist = distance
				end
			end
		end
	end
	return bestTarget
end

ToggleBlock.OnServerEvent:Connect(function(player, isBlocking)
	if typeof(isBlocking) ~= "boolean" then return end
	if GameState.Current ~= GameState.States.ROUND then
		GameState.IsBlocking[player] = false
		return
	end
	if not GameState.Participants[player] or not GameState.Alive[player] or isStunned(player) then
		GameState.IsBlocking[player] = false
		return
	end
	GameState.IsBlocking[player] = isBlocking
end)

AttackRemote.OnServerEvent:Connect(function(player, action)
	if GameState.Current ~= GameState.States.ROUND then return end
	if not GameState.Participants[player] or not GameState.Alive[player] then return end
	if isStunned(player) then return end

	local character = player.Character
	if not character or not character.PrimaryPart then return end

	if action == "Start" then
		if GameState.ChargeStarted[player] then return end
		local now = os.clock()
		local lastTime = GameState.LastAttackTime[player] or 0
		if now - lastTime < ATTACK_COOLDOWN then return end
		if GameState.IsBlocking[player] then return end
		GameState.ChargeStarted[player] = now
		return
	end

	if action ~= "Release" then return end

	local startTime = GameState.ChargeStarted[player]
	if not startTime then return end
	GameState.ChargeStarted[player] = nil

	local now = os.clock()
	GameState.LastAttackTime[player] = now

	local expiresAt = GameState.ComboExpiresAt[player] or 0
	if (GameState.ComboCount[player] or 0) <= 0 or now > expiresAt then
		GameState.ComboCount[player] = 1
	else
		GameState.ComboCount[player] = (GameState.ComboCount[player] % 3) + 1
	end

	local currentCombo = GameState.ComboCount[player]
	local duration = math.max(0, now - startTime)

	if duration >= OVERCHARGE_LIMIT then
		GameState.StunnedUntil[player] = now + 0.6
		GameState.IsBlocking[player] = false
		resetCombo(player)
		HitFXRemote:FireClient(player, "Attacker", "Overcharge")
		return
	end

	local hSpeed, vSpeed, damage = 50, 18, 20
	local hitType = "Normal"
	if duration < WEAK_MAX then
		hSpeed, vSpeed, damage, hitType = 25, 15, 10, "Weak"
	elseif duration >= PERFECT_WINDOW_MIN and duration <= PERFECT_WINDOW_MAX then
		hSpeed, vSpeed, damage, hitType = 75, 25, 35, "Perfect"
	elseif duration > PERFECT_WINDOW_MAX then
		hSpeed, vSpeed, damage, hitType = 20, 10, 10, "Weak"
	end

	local isFinisher = currentCombo == 3
	if currentCombo == 2 then
		damage = math.floor(damage * 1.25)
	elseif isFinisher then
		damage = math.floor(damage * 1.5)
		hSpeed *= 1.35
		vSpeed *= 1.25
	end

	local targetChar = getHitTarget(player)
	if not targetChar or not targetChar.PrimaryPart then
		resetCombo(player)
		HitFXRemote:FireClient(player, "Attacker", "Miss")
		return
	end

	local victimPlayer = Players:GetPlayerFromCharacter(targetChar)
	if not victimPlayer or not GameState.Participants[victimPlayer] or not GameState.Alive[victimPlayer] then
		resetCombo(player)
		return
	end

	local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		resetCombo(player)
		return
	end

	local isBlocked = GameState.IsBlocking[victimPlayer] == true
	if isBlocked then
		damage = math.max(1, math.floor(damage * 0.4))
		hSpeed *= 0.2
		vSpeed *= 0.2
		resetCombo(player)
		isFinisher = false
		HitFXRemote:FireClient(player, "Attacker", "Blocked")
		HitFXRemote:FireClient(victimPlayer, "Victim", "Blocked")
	else
		GameState.ComboExpiresAt[player] = now + COMBO_WINDOW_DURATION
		HitFXRemote:FireClient(player, "Attacker", isFinisher and "Finisher" or hitType)
		HitFXRemote:FireClient(victimPlayer, "Victim", isFinisher and "Finisher" or hitType)
	end

	applyKnockback(character.PrimaryPart, targetChar.PrimaryPart, hSpeed, vSpeed)
	humanoid:TakeDamage(damage)
	showDamageIndicator(targetChar.PrimaryPart, damage, hitType == "Perfect", currentCombo, isFinisher)

	if humanoid.Health <= 0 then
		GameState.Alive[victimPlayer] = nil
		GameState.IsBlocking[victimPlayer] = false
		GameState.ChargeStarted[victimPlayer] = nil
		resetCombo(victimPlayer)
	else
		GameState.ChargeStarted[victimPlayer] = nil
		GameState.IsBlocking[victimPlayer] = false
		GameState.StunnedUntil[victimPlayer] = now + (isBlocked and STUN_DURATION * 0.5 or STUN_DURATION)
	end
end)

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

print(">>> IMPACT Clash CombatServer loaded <<<")
