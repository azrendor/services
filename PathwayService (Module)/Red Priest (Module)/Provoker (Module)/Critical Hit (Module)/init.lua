--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local EffectsService = Knit.GetService('EffectsService')

-- Passive
local Passive = {
	Chance = 10,
	Multiplier = 1.1
}

function Passive:OnHitConfirmed(player, args)
	local target = args.Target
	local damage = args.Damage

	if math.random(1, 100) <= self.Chance then
		local bonus = (damage * self.Multiplier) - damage
		target:FindFirstChildWhichIsA('Humanoid'):TakeDamage(bonus)
	end
end

return Passive

