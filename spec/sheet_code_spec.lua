local sheet_code = require("rechenblatt.sheet_code")
local tasks = require("rechenblatt.tasks")

describe("sheet_code", function()
	local v = tasks.GENERATOR_VERSION

	it("kodiert alle festlegenden Optionen", function()
		local code = sheet_code.encode({ operations = { "mul", "add" }, min = 2, max = 50, count = 12, seed = 48213 })
		assert.are.equal(v .. "-MA-2-50-12-48213", code)
	end)

	it("dekodiert, was es kodiert hat", function()
		local opts = { operations = { "sub", "div", "add", "mul" }, min = 1, max = 100, count = 22, seed = 0 }
		assert.are.same(opts, sheet_code.decode(sheet_code.encode(opts)))
	end)

	it("ignoriert Groß-/Kleinschreibung und Leerzeichen am Rand", function()
		local decoded = sheet_code.decode("  " .. v .. "-as-1-100-22-48213 ")
		assert.are.same({ "add", "sub" }, decoded.operations)
		assert.are.equal(48213, decoded.seed)
		assert.are.equal("integer", math.type(decoded.count))
	end)

	it("lehnt fehlerhafte Codes ab", function()
		local bad = {
			(v + 1) .. "-AS-1-100-22-1", -- other generator version
			v .. "-AX-1-100-22-1", -- unknown letter
			v .. "-AA-1-100-22-1", -- duplicate operation
			v .. "--1-100-22-1", -- no operations
			v .. "-AS-1-100-22", -- too few parts
			v .. "-AS-1-100-22-1-9", -- too many parts
			v .. "-AS-1-1x0-22-1", -- not a number
		}
		for _, code in ipairs(bad) do
			assert.has_error(function()
				sheet_code.decode(code)
			end)
		end
	end)

	it("nennt bei falscher Version beide Versionen", function()
		local ok, msg = pcall(sheet_code.decode, (v + 1) .. "-AS-1-100-22-1")
		assert.is_false(ok)
		assert.truthy(msg:find("Version " .. (v + 1), 1, true))
		assert.truthy(msg:find("Version " .. v, 1, true))
	end)
end)
