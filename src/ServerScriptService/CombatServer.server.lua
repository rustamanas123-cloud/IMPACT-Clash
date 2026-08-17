local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameState = require(ServerScriptService:WaitForChild("GameState"))
local AttackRemote = ReplicatedStorage:WaitForChild("AttackRemote")
local ToggleBlock = ReplicatedStorage:WaitForChild("ToggleBlock")
local HitFXRemote = ReplicatedStorage:WaitForChild("HitFX")

local WEAK_MAX = 0.40
local PERFECT_WINDOW_MIN = 0.85
local PERFECT_WINDOW_MAX = 0.98
local OVERCHARGE_LIMIT = 1.02
local ATTACK_RANGE = 15
local MIN_DOT = 0.30
local STUN_DURATION = 0.45
local ATTACK_COOLDOWN = 0.60
local COMBO_WINDOW_DURATION = 0.73
local OVERCHARGE_STUN = 0.60
local KNOCKBACK_DURATION = 0.12
local MAX_ACTIONS_PER_SECOND = 12

local rateState = {}

local function rateAllowed(player: Player): boolean
	local now = os.clock()
	local state = rateState[player]
	if not state or now - state.windowStart >= 1 then
		rateState[player] = {windowStart = now, count = 1}
		return true
	end
	state.count += 1
	return state.count <= MAX_ACTIONS_PER_SECOND
end

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

local function clearCombatState(player: Player)
	GameState.Participants[player] = nil
	GameState.Alive[player] = nil
	GameState.ChargeStarted[player] = nil
	GameState.StunnedUntil[player] = nil
	GameState.IsBlocking[player] = nil
	GameState.ComboCount[player] = nil
	GameState.LastAttackTime[player] = nil
	GameState.ComboExpiresAt[player] = nil
	rateState[player] = nil
end

local function fireFX(player: Player?, role: string, hitType: string, combo: number?, damage: number?)
	if player and player.Parent == Players then
		HitFXRemote:FireClient(player, role, hitType, combo or 0, damage or 0)
	end
end

local function applyKnockback(attackerRoot: BasePart, victimRoot: BasePart, horizontalSpeed: number, upwardSpeed: number)
	local direction = attackerRoot.CFrame.LookVector
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.001 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	local attackerMass = math.max(attackerRoot.AssemblyMass, 1)
	local victimMass = math.max(victimRoot.AssemblyMass, 1)
	local massFactor = math.clamp(math.sqrt(attackerMass / victimMass), 0.78, 1.22)
	local velocity = direction * (horizontalSpeed * massFactor) + Vector3.new(0, upwardSpeed * massFactor, 0)

	local attachment = Instance.new("Attachment")
	attachment.Name = "ImpactKnockbackAttachment"
	attachment.Parent = victimRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "ImpactKnockback"
	linearVelocity.MaxForce = 200000
	linearVelocity.VectorVelocity = velocity
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = victimRoot

	task.delay(KNOCKBACK_DURATION, function()
		if linearVelocity.Parent then linearVelocity:Destroy() end
		if attachment.Parent then attachment:Destroy() end
	end)
end

