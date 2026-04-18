--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)

--// Type
type EffectData = {
	Name: string,
	Target: Instance,
	Origin: Vector3,
	RenderDistance: number
}

--// Service
local EffectsService = Knit.CreateService{
	Name = 'EffectsService',
	Client = {
		EffectSignal = Knit.CreateSignal(),
		EffectForPlayerSignal = Knit.CreateSignal()
	}
}

--// Public API
function EffectsService:TriggerEffect(effectData: EffectData, ...)
	self.Client.EffectSignal:FireAll(effectData, ...)
end

function EffectsService:TriggerEffectForPlayer(player, effectData: EffectData, ...)
	self.Client.EffectForPlayerSignal:Fire(player, effectData, ...)
end

return EffectsService