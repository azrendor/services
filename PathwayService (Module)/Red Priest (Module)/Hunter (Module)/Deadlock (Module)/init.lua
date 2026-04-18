--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local FastCastHandler = require(game:GetService('ReplicatedStorage').Packages.FastCastHandler)
local CombatUtils = require(game:GetService('ReplicatedStorage').Packages.CombatUtils)
local WeaponsService = Knit.GetService('WeaponsService')
local PathwayService = Knit.GetService('PathwayService')
local EffectsService = Knit.GetService('EffectsService')
local PassivesService = Knit.GetService('PassivesService')

--// Constants
local MINIMUN_MOUSE_DISTANCE = 85

--// Skill
local Skill = {
	Cooldown = 4,
	Damage = 50,
}

Skill.Activate = function(player, mousePos)
	-- Get the current weapon object.
	local Weapon = WeaponsService:GetEquippedWeapon(player)	
	if not Weapon then
		return
	end
	
	-- Check and set the ammo.
	if Weapon.CurrentMagAmmo <= 0 or Weapon.Reloading then
		return
	end
	--> Call the client visualizer for the cooldown
	PathwayService.Client.SetClientCooldownSignal:Fire(player, script.Name, Skill.Cooldown)
	
	--> Disable skill usage to stop movestacking.
	PathwayService:DisablePlayerSkillUsage(player)

	Weapon.CanFire = false -- Make it so they cant fire with clicks when the skill is ongoing
	Weapon.CanReload = false
	
	local effect = {
		Name = 'DeadlockActivate',
		RenderDistance = 1000,
		Player = player,
		Origin = player.Character.HumanoidRootPart.Position,
		Tool = Weapon.Tool,
		Destroy = false
	}
	EffectsService:TriggerEffect(effect)
	
	-- Play the animation and cast sound.
	local animation = game.ReplicatedStorage.Animations.Skills.Deadlock
	local track: AnimationTrack = player.Character.Humanoid.Animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()

	local magicCastSound = game.ReplicatedStorage.Sounds.Skills.MagicCast:Clone()
	magicCastSound.Parent = Weapon.Tool:FindFirstChild('Handle') or Weapon.Character.HumanoidRootPart
	magicCastSound.PlayOnRemove = true
	magicCastSound:Destroy()
	
	local target
	local connection
	connection = PathwayService.Client.RequestClosestCharacterToMouse:Connect(function(requestPlayer, requestedTarget)
		if requestPlayer ~= player then
			return
		end
		
		target = requestedTarget
		connection:Disconnect()
	end)
	PathwayService.Client.RequestClosestCharacterToMouse:Fire(player, MINIMUN_MOUSE_DISTANCE)
	
	-- Set the signal for the fire marker.
	track:GetMarkerReachedSignal('Fire'):Once(function()
		local hitStopEffect = {
			Name = 'Blur',
			Size = 2.5,
			Duration = 0.1
		}
		EffectsService:TriggerEffectForPlayer(player, hitStopEffect)
		 
		local effect = {
			Name = 'DeadlockActivate',
			RenderDistance = 1000,
			Player = player,
			Origin = player.Character.HumanoidRootPart.Position,
			Tool = Weapon.Tool,
			Destroy = true
		}
		EffectsService:TriggerEffect(effect)
		
		
		if target then
			-- Reduce the ammo by one.
			Weapon.CurrentMagAmmo -= 1
			Weapon.Tool:SetAttribute('Ammo', Weapon.CurrentMagAmmo)

			-- Shoot effects
			local fireSound = Weapon.SoundsFolder:FindFirstChild('Fire'):Clone() or Weapon.SoundsFolder.Parent:FindFirstChild('Fire'):Clone()
			fireSound.Parent = Weapon.Tool:FindFirstChild('Handle') or Weapon.Character.HumanoidRootPart
			fireSound.PlayOnRemove = true
			fireSound:Destroy()

			local magicShotSound = game.ReplicatedStorage.Sounds.Skills.MagicShot:Clone()
			magicShotSound.Parent = Weapon.Tool:FindFirstChild('Handle') or Weapon.Character.HumanoidRootPart
			magicShotSound.PlayOnRemove = true
			magicShotSound:Destroy()

			for _, emitter in pairs(Weapon.Tool.SmokePart:GetChildren()) do
				if emitter:IsA('ParticleEmitter') then
					emitter:Emit(1)
				end
			end

			WeaponsService.Client.RecoilSignal:Fire(player)

			-- Shooting logic
			local origin = player.Character.HumanoidRootPart.Position
			local direction = (mousePos - origin).Unit
			local range = Weapon.BulletRange
			local speed = Weapon.BulletSpeed * 2

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {player.Character, workspace.Debris}

			local cast = FastCastHandler:Fire(player, origin, direction, speed, params, target)
			cast:Once(function(result, humanoid)
				CombatUtils.HandleHit(player, result, humanoid, Skill.Damage)
				cast:Destroy()
			end)
		else
			-- Failed
			local magicFailSound = game.ReplicatedStorage.Sounds.Skills.MagicFail:Clone()
			magicFailSound.Parent = Weapon.Tool:FindFirstChild('Handle') or Weapon.Character.HumanoidRootPart
			magicFailSound.PlayOnRemove = true
			magicFailSound:Destroy()

			track:Stop()
		end
	end)
	
	local trackFired = false
	local function restoreWeapon()
		if trackFired then return end
		if not Weapon then return end
		trackFired = true

		Weapon.CanFire = true
		Weapon.CanReload = true
		
		PathwayService:EnablePlayerSkillUsage(player)
	end

	track.Ended:Once(restoreWeapon)
	track.Stopped:Once(restoreWeapon)
end

return Skill