--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local Signal = require(game.ReplicatedStorage.Packages.Signal)

--// Constants
local WeaponPath = script.Weapon  -- Folder containing all weapon modules organized by class

--// Service
local WeaponsService = Knit.CreateService{
	Name = 'WeaponsService',

	Client = {
		EquipSignal = Knit.CreateSignal(), 
		UnEquipSignal = Knit.CreateSignal(), 
		FireSignal = Knit.CreateSignal(),   
		ReloadSignal = Knit.CreateSignal(),
		RecoilSignal = Knit.CreateSignal(),
	},

	WeaponClasses = {},     -- Holds references to all weapon modules, organized by class and weapon name
	EquippedWeapons = {},   -- Tracks the currently equipped weapon per player
	PlayerWeapons = {},     -- Tracks all weapon instances per player
	LastShotTimes = {},     -- Tracks last shot timestamp for fire rate control
	NextShotModifications = {},  -- Holds modifications to apply on the next shot
	RestrictedPlayers = {}  -- Tracks players restricted from firing or reloading
}

--// Public API
function WeaponsService:Create(player, tool)
	if not player or not tool then return end

	local class = tool:GetAttribute('Class')
	if not class then
		warn(`[WeaponsService]: Tool:{tool.Name}, missing class.`)
		return
	end
	if not WeaponPath[class] then
		warn(`[WeaponsService]: Class:{class}, does not exist.`)
		return
	end
	if not WeaponPath[class][tool.Name] then
		warn(`[WeaponsService]: Weapon:{tool.Name}, does not exist.`)
		return
	end

	if not self.PlayerWeapons[player.Name] then
		self.PlayerWeapons[player.Name] = {}
	end

	if not self.PlayerWeapons[player.Name][tool.Name] then
		local weaponClass = self.WeaponClasses[class][tool.Name]
		local weapon = weaponClass.new(player, tool)
		self.PlayerWeapons[player.Name][tool.Name] = weapon

		self.HolsterService:Holster(player, tool)

		tool.Destroying:Once(function()
			self.PlayerWeapons[player.Name][tool.Name] = nil
			local equippedWeapon = self.EquippedWeapons[player.Name]
			if equippedWeapon and equippedWeapon.Tool == tool then
				self.EquippedWeapons[player.Name] = nil
			end
		end)
	end
end

function WeaponsService:Equip(player, tool)
	if not player or not tool then return end
	local weapon = self.PlayerWeapons[player.Name][tool.Name]
	if weapon then
		self.HolsterService:Unholster(player)
		weapon:Equip()   
		self.EquippedWeapons[player.Name] = weapon
	else
		warn(`[WeaponsService]: Player does not have Weapon:{tool.Name}`)
	end
end

function WeaponsService:UnEquip(player)
	if not player then return end
	local weapon = self.EquippedWeapons[player.Name]
	if not weapon then
		warn(`[WeaponsService]: {player.Name} has no weapon equipped.`)
		return
	end
	self.HolsterService:Holster(player, weapon.Tool)
	weapon:UnEquip()
	self.EquippedWeapons[player.Name] = nil
end

function WeaponsService:Fire(player, mousePos, isAiming)
	if not player or self:IsRestricted(player) then return end
	local weapon = self.EquippedWeapons[player.Name]
	if not weapon then
		warn(`[WeaponsService]: {player.Name} has no weapon equipped.`)
		return
	end

	local roundsPerSecond = weapon.RoundsPerSecond
	if not roundsPerSecond or roundsPerSecond <= 0 then
		warn(`[WeaponsService]: Invalid RoundsPerSecond for {weapon.Name}.`)
		return
	end

	-- fire rate cooldown
	local lastShotTime = self.LastShotTimes[player.Name]
	local currentTime = tick()
	local shotCooldown = 1 / roundsPerSecond
	local marginOfError = 0.015
	if lastShotTime and (currentTime - lastShotTime) < (shotCooldown - marginOfError) then
		return
	end

	-- Apply modifications if queued
	local modification = self.NextShotModifications[player.Name]
	if modification then
		weapon:ApplyModification(modification)
		self.NextShotModifications[player.Name] = nil
	end

	self.LastShotTimes[player.Name] = currentTime
	weapon:Fire(player, mousePos, isAiming, self.Client.RecoilSignal)
end

