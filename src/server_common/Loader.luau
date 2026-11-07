--!strict
-- The whole "framework": require every service, init them all, then start them all. Services reach
-- each other through the table passed to init, which keeps require chains flat.
local Loader = {}

function Loader.run(folder: Instance): { [string]: any }
	local services: { [string]: any } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			services[child.Name] = require(child) :: any
		end
	end
	for name, service in services do
		if service.init then
			local ok, err = xpcall(service.init, debug.traceback, services)
			if not ok then
				warn(`[Loader] {name}.init failed: {err}`)
			end
		end
	end
	for name, service in services do
		if service.start then
			task.spawn(function()
				local ok, err = xpcall(service.start, debug.traceback)
				if not ok then
					warn(`[Loader] {name}.start failed: {err}`)
				end
			end)
		end
	end
	return services
end

return Loader
