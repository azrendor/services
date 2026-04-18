--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local Players = game:GetService('Players')

--// Variables
local ToolsFolder = game.ReplicatedStorage:WaitForChild('Tools'):WaitForChild('Skills')

--// Service
local PathwayService = Knit.CreateService {
	Name = 'PathwayService',
	Client = {
		SkillActivate = Knit.CreateSignal(),
		ConsumePotion = Knit.CreateSignal(),
		RequestClosestCharacterToMouse = Knit.CreateSignal(),
		SetClientCooldownSignal = Knit.CreateSignal(),
	},
	
	
	Pathways = {},
	Cooldowns = {},
	PlayerData = {},
	Silenced = {} -- Players that are disabled of using skills.
}

--// Public API

function PathwayService:DisablePlayerSkillUsage(player, duration: number?)
	if not player then return end
	if not self.Silenced[player.Name] then
		self.Silenced[player.Name] = true
	end
	if duration then
		task.delay(duration, function()
			self.Silenced[player.Name] = nil
		end)
	end
end

function PathwayService:EnablePlayerSkillUsage(player)
	if not player then return end
	
	if self.Silenced[player.Name] then
		self.Silenced[player.Name] = nil
	end
end


function PathwayService:CanUseSkill(player, skillId)
	if self:_IsPlayerSkillsEnabled(player) then
		return false
	end
	
	local playerCooldowns = self.Cooldowns[player.Name]
	if not playerCooldowns then return true end -- failsafe

	local cooldownEnd = playerCooldowns[skillId]
	if not cooldownEnd then return true end

	return tick() >= cooldownEnd
end

function PathwayService:SetCooldown(player, skillId, duration)
	self.Cooldowns[player.Name][skillId] = tick() + duration
end

function PathwayService:ActivateSkill(player, pathway, skillName, ...)
	if not self.Pathways[pathway] then
		warn('Pathway does not exist:', pathway)
		return
	end

	local skill = self.Pathways[pathway]:GetSkill(skillName)
	if not skill then
		warn('Pathway skill does not exist:', skillName)
		return
	end

	if not skill.Activate then
		warn('Pathway skill does not have activate method:', skillName)
		return
	end

	local skillId = pathway .. '_' .. skillName

	if not self:CanUseSkill(player, skillId) then
		warn('Cannot use skill:', skillName)
		return
	end

	-- Activate and set cooldown
	skill.Activate(player, ...)
	self:SetCooldown(player, skillId, skill.Cooldown or 1)
end

function PathwayService:IsActiveSkill(skillName)
	return ToolsFolder:FindFirstChild(skillName) ~= nil
end

function PathwayService:GiveSkillTool(player, skillName)
	local toolTemplate = ToolsFolder:FindFirstChild(skillName)
	if not toolTemplate then return end

	for _, location in ipairs({ player.Backpack, player.Character }) do
		local existing = location:FindFirstChild(skillName)
		if existing then existing:Destroy() end
	end

	toolTemplate:Clone().Parent = player.Backpack
end

function PathwayService:RemoveSkillTool(player, skillName)
	for _, location in ipairs({ player.Backpack, player.Character }) do
		local existing = location:FindFirstChild(skillName)
		if existing then existing:Destroy() end
	end
end

function PathwayService:ApplySkills(player, sequence)
	for skillName, skillModule in pairs(sequence.Skills or {}) do
		if self:IsActiveSkill(skillName) then
			self:GiveSkillTool(player, skillName)
		else
			if not self.PassivesService:GetPassive(player, skillName) then
				self.PassivesService:ApplyPassive(player, skillModule, skillName)
			end
		end
	end
end

function PathwayService:RemoveSkills(player, sequence)
	for skillName, _ in pairs(sequence.Skills or {}) do
		self:RemoveSkillTool(player, skillName)
		self.PassivesService:RemovePassive(player, skillName)
	end
end

function PathwayService:AdvanceSequence(player)
	local profile = self.DataService:GetProfile(player)
	if not profile then return false end

	local current = profile.Data.Pathway.Sequence
	local nextSequence = self:GetNextSequence(current)

	if not nextSequence then
		return false
	end

	print(nextSequence)
	player:SetAttribute('Sequence', nextSequence)

	return true
end

function PathwayService:GetNextSequence(current)
	if current == nil then
		return 4
	end
	if current <= 0 then
		return nil
	end

	return current - 1
end

function PathwayService:CanAssignPathway(player)
	local profile = self.DataService:GetProfile(player)
	if not profile then
		return false
	end

	return profile.Data.Pathway.Name == ""
end

function PathwayService:AssignInitialPathway(player, pathway)
	if not self:CanAssignPathway(player) then
		return false
	end

	local profile = self.DataService:GetProfile(player)

	local initialSequence = 4 -- hardcoded...

	profile.Data.Pathway.Name = pathway
	profile.Data.Pathway.Sequence = initialSequence

	self:_Apply(player, pathway, initialSequence)

	return true
end

