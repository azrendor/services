--// Dependencies
local Knit = require(game:GetService('ReplicatedStorage').Packages.Knit)
local Players = game:GetService('Players')

--// Service
local PassivesService = Knit.CreateService {
	Name = 'PassivesService',

	LoadedPassives = {},       -- [PassiveName] = Module
	ActivePassives = {}        -- [PlayerName] = { [PassiveName] = Module | Table }
}

--// Methods
local function GetOrCreatePassivesFolder(character: Model): Folder
	local folder = character:FindFirstChild('Passives')
	if not folder then
		folder = Instance.new('Folder')
		folder.Name = 'Passives'
		folder.Parent = character
	end
	return folder
end

function PassivesService:LoadPassive(passive: ModuleScript | Table, passiveName: string)
	-- Loads and caches the passive
	
	if self.LoadedPassives[passiveName] then
		return
	end

	self.LoadedPassives[passiveName] = require(passive)
	
	return self.LoadedPassives[passiveName]
end

function PassivesService:ApplyPassive(player: Player, passive: ModuleScript | Table, passiveName: string)
	-- Applies a passive to a player

	local passiveModule
	if typeof(passive) == 'ModuleScript' then
		passiveModule = self:LoadPassive(passive, passiveName)
	else
		passiveModule = passive
	end

	self.ActivePassives[player.Name] = self.ActivePassives[player.Name] or {}

	if not self.ActivePassives[player.Name][passiveName] then
		self.ActivePassives[player.Name][passiveName] = passiveModule

		local character = player.Character
		if character then
			local folder = GetOrCreatePassivesFolder(character)

			local bool = folder:FindFirstChild(passiveName)
			if not bool then
				bool = Instance.new('BoolValue')
				bool.Name = passiveName
				bool.Value = true
				bool.Parent = folder
			end
		end
		
		if passiveModule.OnApply then
			passiveModule:OnApply(player)
		end
	end
end

function PassivesService:RemovePassive(player: Player, passiveName: string)
	-- Removes a passive from a player

	local active = self.ActivePassives[player.Name]
	if active and active[passiveName] then
		local passiveModule = active[passiveName]

		if passiveModule.OnRemove then
			passiveModule.OnRemove(player)
		end

		local character = player.Character
		if character then
			local folder = character:FindFirstChild('Passives')
			if folder then
				local bool = folder:FindFirstChild(passiveName)
				if bool then
					bool:Destroy()
				end
			end
		end

		active[passiveName] = nil
	end
end


function PassivesService:RemoveAllPassives(player: Player)
	-- Removes all passives from a player

	local active = self.ActivePassives[player.Name]
	if not active then return end

	for passiveName, passiveModule in pairs(active) do
		if passiveModule.OnRemove then
			passiveModule.OnRemove(player)
		end
	end

	self.ActivePassives[player.Name] = nil
end

function PassivesService:GetPassives(player: Player)
	-- Returns all passives of a player

	return self.ActivePassives[player.Name]
end

function PassivesService:GetPassive(player, passiveName: string)
	if not self.ActivePassives[player.Name] then
		return nil
	end
	
	return self.ActivePassives[player.Name][passiveName]
end

function PassivesService:FirePassiveEvent(player: Player, eventName: string, args: any)
	-- Dispatch an event to all active passives

	local playerPassives = self.ActivePassives[player.Name]
	if not playerPassives then return end
	
	for _, passiveModule in pairs(playerPassives) do
		if passiveModule[eventName] then
			task.spawn(function()
				passiveModule[eventName](passiveModule, player, args)
			end)
		end
	end
end

return PassivesService