function WeaponsService:ModifyNextShot(player, modification)
	if not player or not modification then return end
	self.NextShotModifications[player.Name] = modification
end

function WeaponsService:Reload(player)
	if not player or self:IsRestricted(player) then return end
	local weapon = self.EquippedWeapons[player.Name]
	if not weapon then
		warn(`[WeaponsService]: {player.Name} has no weapon equipped.`)
		return
	end
	weapon:Reload()
end

function WeaponsService:SetRestricted(player, isRestricted)
	if not player then return end
	self.RestrictedPlayers[player.Name] = isRestricted and true or nil
end

function WeaponsService:IsRestricted(player)
	return self.RestrictedPlayers[player.Name] ~= nil
end

function WeaponsService:GetEquippedWeapon(player)
	if not player then return end
	local weapon = self.EquippedWeapons[player.Name]
	if not weapon then
		warn(`[WeaponsService]: {player.Name} has no weapon equipped.`)
	end
	return weapon
end

function WeaponsService:DestroyWeapons(player)
	if not player then return end
	local weapon = self.EquippedWeapons[player.Name]
	if weapon then
		self.PlayerWeapons[player.Name][weapon.Tool.Name] = nil
		weapon:Destroy()
		self.EquippedWeapons[player.Name] = nil
	end
	for _, weapon in pairs(self.PlayerWeapons[player.Name]) do
		weapon:Destroy()
	end
	self.PlayerWeapons[player.Name] = {}
end

function WeaponsService.Client:DestroyWeapons(player)
	self.Server:DestroyWeapons(player)
end

function WeaponsService.Client:GetWeaponSettings(player, class, weaponName, setting)
	-- Integrity checks.
	if not self.Server.WeaponClasses[class] then
		warn(`[WeaponsService]: Class:{class} does not exist.`)
	end
	if not self.Server.WeaponClasses[class][weaponName] then
		warn(`[WeaponsService]: Weapon:{weaponName} does not exist.`)
	end
	if not self.Server.WeaponClasses[class][weaponName].Settings[setting] then
		warn(`[WeaponsService]: Setting:{setting} does not exist.`)
	end
	return self.Server.WeaponClasses[class][weaponName].Settings[setting]
end

--// Knit Lifecycle
function WeaponsService:KnitStart()
	self.HolsterService = Knit.GetService('HolsterService')

	-- Load all weapon classes from WeaponPath
	for _, class in pairs(WeaponPath:GetChildren()) do
		self.WeaponClasses[class.Name] = self.WeaponClasses[class.Name] or {}
		for _, weapon in pairs(class:GetChildren()) do
			self.WeaponClasses[class.Name][weapon.Name] = require(weapon)
		end
	end

	-- Prepare PlayerWeapons for current players
	for _, player in pairs(game.Players:GetPlayers()) do
		self.PlayerWeapons[player.Name] = {}
	end

	-- Setup PlayerAdded and CharacterAdded handlers
	game.Players.PlayerAdded:Connect(function(player)
		self.PlayerWeapons[player.Name] = {}
		player.CharacterAdded:Connect(function(character)
			for _, weapon in pairs(player.Backpack:GetChildren()) do
				if weapon:IsA('Tool') and weapon:GetAttribute('Weapon') then
					self:Create(player, weapon)
				end
			end
		end)
		player.Backpack.ChildAdded:Connect(function(weapon)
			if weapon:IsA('Tool') and weapon:GetAttribute('Weapon') then
				self:Create(player, weapon)
			end
		end)
	end)

	-- Cleanup on player leave
	game.Players.PlayerRemoving:Connect(function(player)
		local weapon = self.EquippedWeapons[player.Name]
		if weapon then
			weapon:Destroy()
		end
		self.EquippedWeapons[player.Name] = nil
	end)

	-- Connect client signals to server methods
	self.Client.EquipSignal:Connect(function(player, weaponName)
		local weapon = player.Character:FindFirstChild(weaponName)
		if weapon then
			self:Equip(player, weapon)
		end
	end)
	self.Client.UnEquipSignal:Connect(function(player)
		self:UnEquip(player)
	end)
	self.Client.FireSignal:Connect(function(player, mousePos, isAiming)
		self:Fire(player, mousePos, isAiming)
	end)
	self.Client.ReloadSignal:Connect(function(player)
		self:Reload(player)
	end)
end

return WeaponsService