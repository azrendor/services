local Class = require(script.Parent)
local Weapon = {}

Weapon.Settings = {
	Name = script.Name,
	Class = script.Parent.Name,
	Ammo = 6,
	TotalAmmo = 42,
	Damage = 30,
	RoundsPerSecond = 5,
	BulletSpeed = 3000,
	BulletRange = 1000,
	Automatic = false
}

function Weapon.new(player, tool)
	return Class.new(player, tool, Weapon.Settings)
end

return Weapon
