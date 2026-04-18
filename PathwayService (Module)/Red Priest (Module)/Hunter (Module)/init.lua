local Sequence = {
	Name = script.Name,
	Sequence = 4,
	Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0.172549, 1, 0.435294)), ColorSequenceKeypoint.new(1, Color3.new(0.466667, 1, 0.909804)) }),

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