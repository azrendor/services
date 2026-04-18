--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local FastCastHandler = require(game:GetService('ReplicatedStorage').Packages.FastCastHandler)
local CombatUtils = require(game:GetService('ReplicatedStorage').Packages.CombatUtils)
local WeaponsService = Knit.GetService('WeaponsService')
local EffectsService = Knit.GetService('EffectsService')
local PassivesService = Knit.GetService('PassivesService')
local PathwayService = Knit.GetService('PathwayService')

--// Constants
local MARKED_DURATION = 5
local MARKED_DAMAGE_MULTIPLIER = 2

--// Skill
local Skill = {
	Cooldown = 2,
}

function Skill.Activate(player, mousePos)
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
	Weapon.CanReload = false
		
	-- Play the animation and cast sound.
	local animation = game.ReplicatedStorage.Animations.Skills.Deadlock --TC
	local track: AnimationTrack = player.Character.Humanoid.Animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()
	
	track:GetMarkerReachedSignal('Fire'):Once(function()
		local hitStopEffect = {
			Name = 'Blur',
			Size = 2.5,
			Duration = 0.1
		}
		EffectsService:TriggerEffectForPlayer(player, hitStopEffect)
		
		-- Shoot effects
		local effect = {
			Name = 'FalseTriggerActivate',
			RenderDistance = 1000,
			Player = player,
			Origin = player.Character.HumanoidRootPart.Position,
			Tool = Weapon.Tool,
			Destroy = false
		}
		EffectsService:TriggerEffect(effect)

		local falseTriggerSound = game.ReplicatedStorage.Sounds.Skills.FalseTrigger:Clone()
		falseTriggerSound.Parent = Weapon.Tool:FindFirstChild('Handle') or Weapon.Character.HumanoidRootPart
		falseTriggerSound.PlayOnRemove = true
		falseTriggerSound:Destroy()
		
		local fireSound = Weapon.SoundsFolder:FindFirstChild('Fire'):Clone() or Weapon.SoundsFolder.Parent:FindFirstChild('Fire'):Clone()
		fireSound.Parent = Weapon.Tool:FindFirstChild('Handle') or Weapon.Character.HumanoidRootPart
		fireSound.PlayOnRemove = true
		fireSound:Destroy()
		
		WeaponsService.Client.RecoilSignal:Fire(player)
		
		local shooter = player.Character
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {shooter, workspace.Debris}

		local origin = player.Character.HumanoidRootPart.Position + (player.Character.HumanoidRootPart.CFrame.LookVector * 2)
		local direction = (mousePos - origin).Unit
		local range = Weapon.BulletRange
		local speed = Weapon.BulletSpeed
		local cast = FastCastHandler:Fire(player, origin, direction, speed, params)
		cast:Once(function(result, humanoid)
			cast:Destroy()
			if not humanoid then return end
			
			-- Mark the enemy using a passive.
			local targetPlayer = game.Players:GetPlayerFromCharacter(humanoid.Parent)
			-- Create the mark on the enemy.
			local markedName = 'Marked' .. humanoid.Parent.Name
			local markedPassive = {}
			function markedPassive:OnHitConfirmed(player, args)
				local target = args.Target
				local damage = args.Damage
				local humanoid = target:FindFirstChildWhichIsA('Humanoid')
				if humanoid then
					humanoid:TakeDamage(damage) -- Deal the damage twice.
				end
				
				-- Remove the mark once a bullet hits
				PassivesService:RemovePassive(player, markedName)
				-- Enable skill usage.
				PathwayService:EnablePlayerSkillUsage(targetPlayer)
			end
			
			local markedEffect = {
				Name = 'FalseTriggerMark',
				Player = player,
				Target = humanoid.Parent,
				PassiveName = markedName,
			}
			EffectsService:TriggerEffectForPlayer(player, markedEffect)
			
			-- Apply the passive and remove it after marked_duration
			PassivesService:ApplyPassive(player, markedPassive, markedName)
			-- Disable skill usage while marked.
			PathwayService:DisablePlayerSkillUsage(targetPlayer, MARKED_DURATION)
			task.delay(MARKED_DURATION, function()
				PathwayService:EnablePlayerSkillUsage(targetPlayer)
				PassivesService:RemovePassive(player, markedName)
			end)
		end)
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