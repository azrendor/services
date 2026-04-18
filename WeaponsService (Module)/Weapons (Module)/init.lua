--// Dependencies
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local FastCastHandler = require(game.ReplicatedStorage.Packages.FastCastHandler)
local ProjectileCast = require(game.ReplicatedStorage.Packages.ProjectileCast)
local CombatUtils = require(game:GetService('ReplicatedStorage').Packages.CombatUtils)
local EffectsService = Knit.GetService('EffectsService')
local WeaponsService = Knit.GetService('WeaponsService')
local PassivesService = Knit.GetService('PassivesService')

--// Weapon Base Class
local Weapon = {}
Weapon.__index = Weapon

function Weapon.new(player, tool, settings)
	local self = setmetatable({}, Weapon)
	self.Player = player
	self.Character = player.Character
	self.Tool = tool
	
	self.Name = settings.Name
	self.Class = settings.Class

	self.CurrentMagAmmo = settings.Ammo
	self.TotalAmmo = settings.TotalAmmo
	self.MagAmmoCapacity = settings.Ammo
	self.Damage = settings.Damage
	self.RoundsPerSecond = settings.RoundsPerSecond
	self.BulletSpeed = settings.BulletSpeed
	self.BulletRange = settings.BulletRange
	self.Automatic = settings.Automatic

	self.Equipped = false
	self.Reloading = false
	
	self.CanFire = true
	self.CanReload = true
	
	-- Modifications
	self.DamageMultiplier = 1
	self.ReloadSpeed = 1

	-- Get the weapon animation and sounds, if it does not have custom ones it will use defaults.
	if game.ReplicatedStorage.Animations[self.Class][self.Name] and #game.ReplicatedStorage.Animations[self.Class][self.Name]:GetChildren() > 0 then
		self.AnimationsFolder = game.ReplicatedStorage.Animations[self.Class][self.Name]
	else
		-- Defaults
		self.AnimationsFolder = game.ReplicatedStorage.Animations[self.Class]
	end
	
	if game.ReplicatedStorage.Sounds[self.Class][self.Name] and #game.ReplicatedStorage.Sounds[self.Class][self.Name]:GetChildren() > 0 then
		self.SoundsFolder = game.ReplicatedStorage.Sounds[self.Class][self.Name]
	else
		-- Defaults
		self.SoundsFolder = game.ReplicatedStorage.Sounds[self.Class]
	end

	tool:SetAttribute('TotalAmmo', self.TotalAmmo)
	tool:SetAttribute('MagCapacity', self.MagAmmoCapacity)
	tool:SetAttribute('Ammo', self.CurrentMagAmmo)
	tool:SetAttribute('Automatic', self.Automatic)
	
	return self
end

function Weapon:Equip()
	if not self.Character or self.Character ~= self.Player.Character then
		self.Character = self.Player.Character
	end

	-- Safety check for Tool
	if not self.Tool then
		warn('Error: Tool is nil for', self.Player.Name)
		return
	end

	-- Safety check for Handle
	task.wait(0.1)
	local handle = self.Tool:WaitForChild('Handle', 1)
	if not handle then
		warn('Error: Handle is missing in', self.Tool:GetFullName())
		return
	end

	local humanoid = self.Character:FindFirstChild('Humanoid')
	if not humanoid or not humanoid:FindFirstChild('Animator') then
		warn('Error: Humanoid or Animator missing in', self.Character:GetFullName())
		return
	end

	-- Sound
	local sound = game.ReplicatedStorage.Sounds.GunEquip:Clone()
	sound.Parent = self.Character
	sound.PlayOnRemove = true
	sound:Destroy()
	
	-- Load animations
	local drawAnimation = self.AnimationsFolder:FindFirstChild('Draw') or self.AnimationsFolder.Parent:FindFirstChild('Draw')
	local drawTrack = humanoid.Animator:LoadAnimation(drawAnimation)
	drawTrack:Play()

	local holdAnimation = self.AnimationsFolder:FindFirstChild('Hold') or self.AnimationsFolder.Parent:FindFirstChild('Hold')
	local holdTrack = humanoid.Animator:LoadAnimation(holdAnimation)
	holdTrack.Looped = true
	holdTrack:Play()

	-- Attach weapon to hand using Motor6D
	local rightArm = self.Character:FindFirstChild('Right Arm')
	if not rightArm then
		warn('Error: Right Arm missing in', self.Character:GetFullName())
		return
	end

	local motor6d = Instance.new('Motor6D')
	motor6d.Part0 = rightArm
	motor6d.Part1 = handle
	motor6d.Parent = self.Tool

	self.Equipped = true
	
	-- Fire the passives event for weapon modifiers
	PassivesService:FirePassiveEvent(self.Player, 'SetWeaponModifiers', {
		Weapon = self
	})
end


function Weapon:UnEquip()
	self.Equipped = false
	
	local sound = game.ReplicatedStorage.Sounds.GunUnequip:Clone()
	sound.Parent = self.Character
	sound.PlayOnRemove = true
	sound:Destroy()

	local humanoid = self.Character.Humanoid
	for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
		if track.Animation:IsDescendantOf(self.AnimationsFolder) then
			track:Stop()
		end
	end

	local motor6d = self.Tool:FindFirstChild('Motor6D')
	if motor6d then
		motor6d:Destroy()
	end
