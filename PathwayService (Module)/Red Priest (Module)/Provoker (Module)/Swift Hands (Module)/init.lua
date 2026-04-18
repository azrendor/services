--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local EffectsService = Knit.GetService('EffectsService')

local RELOAD_BUFF = 1.15
--// Passive
local Passive = {}
local PassiveWeaponCache = {}

function Passive.OnRemove(player)
	local weapon = PassiveWeaponCache[player]
	if weapon then
		weapon.ReloadSpeed = 1
	end
	
	PassiveWeaponCache[player] = nil
end

function Passive:SetWeaponModifiers(player, args)
	if not PassiveWeaponCache[player] then
		PassiveWeaponCache[player] = args.Weapon
	end	
	
	args.Weapon.ReloadSpeed = RELOAD_BUFF
end

return Passive
