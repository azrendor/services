local Pathway = {}
local Sequences = {}
local CachedSkills = {} -- Cache to speed up lookups

for _, moduleScript in ipairs(script:GetChildren()) do
	if moduleScript:IsA('ModuleScript') then
		local sequence = require(moduleScript)
		Sequences[sequence.Sequence] = sequence

		-- Populate CachedSkills
		for name, skill in pairs(sequence.Skills or {}) do
			CachedSkills[name] = skill
		end
	end
end

function Pathway:ApplyAttributes(player, sequenceNumber)
	local sequence = Sequences[sequenceNumber]
	if sequence and sequence.ApplyAttributes then
		sequence:ApplyAttributes(player)
	end
end

function Pathway:GetSequence(sequenceNumber)
	return Sequences[sequenceNumber]
end

function Pathway:GetAllSequences()
	return Sequences
end

function Pathway:GetSkill(skillName)
	return CachedSkills[skillName]
end

return Pathway
