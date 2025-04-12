--[=[
	@type ClientAccess { (any) -> any }  
	@within NetworkServiceServer  
]=]
export type ClientAccess = { (any) -> any }

--[=[
	@type NetworkTag string | Instance  
	@within NetworkServiceServer  
]=]
export type NetworkTag = string | Instance

return {
	SET_TAG = "__set",
	INSTANCE_TAG = "__instance_networker",
}
