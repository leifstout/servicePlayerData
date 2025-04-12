--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NetworkerUtils = require(script.Parent.NetworkerUtils)

--[[if RunService:IsClient() then
	return nil
end]]

local NetworkServiceContainer = nil
if RunService:IsRunning() and RunService:IsServer() then
	NetworkServiceContainer = Instance.new("Folder")
	NetworkServiceContainer.Name = "_NetworkServiceContainer"
	NetworkServiceContainer.Parent = script.Parent
end

type NetworkTag = NetworkerUtils.NetworkTag
type ClientAccess = NetworkerUtils.ClientAccess

--[=[
	NetworkerServer facilitates the communication of server-sided networking and handles client networking requests  
	@class NetworkerServer  
]=]
local NetworkerServer = {}
NetworkerServer.__index = NetworkerServer

--[=[
	@within NetworkerServer  
	@type PlayerGroup Player | { Player }  
]=]
type PlayerGroup = Player | { Player }

export type NetworkerServer = typeof(setmetatable(
	{} :: {
		networkTag: NetworkTag,
		remote: RemoteEvent,
		instanceConn: RBXScriptConnection?,
		recipients: { Player }?,
	},
	NetworkerServer
))

--[=[
	Constructs a new NetworkerServer  
	@param networkTag NetworkTag -- The unqiue tag of the networker  
	@param module table? -- The class or service the client will be communicating with  
	@param clientAccess ClientAccess? -- The methods that the client is allowed to call  
	@return NetworkerServer  
]=]
function NetworkerServer.new(networkTag: NetworkTag, module: {}?, clientAccess: ClientAccess?): NetworkerServer
	local self = {
		networkTag = networkTag,
	}

	local remote = Instance.new("RemoteEvent")
	self.remote = remote

	setmetatable(self, NetworkerServer)

	if typeof(networkTag) == "Instance" then
		remote.Name = NetworkerUtils.INSTANCE_TAG
		remote.Parent = networkTag
		self.instanceConn = networkTag.Destroying:Once(function()
			self:destroy()
		end) :: RBXScriptConnection
	else
		remote.Name = networkTag
		remote.Parent = NetworkServiceContainer
	end

	if not clientAccess then
		return self
	end

	assert(module, "Module must be provided when clientAccess is set")

	remote.OnServerEvent:Connect(function(player: Player, method: string, ...: any?)
		local func = module[method]

		if not func then
			warn("Method " .. method .. " does not exist on module", networkTag)
			return
		end

		if not table.find(clientAccess, func) then
			warn(player.Name .. " attempted to call restricted method " .. method .. " on service", networkTag)
			return
		end

		func(module, player, ...)
	end)

	return self
end

--[=[
	Adds a player to the list of recipients  
	@param player Player -- The player to add to the list of recipients  
	@return ()  
]=]
function NetworkerServer.addRecipient(self: NetworkerServer, player: Player): ()
	if not self.recipients then
		self.recipients = {}
	end

	assert(self.recipients, "Recipients list is nil")
	table.insert(self.recipients, player)
end

--[=[
	Removes a player from the list of recipients  
	@param player Player -- The player to remove from the list of recipients  
	@return ()  
]=]
function NetworkerServer.removeRecipient(self: NetworkerServer, player: Player): ()
	if not self.recipients then
		return
	end

	local index = table.find(self.recipients, player)
	if index then
		table.remove(self.recipients, index)
	end
end

--[=[
	Clears the list of recipients  
	@return ()  
]=]
function NetworkerServer.clearRecipients(self: NetworkerServer): ()
	self.recipients = nil
end

--[=[
	Fires a method to the given players  
	@param players PlayerGroup -- The players to fire the method to  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fire(self: NetworkerServer, players: PlayerGroup, method: string, ...: any?): ()
	if typeof(players) == "Instance" then
		self.remote:FireClient(players, method, ...)
		return
	end

	for _, player in players :: { Player } do
		self.remote:FireClient(player, method, ...)
	end
end

--[=[
	Fires a method to all players  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fireAll(self: NetworkerServer, method: string, ...: any?): ()
	self.remote:FireAllClients(method, ...)
end

--[=[
	Fires a method to all players except the given players  
	@param players PlayerGroup -- The players to exclude from the firing  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fireAllExcept(self: NetworkerServer, players: PlayerGroup, method: string, ...: any?): ()
	if typeof(players) == "Instance" then
		players = { players }
	end

	for _, player in Players:GetPlayers() do
		if not table.find(players :: { Player }, player) then
			self.remote:FireClient(player, method, ...)
		end
	end
end

--[=[
	Fires a method to the list of recipients  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fireRecipients(self: NetworkerServer, method: string, ...: any?): ()
	if not self.recipients then
		warn("No recipients set for service ", self.networkTag)
		return
	end

	self:fire(self.recipients, method, ...)
end

--[=[
	Sets a value to the given players  
	@param players PlayerGroup -- The players to set the value to  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.set(self: NetworkerServer, players: PlayerGroup, index: string, value: any?)
	self:fire(players, NetworkerUtils.SET_TAG, index, value)
end

--[=[
	Sets a value to all players  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.setAll(self: NetworkerServer, index: string, value: any?)
	self:fireAll(NetworkerUtils.SET_TAG, index, value)
end

--[=[
	Sets a value to all players except the given players  
	@param players PlayerGroup -- The players to exclude from the setting  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.setAllExcept(self: NetworkerServer, players: PlayerGroup, index: string, value: any?)
	self:fireAllExcept(players, NetworkerUtils.SET_TAG, index, value)
end

--[=[
	Sets a value to the list of recipients  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.setRecipients(self: NetworkerServer, index: string, value: any?): ()
	self:fireRecipients(NetworkerUtils.SET_TAG, index, value)
end

function NetworkerServer.destroying(_self: NetworkerServer): () end

--[=[
	Destroys the NetworkerServer  
	@return ()  
]=]
function NetworkerServer.destroy(self: NetworkerServer): ()
	self:destroying()
	self.remote:Destroy()
	self:clearRecipients()
	if self.instanceConn then
		self.instanceConn:Disconnect()
	end
end

return NetworkerServer
