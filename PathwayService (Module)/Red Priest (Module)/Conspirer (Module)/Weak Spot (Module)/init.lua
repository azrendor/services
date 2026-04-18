local PassivesService = require(game:GetService('ReplicatedStorage').Packages.Knit).GetService('PassivesService')
local Passive = {}

function Passive:OnApply(player)
	local critPassive = PassivesService:GetPassive(player, 'CriticalHit')

	if critPassive then
		critPassive.Chance = 25
		critPassive.Multiplier = 1.3
	end
end

return Passive
