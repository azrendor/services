local Sequence = {
	Name = script.Name,
	Sequence = 3,
	Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 0.188235, 0.027451)), ColorSequenceKeypoint.new(1, Color3.new(1, 0.639216, 0.0196078)) }),
	
	Skills = {}
}

for _, skill in pairs(script:GetChildren()) do
	if skill:IsA("ModuleScript") then
		Sequence.Skills[skill.Name] = require(skill)
	end
end

function Sequence:ApplyAttributes(player)
	player:SetAttribute('PathwayColor', Sequence.Color)
end

return Sequence