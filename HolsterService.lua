--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

--// Service
local HolsterService = Knit.CreateService{
	Name = 'HolsterService',
	HolsteredWeapons = {},
}

--// Public API
function HolsterService:Holster(player, weapon)
	if not player or not weapon then return end
	local character = player.Character
	if not character then
		return
	end
	local torso = character:FindFirstChild('Torso')
	local holstersFolder = player.Character:WaitForChild('Holsters', 2)
	if not torso or not holstersFolder then
		return
	end
	
	-- If the player already has a holstered model, remove it
	if self.HolsteredWeapons[player.Name] then
		self.HolsteredWeapons[player.Name]:Destroy()
		self.HolsteredWeapons[player.Name] = nil
	end
	
	local holsterModel = ReplicatedStorage.Models:FindFirstChild(weapon.Name)
	if not holsterModel then
		return
	end
	
	local holster = holsterModel:Clone()
	local handle = holster:FindFirstChild('Handle')
	if not handle then
		return
	end
	
	local weld = Instance.new('Weld')
	weld.Part0 = torso
	weld.Part1 = handle
	weld.C1 = weapon:GetAttribute('HolsterCFrame')
	weld.Parent = holster
	
	holster.Parent = holstersFolder
	
	self.HolsteredWeapons[player.Name] = holster
end

function HolsterService:Unholster(player)
	if self.HolsteredWeapons[player.Name] then
		self.HolsteredWeapons[player.Name]:Destroy()
		self.HolsteredWeapons[player.Name] = nil
	end
end

--// Knit Lifecycle
function HolsterService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local holstersFolder = Instance.new('Folder')
			holstersFolder.Name = 'Holsters'
			holstersFolder.Parent = character
		end)
	end)
	
end

return HolsterService