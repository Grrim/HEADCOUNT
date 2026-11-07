--!strict
-- Same lifecycle as the server's loader: require all, init all, start all, isolate each failure.
local Loader = {}

function Loader.run(folder: Instance): { [string]: any }
	local controllers: { [string]: any } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = xpcall(require, debug.traceback, child)
			if ok then
				controllers[child.Name] = result
			else
				warn(`[Loader] {child.Name} failed to load: {result}`)
			end
		end
	end
	for name, controller in controllers do
		if controller.init then
			local ok, err = xpcall(controller.init, debug.traceback, controllers)
			if not ok then
				warn(`[Loader] {name}.init failed: {err}`)
			end
		end
	end
	for name, controller in controllers do
		if controller.start then
			task.spawn(function()
				local ok, err = xpcall(controller.start, debug.traceback)
				if not ok then
					warn(`[Loader] {name}.start failed: {err}`)
				end
			end)
		end
	end
	return controllers
end

return Loader
