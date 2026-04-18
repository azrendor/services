local WeaponBase = require(script.Parent)

--// Pistol Base Class
local Pistol = {}
Pistol.__index = Pistol

function Pistol.new(player, tool, settings)
	return WeaponBase.new(player, tool, settings)
end

return Pistol