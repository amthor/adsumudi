rockspec_format = "3.0"
package = "rechenblatt"
version = "dev-1"
source = {
	url = ".",
}
description = {
	summary = "Mathe-Übungsblätter für die Grundschule als LaTeX/PDF",
}
dependencies = {
	"lua >= 5.3",
	"etlua >= 1.3",
}
test_dependencies = {
	"busted",
}
build = {
	type = "none",
}
