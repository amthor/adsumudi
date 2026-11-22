local shell = require("adsumudi.shell")

describe("shell.quote", function()
	it("macht beliebigen Text zu genau einem Shell-Wort", function()
		for _, text in ipairs({ "einfach", "mit leer zeichen", "it's", "$HOME `x` \\ \"q\"", "" }) do
			local p = io.popen("printf %s " .. shell.quote(text))
			assert.are.equal(text, p:read("a"))
			p:close()
		end
	end)
end)