local function showDamageIndicator(part: BasePart, damage: number, hitType: string, comboStep: number, isFinisher: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ImpactDamage"
	billboard.Size = UDim2.fromOffset(190, 76)
	billboard.StudsOffset = Vector3.new(math.random(-12, 12) / 10, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(10, 10, 15)
	label.Text = isFinisher and ("FINISHER  " .. damage) or (comboStep > 1 and ("x" .. comboStep .. "  " .. damage) or tostring(damage))
	label.TextColor3 = isFinisher and Color3.fromRGB(255, 45, 45) or hitType == "Perfect" and Color3.fromRGB(255, 195, 55) or hitType == "Blocked" and Color3.fromRGB(100, 190, 255) or Color3.fromRGB(255, 255, 255)
	label.Parent = billboard

	local rise = TweenService:Create(billboard, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, 3.5, 0),
	})
	local fade = TweenService:Create(label, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	rise:Play()
	fade:Play()

	task.delay(0.75, function()
		if billboard.Parent then billboard:Destroy() end
	end)
end

local function hasLineOfSight(attackerRoot: BasePart, victimCharacter: Model, victimRoot: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {attackerRoot.Parent}
	params.IgnoreWater = true
	local result = Workspace:Raycast(attackerRoot.Position, victimRoot.Position - attackerRoot.Position, params)
	return result == nil or result.Instance:IsDescendantOf(victimCharacter)
end

local function getHitTarget(attacker: Player): Model?
	local attackerCharacter = attacker.Character
	local attackerRoot = attackerCharacter and attackerCharacter.PrimaryPart
	if not attackerRoot then return nil end

	local bestTarget = nil
	local closestDistance = ATTACK_RANGE
	for _, victimPlayer in ipairs(Players:GetPlayers()) do
		if victimPlayer ~= attacker and GameState.Participants[victimPlayer] and GameState.Alive[victimPlayer] then
			local victimCharacter = victimPlayer.Character
			local victimRoot = victimCharacter and victimCharacter.PrimaryPart
			local humanoid = victimCharacter and victimCharacter:FindFirstChildOfClass("Humanoid")
			if victimRoot and humanoid and humanoid.Health > 0 then
				local offset = victimRoot.Position - attackerRoot.Position
				local distance = offset.Magnitude
				if distance > 0.001 and distance <= closestDistance and attackerRoot.CFrame.LookVector:Dot(offset.Unit) >= MIN_DOT and hasLineOfSight(attackerRoot, victimCharacter, victimRoot) then
					bestTarget = victimCharacter
					closestDistance = distance
				end
			end
		end
	end
	return bestTarget
end

ToggleBlock.OnServerEvent:Connect(function(player, requestedBlocking)
	if not rateAllowed(player) or typeof(requestedBlocking) ~= "boolean" then return end
	if GameState.Current ~= GameState.States.ROUND or not GameState.Participants[player] or not GameState.Alive[player] or isStunned(player) then
		GameState.IsBlocking[player] = false
		return
	end
	if requestedBlocking and GameState.ChargeStarted[player] then return end
	GameState.IsBlocking[player] = requestedBlocking
end)

AttackRemote.OnServerEvent:Connect(function(player, action)
	if not rateAllowed(player) or typeof(action) ~= "string" then return end
	if GameState.Current ~= GameState.States.ROUND or not GameState.Participants[player] or not GameState.Alive[player] or isStunned(player) then return end

	local character = player.Character
	local root = character and character.PrimaryPart
	if not root then return end

	if action == "Start" then
		if GameState.ChargeStarted[player] or GameState.IsBlocking[player] then return end
		local now = os.clock()
		if now - (GameState.LastAttackTime[player] or 0) < ATTACK_COOLDOWN then return end
		GameState.ChargeStarted[player] = now
		return
	end

	if action ~= "Release" then return end

	local startTime = GameState.ChargeStarted[player]
	if not startTime then return end
	GameState.ChargeStarted[player] = nil

	local now = os.clock()
	GameState.LastAttackTime[player] = now
	local duration = math.max(0, now - startTime)
	if duration >= OVERCHARGE_LIMIT then
		GameState.StunnedUntil[player] = now + OVERCHARGE_STUN
		GameState.IsBlocking[player] = false
		resetCombo(player)
		fireFX(player, "Attacker", "Overcharge")
		return
	end

	if (GameState.ComboCount[player] or 0) <= 0 or now > (GameState.ComboExpiresAt[player] or 0) then
		GameState.ComboCount[player] = 1
	else
		GameState.ComboCount[player] = (GameState.ComboCount[player] % 3) + 1
	end

	local combo = GameState.ComboCount[player]
	local hSpeed, vSpeed, damage, hitType = 50, 18, 20, "Normal"
	if duration < WEAK_MAX then
		hSpeed, vSpeed, damage, hitType = 25, 15, 10, "Weak"
	elseif duration >= PERFECT_WINDOW_MIN and duration <= PERFECT_WINDOW_MAX then
		hSpeed, vSpeed, damage, hitType = 75, 25, 35, "Perfect"
	elseif duration > PERFECT_WINDOW_MAX then
		hSpeed, vSpeed, damage, hitType = 20, 10, 10, "Weak"
	end

	local isFinisher = combo == 3
	if combo == 2 then
		damage = math.floor(damage * 1.25)
	elseif isFinisher then
		damage = math.floor(damage * 1.5)
		hSpeed *= 1.35
		vSpeed *= 1.25
	end

	local targetCharacter = getHitTarget(player)
	if not targetCharacter or not targetCharacter.PrimaryPart then
		resetCombo(player)
		fireFX(player, "Attacker", "Miss")
		return
	end

	local victimPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not victimPlayer or not GameState.Participants[victimPlayer] or not GameState.Alive[victimPlayer] or not humanoid or humanoid.Health <= 0 then
		resetCombo(player)
		return
	end

	local blocked = GameState.IsBlocking[victimPlayer] == true
	if blocked then
		damage = math.max(1, math.floor(damage * 0.4))
		hSpeed *= 0.2
		vSpeed *= 0.2
		isFinisher = false
		resetCombo(player)
		fireFX(player, "Attacker", "Blocked", combo, damage)
		fireFX(victimPlayer, "Victim", "Blocked", combo, damage)
	else
		GameState.ComboExpiresAt[player] = now + COMBO_WINDOW_DURATION
		local fxType = isFinisher and "Finisher" or hitType
		fireFX(player, "Attacker", fxType, combo, damage)
		fireFX(victimPlayer, "Victim", fxType, combo, damage)
	end

	applyKnockback(root, targetCharacter.PrimaryPart, hSpeed, vSpeed)
	humanoid:TakeDamage(damage)
	showDamageIndicator(targetCharacter.PrimaryPart, damage, hitType, combo, isFinisher)

	GameState.ChargeStarted[victimPlayer] = nil
	GameState.IsBlocking[victimPlayer] = false
	if humanoid.Health <= 0 then
		GameState.Alive[victimPlayer] = nil
		GameState.StunnedUntil[victimPlayer] = nil
		resetCombo(victimPlayer)
		fireFX(victimPlayer, "Victim", "KO", combo, damage)
	else
		GameState.StunnedUntil[victimPlayer] = now + STUN_DURATION
	end
end)

Players.PlayerRemoving:Connect(clearCombatState)

print(">>> IMPACT Clash CombatServer // SERVER AUTHORITY READY <<<")
