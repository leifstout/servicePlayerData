local server = require(script.NetworkerServer)
local client = require(script.NetworkerClient)

export type Server = server.NetworkerServer
export type Client = client.NetworkerClient

return {
	server = server,
	client = client,
}
