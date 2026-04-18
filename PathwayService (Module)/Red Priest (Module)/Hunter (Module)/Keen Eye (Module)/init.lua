--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local EffectsService = Knit.GetService('EffectsService')

--// Passive
local Passive = {}

function Passive:OnHitConfirmed(player, args)
	local hightlightEffect = {
		Name = 'Highlight',
		Target = args.Target,
		FillColor = player:GetAttribute('PathwayColor').Keypoints[1].Value,
		FillTransparency = 0.8,
		OutlineTransparency = 1,
		Duration = 0.25
	}
	EffectsService:TriggerEffectForPlayer(player, hightlightEffect)
end

return Passive
