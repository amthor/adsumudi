rockspec_format = "3.0"
package = "adsumudi"
version = "dev-1"
source = {
	url = ".",
}
description = {
	summary = "Mathe-Übungsblätter für die Grundschule als PDF (Typst, alternativ LaTeX)",
}
dependencies = {
	"lua >= 5.3",
	-- only for the LaTeX backend (--satz latex); dkjson is vendored in dkjson/
	"etlua >= 1.3",
}
test_dependencies = {
	"busted",
}
build = {
	type = "none",
}
