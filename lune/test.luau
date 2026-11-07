--!strict
-- Headless test runner: `lune run test` from the project root.
-- Every tests/*.spec.luau returns { [name]: () -> () }. A test passes unless it errors.
local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0
local names = fs.readDir("tests")
table.sort(names)
for _, fileName in names do
	if not fileName:match("%.spec%.luau$") then
		continue
	end
	local requirePath = `tests/{fileName:gsub("%.luau$", "")}`
	local ok, spec = pcall(require, requirePath)
	if not ok then
		failed += 1
		print(`FAIL {fileName} (could not load): {spec}`)
		continue
	end
	for testName, testFn in spec :: { [string]: () -> () } do
		local testOk, err = pcall(testFn)
		if testOk then
			passed += 1
		else
			failed += 1
			print(`FAIL {fileName} :: {testName}\n     {err}`)
		end
	end
end
print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