function PathwayService:SetupPlayer(player, profile)

	--// For testing
	profile.Data.Pathway.Name = ''
	--profile.Data.Pathway.Sequence = 2
	--\\

	self.Cooldowns[player.Name] = {}
	self.PlayerData[player] = {
		Pathway = '',
		Sequence = 4,
		Profile = profile,
		AttributeConnections = {},
	}

	local pathway = profile.Data.Pathway.Name
	local sequence = profile.Data.Pathway.Sequence

	if pathway ~= '' then
		self:_Apply(player, pathway, sequence)
	end

	player.CharacterAdded:Connect(function()
		self:_Apply(player, pathway, sequence)
	end)

	self:_ConnectAttributeSignals(player, profile)
end

--// Private API

function PathwayService:_IsPlayerSkillsEnabled(player)
	return self.Silenced[player.Name]
end

function PathwayService:_Apply(player, pathway, sequence)
	local pathwayModule = self.Pathways[pathway]
	if not pathwayModule then return end
	
	-- Disconnect change signals during apply
	local attrConns = self.PlayerData[player].AttributeConnections or {}
	for _, conn in ipairs(attrConns) do
		conn:Disconnect()
	end

	self:_Clear(player)

	player:SetAttribute('Pathway', pathway)
	player:SetAttribute('Sequence', sequence)

	for i = 4, sequence, -1 do
		local seq = pathwayModule:GetSequence(i)
		if seq then
			self:ApplySkills(player, seq)
		end
	end

	pathwayModule:ApplyAttributes(player, sequence)
	self:_ConnectAttributeSignals(player, self.PlayerData[player].Profile)
end

function PathwayService:_Clear(player)
	local data = self.PlayerData[player]
	if not data then return end

	local pathway = data.Pathway
	if not pathway then return end

	local current = self.Pathways[pathway]
	if not current then return end

	for i = 4, 0, -1 do
		local seq = current:GetSequence(i)
		if seq then
			self:RemoveSkills(player, seq)
		end
	end
end

function PathwayService:_ConnectAttributeSignals(player, profile)
	local conns = {}

	table.insert(conns, player:GetAttributeChangedSignal('Pathway'):Connect(function()
		local newPathway = player:GetAttribute('Pathway')
		if not newPathway then return end

		profile.Data.Pathway.Name = newPathway
		self.PlayerData[player].Pathway = newPathway

		local sequence = player:GetAttribute('Sequence') or 4
		self:_Apply(player, newPathway, sequence)
	end))

	table.insert(conns, player:GetAttributeChangedSignal('Sequence'):Connect(function()
		local newSequence = player:GetAttribute('Sequence')
		if not newSequence then  return end
		profile.Data.Pathway.Sequence = newSequence
		self.PlayerData[player].Sequence = newSequence

		local pathway = player:GetAttribute('Pathway')
		if not pathway then return end

		local pathwayModule = self.Pathways[pathway]
		if not pathwayModule then return end
		
		local oldSequence = profile.Data.Pathway.Sequence or 4
		if newSequence > oldSequence then
			for i = oldSequence, newSequence - 1, -1 do
				local seq = pathwayModule:GetSequence(i)
				if seq then
					self:RemoveSkills(player, seq)
				end
			end
		end
		
		self:_Apply(player, pathway, newSequence)
	end))

	self.PlayerData[player].AttributeConnections = conns
end

--// Knit Lifecycle
function PathwayService:KnitStart()
	-- Get the services
	self.PassivesService = Knit.GetService('PassivesService')
	self.EffectsService = Knit.GetService('EffectsService')
	self.MovementService = Knit.GetService('MovementService')
	self.WeaponsService = Knit.GetService('WeaponsService')
	self.DataService = Knit.GetService('DataService')

	local PotionService = Knit.GetService('PotionService')
	
	
	--Get the pathway modules.
	for _, pathway in pairs(script:GetChildren()) do
		if pathway:IsA('ModuleScript') then
			local module = require(pathway)
			self.Pathways[pathway.Name] = module
		end
	end

	Players.PlayerAdded:Connect(function(player)
		self.DataService:WaitForProfile(player):andThen(function(profile)
			PathwayService:SetupPlayer(player, profile)
		end):catch(warn)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Cooldowns[player.Name] = nil
	end)
	
	-- Listen for client skill activations
	PathwayService.Client.SkillActivate:Connect(function(player, tool, ...)
		if not tool or not player.Character then 
			return 
		end
		
		if tool.Parent ~= player.Backpack and tool.Parent ~= player.Character then
			return 
		end
		
		local pathway, skill = tool:GetAttribute('Pathway'), tool:GetAttribute('Skill')
		if not pathway or not skill then 
			return 
		end
		
		PathwayService:ActivateSkill(player, pathway, tool.Name, ...)
	end)
	
	PathwayService.Client.ConsumePotion:Connect(function(player, tool)
		PotionService:ConsumePotion(player, tool)
	end)
end

return PathwayService
