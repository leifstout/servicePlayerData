--!strict
local RunService = game:GetService("RunService")

local Packages = script.Parent.Parent
local Signal = require(Packages.Signal)
local NetworkerUtils = require(script.Parent.NetworkerUtils)

local NetworkServiceContainer = if RunService:IsRunning()
	then script.Parent:WaitForChild("_NetworkServiceContainer") :: Folder
	else nil :: any

type NetworkTag = NetworkerUtils.NetworkTag

--[=[
	NetworkerClient facilitates the communication of client-sided networking and handles server networking instructions  
	@class NetworkerClient  
]=]
local NetworkerClient = {}
NetworkerClient.__index = NetworkerClient

export type NetworkerClient = typeof(setmetatable(
	{} :: {
		networkTag: NetworkTag,
		remote: RemoteEvent,
		instanceConn: RBXScriptConnection?,
		changedSignals: { [string]: Signal.Signal<any> },
	},
	NetworkerClient
))

--[=[
	Constructs a new NetworkerClient  
	@param networkTag NetworkTag -- The unqiue tag of the networker  
	@param module {} -- The class or service the networker will be communicating with  
	@return NetworkerClient  
]=]
function NetworkerClient.new(networkTag: NetworkTag, module: {}): NetworkerClient
	local self = {
		networkTag = networkTag,
		changedSignals = {},
	}

	local strName

	setmetatable(self, NetworkerClient)

	if not RunService:IsRunning() then
		self.remote = nil :: any
		return self
	end

	if typeof(networkTag) == "Instance" then
		self.remote = networkTag:WaitForChild(NetworkerUtils.INSTANCE_TAG) :: RemoteEvent
		strName = networkTag:GetFullName()
		self.instanceConn = networkTag.Destroying:Once(function()
			self:destroy()
		end) :: RBXScriptConnection
	else
		self.remote = NetworkServiceContainer:WaitForChild(networkTag) :: RemoteEvent
		strName = networkTag
	end

	self.remote.OnClientEvent:Connect(function(method: string, key: string, ...: any?)
		if method == NetworkerUtils.SET_TAG then
			module[key] = ...
			if self.changedSignals[key] then
				self.changedSignals[key]:Fire(module[key])
			end
			return
		end

		assert(module[method], "Method " .. method .. " does not exist on networkTag " .. strName)
		module[method](module, key, ...)
	end)

	return self
end

--[=[
	Gets the Signal for the given key. Changed signals are used to notify the client when a value has been changed on the server using the set methods.  
	@param key string -- The key of the signal  
	@return Signal -- Returns the Signal  
]=]
function NetworkerClient.getServerChangedSignal<T>(self: NetworkerClient, key: string): Signal.Signal<T>
	if not self.changedSignals[key] then
		self.changedSignals[key] = Signal.new()
	end

	return self.changedSignals[key]
end

--[=[
	Requests a method on the server.  
	@param method string -- The method to fire  
	@param ... any -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerClient.fire(self: NetworkerClient, method: string, ...: any?): ()
	if RunService:IsRunning() then
		self.remote:FireServer(method, ...)
	end
end

--[=[
	Destroys the NetworkerClient and cleans up all connections  
	@return ()  
]=]
function NetworkerClient.destroy(self: NetworkerClient): ()
	if self.remote then
		self.remote:Destroy()
	end
	for _, signal in self.changedSignals do
		signal:Destroy()
	end
	if self.instanceConn then
		self.instanceConn:Disconnect()
	end
end

return NetworkerClient