end

function Weapon:Fire(player, mousePos, isAiming, recoilSignal)
	if not self.Equipped then return end
	if not self.CanFire then return end
	
	if self.CurrentMagAmmo <= 0 or self.Reloading then
		return
	end
	self.CurrentMagAmmo -= 1
	self.Tool:SetAttribute('Ammo', self.CurrentMagAmmo)
	
	PassivesService:FirePassiveEvent(self.Player, 'OnShoot', {
		Weapon = self
	})

	local animation = isAiming and (self.AnimationsFolder:FindFirstChild('AimFire') or self.AnimationsFolder.Parent:FindFirstChild('AimFire')) or (self.AnimationsFolder:FindFirstChild('Fire') or self.AnimationsFolder.Parent:FindFirstChild('Fire'))
	local track = self.Character.Humanoid.Animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()

	local sound = self.SoundsFolder:FindFirstChild('Fire'):Clone() or self.SoundsFolder.Parent:FindFirstChild('Fire'):Clone()
	sound.Parent = self.Tool:FindFirstChild('Handle') or self.Character.HumanoidRootPart
	sound.PlayOnRemove = true
	sound:Destroy()

	for _, emitter in pairs(self.Tool.SmokePart:GetChildren()) do
		if emitter:IsA('ParticleEmitter') then
			emitter:Emit(1)
		end
	end
	
	recoilSignal:Fire(player)
	
	local hitStopEffect = {
		Name = 'Blur',
		Size = 2.5,
		Duration = 0.1
	}
	EffectsService:TriggerEffectForPlayer(player, hitStopEffect)

	local shooter = self.Character
	local tool = self.Tool
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {shooter, workspace.Debris}

	local origin = self.Character.HumanoidRootPart.Position
	local direction = (mousePos - origin).Unit
	local range = self.BulletRange
	local speed = self.BulletSpeed
	
	local cast = FastCastHandler:Fire(player, origin, direction, speed, params)
	cast:Once(function(result, humanoid)
		CombatUtils.HandleHit(player, result, humanoid, self.Damage)
		cast:Destroy()
	end)
end

function Weapon:Reload(reloadSignal)
	if self.Reloading or not self.CanReload then
		return
	end

	local ammoNeeded = self.MagAmmoCapacity - self.CurrentMagAmmo

	if self.TotalAmmo > 0 and ammoNeeded > 0 then
		self.Reloading = true
		
		local animation = self.AnimationsFolder:FindFirstChild('Reload') or self.AnimationsFolder.Parent:FindFirstChild('Reload')
		local track = self.Character.Humanoid.Animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action3
		track:Play()
		track:AdjustSpeed(self.ReloadSpeed)

		local sound: Sound = (self.SoundsFolder:FindFirstChild('Reload') or self.SoundsFolder.Parent:FindFirstChild('Reload')):Clone()
		sound.Parent = self.Tool:FindFirstChild('Handle') or self.Character.HumanoidRootPart
		sound.PlayOnRemove = true
		sound.PlaybackSpeed = self.ReloadSpeed
		sound:Destroy()
			
		local trackFired = false

		local function trackEndedOrStopped()
			if trackFired then return end
			trackFired = true

			if not self.Tool then
				return
			end

			if not self.Equipped then
				self.Tool:SetAttribute('TotalAmmo', self.TotalAmmo)
				self.Tool:SetAttribute('Ammo', self.CurrentMagAmmo)

				self.Reloading = false
				return
			end

			local ammoToReload = math.min(ammoNeeded, self.TotalAmmo)
			self.CurrentMagAmmo += ammoToReload
			self.TotalAmmo = self.TotalAmmo - ammoToReload

			self.Tool:SetAttribute('TotalAmmo', self.TotalAmmo)
			self.Tool:SetAttribute('Ammo', self.CurrentMagAmmo)

			self.Reloading = false
		end

		track.Ended:Once(trackEndedOrStopped)
		track.Stopped:Once(trackEndedOrStopped)
	end
end

function Weapon:ApplyModification(modification)
	for key, value in pairs(modification) do
		self[key] = value
	end
end


function Weapon:Destroy()
	-- Stop all animations related to the weapon
	local humanoid = self.Character.Humanoid
	for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	-- Destroy Motor6D if it exists
	--[[local motor6d = self.Tool:FindFirstChild('Motor6D')
	if motor6d then
		motor6d:Destroy()
	end]]

	-- Reset attributes on the tool
	--[[self.Tool:SetAttribute('TotalAmmo', nil)
	self.Tool:SetAttribute('MagCapacity', nil)
	self.Tool:SetAttribute('Ammo', nil)]]

	-- Nullify references to avoid memory leaks
	for i,v in self do
		self[i] = nil
	end

	-- Signal garbage collection by clearing metatable
	setmetatable(self, nil)
end

return Weapon
