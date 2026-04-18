--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)

--// Constants
local WALK_SPEED = game.StarterPlayer.CharacterWalkSpeed
local JUMP_HEIGHT = game.StarterPlayer.CharacterJumpHeight
local DODGE_COOLDOWN = 2
local DOGE_FORCE = 150
local DODGE_DURATION = 0.2

--// Service
local MovementService = Knit.CreateService{
	Name = 'MovementService',
	Client = {
		DodgeSignal = Knit.CreateSignal(),
		EnableJumpingSignal = Knit.CreateSignal(),
		DisableMovementSignal = Knit.CreateSignal()
	},
	Cooldowns = {
		Dodge = {}
	},
	
	DisabledPlayers = {}
}

--// Public API

function MovementService:DisableMovementForPlayer(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass('Humanoid')
	if not humanoid then return end
	
	player:SetAttribute('MovementDisabled', true)

	--self.DisabledPlayers[player] = true

	-- Force default movement settings and disable jump
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	
end

function MovementService:EnableMovementForPlayer(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass('Humanoid')
	if not humanoid then return end
	
	local movementDisabled = player:GetAttribute('MovementDisabled')
	if not movementDisabled then return end
	player:SetAttribute('MovementDisabled', false)

	-- Restore default movement settings
	humanoid.WalkSpeed = WALK_SPEED * player:GetAttribute('SpeedMultiplier')
	humanoid.JumpHeight = JUMP_HEIGHT
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	
end

function MovementService:Dodge(player)
	local lastDodgeTime = self.Cooldowns.Dodge[player] or 0
	if tick() - lastDodgeTime < DODGE_COOLDOWN then
		self.Client.EnableJumpingSignal:Fire(player)
		return
	end
	
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid
	if not humanoidRootPart or not humanoid or not humanoid:FindFirstChild('Animator') then return end
	
	-- If the character is in the air or jumping return.
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall or humanoid:GetState() == Enum.HumanoidStateType.Jumping then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		return
	end
		
	self.Cooldowns.Dodge[player] = tick() -- Update cooldown time
	
	-- Create sound
	local sound = game.ReplicatedStorage.Sounds.Dash:Clone()
	sound.Parent = humanoidRootPart
	sound.PlayOnRemove = true
	sound:Destroy()
	
	local dodgeSettings = {
		duration = DODGE_DURATION,
		force = DOGE_FORCE
	}
	
	self.PassivesService:FirePassiveEvent(player, 'SetDodgeModifiers', {
		DodgeSettings = dodgeSettings
	})
		
	-- Send the signal for the client to handle the dodge.
	self.Client.DodgeSignal:Fire(player, dodgeSettings.duration, dodgeSettings.force)
end

function MovementService:ListenForAttributeChanges(player)
	player:GetAttributeChangedSignal('SpeedMultiplier'):Connect(function()
		local character = player.Character
		if character and character:FindFirstChild('Humanoid') then
			character.Humanoid.WalkSpeed = WALK_SPEED * player:GetAttribute('SpeedMultiplier')
		end
	end)
end

--// Knit Lifecycle
function MovementService:KnitStart()
	self.PassivesService = Knit.GetService('PassivesService')
	
	game.Players.PlayerAdded:Connect(function(player)
		player:SetAttribute('SpeedMultiplier', 1)
		
		self:ListenForAttributeChanges(player)
	end)
	
	self.Client.DodgeSignal:Connect(function(player)
		self:Dodge(player)
	end)
end

return MovementService
