local Players = game:GetService("Players")

local Packages = script.Parent.Parent
local Sift = require(Packages.Sift)
local Signal = require(Packages.Signal)

local SerivcePlayerData = {}

export type ServicePlayerData<T> = {
	get: (self: ServicePlayerData<T>, player: Player) -> T,
	onPlayerAdded: Signal.Signal<Player, T>,
	onPlayerRemoving: Signal.Signal<Player, T>,
	destroy: (self: ServicePlayerData<T>) -> (),
}

function SerivcePlayerData.new<T>(dataTemplate: T, service: any?): ServicePlayerData<T>
	local self = {
		onPlayerAdded = Signal.new(),
		onPlayerRemoving = Signal.new(),
	}

	local servicePlayerData = {}

	local function addPlayer(player: Player)
		if servicePlayerData[player] ~= nil then
			return
		end

		local newPlayerData = Sift.Dictionary.copyDeep(dataTemplate)
		servicePlayerData[player] = newPlayerData
		self.onPlayerAdded:Fire(player, newPlayerData)

		if service and service.playerAdded then
			service:playerAdded(player, newPlayerData)
		end
	end

	local function removePlayer(player: Player)
		local playerData = servicePlayerData[player]
		if playerData then
			servicePlayerData[player] = nil
			self.onPlayerRemoving:Fire(player, playerData)
		end
		if service and service.playerRemoving then
			service:playerRemoving(player, playerData)
		end
	end

	local addedConn = Players.PlayerAdded:Connect(addPlayer)
	local removeConn = Players.PlayerRemoving:Connect(removePlayer)

	self.destroy = function(_)
		addedConn:Disconnect()
		removeConn:Disconnect()
		self.onPlayerAdded:Destroy()
		self.onPlayerRemoving:Destroy()
		for _, player in Players:GetPlayers() do
			removePlayer(player)
		end
	end

	self.get = function(_, player: Player): T
		local playerData = servicePlayerData[player]
		assert(playerData ~= nil, "Service player data not found for player: " .. player.Name)
		return playerData
	end

	return self
end

return SerivcePlayerData
