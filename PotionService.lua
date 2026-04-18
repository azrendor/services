--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local Players = game:GetService('Players')

--// Service
local PotionService = Knit.CreateService {
	Name = 'PotionService',
}

--// Public API
function PotionService:ConsumePotion(player, tool)
	if not tool or not player.Character then 
		return 
	end

	if tool.Parent ~= player.Backpack and tool.Parent ~= player.Character then
		return 
	end

	local pathway = tool:GetAttribute('Pathway')
	if not pathway then 
		return 
	end

	local Drinking = tool:GetAttribute('Drinking')
	if Drinking then return end

	local humanoid = player.Character:FindFirstChildWhichIsA('Humanoid')
	if not humanoid then return end

	self.MovementService:DisableMovementForPlayer(player)

	--> Set restricted state for player.
	self.WeaponsService:SetRestricted(player, true)

	--> Declare the potion tracks.
	local drinkTrack = humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Animations.PotionDrink)
	local openTrack = humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Animations.PotionOpen)
	local heavyBreathTrack = humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Animations.HeavyBreath)
	heavyBreathTrack.Priority = Enum.AnimationPriority.Action2

	local drank = false
	local thread
	tool.Unequipped:Connect(function()
		if drank then return end

		if thread then
			coroutine.close(thread)

			--> Stop animations.
			if openTrack.IsPlaying then
				openTrack:Stop()
			end

			if drinkTrack.IsPlaying then
				drinkTrack:Stop()
			end

			if heavyBreathTrack.IsPlaying then
				heavyBreathTrack:Stop()
			end

			--> Set the tool drinking attribute back to false to let it be consumed again later on.
			tool:SetAttribute('Drinking', false)

			self.MovementService:EnableMovementForPlayer(player)
		end
	end)

	thread = task.spawn(function()
		tool:SetAttribute('Drinking', true)

		openTrack:Play()
		openTrack:GetMarkerReachedSignal('Open'):Once(function()
			local sound = game.ReplicatedStorage.Sounds.PotionOpen:Clone()
			sound.PlayOnRemove = true
			sound.Parent = player.Character.HumanoidRootPart
			sound:Destroy()
		end)
		openTrack.Ended:Wait()

		drinkTrack:Play()
		drinkTrack:GetMarkerReachedSignal('Drink'):Once(function()
			local sound = game.ReplicatedStorage.Sounds.PotionDrink:Clone()
			sound.PlayOnRemove = true
			sound.Parent = player.Character.HumanoidRootPart
			sound:Destroy()
		end)
		drinkTrack.Ended:Wait()

		heavyBreathTrack:Play()
		heavyBreathTrack:GetMarkerReachedSignal('Start'):Once(function()
			local sound = game.ReplicatedStorage.Sounds.HeavyBreath:Clone()
			sound.Parent = player.Character:FindFirstChild('HumanoidRootPart') or workspace
			sound.PlayOnRemove = true
			sound:Destroy()

			local effect = {
				Name = 'PathwayObtainment',
				Pathway = pathway,
				Sequence = self.PathwayService:GetNextSequence(player:GetAttribute('Sequence')),
				TotalPhrases = 30
			}
			self.EffectsService:TriggerEffectForPlayer(player, effect)

			drank = true
			tool:Destroy()
		end)

		heavyBreathTrack.Ended:Wait()		
		self.WeaponsService:SetRestricted(player, false)

		local sound = game.ReplicatedStorage.Sounds.MagicGained:Clone()
		sound.Parent = player.Character:FindFirstChild('HumanoidRootPart') or workspace
		sound.PlayOnRemove = true
		sound:Destroy()

		self.MovementService:EnableMovementForPlayer(player)

		if player:GetAttribute('Sequence') then
			self.PathwayService:AdvanceSequence(player)
		elseif self.PathwayService:CanAssignPathway(player) then
			self.PathwayService:AssignInitialPathway(player, pathway)
		end
	end)
end

--// Knit Lifecycle
function PotionService:KnitStart()
	self.EffectsService = Knit.GetService('EffectsService')
	self.WeaponsService = Knit.GetService('WeaponsService')
	self.DataService = Knit.GetService('DataService')
	self.MovementService = Knit.GetService('MovementService')
	self.PathwayService = Knit.GetService('PathwayService')
end

return PotionService