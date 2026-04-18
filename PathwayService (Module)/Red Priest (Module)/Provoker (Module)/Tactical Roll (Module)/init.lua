--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)

local DodgeForce = 190
local DodgeDuration = 0.4
--// Passive
local Passive = {}

function Passive:SetDodgeModifiers(player, args)
	local dodgeSettings = args.DodgeSettings
	dodgeSettings.duration = DodgeDuration
	dodgeSettings.force = DodgeForce
end

return Passive
