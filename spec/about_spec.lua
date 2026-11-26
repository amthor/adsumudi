local version = require("adsumudi.version")

describe("version.VERSION", function()
	it("ist eine SemVer-Versionsnummer", function()
		local v = version.VERSION
		assert.is_string(v)
		-- MAJOR.MINOR.PATCH, optionally followed by a pre-release such as -rc.1
		assert.matches("^%d+%.%d+%.%d+", v)
		local core, pre = v:match("^(%d+%.%d+%.%d+)(.*)$")
		assert.is_nil(("." .. core):find("%.0%d")) -- no leading zeros
		assert.matches("^[%w.%-]*$", pre:sub(2)) -- pre-release identifiers
		assert.truthy(pre == "" or pre:sub(1, 1) == "-")
	end)
end)
