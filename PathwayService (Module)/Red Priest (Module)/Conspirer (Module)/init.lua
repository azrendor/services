local Sequence = {
	Name = script.Name,
	Sequence = 2,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
		ColorSequenceKeypoint.new(0.358, Color3.fromRGB(93, 0, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(112, 0, 0))
	})
	,
	
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